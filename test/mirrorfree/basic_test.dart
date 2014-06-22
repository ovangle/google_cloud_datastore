/**
 * Test entity creation and deletion, property access etc.
 */
library mirrorfree_tests.basic;

import 'dart:async';
import 'dart:typed_data';

import 'package:quiver/async.dart';
import 'package:quiver/iterables.dart';
import 'package:unittest/unittest.dart';

import '../../lib/src/connection.dart';
import '../../lib/src/common.dart';

import '../logging.dart';

import 'kinds.dart';

final NOW = new DateTime.now();

void main() {

  initLogging();

  group("basic", () {
    Datastore datastore;

    setUp(() {
      //Do once, rather than on every time the datastore is set up
      Datastore.clearKindCache();
      return DatastoreConnection.open('41795083', 'crucial-matter-487',
                  host: 'http://127.0.0.1:5961').then((conn) {
        datastore = new Datastore.withKinds(conn, mirrorfreeKinds);
      });
    });

    group("properties", () {

      Entity user;
      List<Key> friends;

      setUp(() {
        friends = [new Key("User", id: 4), new Key("User", id: 5)];
        user=new User(new Key("User", id: 0));

        user.setProperty("name", "bob");
        user.setProperty("password", new Uint8List.fromList([1,2,3,4,5]));
        user.setProperty("user_details", new Key("UserDetails", name: "bob"));
        user.setProperty("date_joined", new DateTime.fromMillisecondsSinceEpoch(0));
        user.setProperty("friends", friends);


      });

      test("should be able to create an entity with a specific key", () {
        expect(user.key, new Key("User", id: 0));
      });

      test("should be able to get and set the name property of user", () {
        expect(user.getProperty("name"), "bob");
        expect(() => user.setProperty("name", 4), throws, reason: "Invalid property type");
      });

      test("should be able to get and set the password property of user", () {
        expect(user.getProperty("password"), [1,2,3,4,5]);
        user.setProperty("password", [5,4,3,2,1]);
        expect(user.getProperty("password"), [5,4,3,2,1], reason: "List<int> is assignable to Uint8List");
      });

      test("should be able to get and set the user_details property of user", () {
        expect(user.getProperty("user_details"), new Key("UserDetails", name: "bob"));
      });

      test("should be able to get and set the date_joined property of an entity", () {
        expect(user.getProperty("date_joined"), new DateTime.fromMillisecondsSinceEpoch(0));
      });

      test("should be able to get and set the friends property of an entity", () {
        expect(user.getProperty("friends"), friends);
      });

      test("should not be able to set a non-existent entity property", () {
        expect(() => user.setProperty("non-existent", 4), throwsA(new isInstanceOf<NoSuchPropertyError>()));
      });
    });

    group("foreign keys", () {
      Entity user;
      var userDetails;
      var friends = new List();
      setUp(() {
        return new Future.value().then((_) {
          return datastore.allocateKey("UserDetails").then((key) {
            userDetails = new UserDetails(key);
            return datastore.insert(userDetails);
          });
        }).then((_) {
          return forEachAsync(
              range(5),
              (i) {
                return datastore.allocateKey("User").then((key) {
                  var friend = new User(key);
                  friend.setProperty("name", "friend-$i");
                  friends.add(friend);
                  return datastore.insert(friend);
                });
              }
          );
        }).then((_) {
          return new Future.value().then((_) {
            return datastore.allocateKey("User").then((key) {
              user = new User(key);
              user.setProperty("user_details", userDetails.key);
              user.setProperty("friends", friends.map((f) => f.key).toList());
              return datastore.insert(user);
            });
          });
        });
      });

      tearDown(() {
        return datastore.delete(user.key)
            .then((_) => datastore.delete(userDetails.key))
            .then((_) {
              return forEachAsync(
                  friends,
                  (f) => datastore.delete(f.key)
              );
        }).then((_) {
          friends.clear();
        });
      });

      test("should be able to get the value of a foreign key property", () {
        return user.getForeignKeyProperty(datastore, "user_details").then((value) {
          expect(value.isPresent, isTrue);
          expect(value.entity, userDetails);
        });
      });

      test("should cache the foreign key value", () {
        var cachedValue;
        return user.getForeignKeyProperty(datastore, "user_details").then((value) {
          cachedValue = value;
          return user.getForeignKeyProperty(datastore, "user_details");
        }).then((value) {
          expect(value, same(cachedValue));
        });
      });

      test("should clear the cache when setting the property by the key", () {
        var cachedValue;
        return user.getForeignKeyProperty(datastore, "user_details").then((value) {
          cachedValue = value;
          user.setProperty("user_details", userDetails.key);
          return user.getForeignKeyProperty(datastore, "user_details");
        }).then((value) {
          expect(value, isNot(same(cachedValue)));
        });
      });

      test("should recache the value when setting the property by fk", () {
        var cachedValue = new UserDetails(new Key("UserDetails", id: 123));
        user.setForeignKeyProperty("user_details", cachedValue);
        return user.getForeignKeyProperty(datastore, "user_details").then((value) {
          expect(value, same(cachedValue));
        });
      });
    });
  });
}