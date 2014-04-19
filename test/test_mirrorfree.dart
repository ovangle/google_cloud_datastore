library datastore.mirrorfree.test;

import 'dart:typed_data';

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
  new KindDefinition("UserDetails", []);

final NOW = new DateTime.now();

void defineTests(DatastoreConnection connection) {
  group("properties", () {
    Datastore datastore = new Datastore(connection, [userKind, userDetailsKind]);

    Entity user = new Entity(new Key("User", id: 0));
    test("should be able to create an entity with a specific key", () {
      expect(user.key, new Key("User", id: 0));
    });

    test("should be able to get and set the name property of user", () {
      user.setProperty("name", "bob");
      expect(user.getProperty("name"), "bob");
      expect(() => user.setProperty("name", 4), throws, reason: "Invalid property type");
    });

    test("should be able to get and set the password property of user", () {
      user.setProperty("password", new Uint8List.fromList([1,2,3,4,5]));
      expect(user.getProperty("password"), [1,2,3,4,5]);
      user.setProperty("password", [5,4,3,2,1]);
      expect(user.getProperty("password"), [5,4,3,2,1], reason: "List<int> is assignable to Uint8List");
    });

    test("should be able to get and set the user_details property of user", () {
      user.setProperty("user_details", new Key("UserDetails", name: "bob"));
      expect(user.getProperty("user_details"), new Key("UserDetails", name: "bob"));
    });

    test("should be able to get and set the date_joined property of an entity", () {
      user.setProperty("date_joined", new DateTime.fromMillisecondsSinceEpoch(0));
      expect(user.getProperty("date_joined"), new DateTime.fromMillisecondsSinceEpoch(0));
    });

    test("should be able to get and set the friends property of an entity", () {
      var friends = [new Key("User", id: 4), new Key("User", id: 5)];
      user.setProperty("friends", friends);
      expect(user.getProperty("friends"), friends);
    });

    test("should not be able to set a non-existent entity property", () {

    });
  });

  group("lookup tests", () {

  });

  group("query", () {
    test("should only be able to filter for inequality on one property", () {
      var filter1 = new Filter.and([new Filter("age", Operator.LESS_THAN_OR_EQUAL, 4),
                                   new Filter("age", Operator.GREATER_THAN_OR_EQUAL, 16) ]);
      expect(new Query("User", filter1).filter, same(filter1));

      var filter2 = new Filter.and([new Filter("age", Operator.LESS_THAN_OR_EQUAL, 4),
                                   new Filter("name", Operator.GREATER_THAN_OR_EQUAL, "hello")]);
      expect(() => new Query("User", filter2), throwsA(new isInstanceOf<InvalidQueryException>()));
    });

    test("A property which has been filtered for inequality must be sorted first", () {
      var filter = new Filter("age", Operator.LESS_THAN, 4);
      var query = new Query("User", filter);

      expect(() => query..sortBy("age")..sortBy("name"), returnsNormally);
      expect(() => query..sortBy("name")..sortBy("age"), throwsA(new isInstanceOf<InvalidQueryException>()));
    });

    test("should throw a `NoSuchProperty` error when trying to filter for a query which is not on the kind", () {
      expect(() => new Query("User", new Filter("whosit", Operator.EQUAL, 4)),
          throwsA(new isInstanceOf<NoSuchPropertyError>()));
    });
  });

}