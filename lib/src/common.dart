/*
 * Classes and definitions common to both reflection based and reflection-free datastore implementations.
 */
library  datastore.common;

import 'dart:async';
import 'dart:typed_data';
import 'dart:collection';

import 'package:quiver/async.dart';

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
  final Map<String, KindDefinition> _entityKinds;
  final DatastoreConnection connection;

  final Logger logger = new Logger("datastore");

  /**
   * Create a new instance of the [Datastore].
   *
   * [clientId] is the google assigned `Client ID` associated with a service account
   * authorised to access the datastore.
   * [datasetId] is the name of the dataset to connect to, usally
   */
  Datastore(DatastoreConnection this.connection, List<KindDefinition> entityKinds) :
    this._entityKinds = new Map.fromIterable(entityKinds, key: (kind) => kind.name);

  /**
   * Retrieve the kind associated with the name of the kind.
   * Throws a [NoSuchKindError] if the kind is not known
   * by the datastore.
   */
  KindDefinition kindByName(String name) {
    var kind = _entityKinds[name];
    if (kind == null)
      throw new NoSuchKindError(name);
    return kind;
  }
  /**
   * Retrieve the property associated with the name of the kind.
   * Throws a [NoSuchPropertyError] if the property is not
   * found on the kind.
   */
  PropertyDefinition propByName(String kindName, String propertyName) {
    var prop = kindByName(kindName).properties[propertyName];
    if (prop == null)
      throw new NoSuchPropertyError(kindName, propertyName);
    return prop;
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
  Future<EntityResult> lookup(Key key, [Transaction transaction]) {
    logger.info("Submitting lookup request for $key"
                "${transaction != null ? " (transaction: ${transaction.id}": "" }");
    return _lookupAllSchemaKeys([key._toSchemaKey()], transaction)
        .first;
  }

  /**
   * Lookup all the given keys in the datastore, in the context of the given transaction.
   */
  Stream<EntityResult> lookupAll(Iterable<Key> keys, [Transaction transaction]) {
    logger.info("Submitting lookup request for ${keys}"
                "${transaction != null ? " (transaction: ${transaction.id}" : ""}");
    return _lookupAllSchemaKeys(keys.map((k) => k._toSchemaKey()), transaction);
  }

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

    StreamController controller = new StreamController<EntityResult>();
    connection.lookup(lookupRequest)
        .then((lookupResponse) {
          for (var schemaEntityResult in lookupResponse.found) {
            var entityResult =
                new EntityResult._fromSchemaEntityResult(
                    this,
                    schemaEntityResult,
                    schema.EntityResult_ResultType.FULL);
            logger.info("Found result for key ${entityResult.key}");
            if (!controller.isClosed)
              controller.add(entityResult);
          }
          for (var schemaEntityResult in lookupResponse.missing) {
            var entityResult =
                new EntityResult._fromSchemaEntityResult(
                    this,
                    schemaEntityResult,
                    schema.EntityResult_ResultType.KEY_ONLY);
            logger.info("No result found for key ${entityResult.key}");
            if (!controller.isClosed)
              controller.add(entityResult);
          }
          if (lookupResponse.deferred.isEmpty) {
            if (!controller.isClosed)
              controller.close();
          } else {
            var deferredKeys = lookupResponse.deferred.map((defKey) => new Key._fromSchemaKey(defKey));
            logger.info("Response contained deferred keys: ${deferredKeys}");
            logger.info("Submitting lookup request for deferred keys");
            if (!controller.isClosed)
              controller
                  .addStream(_lookupAllSchemaKeys(lookupResponse.deferred, transaction))
                  .then((_) => controller.close(), onError: controller.addError);
          }
        })
        .catchError(controller.addError);

    return controller.stream;
  }

  /**
   * Run a query against the datastore, fetching all for [Entity]s which match the provided [Query]
   *
   * If [:offset:] is provided, represents the number of results to skip before the first result
   * of the query is returned
   * If [:limit:] is provided and non-negative, represents the maximum number of results to fetch.
   * A [:limit:] of `-1` is interpreted as a request for all matched results.
   *
   * NOTE:
   * Queries will *not* return results for subkinds of a kind, only objects which
   * match the kind itself.
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
    StreamController<EntityResult> streamController;

    streamController = new StreamController();

    if (startCursor != null) {
      schemaRequest
        ..query.startCursor = startCursor;
    } else {
      schemaRequest
        ..query.clearStartCursor();
    }

    connection.runQuery(schemaRequest)
      .then((schema.RunQueryResponse response) {
          if (streamController.isClosed)
            return;
          schema.QueryResultBatch batch = response.batch;
          for (var schemaResult in batch.entityResult) {
            var result = new EntityResult._fromSchemaEntityResult(
                this, schemaResult, batch.entityResultType
            );
            if (!streamController.isClosed)
              streamController.add(result);
          }
          switch (batch.moreResults) {
            case schema.QueryResultBatch_MoreResultsType.NOT_FINISHED:
              if (!streamController.isClosed) {
                streamController
                    .addStream(_runSchemaQuery(schemaRequest, batch.endCursor))
                    .then((_) => streamController.close(), onError: streamController.addError);
              }
              return;
            case schema.QueryResultBatch_MoreResultsType.MORE_RESULTS_AFTER_LIMIT:
            case schema.QueryResultBatch_MoreResultsType.NO_MORE_RESULTS:
              if (!streamController.isClosed)
                streamController.close();
              return;
            default:
              //Covered all result types
              assert(false);
          }
      })
      .catchError((err, stackTrace) {
        logger.severe("Query failed with error", err, stackTrace);
        if (!streamController.isClosed)
          streamController.addError(err, stackTrace);
      });
    return streamController.stream;
  }

  Future<Transaction> insert(Entity entity) {
    logger.info("Inserting $entity into datastore");
    return withTransaction((transaction) => transaction.insert.add(entity))
        .then((transaction) {
          if (transaction.isCommitted) {
            logger.info("Insert successful (transaction id: ${transaction.id})");
          } else {
            logger.warning("Insert failed (transaction id: ${transaction.id})");
          }
          return transaction;
        });

  }

  /**
   * Insert the specified entities into the datastore.
   * Returns the committed transaction.
   */
  Future<Transaction> insertMany(Iterable<Entity> entities) {
    logger.info("Inserting ${entities} into datastore");
    return withTransaction((Transaction transaction) => transaction.insert.addAll(entities))
        .then((transaction) {
            logger.info("Insert successful (transaction id: ${transaction.id}");
            return transaction;
        });
  }

  /**
   * Update the specified entity in the datastore.
   * Returns the committed transaction.
   */
  Future<Transaction> update(Entity entity) {
    logger.info("Updating $entity in datastore");
    return withTransaction((transaction) => transaction.update.add(entity))
        .then((transaction) {
          logger.info("Update of $entity successful (transaction id: ${transaction.id})");
          return transaction;
        });
  }

  /**
   * Update all the specified entities in the datastore.
   * Returns the committed transaction.
   */
  Future<Transaction> updateMany(Iterable<Entity> entities) {
    logger.info("Updating entities ${entities} in datastore");
    return withTransaction((Transaction transaction) => transaction.update.addAll(entities))
        .then((transaction) {
          logger.info("Update of ${entities} successful (transaction id: ${transaction.id}");
          return transaction;
        });
  }

  /**
   * Upsert the given entity into the datastore.
   *
   * An `upsert` operation inserts the entity into the datastore if no matching entity is found
   * and updates it otherwise.
   *
   * Returns the committed transaction.
   */
  Future<Transaction> upsert(Entity entity) {
    logger.info("Upserting ${entity} in datastore");
    return withTransaction((transaction) => transaction.upsert.add(entity))
        .then((transaction) {
          logger.info("Upsert of $entity successful (transaction id: ${transaction.id}");
          return transaction;
        });
  }

  /**
   * Upsert all the given entities in the datastore.
   *
   * An `upsert` operation inserts the entity into the datastore if no matching entity is found
   * and updates it otherwise.
   *
   * Returns the committed transaction.
   */
  Future<Transaction> upsertMany(Iterable<Entity> entities) {
    logger.info("Upserting entities ${entities} in datastore");
    return withTransaction((Transaction transaction) => transaction.upsert.addAll(entities))
        .then((transaction) {
          logger.info("Upsert of ${entities} successful (transaction is ${transaction.id}");
          return transaction;
        });
  }

  /**
   * Delete the entity with the given key from the datastore.
   *
   * Returns the committed transaction.
   */
  Future<Transaction> delete(Key key) {
    logger.info("Deleting ${key} from datastore");
    return withTransaction((Transaction transaction) => transaction.delete.add(key))
        .then((transaction) {
          logger.info("Delete successful");
          return transaction;
        });
  }

  /**
   * Delete the entities with any of the given [:keys:] from the datastore.
   *
   * Returns the committed transaction.
   */
  Future<Transaction> deleteMany(Iterable<Key> keys) {
    logger.info("Deleting keys ${keys} from datastore");
    return withTransaction((Transaction transaction) => transaction.delete.addAll(keys))
        .then((transaction) {
          logger.info("Delete of ${keys} successfull (transaction id: ${transaction.id}");
          return transaction;
        });
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