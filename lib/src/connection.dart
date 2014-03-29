library connection;

import 'dart:async';
import 'dart:convert' show UTF8;

import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:protobuf/protobuf.dart';
import 'package:google_oauth2_client/google_oauth2_console.dart' as oauth2;

import 'schema_v1_pb2.dart';


/**
 * The API scopes required by google cloud datastore access
 */
const List<String> API_SCOPE =
    const ['https://www.googleapis.com/auth/datastore',
           'https://www.googleapis.com/auth/userinfo.email' ];

const String GOOGLE_API_URL = 'https://www.googleapis.com';
const String API_VERSION = 'v1beta2';

typedef Future<http.StreamedResponse> _SendRequest(http.Request request);

class DatastoreConnection {
  final Logger logger = new Logger("datastore.connection");
  
  /**
   * The dataset to connect to. Same as the project ID
   */
  final String datasetId;

  final _SendRequest _sendRequest;

  /**
   * The hostname of the datastore. defaults to `https://www.googleapis.com`.
   *
   * Until dart oauth supports service account request, this is hardcoded to 'http://localhost:5556'
   * which is a python server on localhost which reads authorises the request
   * and forwards the result onto the datastore.
   */
  final String host;
  
  String get _url => '$host/datastore/$API_VERSION/datasets/$datasetId';

  DatastoreConnection._(this.datasetId, this._sendRequest, this.host);

  /**
   * Create a new connection to the [Datastore].
   * [:clientId:] is the google assigned client ID associated with a service account
   * authorised to access the dataset.
   * [:datasetId:] is the name of the dataset to connect to. Usually the same as the projectId
   * associated with the service account.
   * [:host:] is the hostname of the google datastore. Defaults to `http://www.googleapis.com`.
   * 
   * If connecting to a `gcd` test server (see `https://developers.google.com/datastore/docs/tools/`)
   * then [:host:] should be set to the gcd server location and [:makeAuthRequests:] should be `false`.
   */
  factory DatastoreConnection(String clientId, String datasetId, {bool makeAuthRequests: true, String host:GOOGLE_API_URL}) {
    if (makeAuthRequests) {
      oauth2.ComputeOAuth2Console computeEngineConsole = new oauth2.ComputeOAuth2Console(clientId);
      _sendAuthorisedRequest(http.Request request) {
        return computeEngineConsole
            .withClient((client) => client.send(request));
      }
      return new DatastoreConnection._(datasetId, _sendAuthorisedRequest, host);
    } else {
      _sendRequest(http.Request request) => request.send();
      return new DatastoreConnection._(datasetId, _sendRequest, host);
    }
    
  }

  /**
   * Submits a lookup request to the datastore.
   * 
   * Throws an [RPCException] if the server responds with an invalid status
   */
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
  
  Future<GeneratedMessage> _call(String method, GeneratedMessage message, GeneratedMessage reconstructResponse(List<int> bytes)) {
    var request = new http.Request("POST", Uri.parse("$_url/$method"))
        ..headers['content-type'] = 'application/x-protobuf'
        ..bodyBytes = message.writeToBuffer();
    logger.info("($method) request sent to ${request.url}");
    return _sendRequest(request)
        .then((http.StreamedResponse response) {
          if (response.statusCode != 200) {
            response.stream.listen((bytes) {
              logger.severe("Request to $method failed with status ${response.statusCode}");
              logger.severe(UTF8.decode(bytes));
            });
            throw new RPCException(response.statusCode, method, response.reasonPhrase);
          }
          logger.info("Server returned valid response");
          return response.stream
              .first.then(reconstructResponse);
        });
  }
}

class RPCException implements Exception {
  final int status;
  final String method;
  final String reason;

  RPCException(int this.status, String this.method, this.reason);

  String toString() {
    return "Remote procedure call $method failed with status $status ($reason)";
  }
}