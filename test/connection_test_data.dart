
import 'dart:async';
import 'dart:io';
import 'dart:math' show max;
import 'package:fixnum/fixnum.dart';

import 'package:quiver/async.dart';
import '../lib/src/schema_v1_pb2.dart';




//Just test that we get some random entities generated.
void main() {
  testUsers().then((users) {
    for (Entity user in users) {
      //print(user);
    }
  });
}

//A list of users of encoded entities
//TODO: Extend entity.
// @Kind()
// class User extends Entity {
//   User(datastore, int id): super(datastore, new Key("User", id: id);
//
//   @property(indexed: true)
//   String name => getProperty("name");
//   @property()
//   Uint8List password => getProperty("password");
//   @property(name: "date_joined")
//   DateTime get dateJoined => getProperty("date_joined");
//   @property(name: "user_details")
//   Key get userDetails => getProperty("user_details");
//   @property(name: "age")
//   int get age => getProperty("age");
//   @property(name: "isAdmin")
//   bool get isAdmin => getProperty("isAdmin");
//   @property(name: "friends")
//   List<Key> get friends => getProperty("friends");
// }
Future<List<Entity>> testUsers() {
  List<Entity> ents = new List();
  Completer completer = new Completer();
  forEachAsync(
      userKeys,
      (key) {
        return _userProperties(ents.length).then((props) {
          var ent = new Entity()
            ..key = key
            ..property.addAll(props);
          ents.add(ent);
        });
      })
      .then((_) => completer.complete(ents));
  return completer.future;
}


List<Key> get userKeys {
  List<Key> keys = [];
  for (var i=0;i<100;i++) {
    var path = new Key_PathElement()..kind="User"..id=new Int64(i);
    keys.add(new Key()..pathElement.add(path));
  }
  return keys;
}

List<Key> get userDetailsKeys {
  List<Key> keys = [];
  for (var i=0;i<100;i++) {
    var path = new Key_PathElement()..kind="UserDetails"..id=new Int64(i + 100);
    keys.add(new Key()..pathElement.add(path));
  }
  return keys;
}

var _words;
Future<Iterable<String>> get loadWords {
  if (_words == null) {
    //TODO: Don't load from words!
    var f = new File('/usr/share/dict/words');
    return f.readAsLines()
        .then((lines) =>
            _words = lines
                .where((line) => line.length > 5)
                .toList(growable: false))
        .then((_) => _words);
  }
  return new Future.value(_words);
}

Future<Property> _getName(int i) {
  return loadWords.then((words) {
    var name = words[i];
    return new Property()
      ..name = "name"
      ..value = (new Value()..stringValue = name..indexed=true);
  });
}

Future<Property> _getPassword(int i) {
   return loadWords.then((words) {
      var password = words[500 + i];
      return new Property()
        ..name = "password"
        ..value = (new Value()..blobValue=password.codeUnits);
   });
}

Property _getDateJoined(int i) {
  return new Property()
    ..name = "date_joined"
    ..value = (new Value()..timestampMicrosecondsValue = new Int64(i * 100000));
}

Property _getUserDetailsProp(int i) {
  return new Property()
      ..name = "user_details"
      ..value = (new Value()..keyValue = userDetailsKeys[i]);
}

Future<List<Property>> _userProperties(int i) {
  var props = [];
  props.add(_getDateJoined(i));
  props.add(_ageProperty(i));
  props.add(_isAdminProperty(i));
  props.add(_friendsProperty(i));
  props.add(_getUserDetailsProp(i));
  return _getName(i).then((name) {
    props.add(name);
    return _getPassword(i).then((password) {
      props.add(password);
      return props;
    });
  });
}

Property _ageProperty(int i) {
  return new Property()
    ..name = "age"
    ..value = (new Value()..integerValue = new Int64(i));
}

Property _isAdminProperty(int i) {
  return new Property()
    ..name = "isAdmin"
    ..value = (new Value()..booleanValue = (i % 2 == 0));
}

Property _friendsProperty(int i) {
  var friends = userKeys.skip(max(i - 1 , 0)).take(2);
  var friendsValues = friends.map((f) => new Value()..keyValue = f);
  return new Property()
    ..name = "friends"
    ..value = (new Value()..listValue.addAll(friendsValues));
}

