part of datastore.common;

typedef Entity EntityFactory(Datastore datastore, Key key);

/**
 * Represents a static definition of an [Entity].
 */
class Kind {
  
  //TODO: Kind inheritance?
  
  static Entity _entityFactory(Datastore datastore, Key key) => 
      new Entity(datastore, key);
  
  /**
   * The datastore name of the kind.
   */
  final String name;
  /**
   * The properties of the entity.
   */
  UnmodifiableMapView<String,Property> get properties => new UnmodifiableMapView<String,Property>(_properties);
  final Map<String,Property> _properties;
  
  final EntityFactory entityFactory;
  
  Entity _fromSchemaEntity(Datastore datastore, Key key, schema.Entity schemaEntity) {
    Entity ent = entityFactory(datastore, key);
    
    for (schema.Property schemaProp in schemaEntity.property) {
      var kindProp = _properties[schemaProp.name];
      if (kindProp == null)
        throw new NoSuchPropertyError(this, schemaProp.name);
      ent._properties[schemaProp.name].value = 
          kindProp.type._fromSchemaValue(schemaProp.value);
    }
    return ent;
  }
  
  /**
   * Create a new [Kind] with the given [:name:] and [:properties:]. 
   * The [:entityFactory:] argument should *never* be provided by user code.
   */
  Kind(this.name, List<Property> properties, [EntityFactory this.entityFactory = _entityFactory]) :
    this._properties = new Map.fromIterable(properties, key: (prop) => prop.name);
  
  schema.KindExpression _toSchemaKindExpression() {
    return new schema.KindExpression()
        ..name = this.name;
  }
}