part of datastore.common;

class Query {
  /**
   * A kind or list of kinds to query
   */
  final KindDefinition kind;
  final Filter filter;
  final List<PropertyDefinition> _groupBy;
  final List<_Ordering> _sortBy;
  final bool keysOnly;

  factory Query(/* String | KindDefinition */ kind, Filter filter, {bool keysOnly: false}) {
    if (kind is String) {
      kind = Datastore.kindByName(kind);
    } else {
      assert(kind is KindDefinition);
    }
    filter._checkValidFilter(kind);
    return new Query._(kind, filter, keysOnly: keysOnly);
  }

  /**
   * Create a new [Query] which matches against subkinds of the given [KindDefinition]
   */
  Query._(KindDefinition this.kind, Filter this.filter, {bool this.keysOnly: false}) :
    this._groupBy = new List<PropertyDefinition>(),
    this._sortBy = new List<_Ordering>();

  /**
   * Group the results of a query by the value of the specified property.
   *
   * [:property:] can either be a [String] or a [PropertyDefinition].
   */
  void groupBy(/* String | PropertyDefinition */ property) {
    if (property is String)
      property = Datastore.propByName(kind.name, property);
    if (!kind.hasProperty(property)) {
      throw new NoSuchPropertyError(kind, property.name);
    }
    _groupBy.add(property);
  }

  /**
   * Sort the results of a query by the value of a specified property.
   *
   * [:property:] can be either a [String] or a [PropertyDefinition].
   *
   * If [:ascending:] is `true`, the results will be ordered in the direction of increasing value of the property.
   * Otherwise, the results will be ordered in the direction of decreasing value.
   *
   * If `sortBy` has already been called with a value of another proeprty, the results will be sorted with respect
   * to that proeprty first, and subsequently by the value of the current property.
   */
  void sortBy(/*String | PropertyDefinition */ property, {bool ascending: true}) {
    if (property is String)
      property = Datastore.propByName(kind.name, property);
    var inequalityProps = filter._inequalityProperties;
    if (inequalityProps.isNotEmpty) {
      var inequalityProp = inequalityProps.single;
      if (_sortBy.isNotEmpty && property == inequalityProp) {
        throw new InvalidQueryException(
            "A property used in an equality filter (${property.name}) "
            "must be sorted first");
      }
    }

    if (!property.indexed) {
      throw new InvalidQueryException(
          "Cannot sort by unindexed property ${property.name}.");
    }

    if (!kind.hasProperty(property)) {
      throw new NoSuchPropertyError(kind, property.name);
    }
    this._sortBy.add(new _Ordering(property, ascending));
  }

  /**
   * Sort the results of a query by the value of the key.
   */
  void sortByKey({bool ascending: true}) {
    this._sortBy.add(new _Ordering(kind._keyProperty, ascending));
  }

  /**
   * Get a schema query expression from the properties
   * of this
   */
  schema.Query _toSchemaQuery() {
    var projection = [];
    if (keysOnly) {
      var proj = new schema.PropertyExpression()
          ..property = kind._keyProperty._toSchemaPropertyReference();
      projection.add(proj);
    }
    return new schema.Query()
        ..kind.add(kind._toSchemaKindExpression())
        ..filter = filter._toSchemaFilter()
        ..groupBy.addAll(_groupBy.map((prop) => prop._toSchemaPropertyReference()))
        ..order.addAll(_sortBy.map((order) => order._toSchemaPropertyOrder()))
        ..projection.addAll(projection);
  }
}

class _Ordering {
  final PropertyDefinition property;
  final bool isAscending;

  _Ordering(PropertyDefinition this.property, bool this.isAscending);

  schema.PropertyOrder _toSchemaPropertyOrder() =>
      new schema.PropertyOrder()
          ..property = property._toSchemaPropertyReference()
          ..direction = (
              isAscending
                  ? schema.PropertyOrder_Direction.ASCENDING
                  : schema.PropertyOrder_Direction.DESCENDING
          );

  bool operator ==(Object other) =>
      other is _Ordering && other.property == property;

  int get hashCode => property.hashCode;
}

class InvalidQueryException implements Exception {
  final String message;

  InvalidQueryException(this.message);

  toString() => "Invalid query: $message";
}