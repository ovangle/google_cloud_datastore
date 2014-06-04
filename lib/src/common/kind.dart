part of datastore.common;

typedef Entity EntityFactory(Key key);

/**
 * Represents a static definition of an [Entity].
 */
class KindDefinition {

  /**
   * The datastore name of the kind.
   */
  final String name;

  /**
   * The name of the kind extended by `this`, or `null` if this kind directly extends from [Entity].
   *
   * Only one superclass of the kind can have a kind definition.
   */
  final KindDefinition extendsKind;

  /**
   * A [:concrete:] kind is stored in the datastore as an entity with the kind [:name:]
   * If a kind is not concrete, it is stored as an entity with the name of the first
   * concrete ancestor of the kind.
   *
   * It is an error for a kind to be both concrete and to have concrete ancestors.
   *
   * For example,
   * Given the kind `Mammal` and kinds `Dog` and `Cat` which extend `Mammal`, there are
   * two possibilities:
   * - `Dog` and `Cat` should inherit the properties of `Mammal`, but should be stored
   * in separate datastore entities. In this case, both subkinds should be concrete, and
   * keys and queries should have the name of the concrete kind.
   * - `Dog` and `Cat` should inherit the properties of `Mammal` *and* should be stored
   * in the same datastore entity. In this case, only the `Mammal` type should be concrete
   * and queries against the `Mammal` type can return entities of either subkind.
   */
  final bool concrete;

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

    //abstract properties always have a `___subkind___` property
    if (!concrete) {
      _allProperties[Entity.SUBKIND_PROPERTY.name] = Entity.SUBKIND_PROPERTY;
    }

    return new UnmodifiableMapView(_allProperties);
  }


  final EntityFactory entityFactory;

  /**
   * Create a new [KindDefinition] with the given [:name:] and [:properties:].
   * The [:entityFactory:] argument should *never* be provided by user code.
   */
  KindDefinition._(this.name, List<PropertyDefinition> properties, {KindDefinition this.extendsKind, bool this.concrete: true, this.entityFactory}) :
    this._properties = new Map.fromIterable(properties, key: (prop) => prop.name);

  factory KindDefinition(
      String name,
      List<PropertyDefinition> properties,
      { KindDefinition extendsKind,
        bool concrete: true,
        EntityFactory entityFactory}) {
    var parentKind = extendsKind;
    if (concrete) {
      while (parentKind != null) {
        if (parentKind.concrete)
          throw new KindError.multipleConcreteKindsInInheritanceHeirarchy(name, parentKind.name);
      }
    }
    return new KindDefinition._(
        name,
        properties,
        extendsKind: extendsKind,
        concrete: concrete,
        entityFactory: entityFactory
    );
  }

  PropertyDefinition get _keyProperty => new _KeyProperty();

  bool hasProperty(PropertyDefinition property) {
    return properties.keys.any((k) => k == property.name);
  }

  Entity _fromSchemaEntity(Key key, schema.Entity schemaEntity, [bool atSubkind=false]) {

    if (!atSubkind) {
      //Check if we need to create a subkind for the entity.
      for (var prop in schemaEntity.property) {
        if (prop.name == Entity.SUBKIND_PROPERTY.name) {
          var subkind = prop.value.stringValue;
          if (subkind != null) {
            return Datastore.kindByName(subkind)._fromSchemaEntity(key, schemaEntity, true);
          }
        }
      }
    }

    Entity ent = entityFactory(key);

    for (schema.Property schemaProp in schemaEntity.property) {
      var kindProp = properties[schemaProp.name];
      if (kindProp == null) {
        datastoreLogger.warning(
            "No property found on datastore entity ${this} corresponding\n"
            "to schema property ${schemaProp.name}");
      } else {
        ent._properties[schemaProp.name].value =
          kindProp.type._fromSchemaValue(schemaProp.value);
      }
    }
    return ent;
  }

  /**
   * Initializes all the properties on the given entity
   */
  void initializeEntity(Entity entity) {
    entity._initProperties( (!concrete) ? this : null );
  }

  schema.KindExpression _toSchemaKindExpression() {
    return new schema.KindExpression()
        ..name = this.name;
  }

  String toString() => name;

  bool operator ==(Object other) => other is KindDefinition && other.name == name;

  int get hashCode => 37 * name.hashCode;
}