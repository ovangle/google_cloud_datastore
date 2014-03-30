/*
 * Classes and definitions common to both reflection based and reflection-free datastore implementations.
 */
library  datastore.common;

import 'dart:async';
import 'dart:typed_data';
import 'dart:collection';

import 'package:crypto/crypto.dart' show CryptoUtils;
import 'package:fixnum/fixnum.dart';
import 'package:collection/wrappers.dart';
import 'package:logging/logging.dart';

import 'schema_v1_pb2.dart' as schema;
import 'connection.dart';

part 'common/key.dart';
part 'common/kind.dart';
part 'common/entity.dart';
part 'common/filter.dart';
part 'common/property.dart';
part 'common/property_instance.dart';
part 'common/query.dart';
part 'common/transaction.dart';

class Datastore {
  final Map<String, Kind> _entityKinds;
  final DatastoreConnection connection;
  
  final Logger logger = new Logger("datastore");
  
  /**
   * Create a new instance of the [Datastore].
   * 
   * [clientId] is the google assigned `Client ID` associated with a service account
   * authorised to access the datastore.
   * [datasetId] is the name of the dataset to connect to, usally 
   */
  Datastore(DatastoreConnection this.connection, List<Kind> entityKinds) :
    this._entityKinds = new Map.fromIterable(entityKinds, key: (kind) => kind.name);
    
  Kind kindByName(String name) {
    var kind = _entityKinds[name];
    if (kind == null) {
      throw new NoSuchKindError(name);
    }
    return kind;
  }
  
  /**
   * Allocate a new unnamed datastore key.
   */
  Future<Key> allocateKey(String kind, {Key parentKey}) {
    var key = (parentKey != null) ? parentKey._toSchemaKey() : new schema.Key();
    key.pathElement.add(
        new schema.Key_PathElement()
        ..kind = kind
    );
    schema.AllocateIdsRequest request = new schema.AllocateIdsRequest()
        ..key.add(key);
    return connection.allocateIds(request)
        .then((schema.AllocateIdsResponse response) {
          return new Key._fromSchemaKey(response.key.first);
        });
  }
  
  /**
   * Lookup the given [Key] in the datastore and return the associated entity.
   * If the [Key] is not found, the [Future] will complete with a [NoSuchKeyException].
   */
  Future<EntityResult> lookup(Key key, [Transaction transaction]) =>
      _lookupAllSchemaKeys([key._toSchemaKey()], transaction)
      .first;
  
  /**
   * Lookup all the given keys in the datastore, in the context of the given transaction.
   */
  Stream<EntityResult> lookupAll(Iterable<Key> keys, [Transaction transaction]) =>
      _lookupAllSchemaKeys(keys.map((k) => k._toSchemaKey()), transaction);
  
  /**
   * Lookup the given schema keys in the datastore, optionally in the context
   * of the given transaction.
   */
  Stream<EntityResult> _lookupAllSchemaKeys(Iterable<schema.Key> keys, [Transaction transaction]) {
    schema.LookupRequest lookupRequest = new schema.LookupRequest()
      ..key.addAll(keys);
    if (transaction != null) {
      lookupRequest.readOptions = new schema.ReadOptions()
          ..transaction.addAll(transaction._id);
    }
    
    StreamController controller = new StreamController<Entity>();
    connection.lookup(lookupRequest)
        .then((lookupResponse) {
          for (var schemaEntityResult in lookupResponse.found) {
            var entityResult = 
                new EntityResult._fromSchemaEntityResult(
                    this, 
                    schemaEntityResult, 
                    schema.EntityResult_ResultType.FULL);
            controller.add(entityResult);
          }
          for (var schemaEntityResult in lookupResponse.missing) {
            var entityResult = 
                new EntityResult._fromSchemaEntityResult(
                    this, 
                    schemaEntityResult, 
                    schema.EntityResult_ResultType.KEY_ONLY);
            controller.add(entityResult);
          }
          if (lookupResponse.deferred.isEmpty) {
            controller.close();
          } else {
          controller
            .addStream(_lookupAllSchemaKeys(lookupResponse.deferred, transaction))
            .then((_) => controller.close(),
                  onError: controller.addError);
          }
        })
        .catchError(controller.addError);
 
    return controller.stream;
  }
  
  /**
   * A property expression which is intepreted by the datastore
   * to mean *return only the entity keys in this query*
   */
  static final schema.PropertyExpression _QUERY_PROJECT_KEYS =
      new schema.PropertyExpression()
          ..property = (new schema.PropertyReference()..name = '__key__');
  
