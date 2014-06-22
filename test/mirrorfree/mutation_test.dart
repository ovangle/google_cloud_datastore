/**
 * Test datastore mutations of entities using the mirrorfree api.
 */
library mirrorfree_tests.mutation;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../../lib/src/connection.dart';
import '../../lib/src/common.dart';

import '../logging.dart';
import 'kinds.dart';


void main() {
  initLogging();

  group("mutations", () {
    Datastore datastore;

     setUp(() {
       //Do once, rather than on every time the datastore is set up
       Datastore.clearKindCache();
       return DatastoreConnection.open('41795083', 'crucial-matter-487',
                   host: 'http://127.0.0.1:5961').then((conn) {
         datastore = new Datastore.withKinds(conn, mirrorfreeKinds);
       });
     });


    group("insert", () {
      //TODO: More tests.
      var ent;

       setUp(() {
         return datastore.allocateKey("File").then((key) {
           ent = new Entity(
               key,
               { "path": "/path/to/file",
                "user": new Key("User", name: "missy"),
                 "level": 0
               },
               "ProtectedFile");
           return datastore.insert(ent);
         });
       });

       tearDown(() {
         return datastore.delete(ent.key);
       });

       test("Should be able to store a schema entity", () {
         return datastore.lookup((ent.key)).then((result) {
           expect(result.isPresent, isTrue);
           expect(result.entity.getProperty(Entity.SUBKIND_PROPERTY.name), "ProtectedFile");
         });
       });
    });

    group("delete", () {
      Entity devNullFile;
      Entity devUrandomFile;

      Future<Entity> createFile(String path) {
        return datastore.allocateKey("File")
            .then((key) {
          Entity ent = new Entity(key);
          ent.setProperty("path", path);
          return datastore.insert(ent).then((_) => ent);
        });
      }

      setUp(() {
          return createFile("/dev/null").then((ent) => devNullFile = ent).then((_) =>
                 createFile("/dev/urandom")).then((ent) => devUrandomFile = ent);
      });

      tearDown(() {
        return datastore.delete(devNullFile.key)
            .then((_) => datastore.delete(devUrandomFile.key));
      });

      test("should be able to delete a single entity", () {
        return datastore.delete(devNullFile.key).then((_) {
          return datastore.lookup(devNullFile.key).then((result) {
            expect(result.isPresent, isFalse);
          });
        });
      });

      test("delete method should be idempotent", () {
        return datastore.delete(devNullFile.key).then((_) {
          expect(() => datastore.delete(devNullFile.key), returnsNormally);
        });
      });

      test("should be able to delete multiple entities", () {
        return datastore.deleteMany([devNullFile.key, devUrandomFile.key]).then((result) {
          return datastore.lookupAll([devNullFile.key, devUrandomFile.key]).toList().then((results) {
            expect(results.map((r) => r.isPresent), everyElement(isTrue));
          });
        });
      });
    });
  });

}