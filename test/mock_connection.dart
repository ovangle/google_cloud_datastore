library mock_connection;

import 'dart:async';
import 'dart:typed_data';
import 'package:collection/equality.dart';
import 'package:fixnum/fixnum.dart';

import '../lib/src/schema_v1_pb2.dart';
import '../lib/src/connection.dart';

import 'connection_test_data.dart';

final _list_eq = new ListEquality();

class MockConnection implements DatastoreConnection {

  // TODO: implement datasetId
  @override
  String get datasetId => null;

  // TODO: implement host
  @override
  String get host => null;

  get logger => null;

  final List<Entity> testUserData;

  static Future<MockConnection> create() =>
      testUsers()
      .then((users) => new MockConnection(users));

  MockConnection(this.testUserData);

  Int64 maxEntityId = Int64.ZERO;
  List<Int64> allocatedIds = [];

  @override
  Future<AllocateIdsResponse> allocateIds(AllocateIdsRequest request) {
    return new Future.sync(() {
      var ids = testUserData.map((user) => user.key.pathElement.last.id);
      while (ids.contains(maxEntityId++));
      while (allocatedIds.contains(maxEntityId++));
      var allocatedKeys = [];
      for (var key in request.key) {
        var allocatedId = ++maxEntityId;
        allocatedIds.add(allocatedId);
        allocatedKeys.add(
            key.clone()
            ..pathElement.last.id = allocatedId);
      }
      return new AllocateIdsResponse()
          ..key.addAll(allocatedKeys);
    });
  }

  Int64 transactionId = Int64.ZERO;

  var openTransactions = [];
  var committedTransactions = [];

  Int64 _bytesToInt64(List<int> bytes) {
    var bdata = new ByteData.view(new Uint8List.fromList(bytes).buffer);
    return new Int64(bdata.getInt64(0, Endianness.LITTLE_ENDIAN));
  }

  @override
  Future<BeginTransactionResponse> beginTransaction(BeginTransactionRequest request) {
    return new Future.sync(() {
      var nextTransaction = ++transactionId;
      openTransactions.add(nextTransaction);
      var response = new BeginTransactionResponse()
        ..transaction = transactionId.toBytes();
      return response;
    });
  }

  bool isFullySpecified(Key key) =>
      key.pathElement
          .every((pathElement) => pathElement.hasId() || pathElement.hasName());

  void insertEntity(Entity ent) {
    if (testUserData.any((k) => ent.key == k)) {
      throw 'Entity already exists: ${ent.key}';
    }
    if (!isFullySpecified(ent.key))
      throw 'Must be a fully specified key: ${ent.key}';

    testUserData.add(ent.clone());
  }

  void updateEntity(Entity ent) {
    if (!isFullySpecified(ent.key))
      throw 'Must be a fully specified key: ${ent.key}';
    var toUpdate = testUserData.firstWhere((e) => e.key == ent.key, orElse: () => null);
    if (toUpdate == null)
      throw 'Cannot update non-existent entity: ${ent.key}';
    for (var prop in ent.property) {
      var updateProp = toUpdate.property.firstWhere((p) => p.name == prop.name, orElse: () => null);
      if (updateProp == null) {
        toUpdate.property.add(new Property()..name = prop.name..value = prop.value.clone());
        continue;
      }
      updateProp.value = prop.value.clone();
    }
  }

  void upsertEntity(Entity ent) {
    if (!isFullySpecified(ent.key))
      throw 'Must be a fully specified key: ${ent.key}';
    var existing = testUserData.firstWhere((e) => e.key == ent.key, orElse: () => null);
    if (existing == null) {
      insertEntity(ent);
    } else {
      updateEntity(ent);
    }
  }

  void deleteEntity(Key key) {
    if (!isFullySpecified(key))
      throw 'Must be a fully specified key: ${key}';
    testUserData.removeWhere((ent) => ent.key == key);
  }
  @override
  Future<CommitResponse> commit(CommitRequest request) {
    return new Future.sync(() {
      var transactionId = _bytesToInt64(request.transaction);
      if (!openTransactions.contains(transactionId)) {
        throw 'Not an open transaction: ${transactionId}';
      }
      if (committedTransactions.contains(transactionId))
        throw 'Transaction $transactionId already committed';
      var mutation = request.mutation;
      mutation.insert.forEach(insertEntity);
      mutation.update.forEach(updateEntity);
      mutation.upsert.forEach(upsertEntity);
      mutation.delete.forEach(deleteEntity);
      openTransactions.remove(transactionId);
      committedTransactions.add(transactionId);
      return new CommitResponse();
    });
  }