  /**
   * Run a query against the datastore, fetching all [Key]s which point to an [Entity] which
   * matches the specified [Query].
   * 
   * If [:offset:] is provided, represents the number of results to skip before the first result
   * of the query is returned.
   * If [:limit:] is provided and non-negative, represents the maximum number of results to fetch.
   * A [:limit:] of `-1` is interpreted as a request for all matched results.
   */
  Stream<Key> queryKeys(Query query, {int offset: 0, int limit: -1}) {
    schema.Query schemaQuery = query._toSchemaQuery()
        ..projection.add(_QUERY_PROJECT_KEYS)
        ..offset = offset;
    if (limit >= 0)
      schemaQuery.limit = limit;
    return _runSchemaQuery(new schema.RunQueryRequest()..query = schemaQuery)
        .map((EntityResult result) => result.key);
  }
  
  /**
   * Run a query against the datastore, fetching all for [Entity]s which match the provided [Query]
   * 
   * If [:offset:] is provided, represents the number of results to skip before the first result
   * of the query is returned
   * If [:limit:] is provided and non-negative, represents the maximum number of results to fetch.
   * A [:limit:] of `-1` is interpreted as a request for all matched results.
   */
  Stream<EntityResult> query(Query query, {int offset:0, int limit: -1}) {
    schema.Query schemaQuery = query._toSchemaQuery()
        ..offset = offset;
    if (limit >= 0) {
      schemaQuery.limit = limit;
    }
    return _runSchemaQuery(new schema.RunQueryRequest()..query = schemaQuery);
  }
  
  Stream<EntityResult> _runSchemaQuery(schema.RunQueryRequest schemaRequest, [List<int> startCursor]) {
    StreamController<EntityResult> streamController = new StreamController();
    
    if (startCursor != null) {
      schemaRequest
        ..query.startCursor = startCursor;
    } else {
      schemaRequest
        ..query.clearStartCursor();
    }
    
    connection.runQuery(schemaRequest)
      .then((schema.RunQueryResponse response) {
          schema.QueryResultBatch batch = response.batch;
          for (var schemaResult in batch) {
            var result = new EntityResult._fromSchemaEntityResult(
                this, schemaResult, batch.entityResultType
            );
            streamController.add(result);
          }
          switch (batch.moreResults) {
            case schema.QueryResultBatch_MoreResultsType.NOT_FINISHED:
              streamController
                  .addStream(_runSchemaQuery(schemaRequest, batch.endCursor))
                  .then((_) => streamController.close(), onError: streamController.addError);
              return;
            case schema.QueryResultBatch_MoreResultsType.MORE_RESULTS_AFTER_LIMIT:
            case schema.QueryResultBatch_MoreResultsType.NO_MORE_RESULTS:
              streamController.close();
              return;
            default:
              //Covered all result types
              assert(false);
          }
      })
      .catchError(streamController.addError);
    return streamController.stream;
  }
  
  /**
   * Runs an action in the context of a given transaction and commits
   * the transaction to the datastore.
   * 
   * If the action returns a [Future], the transaction will be committed
   * if it hasn't already been committed by the action.
   * 
   * The return/completion value of the action is ignored.
   * 
   * Returns the committed transaction.
   */
  Future<Transaction> withTransaction(dynamic action(Transaction transaction)) {
    Completer<Transaction> completer = new Completer<Transaction>();
    
    Transaction.begin(this)
      .then((transaction) {
      //Check whether the transaction has already been committed and if not
      //commit it.
      void commitIfOpenTransaction() {
        if (transaction.isCommitted) {
          completer.complete(transaction);
        } else {
          transaction.commit().then(
              (_) => completer.complete(transaction), 
              onError: completer.completeError);
        }
      }
      var result = action(transaction);
      if (result is Future) {
        result.then(
            (_) => commitIfOpenTransaction(),
            onError: completer.completeError);
      } else {
        commitIfOpenTransaction();
      }
    });
    
    return completer.future;
  }
}

class NoSuchKindError extends Error {
  final String kind;
  NoSuchKindError(String this.kind);
  
  toString() => "Unknown kind: $kind";
}

class NoSuchPropertyError extends Error {
  final receiver;
  final String property;
  NoSuchPropertyError(/* Kind | Entity */ this.receiver, String this.property);
  
  toString() => 
      "Property $property not found on $receiver";
}