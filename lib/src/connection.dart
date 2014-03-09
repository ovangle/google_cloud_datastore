library connection;

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:protobuf/protobuf.dart';

import 'schema_v1_pb2.dart';

/**
 * The API scopes required by google cloud datastore access
 */
const List<String> API_SCOPE =
    const ['https://www.googleapis.com/auth/datastore',
           'https://www.googleapis.com/auth/userinfo.email' ];

const String GOOGLE_API_URL = 'https://www.googleapis.com';
const String API_VERSION = 'v1beta2';

final logger = new Logger('datastore');

class Datastore {
  /**
   * The dataset to connect to. Same as the project ID
   */
  final String datasetId;

  /**
   * The credentials to use when submitting requests to the datastore.
   * For the moment, they are unused since we pipe credentials through the python
   * googledatastore wrapper.
   */
  //FIXME (ovangle): Move to dart implementation.
  final credentials;

  /**
   * The hostname of the datastore. defaults to `https://www.googleapis.com`.
   *
   * Until dart oauth supports service account request, this is hardcoded to 'http://localhost:5556'
   * which is a python server on localhost which reads authorises the request
   * and forwards the result onto the datastore.
   */
  final String host;

  String get _url => '$host/datastore/$API_VERSION/datasets/$datasetId';

  Datastore._(this.datasetId, this.credentials, this.host);

  factory Datastore(String datasetId, {credentials:null, String host:GOOGLE_API_URL}) {
    //hardcode the request to forward to the python server
    host = 'http://localhost:5555';
    if (datasetId == null) {
      throw new ArgumentError('null dataset id');
    }
    if (credentials == null) {
      logger.fine("No datastore credentials provided");
    }
    return new Datastore._(datasetId, credentials, host);
  }

  Future<LookupResponse> lookup(LookupRequest request) =>
      _call("lookup", request, (bytes) => new LookupResponse.fromBuffer(bytes));

  Future<RunQueryResponse> runQuery(RunQueryRequest request) =>
      _call("runQuery", request, (bytes) => new RunQueryResponse.fromBuffer(bytes));

  Future<BeginTransactionResponse> beginTransaction(BeginTransactionRequest request) =>
      _call("beginTransaction", request, (bytes) => new BeginTransactionResponse.fromBuffer(bytes));

  Future<CommitResponse> commit(CommitRequest request) =>
      _call("commit", request, (bytes) => new CommitResponse.fromBuffer(bytes));

  Future<RollbackResponse> rollback(RollbackRequest request) =>
      _call("rollck", request, (bytes) => new RollbackResponse.fromBuffer(bytes));

  Future<AllocateIdsResponse> allocateIds(AllocateIdsRequest request) =>
      _call("allocateIds", request, (bytes) => new AllocateIdsResponse.fromBuffer(bytes));

  Future<GeneratedMessage> _call(String method, GeneratedMessage request, GeneratedMessage reconstructResponse(List<int> bytes)) {
    var bodyBytes = request.writeToBuffer();
    var headers = { 'Content-Type' : 'application/x-protobuf' };
    return http.post("$_url/$method", headers: headers, body: bodyBytes)
        .then((http.Response response) {
          if (response.statusCode != 200) {
            throw new RPCException(response.statusCode, method, response.body);
          }
          return reconstructResponse(response.bodyBytes);
        });
  }
}

class RPCException implements Exception {
  final int status;
  final String method;
  final String body;

  RPCException(int this.status, String this.method, this.body);

  String toString() {
    return "Remote procedure call $method failed with status $status.";
  }
}