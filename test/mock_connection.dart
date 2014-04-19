library mock_connection;

import 'dart:async';
import 'dart:typed_data';
import 'package:collection/equality.dart';

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
  final List<Entity> testUserDetailsData;

  static Future<MockConnection> create() =>
      testUsers()
      .then((users) {
        return testUserDetails().then((userDetails) =>
            new MockConnection(users, userDetails));
      });

  MockConnection(this.testUserData, this.testUserDetailsData);

  @override
  Future<AllocateIdsResponse> allocateIds(AllocateIdsRequest request) {
    return new Future.value(
        new AllocateIdsResponse()
        ..key.addAll(request.key)
    );
  }

  @override
  Future<BeginTransactionResponse> beginTransaction(BeginTransactionRequest request) {
    BeginTransactionResponse transactionResponse = new BeginTransactionResponse()
      ..transaction.addAll([0,0,0,0,0]);
    return new Future.value(transactionResponse);
  }

  //Set the number of index updates to include in the commit response
  int commitResponseMutationResultIndexUpdates;
  //Set the number of inserted ids to include in the commit response.
  List<Key> commitResponsemutationResultAutoInsertKeys = new List<Key>();

  @override
  Future<CommitResponse> commit(CommitRequest request) {
    MutationResult mutationResult = new MutationResult()
        ..indexUpdates = this.commitResponseMutationResultIndexUpdates
        ..insertAutoIdKey.addAll(this.commitResponsemutationResultAutoInsertKeys);
    CommitResponse commitResponse = new CommitResponse()
        ..mutationResult = mutationResult;
    return new Future.value(mutationResult);
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