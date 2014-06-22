/**
 * Basic tests relating to the definitions of subkinds
 */

library mirrorfree_test.subtyping;

import 'package:unittest/unittest.dart';

import '../logging.dart';

import '../../lib/src/connection.dart';
import '../../lib/src/common.dart';

import 'kinds.dart';

//Invalid since both the implementing and base class are concrete
final concreteBase = new KindDefinition("ConcreteBase", [], concrete: true, entityFactory: (key) => new Entity(key));

//Invalid since
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

  initLogging();

  group("subkinds", () {
    Datastore datastore;

    List testKinds = mirrorfreeKinds
        ..addAll([concreteBase, errKind, notDirectSubkind]);

    setUp(() {
      return DatastoreConnection.open('41795083', 'crucial-matter-487',
         host: 'http://127.0.0.1:5961').then((connection) {
       Datastore.clearKindCache();
       datastore = new Datastore.withKinds(connection, testKinds);
     });
    });

    test("Should inherit properties", () {
       expect(ProtectedFile.protectedFileKind.properties.keys,
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
                    "user": new Key("User", name: "missy"),
                    "level": 0
                  },
                  "ProtectedFile");
        expect(ent.getProperty(Entity.SUBKIND_PROPERTY.name), "ProtectedFile");
        expect(ent.subkind, ProtectedFile.protectedFileKind);
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
  });
}