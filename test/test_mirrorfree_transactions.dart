library mirrorfree_test_transactions;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/src/common.dart';
import '../lib/src/connection.dart';

final KindDefinition fileKind =
    new KindDefinition("File",
        [ new PropertyDefinition("path", PropertyType.STRING, indexed: true) ],
        entityFactory: (key) => new Entity(key)
    );

void main() {

  group("mirrorfree api", () {
    Datastore datastore;
    //true iff already logging records from the datastore
    bool logging = false;

    setUp(() {
      return DatastoreConnection.open('41795083', 'crucial-matter-487',
          host: 'http://127.0.0.1:5961').then((connection) {
        Datastore.clearKindCache();
        datastore = new Datastore.withKinds(connection, [fileKind]);
        if (!logging) {
          datastore.logger.onRecord.listen(print);
          logging = true;
        }
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
        return DatastoreConnection.open('41795083', 'crucial-matter-487',
            host: 'http://127.0.0.1:5961').then((connection) {
          Datastore.clearKindCache();
          datastore = new Datastore.withKinds(connection, [fileKind]);

          return createFile("/dev/null").then((ent) => devNullFile = ent).then((_) =>
                 createFile("/dev/urandom")).then((ent) => devUrandomFile = ent);
        });
      });

      tearDown(() {
        return datastore.delete(devNullFile.key)
            .then((_) => datastore.delete(devUrandomFile.key));
      });

      test("should be able to delete a single entity", () {
        return datastore.delete(devNullFile.key).then((_) {
          return datastore.lookup(devNullFile.key).then((result) {
            print("Present here");
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
