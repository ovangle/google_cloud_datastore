/*
 * Classes and definitions common to both reflection based and reflection-free datastore implementations.
 */
library  datastore.common;

import 'dart:async';
import 'dart:typed_data';
import 'dart:collection';

import 'package:collection/wrappers.dart' show UnmodifiableMapMixin;
import 'package:quiver/core.dart' as qcore;

import 'package:crypto/crypto.dart' show CryptoUtils;
import 'package:fixnum/fixnum.dart';
import 'package:logging/logging.dart';

import 'proto/schema_v1_pb2.dart' as schema;
import 'connection.dart';

part 'common/key.dart';
part 'common/kind.dart';
part 'common/entity.dart';
part 'common/filter.dart';
part 'common/property.dart';
part 'common/property_instance.dart';
part 'common/query.dart';
part 'common/transaction.dart';

/**
 * The top level logger for all datastore logs.
 * By default, log records are written to the top level 'datastore'
 * logger.
 */
Logger datastoreLogger = new Logger("datastore");

class Datastore {
  static final Map<String, KindDefinition> _entityKinds = new Map();
  final DatastoreConnection connection;

  /**
   * Clear the known kinds from the datastore.
   * Warning: This will make methods not work until a new [Datastore] instance is
   * constructed.
   */
  static void clearKindCache() {
    _entityKinds.clear();
  }

  /**
   * The logger associated with the datastore.
   * By default, log records are written to the logger with name 'datastore'.
   *
   * Changing the logger here will also rename the connection logger, so that
   * it logs to the 'connection' child of this logger.
   */
  Logger get logger => datastoreLogger;
  set logger(Logger logger) {
    datastoreLogger = logger;
    connection.logger = new Logger('${datastoreLogger.fullName}.connection');
  }

  /**
   * Create a new instance of the [Datastore].
   *
   * [clientId] is the google assigned `Client ID` associated with a service account
   * authorised to access the datastore.
   * [datasetId] is the name of the dataset to connect to, usally
   */
  Datastore.withKinds(DatastoreConnection this.connection, List<KindDefinition> entityKinds) {
    connection.logger = new Logger('${datastoreLogger.fullName}.connection');
    entityKinds.forEach((kind) {
      _entityKinds.putIfAbsent(kind.name, () => kind);
    });
  }

