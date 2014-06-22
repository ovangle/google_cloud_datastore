library mirrorfree_tests.datastore;

import 'package:unittest/unittest.dart';

import '../../lib/src/connection.dart';
import '../../lib/src/common.dart';

void main() {
  //Test sepeartely since we don't want to clear the kind cache
  group("datastore creation", () {
    //Do once, rather than on every time the datastore is set up
    Datastore.clearKindCache();
    DatastoreConnection connection;

    setUp(() {
      return DatastoreConnection.open('41795083', 'crucial-matter-487',
                host: 'http://127.0.0.1:5961').then((conn) {
        connection = conn;
      });
    });

    //TODO: Test that datastore caches kinds.
  });
}