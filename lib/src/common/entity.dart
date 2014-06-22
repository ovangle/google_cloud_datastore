part of datastore.common;

class Entity {
  /**
   * A property definition which can be used in filters which can be
   * used to specify filters which match on an entity's [:key:].
   *
   * The dastore ordering on keys (when filtering for inequality) is:
   * 1. Ancestor Path
   * 2. Entity Kind
   * 3. Identifier (key name or numeric id)
   */
  static const PropertyDefinition KEY_PROPERTY = const _KeyProperty();

  /**
   * A property definition which can be used to filter for properties
   * of a specific subkind of a concrete kind
   */
  static const PropertyDefinition SUBKIND_PROPERTY = const _SubkindProperty();

  final Key key;
  /**
   * The datastore kind of the entity
   */
  KindDefinition get kind => Datastore.kindByName(key.kind);

  /**
   * The specific subkind of the entity. If the kind is [:concrete:], then will
   * be the same as `kind`.
   */
  KindDefinition get subkind {
    if (hasProperty(SUBKIND_PROPERTY.name)) {
      return Datastore.kindByName(getProperty(SUBKIND_PROPERTY.name));
    }
    return kind;
  }

  final Map<String,dynamic> _propertyInits;
  PropertyMap _properties = null;

  /**
   * Initialise the entity properties.
   */
  void _initProperties([KindDefinition subkind]) {
    if (_properties != null) {
      throw new StateError("Properties already initialized");
    }

    var keyKindDefn = Datastore.kindByName(key.kind);

    if (subkind == null) {
      //There is no subkind. The concrete key is the leaf kind.
      _properties = new PropertyMap(keyKindDefn, _propertyInits);
      return;
    }

    if (subkind.concrete) {
      throw new KindError.concreteSubkind(subkind.name);
    }

    var parentKind = subkind.extendsKind;
    while (parentKind != keyKindDefn) {
      parentKind = parentKind.extendsKind;
      if (parentKind == null) {
        throw new KindError.notDirectSubkind(subkind.name, key.kind);
      }
    }

    _properties = new PropertyMap(subkind, _propertyInits);
  }

  /**
   * Create a new [Entity] against the given [datastore]
   * with the given [key] and, optionally, initial values
   * for the entity's properties.
   *
   * If [:autoInitalize:] is `false`, [:kind.initalizeEntity:] must
   * be called after constructing the entity.
   */
  Entity(Key key, [Map<String,dynamic> propertyInits, String subkind, bool autoInitialise=true]) :
    this.key = key,
    _propertyInits = (propertyInits != null) ? propertyInits : const {} {
    if (autoInitialise)
      _initProperties(subkind != null ? Datastore.kindByName(subkind): null);
  }

  bool hasProperty(String propertyName) {
    return _properties.containsKey(propertyName);
  }

  dynamic getProperty(String propertyName) {
    var prop = _properties[propertyName];
    return prop.value;
  }

  void setProperty(String propertyName, var value) {
    var prop = _properties[propertyName];
    prop.value = value;
  }

  schema.Entity _toSchemaEntity() {
    schema.Entity schemaEntity = new schema.Entity();
    schemaEntity.key = key._toSchemaKey();
    var kindProperties = (subkind != null) ? subkind.properties : kind.properties;
    _properties.forEach((String name, _PropertyInstance prop) {
      var defn = kindProperties[name];
      assert(defn != null);
      schemaEntity.property.add(prop._toSchemaProperty(defn));
    });
    return schemaEntity;
  }

  bool operator ==(Object other) => other is Entity && other.key == key;
  int get hashCode => key.hashCode;

  String toString() => "Entity($key)";
}

/**
 * The result of a lookup operation for an [Entity].
 */
class EntityResult<T extends Entity> {
  static const KEY_ONLY = 'key_only';
  static const ENTITY_PRESENT = 'entity_present';

  /**
   * The looked up key
   */
  final Key key;
  /**
   * The entity found associated with the [:key:] in the datastore,
   * or `null` if no entity corresponding with the given key exists.
   */
  final T entity;

  bool get isKeyOnlyResult => resultType == KEY_ONLY;

  bool get isPresent => resultType == ENTITY_PRESENT;

  final resultType;

  EntityResult._(this.resultType, this.key, this.entity);

  factory EntityResult._fromSchemaEntityResult(
      Datastore datastore,
      schema.EntityResult entityResult,
      schema.EntityResult_ResultType resultType) {
    if (resultType == schema.EntityResult_ResultType.KEY_ONLY) {
      var key = new Key._fromSchemaKey(entityResult.entity.key);
      return new EntityResult._(KEY_ONLY, key, null);
    }
    if (resultType == schema.EntityResult_ResultType.FULL) {
      var key = new Key._fromSchemaKey(entityResult.entity.key);
      var kind = Datastore.kindByName(key.kind);
      var ent = kind._fromSchemaEntity(key, entityResult.entity);
      return new EntityResult._(ENTITY_PRESENT, key, ent);
    }
    //We don't support projections (yet).
    assert(false);
  }
}

class PropertyMap extends UnmodifiableMapMixin<String,_PropertyInstance> {
  final KindDefinition kind;
  Map<String,_PropertyInstance> _entityProperties;

  PropertyMap(KindDefinition this.kind, Map<String,dynamic> propertyInits) :
    _entityProperties = new Map() {
    this.kind.properties.forEach((name, defn) {
      if (name == Entity.SUBKIND_PROPERTY.name) {
        _entityProperties[name] = defn.type.create(initialValue: kind.name);
      } else {
        _entityProperties[name] = defn.type.create(initialValue: propertyInits[name]);
      }
    });
  }

  @override
  _PropertyInstance operator [](String key) {
    if (!containsKey(key))
      throw new NoSuchPropertyError(kind, key);
    return _entityProperties[key];
  }

  @override
  bool containsKey(String key) => _entityProperties.containsKey(key);

  @override
  bool containsValue(_PropertyInstance value) => _entityProperties.containsValue(value);

  @override
  void forEach(void f(String key, _PropertyInstance value)) {
    _entityProperties.forEach(f);
  }

  @override
  bool get isEmpty => _entityProperties.isEmpty;

  @override
  bool get isNotEmpty => _entityProperties.isNotEmpty;

  @override
  Iterable<String> get keys => _entityProperties.keys;

  @override
  int get length => _entityProperties.length;

  @override
  Iterable<_PropertyInstance> get values => _entityProperties.values;
}
