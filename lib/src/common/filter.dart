part of datastore.common;

class Operator {
  static const EQUAL = 
      const Operator._("==", schema.PropertyFilter_Operator.EQUAL);
  static const GREATER_THAN = 
      const Operator._(">", schema.PropertyFilter_Operator.GREATER_THAN);
  static const GREATER_THAN_OR_EQUAL = 
      const Operator._(">=", schema.PropertyFilter_Operator.GREATER_THAN_OR_EQUAL);
  static const LESS_THAN = 
      const Operator._("<", schema.PropertyFilter_Operator.LESS_THAN);
  static const LESS_THAN_OR_EQUAL = 
      const Operator._("<=", schema.PropertyFilter_Operator.LESS_THAN_OR_EQUAL);
  
  //A string representation of the operator
  final String _repr;
  //The underlying schema operator.
  final schema.PropertyFilter_Operator _schemaOperator;
  
  const Operator._(String this._repr, schema.PropertyFilter_Operator this._schemaOperator);
  
  String toString() => _repr;
}

/**
 * A [Filter
 */
abstract class Filter {
  factory Filter(Property property, Operator operator, dynamic value) =>
      new _PredicateFilter(property, operator, value);
  
  factory Filter.and(Iterable<Filter> filters) =>
      new _CompositeFilter(filters);
  
  schema.Filter _toSchemaFilter(); 
}

class _PredicateFilter implements Filter {
  Property property;
  Operator operator;
  dynamic value;
  
  _PredicateFilter(Property property, Operator operator, var value) :
    this.property = property,
    this.operator = operator,
    this.value = property.type.checkType(value);
  
  schema.Filter _toSchemaFilter() {
    
    schema.Value propValue = new schema.Value();
    property.type._toSchemaValue(propValue, value);
    
    schema.PropertyFilter propFilter = new schema.PropertyFilter()
      ..property = property._toSchemaPropertyReference()
      ..operator = operator._schemaOperator
      ..value = propValue;
    return new schema.Filter()
      ..propertyFilter = propFilter;
  }
  
  String toString() => "${property.name} $operator $value";
}

class _CompositeFilter implements Filter {
  final List<Filter> operands;
  
  _CompositeFilter(Iterable<Filter> operands) :
    this.operands = operands.toList(growable: false);
  
  schema.Filter _toSchemaFilter() {
    var compositeFilter = new schema.CompositeFilter()
        ..operator = schema.CompositeFilter_Operator.AND
        ..filter.addAll(operands.map((operand) => operand._toSchemaFilter()));
    return new schema.Filter()
        ..compositeFilter = compositeFilter;
  }
  
  String toString() => operands.join(" AND ");
}

