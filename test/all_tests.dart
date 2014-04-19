

import 'mock_connection.dart';
import 'test_protobuf.dart' as protobuf;
import 'test_mirrorfree.dart' as mirrorfree;
import 'test_reflection.dart' as reflection;

void main() {
  MockConnection.create().then((connection) {
    protobuf.defineTests(connection);
    mirrorfree.defineTests(connection);
    reflection.defineTests(connection);

  });

}