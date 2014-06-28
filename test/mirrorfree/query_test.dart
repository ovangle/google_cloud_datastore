library mirrorfree_tests.query;

import 'dart:async';

import 'package:quiver/async.dart';
import 'package:quiver/iterables.dart';
import 'package:unittest/unittest.dart';

import '../../lib/src/connection.dart';
import '../../lib/src/common.dart';

import '../logging.dart';
import 'kinds.dart';

void main() {
  initLogging();

  group("query", () {
    Datastore datastore;

    setUp(() {
      //Do once, rather than on every time the datastore is set up
      Datastore.clearKindCache();
      return DatastoreConnection.open('41795083', 'crucial-matter-487',
                  host: 'http://127.0.0.1:5961').then((conn) {
        datastore = new Datastore.withKinds(conn, mirrorfreeKinds);
      });
    });

    group("construction", () {
      test("should throw a PropertyTypeError when trying to get a filter with the wrong value type", () {
        var filter = new Filter("age", Operator.EQUAL, "hello");
        expect(() => new Query("User", filter), throwsA(new isInstanceOf<PropertyTypeError>()));
      });
      test("should only be able to filter for inequality on one property", () {
        var filter1 = new Filter.and([new Filter("age", Operator.LESS_THAN_OR_EQUAL, 4),
                                     new Filter("age", Operator.GREATER_THAN_OR_EQUAL, 16) ]);
        expect(new Query("User", filter1).filter, same(filter1));

        var filter2 = new Filter.and([new Filter("age", Operator.LESS_THAN_OR_EQUAL, 4),
                                     new Filter("name", Operator.GREATER_THAN_OR_EQUAL, "hello")]);
        expect(() => new Query("User", filter2), throwsA(new isInstanceOf<InvalidQueryException>()));
      });

      test("cannot filter on unindexed property", () {
        var filter = new Filter("password", Operator.EQUAL, [1,2,3,4,5]);
        expect(() => new Query("User", filter), throwsA(new isInstanceOf<InvalidQueryException>()));
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

    group("execution", () {
      //TODO: More tests

      var ent;

      setUp(() {
        return datastore.allocateKey("File").then((key) {
          ent = new Entity(
              key,
              { "path": "/path/to/file",
               "user": new Key("User", name:"missy"),
                "level": 0
              },
              "ProtectedFile");
          return datastore.insert(ent);
        });
      });

      tearDown(() {
        return datastore.delete(ent.key);
      });

      test("Should be able to query for entities of a specific subkind", () {
        var query = new Query("File", new Filter.subkind("ProtectedFile"));
        return datastore.query(query).toList().then((result) {
          expect(result.map((r) => r.key), anyElement(equals(ent.key)));
        });
      });
    });

    group("list execution", () {
      List<Entity> files;

      setUp(() {
        files = [];
        return new Future.value().then((_) {
          Future createFile(i) {
            return datastore.allocateKey("File").then((key) {
              var f = new File(key);
              f.setProperty("path", "/file$i");
              files.add(f);
              return datastore.insert(f);
            });
          }
          return forEachAsync(
              range(5),
              createFile,
              maxTasks: 5
          ).then((_) {
            Future createProtectedFile(i) {
              return datastore.allocateKey("File").then((key) {
                var f = new ProtectedFile(key);
                f.setProperty("path", "/protected/file$i");
                f.setProperty("level", 0);
                files.add(f);
                return datastore.insert(f);
              });
            }
            return forEachAsync(
                range(5),
                createProtectedFile,
                maxTasks: 5
           );
          });
        });
      });

      tearDown(() {
        return datastore.list("File", keysOnly: true)
            .asyncMap((result) => datastore.delete(result.key))
            .toList();
      });

      test("should be able to list all entities of a specific kind", () {
        return datastore.list("File").toList()
            .then((results) {
          expect(results.map((r) => r.isKeyOnlyResult), everyElement(isFalse));
          expect(results.map((r) => r.entity), unorderedEquals(files));
        });
      });

      test("should be able to list all keys of a specific kind", () {
        return datastore.list("File", keysOnly: true).toList()
            .then((results) {
          expect(results.map((r) => r.isKeyOnlyResult), everyElement(isTrue));
          expect(results.map((r) => r.key), unorderedEquals(files.map((f) => f.key)));
        });
      });

      test("should be able to list all keys of a specific subkind", () {
        return datastore.list("ProtectedFile", keysOnly: true).toList()
            .then((results) {
          expect(
              results.map((r) => r.key),
              unorderedEquals(files.where((f) => f is ProtectedFile).map((f) => f.key))
          );
        });
      });
    });
  });

}