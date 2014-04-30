library connection;

import 'dart:io';
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
           'https://www.googleapis.com/auth/userinfo.email'];

const String GOOGLE_API_URL = 'https://www.googleapis.com';
const String API_VERSION = 'v1beta2';

typedef Future<http.StreamedResponse> _SendRequest(http.Request request);

/**
 * Reads the private key file located at [:path:]
 */
Future _readPrivateKey(String path) {
  if (path == null)
    return new Future.value();
  return new File(path).readAsString();
}

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

  /**
   * The duration to wait before logging a timeout exception and failing
   * the request. Defaults to `30` seconds.
   */
  Duration timeoutDuration = new Duration(seconds: 30);

  String get _url => '$host/datastore/$API_VERSION/datasets/$datasetId';

  DatastoreConnection._(this.datasetId, this._sendRequest, this.host);

  /**
   * Creates a new [DatastoreConnection].
   *
   * [:projectNumber:] is google assigned project number associated with the
   * datastore.
   * [:datasetId:] is the id of the dataset to connect to, usually the same
   * as the google assigned `project ID` associated with the dataset.
   *
   * If connecting to a remote instance of the datastore via a service account, the
   * following two arguments must both be provided, otherwise they should be `null`.
   *
   * [:serviceAccount:] is a service account email used for
   * authenticating with a remote instance of the datastore.
   * [:pathToPrivateKey:] is the filesystem path to the authentication token
   * in the `.pem` format for the service account.
   *
   * If connecting to an instance of the `gcd` tool at the specified `host`, then
   * the [:host:] argument should be set to the location of a running instance of
   * the `gcd` tool.
   */
  static Future<DatastoreConnection> open(String projectNumber, String datasetId,
        { String serviceAccount, String pathToPrivateKey, String host}) {
    var makeAuthRequests = false;
    Uri hostUri;
    if (host == null) {
      host = GOOGLE_API_URL;
      makeAuthRequests = true;
    }
    if (makeAuthRequests) {
        return _readPrivateKey(pathToPrivateKey).then((privateKey) {
          //Stupid behavious of compute client -- scopes must be null if
          //not providing a service account
          var scopes = (serviceAccount == null && pathToPrivateKey == null) ? null : API_SCOPE.join(" ");
          oauth2.ComputeOAuth2Console console = new oauth2.ComputeOAuth2Console(
              projectNumber,
              iss: serviceAccount,
              privateKey: privateKey,
              scopes: scopes);
          _sendAuthorizedRequest(http.Request request) =>
              console.withClient((client) => client.send(request));
          return new DatastoreConnection._(datasetId, _sendAuthorizedRequest, host);
        });
    } else {
      _sendRequest(request) => request.send();
      return new Future.value(new DatastoreConnection._(datasetId, _sendRequest, host));
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

  /**
   * Send a remote shutdown request to the server.
   * Will only successfully perform a shutdown on a test server, production
   * servers will not respond.
   */
  Future sendRemoteShutdown() {
    logger.severe("SUBMITTING REMOTE SHUTDOWN REQUEST");
    return http.post('$host/_ah/admin/quit');
  }

  Future<GeneratedMessage> _call(String method, GeneratedMessage message, GeneratedMessage reconstructResponse(List<int> bytes)) {
    var request = new http.Request("POST", Uri.parse("$_url/$method"))
        ..headers['content-type'] = 'application/x-protobuf'
        ..bodyBytes = message.writeToBuffer();
    logger.info("($method) request sent to ${request.url}");

    return _sendRequest(request)
        .timeout(
            timeoutDuration,
            onTimeout: () {
              logger.severe("Request to $method timed out after $timeoutDuration");
            })
        .then(http.Response.fromStream)
        .then((http.Response response) {
          if (response.statusCode != 200) {
            logger.severe("Request to $method failed with status ${response.statusCode}");
            logger.severe(response.body);
            throw new RPCException(response.statusCode, method, response.reasonPhrase);
          }
          logger.info("Server returned valid ($method) response");
          return reconstructResponse(response.bodyBytes);
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