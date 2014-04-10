library datastore.mirrorfree.test;

import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:unittest/unittest.dart';

import '../../lib/src/common.dart';
import '../../lib/src/schema_v1_pb2.dart' as schema;
import '../mock_connection.dart';

final KindDefinition userKind =
  new KindDefinition("User",
      [ new PropertyDefinition("username", PropertyType.STRING, indexed: true), 
        new PropertyDefinition("email", PropertyType.STRING, indexed: true),
        new PropertyDefinition("password", PropertyType.BLOB),
        new PropertyDefinition("details", PropertyType.KEY),
        new PropertyDefinition("date_joined", PropertyType.DATE_TIME)
      ]);

final KindDefinition userDetailsKind =
  new KindDefinition("UserDetails",
      [ new PropertyDefinition("name", PropertyType.STRING),
        new PropertyDefinition("age", PropertyType.INTEGER),
        new PropertyDefinition("isAdmin", PropertyType.BOOLEAN),
        new PropertyDefinition("friends", PropertyType.LIST(PropertyType.KEY))
      ]);

final NOW = new DateTime.now();

void main() {
  group("property tests", () {
    MockConnection mockConnection = new MockConnection();
    Datastore datastore = new Datastore(mockConnection, [userKind, userDetailsKind]);
    
    test("get/set", () {
      var userDetailsKey = new Key("UserDetails", name: "gary");
      var userDetails = new Entity(datastore, userDetailsKey);
      userDetails.setProperty("name", "Bob");
      expect(userDetails.getProperty("name"), "Bob", reason: "name");
      
      userDetails.setProperty("age", 114);
      expect(userDetails.getProperty("age"), 114, reason: "age");
     
      userDetails.setProperty("isAdmin", true);
      expect(userDetails.getProperty("isAdmin"), true, reason: "isAdmin");
      
      var friends = 
          [ new Key("User", name: "ghreuiorew"),
            new Key("User", name: "fdsjkalfdi")
          ];
      userDetails.setProperty("friends", friends);
      expect(userDetails.getProperty("friends"), friends, reason: "friends");
      
      var userKey = new Key("User", name: "dfhasjkue");
      var user = new Entity(datastore, userKey);
      
      user.setProperty("email", "alice@something.com");
      expect(user.getProperty("email"), "alice@something.com", reason: "email");
      
      user.setProperty("password", new Uint8List.fromList([1,2,3,4,5]));
      expect(user.getProperty("password"), [1,2,3,4,5], reason: "password");
      
      final now = new DateTime.now();
      
      user.setProperty("date_joined", now);
      expect(user.getProperty("date_joined"), now, reason: "date_joined");
    });
    
    schema.Entity _createUser(
        String userKeyName, 
        String username, 
        List<int> password,
        String detailsKeyName,
        DateTime dateJoined) {
      var key = new schema.Key()
          ..pathElement.add(new schema.Key_PathElement()..kind = "User" ..name = userKeyName);
      var usernameProp = new schema.Property()
          ..name = "username"
          ..value = (new schema.Value()..stringValue = username);
      var passwordProp = new schema.Property()
          ..name = "password"
          ..value = (new schema.Value()..blobValue.addAll(password));
      var detailsKey = new schema.Key()
          ..pathElement.add(new schema.Key_PathElement()..kind = "UserDetails"..name = detailsKeyName);
      var detailsProp = new schema.Property()
          ..name = "details"
          ..value = (new schema.Value()..keyValue = detailsKey);
      var dateJoinedProp = new schema.Property()
          ..name = "date_joined"
          ..value = (new schema.Value()..timestampMicrosecondsValue = new Int64(dateJoined.millisecondsSinceEpoch * 1000));
      
      var props = [ usernameProp, passwordProp, detailsProp, dateJoinedProp];
      
      return new schema.Entity()
          ..key = key
          ..property.addAll(props);
    }
    
    final schema.Entity userBob = _createUser("asdf", "bob", [1,2,3], "details_key_asdf", NOW);
    final schema.Entity userAlice = _createUser("asdf2", "alice", [2,3,4], "details_key_asdf2", NOW);
    final schema.Entity userNick = _createUser("asdf3", "nick", [5,5,5], "details_key_asdf3", NOW);
    
    
    group("datastore lookup", () {
      final missingEntityKey =
          new schema.Key()
          ..pathElement.add(new schema.Key_PathElement()..kind = "User"..name="missing1");
      final missingEntity = new schema.Entity()..key = missingEntityKey;
      
      final deferredKey = 
          new schema.Key()
          ..pathElement.add(new schema.Key_PathElement()..kind = "User"..name="deferred1");
      
      final deferredEntity = new schema.Entity()
          ..key = deferredKey
          ..property.addAll(userNick.property);
      
      var connection = new MockConnection();
      connection
          ..lookupResponseFound.addAll(
              [ new schema.EntityResult()..entity = userBob,
                new schema.EntityResult()..entity = userAlice])
          ..lookupResponseMissing.addAll([new schema.EntityResult()..entity = missingEntity])
          ..lookupDeferredFound.addAll([new schema.EntityResult()..entity = deferredEntity]);
      
      Datastore datastore = new Datastore(connection, [userKind]);
      
      var keys = 
                  [ new Key("User", name: "asdf"),
                    new Key("User", name: "asdf2"),
                    new Key("User", name: "missing1"),
                    new Key("User", name: "deferred1")
                  ];
      
      test("single", () {
        return datastore.lookup(new Key("User", name: "asdf"))
            .then((result) {
              expect(result.isKeyOnlyResult, isFalse);
              expect(result.entity.key, isIn(keys));
            });
      });
      
      test("many", () {
        return datastore.lookupAll(keys)
            .toList()
            .then((entityResults) {
              expect(entityResults.map((ent) => ent.key), unorderedEquals(keys));

              var foundEntities = entityResults
                  .where((result) => !result.isKeyOnlyResult)
                    .map((result) => result.entity);
              expect(foundEntities.map((ent) => ent.getProperty("username")), 
                     unorderedEquals(["nick", "bob", "alice"]));
              expect(foundEntities.map((ent) => ent.getProperty("password")),
                     unorderedEquals([[1,2,3], [2,3,4], [5,5,5]]));
            });
      });
    });
  });
  
}