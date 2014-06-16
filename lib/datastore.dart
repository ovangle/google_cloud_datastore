
/**
 * A set of extensions to the datastore framework which allow
 * using the
 */
library datastore;

import 'dart:mirrors';
import 'dart:typed_data';

import 'src/common.dart' hide Datastore;
import 'src/common.dart' as base;
import 'src/connection.dart';

export 'src/common.dart' hide Datastore;
export 'src/connection.dart';

part 'src/datastore_mirrors/annotations.dart';
part 'src/datastore_mirrors/reflection.dart';

class Datastore extends base.Datastore {
  static Map<Type, KindDefinition> _entityTypes = new Map();

  static KindDefinition kindByType(Type type) {
    var kind = _entityTypes[type];
    if (kind == null) {
      throw new NoSuchKindError(type.toString());
    }
    return kind;
  }

  /**
   * Clear the known kinds from the datastore.
   * WARNING: Do not call this method!!! For internal use only.
   */
  static void clearKindCache() {
    base.Datastore.clearKindCache();
    _entityTypes.clear();
  }

  static KindDefinition kindByName(String name) => base.Datastore.kindByName(name);
  static PropertyDefinition propByName(String kind, String name) => base.Datastore.propByName(kind, name);

  Datastore._(DatastoreConnection connection, List<KindDefinition> entityKinds):
    super.withKinds(connection, entityKinds);

  factory Datastore(DatastoreConnection connection) {
    if (_entityTypes.isEmpty) {
      _entityTypes = _entityKinds();
    }
    return new Datastore._(connection, _entityTypes.values.toList(growable: false));
  }
}

class Entity extends base.Entity {
  static Map<Type, String> _clsToKindDefn = new Map();

  Entity(Key key, [Map<String,dynamic> propertyInits=const {}]):
      super(key, propertyInits, null, false) {

    var kind = Datastore.kindByType(runtimeType);
    kind.initializeEntity(this);
  }
}