  @override
  Future<LookupResponse> lookup(LookupRequest request) {

    return new Future.sync(() {
      var keys = request.key;
      var foundEnts = testUserData.where((data) => keys.any((k) => k == data.key));

      var missingEnts = keys.where((k) => !foundEnts.map((ent) => ent.key).contains(k))
          .map((k) => new Entity()..key = k)
          .map((ent)=> new EntityResult()..entity = ent);

      var response = new LookupResponse()
        ..found.addAll(foundEnts.take(10).map((ent) => new EntityResult()..entity = ent))
        ..deferred.addAll(foundEnts.skip(10).map((ent) => ent.key))
        ..missing.addAll(missingEnts);
      return response;
    });
  }

  @override
  Future<RollbackResponse> rollback(RollbackRequest request) {
    return new Future.sync(() {
      var transactionId = _bytesToInt64(request.transaction);
      if (openTransactions.contains(transactionId))
        throw 'Transaction $transactionId not committed';
      if (!committedTransactions.contains(transactionId))
        throw 'Unknown transaction: ${transactionId}';
      //Don't actually undo the transaction.This is just a mock.
      return new RollbackResponse();
    });
  }

  Iterable<Entity> applyPropertyFilter(PropertyFilter filter, Iterable<Entity> entities) {
    getPropValue(Entity ent) {
      if (filter.property.name == "__key__")
        return new Value()..keyValue = ent.key;
      var prop = ent.property.firstWhere((prop) => prop.name == filter.property.name);
      if (prop == null) return null;
      return prop.value;
    }
    return entities
        .where((ent) {
          var value = getPropValue(ent);
          if (value == null) return false;
          switch(filter.operator) {
            case PropertyFilter_Operator.EQUAL:
              return value == filter.value || value.listValue.any((v) => v == filter.value);
            case PropertyFilter_Operator.LESS_THAN:
              return _compareValues(value, filter.value) < 0;
            case PropertyFilter_Operator.LESS_THAN_OR_EQUAL:
              return _compareValues(value, filter.value) <= 0;
            case PropertyFilter_Operator.GREATER_THAN:
              return _compareValues(value, filter.value) > 0;
            case PropertyFilter_Operator.GREATER_THAN_OR_EQUAL:
              return _compareValues(value, filter.value) >= 0;
            case PropertyFilter_Operator.HAS_ANCESTOR:
              throw new UnimplementedError("Ancestor query");
          }
        });
  }

  //Compare values is only mocked for integer values.
  int _compareValues(Value a, Value b) {
    if (a.hasIntegerValue() && b.hasIntegerValue())
      return a.integerValue.compareTo(b.integerValue);
    throw new UnimplementedError("_compareValues only implemented for integer values");
  }

  Iterable<Entity> applyCompositeFilter(CompositeFilter filter, Iterable<Entity> entities) {
    for (var f in filter.filter)
      entities = applyFilter(f, entities);
    return entities;
  }

  Iterable<Entity> applyFilter(Filter f, Iterable<Entity> entities) {
    if (f.hasCompositeFilter())
      return applyCompositeFilter(f.compositeFilter, entities);
    if (f.hasPropertyFilter())
      return applyPropertyFilter(f.propertyFilter, entities);
    throw new StateError("Invalid filter: $f");
  }

  Int64 batchCursor = Int64.ZERO;

  Map<Int64, QueryResultBatch> queryBatches = {};

  static const int BATCH_SIZE = 15;

  @override
  Future<RunQueryResponse> runQuery(RunQueryRequest request) {
    return new Future.sync(() {
      if (request.hasGqlQuery())
        throw 'Gql query not supported';
      var query = request.query;
      if (query.hasStartCursor()) {
        var startCursor = _bytesToInt64(query.startCursor);
        if (queryBatches[startCursor] == null)
          throw 'Invalid start cursor $startCursor';
        return new RunQueryResponse()
            ..batch = queryBatches[startCursor];
      }
      var testData = applyFilter(query.filter, testUserData);
      //Don't bother sorting or grouping the data.
      var lastCursor, initBatch;
      while (testData.isNotEmpty) {
        var cursor = ++batchCursor;
        var resultBatch = new QueryResultBatch()
            ..endCursor = cursor.toBytes()
            ..entityResultType = EntityResult_ResultType.FULL;
        if (initBatch == null) {
          initBatch = resultBatch;
        } else {
          queryBatches[lastCursor] = resultBatch;
        }
        lastCursor = cursor;
        if (testData.length < BATCH_SIZE) {
          resultBatch.moreResults = QueryResultBatch_MoreResultsType.NO_MORE_RESULTS;
          resultBatch.entityResult.addAll(testData.map((ent) => new EntityResult()..entity = ent.clone()));
          testData = [];
        } else {
          resultBatch.moreResults = QueryResultBatch_MoreResultsType.NOT_FINISHED;
          resultBatch.entityResult.addAll(testData.take(BATCH_SIZE).map((ent) => new EntityResult()..entity = ent.clone()));
          testData = testData.skip(BATCH_SIZE);
        }
      }
      return new RunQueryResponse()
          ..batch = initBatch;
    });

  }

  @override
  Future sendRemoteShutdown() {
    throw new UnimplementedError();
  }

  var timeoutDuration = new Duration(seconds: 30);
}