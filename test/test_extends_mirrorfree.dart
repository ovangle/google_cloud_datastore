library extends_mirrorfree;

import 'package:unittest/unittest.dart';

import '../lib/src/connection.dart';
import '../lib/src/common.dart';

final fileKind =
    new KindDefinition(
        "File",
        [ new PropertyDefinition("path", PropertyType.STRING, indexed: true) ],
        entityFactory: (key) => new Entity(key)
    );

final protectedFileKind =
    new KindDefinition(
        "ProtectedFile",
        [ new PropertyDefinition("user", PropertyType.STRING),
          new PropertyDefinition("level", PropertyType.INTEGER)
        ],
        extendsKind: fileKind,
        concrete: false,
        entityFactory: (key) => new Entity(key, {}, "ProtectedFile")
     );

//Invalid since both the implementing and base class are concrete
final concreteBase = new KindDefinition("ConcreteBase", [], concrete: true);

final errKind = new KindDefinition("Err", [], entityFactory: (key) => new Entity(key));

final notDirectSubkind =
  new KindDefinition(
      "NotSubkind",
      [ new PropertyDefinition("user", PropertyType.STRING),
        new PropertyDefinition("level", PropertyType.INTEGER)
      ],
      extendsKind: errKind,
      concrete: false,
      entityFactory: (key) => new Entity(key)
  );

void main() {

  group("kind subtyping", () {
    Datastore datastore;
    bool logging = false;
    setUp(() {
      return DatastoreConnection.open('41795083', 'crucial-matter-487',
          host: 'http://127.0.0.1:5961').then((connection) {
        Datastore.clearKindCache();
        datastore = new Datastore.withKinds(connection, [fileKind, protectedFileKind, notDirectSubkind, errKind]);
        if (!logging) {
          datastore.logger.onRecord.listen(print);
          logging = true;
        }
      });
    });

    test("Should inherit properties", () {
      expect(protectedFileKind.properties.keys,
        unorderedEquals([ "path", "user", "level", Entity.SUBKIND_PROPERTY.name ]));
    });

    test("Should not be able to create a kind which extends a concrete kind", () {
      var concreteKind = new KindDefinition("Concrete", [], concrete: true, entityFactory: (key) => new Entity(key));
      expect(() => new KindDefinition("ConcreteSubkind", [], extendsKind: concreteKind, concrete: true),
          throwsA(new isInstanceOf<KindError>()));
    });

    test("Should be able to instantiate an subkind", () {
        var key = new Key("File", id: 123);
        var ent = new Entity(
                  key,
                  { "path": "/path/to/file",
                    "user": "missy",
                    "level": 0
                  },
                  "ProtectedFile");
        expect(ent.getProperty(Entity.SUBKIND_PROPERTY.name), "ProtectedFile");
        expect(ent.subkind, protectedFileKind);
        //Should inherit the supertype properties
        expect(ent.getProperty("path"), "/path/to/file");
        //And have own properties
        expect(ent.getProperty("level"), 0);
    });

    test("Should not be able to create a key with an abstract kind", () {
      expect(() => new Key("ProtectedFile", id: 123),
          throwsA(new isInstanceOf<KindError>()));
    });

    test("Should throw when instantiating an entity where the subkind does not extend the key", () {
      var key = new Key("File", id: 123);
      expect(
          () => new Entity(key, {}, "NotSubkind"),
          throwsA(new isInstanceOf<KindError>()));
    });

    group("subkind transactions", () {

      var ent;

      setUp(() {
        return datastore.allocateKey("File").then((key) {
          ent = new Entity(
              key,
              { "path": "/path/to/file",
               "user": "missy",
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

      test("Should be able to query for entities of a specific subkind", () {
        var query = new Query("File", new Filter.subkind("ProtectedFile"));
        return datastore.query(query).toList().then((result) {
          expect(result.map((r) => r.key), anyElement(equals(ent.key)));
        });
      });
    });


  });

}