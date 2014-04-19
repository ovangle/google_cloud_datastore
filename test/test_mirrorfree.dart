library datastore.mirrorfree.test;

import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:unittest/unittest.dart';

import '../lib/src/common.dart';
import '../lib/src/connection.dart';

final KindDefinition userKind =
  new KindDefinition("User",
      [ new PropertyDefinition("name", PropertyType.STRING, indexed: true),
        new PropertyDefinition("password", PropertyType.BLOB),
        new PropertyDefinition("user_details", PropertyType.KEY),
        new PropertyDefinition("date_joined", PropertyType.DATE_TIME),
        new PropertyDefinition("age", PropertyType.INTEGER),
        new PropertyDefinition("isAdmin", PropertyType.BOOLEAN),
        new PropertyDefinition("friends", PropertyType.LIST(PropertyType.KEY))
      ]);

final KindDefinition userDetailsKind =
  new KindDefinition("UserDetails",
      [ new PropertyDefinition("age", PropertyType.INTEGER),
        new PropertyDefinition("isAdmin", PropertyType.BOOLEAN),
        new PropertyDefinition("friends", PropertyType.LIST(PropertyType.KEY))
      ]);

final NOW = new DateTime.now();

void defineTests(DatastoreConnection connection) {
  group("properties", () {
    Datastore datastore = new Datastore(connection, [userKind, userDetailsKind]);

    Entity user = new Entity(datastore, new Key("User", id: 0));
    test("should be able to create an entity with a specific key", () {
      expect(user.key, new Key("User", id: 0));
    });

    test("should be able to get and set the name property of user", () {
      user.setProperty("name", "bob");
      expect(user.getProperty("name"), "bob");
    });

    test("should be able to get and set the password property of user", () {
      user.setProperty("password", new Uint8List.fromList([1,2,3,4,5]));
      expect(user.getProperty("password"), [1,2,3,4,5]);
    });

    test("should be able to get and set the user_details property of user", () {
      user.setProperty("user_details", new Key("UserDetails", name: "bob"));
      expect(user.getProperty("user_details"), new Key("UserDetails", name: "bob"));
    });

    test("should be able to get and set the date_joined property of an entity", () {
      user.setProperty("date_joined", new DateTime.fromMillisecondsSinceEpoch(0));
      expect(user.getProperty("date_joined"), new DateTime.fromMillisecondsSinceEpoch(0));
    });
    test("should be able to get and set the key property of an entity", () {

    });





  });

  group("lookup tests", () {

  });

}