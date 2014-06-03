library extends_mirrorfree;

import 'package:unittest/unittest.dart';

import '../lib/src/connection.dart';
import '../lib/src/common.dart';

final fileKind =
    new KindDefinition(
        "File",
        [ new PropertyDefinition("path", PropertyType.STRING, indexed: true) ]
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

final errKind = new KindDefinition("Err", []);

final notDirectSubkind =
  new KindDefinition(
      "NotSubkind",
      [ new PropertyDefinition("user", PropertyType.STRING),
        new PropertyDefinition("level", PropertyType.INTEGER)
      ],
      extendsKind: errKind,
      concrete: false
  );
void main() {

  group("kind subtyping", () {
    Datastore datastore;
    setUp(() {
      return DatastoreConnection.open('41795083', 'crucial-matter-487',
          host: 'http://127.0.0.1:5961').then((connection) {
        datastore = new Datastore(connection, [fileKind, protectedFileKind, notDirectSubkind, errKind]);
      });
    });

    test("Should inherit properties", () {
      expect(protectedFileKind.properties.keys,
        unorderedEquals([ "path", "user", "level", Entity.SUBKIND_PROPERTY.name ]));
    });

    test("Should not be able to create a kind which extends a concrete kind", () {
      var concreteKind = new KindDefinition("Concrete", [], concrete: true);
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
      expect(() => new Entity(key, {}, "NotSubkind"), throwsA(new isInstanceOf<KindError>()));
    });

    test("Should be able to store a schema entity", () {
      var key = new Key("File", id: 123);
      var ent = new Entity(key,
          { "path": "/path/to/file",
            "user": "missy",
            "level": 0
          },
          "ProtectedFile");
      return datastore.insert(ent)
          .then((transaction) {
        return datastore.lookup((key)).then((result) {
          expect(result.isPresent, isTrue);
          expect(result.entity.getProperty(Entity.SUBKIND_PROPERTY.name), "ProtectedFile");
        });
      })
      .whenComplete(() => datastore.delete(key));
    });



  });

}