library reflection.test;

import 'dart:typed_data';

import 'package:unittest/unittest.dart';

import '../lib/datastore.dart';
import 'mock_connection.dart';
import 'test_mirrorfree.dart' as mirrorfree;


@Kind()
class User extends Entity {
  User(Key key, [String subtype]): super(key, {});

  @Property(indexed: true)
  String get name => getProperty("name");

  @Property()
  Uint8List get password => getProperty("password");

  @Property(name: "user_details")
  Key get details => getProperty("user_details");

  @Property(name: "date_joined")
  DateTime get dateJoined => getProperty("date_joined");

  @Property(indexed: true)
  int get age => getProperty("age");
  @Property()
  bool get isAdmin => getProperty("isAdmin");
  @Property()
  List<Key> get friends => getProperty("friends");
}

@Kind(name: "PrivateUser", concrete: false)
class PrivateUser extends User {
  PrivateUser(Key key): super(key);
}

void main() {
  DatastoreConnection connection;
  Datastore datastore;
  bool logging = false;
  setUp(() {
    return DatastoreConnection.open('41795083', 'crucial-matter-487',
        host: 'http://127.0.0.1:5961').then((conn) {
      connection = conn;
      Datastore.clearKindCache();
      datastore = new Datastore(conn);
      if (!logging) {
        datastore.logger.onRecord.listen(print);
        logging = true;
      }
    });
  });

  test("reflected user kind should be identical to mirrorfree kind", () {
    var userKind = Datastore.kindByName("User");
    expect(userKind, mirrorfree.userKind);
    expect(userKind.properties, mirrorfree.userKind.properties);
  });

  test("reconstructing the datastore should not overwrite existing kinds", () {
    var userKind = Datastore.kindByName("User");
    Datastore datastore2 = new Datastore(connection);
    expect(Datastore.kindByName("User"), same(userKind));
  });

  test("A private user should be an abstract subtype of the kind User", () {
    var privateUserKind = Datastore.kindByName("PrivateUser");
    expect(privateUserKind.concrete, false);
  });

  group("wrappers", () {
    test("Should be able to initialize an entity wrapper for a normal kind", () {
      var user = new User(new Key("User", id: 123));
      expect(user.subkind, Datastore.kindByName("User"));
    });

    test("Should be able to initialize a subkind", () {
      var user = new PrivateUser(new Key("User", id: 123));
      expect(user.subkind, Datastore.kindByName("PrivateUser"));
    });
  });
}