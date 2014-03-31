part of datastore.common;

class Query {
  /**
   * A kind or list of kinds to query
   */
  final Kind kind;
  final Filter filter;
  final List<Property> _groupBy;
  final List<_Ordering> _sortBy;
  final bool keysOnly;
  
  /**
   * Create a new [Query] which matches against subkinds of the given [Kind]
   */
  Query(Kind kind, Filter filter, {bool this.keysOnly: false}) :
    this.kind = kind,
    this.filter = filter._checkValidFilterForKind(kind),
    this._groupBy = new List<Property>(),
    this._sortBy = new List<_Ordering>();
  
  /**
   * Group the results of a query by the value of the specified property.
   */
  void groupBy(Property property) {
    if (!kind.properties.keys.contains(property.name)) {
      throw new NoSuchPropertyError(kind, property.name);
    }
    _groupBy.add(property);
  }
  
  /**
   * Sort the results of a query by the value of a specified property.
   * 
   * If [:ascending:] is `true`, the results will be ordered in the direction of increasing value of the property.
   * Otherwise, the results will be ordered in the direction of decreasing value.
   * 
   * If `sortBy` has already been called with a value of another proeprty, the results will be sorted with respect
   * to that proeprty first, and subsequently by the value of the current property.
   */
  void sortBy(Property property, {bool ascending: true}) {
    if (!kind.properties.keys.contains(property.name)) {
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
  final Property property;
  final bool isAscending;
  
  _Ordering(Property this.property, bool this.isAscending);
  
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