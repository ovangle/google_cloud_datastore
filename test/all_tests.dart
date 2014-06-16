

import 'mock_connection.dart';
import 'test_protobuf.dart' as protobuf;
import 'test_extends_mirrorfree.dart' as extends_mirrorfree;
import 'test_mirrorfree.dart' as mirrorfree;
import 'test_mirrorfree_transactions.dart' as mirrorfree_transactions;
import 'test_reflection.dart' as reflection;

void main() {
  MockConnection.create().then((connection) {
    protobuf.defineTests(connection);
    mirrorfree.defineTests(connection);
    mirrorfree_transactions.main();
    extends_mirrorfree.main();
    reflection.main();
  });

}