  /**
   * Retrieve the kind associated with the name of the kind.
   * Throws a [NoSuchKindError] if the kind is not known
   * by the datastore.
   */
  static KindDefinition kindByName(String name) {
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
  static PropertyDefinition propByName(String kindName, String propertyName) {
    var prop = kindByName(kindName).properties[propertyName];
    if (prop == null)
      throw new NoSuchPropertyError(kindName, propertyName);
    return prop;
  }

  /**
   * Allocate a new unnamed datastore key.
   */
  Future<Key> allocateKey(String kind, {Key parentKey}) {
    return new Future.sync(() {
      if (!Datastore.kindByName(kind).concrete) {
        throw new KindError.kindOnKeyMustBeConcrete(kind);
      }
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
   * List all entities of the given [:kind:] in the datastore.
   *
   * If the kind is a subkind of a concrete kind, then this method is equivalent to
   *
   *       query(new Query(<concrete superkind>, new Filter.subkind(kind));
   *
   * If [:keysOnly:] is `true`, then only the entity keys will be fetched and all [EntityResult]s
   * in the stream will be [:keysOnly:]
   *
   * If [:offset:] is provided, represents the number of results to skip before the first result
   * of the query is returned
   * If [:limit:] is provided and non-negative, represents the maximum number of results to fetch.
   * A [:limit:] of `-1` is interpreted as a request for all matched results.
   */
  Stream<EntityResult> list(String kind, {bool keysOnly: false, int offset: 0, int limit: -1}) {
    var kindDefn = Datastore.kindByName(kind);
    schema.Query query;
    if (kindDefn.concrete) {
      query = new schema.Query()
          ..kind.add(kindDefn._toSchemaKindExpression());
    } else {
      while (!kindDefn.concrete) {
        kindDefn = kindDefn.extendsKind;
        if (kindDefn == null) {
          throw new KindError.noConcreteSuper(kind);
        }
      }
      Query subkindQuery = new Query(kindDefn, new Filter.subkind(kind));
      query = subkindQuery._toSchemaQuery();
    }

    query.offset = offset;
    if (limit >= 0) query.limit = limit;

    if (keysOnly) {
      var proj = new schema.PropertyExpression()
          ..property = Entity.KEY_PROPERTY._toSchemaPropertyReference();
      query.projection.add(proj);
    }
    return _runSchemaQuery(new schema.RunQueryRequest()..query = query);
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

  /**
   * Insert the entity into the datastore.
   * If the entity already exists, nothing is inserted.
   */
  Future<Transaction> insert(Entity entity) {
    logger.info("Inserting $entity into datastore");
    return withTransaction((transaction) {
          return lookup(entity.key, transaction).then((entityResult) {
            if (entityResult.isPresent) return;
            transaction.insert.add(entity);
          });
        })
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
   *
   * Only entities that do not exist in the datastore at the beginning of
   * the transaction are inserted.
   */
  Future<Transaction> insertMany(Iterable<Entity> entities) {
    logger.info("Inserting ${entities} into datastore");
    return withTransaction((Transaction transaction) {
          return lookupAll(entities.map((ent) => ent.key), transaction).toList().then((results) {
            var missingKeys = results.where((r) => !r.isPresent);
            //Shortcut if none of the keys have been added previously.
            if (missingKeys.length == entities.length) {
              transaction.insert.addAll(entities);
            } else {
              //Missing keys should be empty.
              transaction.insert.addAll(
                  missingKeys.map((k) => entities.firstWhere((ent) => ent.key == k))
              );
            }
          });
        })
        .then((transaction) {
            logger.info("Insert successful (transaction id: ${transaction.id}");
            return transaction;
        });
  }

  /**
   * Update the specified entity in the datastore.
   * Returns the committed transaction.
   *
   * *NOTE*: This method is not idempotent, which is a recommended property
   * for safe datastore transactions (see [0]). Updates should ideally be performed
   * manually via [:withTransaction:]
   *
   * [0]: https://developers.google.com/appengine/articles/handling_datastore_errors
   */
  @deprecated
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
   *
   * *NOTE*: This method is not idempotent and will be removed in a future release,
   * See [0] for more information.
   *
   * [0]: https://developers.google.com/appengine/articles/handling_datastore_errors
   */
  @deprecated
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
   *
   * *NOTE*: This method is not idempotent and will be removed in a future release,
   * See [0] for more information.
   *
   * [0]: https://developers.google.com/appengine/articles/handling_datastore_errors
   */
  @deprecated
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
   *
   * *NOTE*: This method is not idempotent and will be removed in a future release,
   * See [0] for more information.
   *
   * [0]: https://developers.google.com/appengine/articles/handling_datastore_errors
   */
  @deprecated
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
   * If the key is not found in the datastore at the beginning of the transaction,
   * the transaction is committed with no update to the datastore.
   *
   * Returns the committed transaction.
   */
  Future<Transaction> delete(Key key) {
    logger.info("Deleting ${key} from datastore");
    return withTransaction((Transaction transaction) {
        return lookup(key).then((result) {
            if (!result.isPresent) return;
            transaction.delete.add(key);
          });
        })
        .then((transaction) {
          logger.info("Delete successful");
          return transaction;
        });
  }

  /**
   * Delete the entities with any of the given [:keys:] from the datastore.
   *
   * If any of the given keys are not found in the datastore at the beginning of the transaction,
   * the transaction is committed with no update to the datastore.
   *
   * Returns the committed transaction.
   */
  Future<Transaction> deleteMany(Iterable<Key> keys) {
    logger.info("Deleting keys ${keys} from datastore");
    return withTransaction((Transaction transaction) {
          return lookupAll(keys, transaction).toList().then((results) {
            transaction.delete.addAll(
                results.where((r) => !r.isPresent).map((r) => r.key)
            );
          });
        })
        .then((transaction) {
          logger.info("Delete of ${keys} successful");
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
    return Transaction.begin(this).then((transaction) {
      return new Future.sync(() {
        return action(transaction);
      }).then((_) {
        if (transaction.isCommitted){
          return transaction;
        } else {
          return transaction.commit();
        }
      });
    });
  }
}

class NoSuchKindError extends Error {
  final String kind;
  NoSuchKindError(String this.kind);

  toString() => "Unknown kind: $kind";
}

class KindError extends Error {
  final String kind;
  final String message;

  KindError(String this.kind, String this.message);

  KindError.noConcreteSuper(String kind):
    this(kind, "$kind has no concrete super kind");

  KindError.multipleConcreteKindsInInheritanceHeirarchy(String kind, String extendsKind):
    this.kind = kind,
    this.message = "Multiple concrete kinds ($kind, $extendsKind) found in inheritance heirarchy";

  KindError.kindOnKeyMustBeConcrete(String name):
    this.kind = name,
    this.message = "Key kind ($name) must be concrete";

  KindError.concreteSubkind(String name):
    this.kind = name,
    this.message = "Entity subkind cannot be concrete";

  KindError.notDirectSubkind(String subkind, dynamic /* String | Kind */ keyKind):
    this.kind = subkind,
    this.message = "Entity subkind ($subkind) must extend the key kind ($keyKind)";

  String toString() => message;
}

class NoSuchPropertyError extends Error {
  final receiver;
  final String property;
  NoSuchPropertyError(/* Kind | Entity */ this.receiver, String this.property);

  toString() =>
      "Property $property not found on $receiver";
}

class PropertyTypeError extends Error {
  final String propertyName;
  final PropertyType propertyType;
  final value;

  PropertyTypeError(String this.propertyName, this.propertyType, this.value);

  toString() =>
      "TypeError: Invalid value for ${propertyType} property '$propertyName'";
}
