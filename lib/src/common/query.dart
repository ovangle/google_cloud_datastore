part of datastore.common;

class Query {
  /**
   * A kind or list of kinds to query
   */
  final Kind kind;
  final Filter filter;
  final List<Property> _groupBy;
  final List<_Ordering> _sortBy;
  
  /**
   * Create a new [Query] which matches against subkinds of the given [Kind]
   */
  Query(Kind kind, Filter filter) :
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
  
  schema.KindExpression get _kindExpr => kind._toSchemaKindExpression();
  
  Iterable<schema.PropertyReference> get _groupByExpr =>
      _groupBy.map((prop) => prop._toSchemaPropertyReference());
  
  Iterable<schema.PropertyOrder> get _orderExpr =>
      _sortBy.map((ordering) => ordering._toSchemaPropertyOrder());
  
  schema.Query _toSchemaQuery() {
    schema.Query schemaQuery = new schema.Query()
        ..kind.add(_kindExpr)
        ..filter = filter._toSchemaFilter()
        ..groupBy.addAll(_groupByExpr)
        ..order.addAll(_orderExpr);
    return schemaQuery;
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