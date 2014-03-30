part of datastore.common;

typedef Entity EntityFactory(Datastore datastore, Key key);

/**
 * Represents a static definition of an [Entity].
 */
class Kind {
  
  static Entity _entityFactory(Datastore datastore, Key key) => 
      new Entity(datastore, key);
  
  /**
   * The datastore name of the kind.
   */
  final String name;
  
  /**
   * The name of the kind extended by `this`, or `null` if this kind directly extends from [Entity].
   */
  final Kind extendsKind;
  
  List<Kind> _cachedSubKinds;
  
  /**
   * Create a new [Kind] with the given [:name:] and [:properties:]. 
   * The [:entityFactory:] argument should *never* be provided by user code.
   */
  Kind(this.name, List<Property> properties, {Kind this.extendsKind, EntityFactory this.entityFactory: _entityFactory}) :
    this.properties = new UnmodifiableMapView(new Map.fromIterable(properties, key: (prop) => prop.name));
  
  Iterable<Kind> _subKinds(Datastore datastore) {
    if (_cachedSubKinds == null) {
      _cachedSubKinds = datastore._entityKinds.values
          .where((kind) => kind._isAssignableTo(this));
    }
    return _cachedSubKinds;
  }
  
  bool _isAssignableTo(Kind kind) {
    if (name == kind.name)
      return true;
    if (extendsKind == null)
      return false;
    return extendsKind._isAssignableTo(kind);
  }
  
  bool hasProperty(Property property) {
    return properties.keys.any((k) => k == property.name);
  }
  
  /**
   * The properties of the entity.
   */
  final UnmodifiableMapView<String,Property> properties;
  
  final EntityFactory entityFactory;
  
  Entity _fromSchemaEntity(Datastore datastore, Key key, schema.Entity schemaEntity) {
    Entity ent = entityFactory(datastore, key);
    
    for (schema.Property schemaProp in schemaEntity.property) {
      var kindProp = properties[schemaProp.name];
      if (kindProp == null)
        throw new NoSuchPropertyError(this, schemaProp.name);
      ent._properties[schemaProp.name].value = 
          kindProp.type._fromSchemaValue(schemaProp.value);
    }
    return ent;
  }
  
  
  schema.KindExpression _toSchemaKindExpression() {
    return new schema.KindExpression()
        ..name = this.name;
  }
}