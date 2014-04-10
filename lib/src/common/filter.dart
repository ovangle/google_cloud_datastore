part of datastore.common;



/**
 * A [Filter] is used in a datastore [Query] to match against persistable properties on a [KindDefinition].
 */
abstract class Filter {
  /**
   * Returns a filter which compares [:property:] against the given [:value:]
   * in the datastore.
   */
  factory Filter(PropertyDefinition property, Operator operator, dynamic value) =>
      new _PredicateFilter(property, operator, value);
  
  /**
   * Filters that matches datastore entities who have an ancestor which
   * matches the specified key.
   */
  factory Filter.ancestorIs(Key key) =>
      new _AncestorFilter(key);
  
  /**
   * Forms a logical conjuction of a collection of filters.
   */
  factory Filter.and(Iterable<Filter> filters) =>
      new _CompositeFilter(filters);
  
  schema.Filter _toSchemaFilter(); 
 
  Filter _checkValidFilterForKind(KindDefinition kind);
}

/**
 * An operator for use in a predicate filter.
 */
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
 * Filter entities where the [PropertyDefinition] matches [value]
 * under one of the operators.
 */
class _PredicateFilter implements Filter {
  PropertyDefinition property;
  Operator operator;
  dynamic value;
  
  _PredicateFilter(PropertyDefinition property, Operator operator, var value) :
    this.property = property,
    this.operator = operator,
    this.value = property.type.checkType(value);
  
  @override
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
    
  @override
  Filter _checkValidFilterForKind(KindDefinition kind) {
    if (!kind.hasProperty(property)) {
      throw new NoSuchPropertyError(kind, property.name);
    }
    return this;
  }
 
  @override
  String toString() =>
    "${property.name} $operator $value";
}

/**
 * Filters entities who have an ancestor which matches the specified [Key].
 */
class _AncestorFilter implements Filter {
  final Key key;
  
  _AncestorFilter(this.key);
 
  @override
  Filter _checkValidFilterForKind(KindDefinition kind) => this;
  
  @override
  schema.Filter _toSchemaFilter() {
    schema.Value propValue = new schema.Value()
        ..keyValue = key._toSchemaKey();
    schema.PropertyFilter propFilter = new schema.PropertyFilter()
      ..property = (new schema.PropertyReference()..name = "__key__")
      ..operator = schema.PropertyFilter_Operator.HAS_ANCESTOR
      ..value = propValue;
    
    return new schema.Filter()
      ..propertyFilter = propFilter;
  }
  
  @override
  String toString() => "ANCESTOR IS ${key}";
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
  
  Filter _checkValidFilterForKind(KindDefinition kind) { 
    operands.forEach((operand) => operand._checkValidFilterForKind(kind));
    return this;
  }
}

