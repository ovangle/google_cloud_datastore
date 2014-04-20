part of datastore.common;

typedef Entity EntityFactory(Key key);

/**
 * Represents a static definition of an [Entity].
 */
class KindDefinition {

  static Entity _entityFactory(Key key) =>
      new Entity(key);

  /**
   * The datastore name of the kind.
   */
  final String name;

  /**
   * The name of the kind extended by `this`, or `null` if this kind directly extends from [Entity].
   */
  final KindDefinition extendsKind;

  /**
   * The properties directly declared on the entity
   */
  final Map<String,PropertyDefinition> _properties;

  /**
   * The properties declared on the entity or any of it's extended entities.
   */
  Map<String,PropertyDefinition> _allProperties;


  UnmodifiableMapView<String,PropertyDefinition> get properties {
    if (_allProperties == null) {
      _allProperties = new Map.from(_properties);
      if (extendsKind != null) {
        _allProperties.addAll(extendsKind.properties);
      }
    }
    return new UnmodifiableMapView(_allProperties);
  }


  final EntityFactory entityFactory;

  /**
   * Create a new [KindDefinition] with the given [:name:] and [:properties:].
   * The [:entityFactory:] argument should *never* be provided by user code.
   */
  KindDefinition(this.name, List<PropertyDefinition> properties, {KindDefinition this.extendsKind, EntityFactory this.entityFactory: _entityFactory}) :
    this._properties = new Map.fromIterable(properties, key: (prop) => prop.name);

  PropertyDefinition get _keyProperty => new _KeyProperty();

  bool hasProperty(PropertyDefinition property) {
    return properties.keys.any((k) => k == property.name);
  }

  Entity _fromSchemaEntity(Key key, schema.Entity schemaEntity) {
    Entity ent = entityFactory(key);

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

  String toString() => name;

  bool operator ==(Object other) => other is KindDefinition && other.name == name;

  int get hashCode => 37 * name.hashCode;
}