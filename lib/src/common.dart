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
part 'common/ordering.dart';
part 'common/property.dart';
part 'common/property_instance.dart';
part 'common/query.dart';
part 'common/transaction.dart';

schema.Value schemaValue;


class Datastore {
  final Map<String, Kind> entityKinds;
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
    this.entityKinds = new Map.fromIterable(entityKinds, key: (kind) => kind.name);
    
  Kind kindByName(String name) {
    var kind = entityKinds[name];
    if (kind == null) {
      throw new NoSuchKindError(name);
    }
    return kind;
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
          for (schema.EntityResult entityResult in lookupResponse.found) {
            var key = new Key._fromSchemaKey(entityResult.entity.key);
            var kind = kindByName(key.kind);
            var found = kind._fromSchemaEntity(this, key, entityResult.entity);
            controller.add(new EntityResult._(new Key.fromKey(found.key), found));
          }
          for (schema.EntityResult entityResult in lookupResponse.missing) {
            var key = entityResult.entity.key;
            controller.add(new EntityResult._(new Key._fromSchemaKey(key), null));
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