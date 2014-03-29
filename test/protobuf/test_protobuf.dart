library datastore_protobuf.test;

import 'dart:io';

import 'package:fixnum/fixnum.dart';
import '../mock_connection.dart';

import 'package:googleclouddatastore/datastore_protobuf.dart';
import 'package:unittest/unittest.dart';

final String HOME_DIR = Platform.environment['HOME'];
final File GCD_SCRIPT = 
    new File("$HOME_DIR/Programming/tools/gcd/gcd.sh");
final Directory TEST_SERVER_DIRECTORY = 
    new Directory("$HOME_DIR/.gcd/protobuf_test");
final int TEST_SERVER_PORT = 6060;

void main() {
  group("protobuf API", () {
    group("with mocked connection:", () {
      test("allocate Ids", () {
        var allocateIds = new List<Key>()
            ..addAll([ new Key()..pathElement.add(new Key_PathElement()..kind = "user"), 
                       new Key()..pathElement.add(new Key_PathElement()..kind = "user"..id =new Int64(5))
                     ]);
        var connection = new MockConnection();
        return connection
            .allocateIds(new AllocateIdsRequest()..key.addAll(allocateIds))
            .then((response) => expect(response.key, allocateIds));
        
      });
    });
    //Create a new connection to a gcd test server 
    group("with test datastore connection", () {
      DatastoreConnection connection =
          new DatastoreConnection(
              TEST_SERVER_DIRECTORY.path, 
              "protobuf-api-test", 
              makeAuthRequests: false, 
              host: "http://127.0.0.1:$TEST_SERVER_PORT"
          );
      connection.logger.onRecord.listen(print);
      test("allocate ids request", () {
        var allocateIds = new List<Key>()
            ..addAll([ new Key()..pathElement.add(new Key_PathElement()..kind = "user"),
                       new Key()..pathElement.add(new Key_PathElement()..kind = "user")
                     ]);
        return connection
            .allocateIds(new AllocateIdsRequest()..key.addAll(allocateIds)) 
            .then((response) {
              expect(response.key.length, 2);
              expect(response.key.map((k) => k.pathElement[0].kind), everyElement("user"));
            });
      });
    });
  });
}