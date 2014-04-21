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
    return bdata.getInt64(0);
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
          .every((pathElement) => pathElement.hasId() && pathElement.hasName());

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
    var toDelete = testUserData.firstWhere((ent) => ent.key == key);
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
      return new CommitResponse();
    });
  }


  @override
  Future<LookupResponse> lookup(LookupRequest request) {
    bool keyEquals(Key key1, Key key2) {
      return _list_eq.equals(key1.pathElement, key2.pathElement);
    }

    var keys = request.key;
    //TODO: foundDetailsEnts?
    var foundEnts = testUserData.where((data) => keys.any((k) => keyEquals(k, data.key)));

    var missingEnts = keys.where((k) => !foundEnts.map((ent) => ent.key).any((dataKey) => keyEquals(k, dataKey)))
        .map((k) => new Entity()..key = k)
        .map((ent)=> new EntityResult()..entity = ent);

    var response = new LookupResponse()
      ..found.addAll(foundEnts.take(10).map((ent) => new EntityResult()..entity = ent))
      ..deferred.addAll(foundEnts.skip(10).map((ent) => ent.key))
      ..missing.addAll(missingEnts);
    return new Future.value(response);
  }

  @override
  Future<RollbackResponse> rollback(RollbackRequest request) {
    return new Future.value(new RollbackResponse());
  }

  //TODO: This needs to be reconciled with the new way of collecting test data
  EntityResult_ResultType queryResultType;

  /**
   * The query result batch that starts at cursor 0, ends at cursor 25
   * and has more elements
   */
  List<EntityResult> entityResultsAt0;

  /**
   * The query result batch that starts at cursor 25, ends at cursor 50
   * and has no more elements
   */
  List<EntityResult> entityResultsAt1;


  @override
  Future<RunQueryResponse> runQuery(RunQueryRequest request) {
    if (!request.query.hasStartCursor()) {
      QueryResultBatch resultBatch = new QueryResultBatch()
        ..endCursor.addAll(new Uint8List.fromList([25]))
        ..moreResults = QueryResultBatch_MoreResultsType.NOT_FINISHED
        ..entityResult.addAll(entityResultsAt0)
        ..entityResultType = queryResultType;
      return new Future.value(
          new RunQueryResponse()
          ..batch = resultBatch);
    }
    QueryResultBatch resultBatch = new QueryResultBatch()
        ..endCursor.addAll(new Uint8List.fromList([50]))
        ..moreResults = QueryResultBatch_MoreResultsType.NO_MORE_RESULTS
        ..entityResult.addAll(entityResultsAt1)
        ..entityResultType = queryResultType;
    return new Future.value(
        new RunQueryResponse()
        ..batch = resultBatch);


  }

  @override
  Future sendRemoteShutdown() {
    throw new UnimplementedError();
  }

  var timeoutDuration = new Duration(seconds: 30);
}