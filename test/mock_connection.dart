library mock_connection;

import 'dart:async';
import 'dart:typed_data';
import '../lib/src/schema_v1_pb2.dart';
import '../lib/src/connection.dart';

class MockConnection implements DatastoreConnection {

  // TODO: implement datasetId
  @override
  String get datasetId => null;

  // TODO: implement host
  @override
  String get host => null;
  
  get logger => null;
  
  MockConnection();

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
  
  List<EntityResult> lookupResponseFound = new List();
  List<EntityResult> lookupResponseMissing = new List();
  Iterable<Key> get lookupDeferredKeys => lookupDeferredFound.map((ent) => ent.entity.key);
  List<EntityResult> lookupDeferredFound = new List();

  bool _lookupDeferred = false;

  @override
  Future<LookupResponse> lookup(LookupRequest request) {
    var lookupResponse = new LookupResponse();
    if (_lookupDeferred) {
      lookupResponse.found.addAll(lookupDeferredFound);
      _lookupDeferred = false;
    } else {
      _lookupDeferred = true;
      lookupResponse.found.addAll(lookupResponseFound);
      lookupResponse.missing.addAll(lookupResponseMissing);
      lookupResponse.deferred.addAll(lookupDeferredKeys);
    }
    return new Future.value(lookupResponse);
  }

  @override
  Future<RollbackResponse> rollback(RollbackRequest request) {
    return new Future.value(new RollbackResponse());
  }

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
}