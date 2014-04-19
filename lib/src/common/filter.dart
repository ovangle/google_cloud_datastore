part of datastore.common;



/**
 * A [Filter] is used in a datastore [Query] to match against persistable properties on a [KindDefinition].
 */
abstract class Filter {
  /**
   * Returns a filter which compares [:property:] against the given [:value:]
   * in the datastore.
   */
  factory Filter(/* String | PropertyDefinition */ property, Operator operator, dynamic value) =>
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

  void _checkValidFilter(KindDefinition kind);

  // The properties which are filtered for inequality
  Set<PropertyDefinition> get _inequalityProperties;
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

  static const values = const [EQUAL, GREATER_THAN, GREATER_THAN_OR_EQUAL, LESS_THAN, LESS_THAN_OR_EQUAL];

  static const inequalities = const [GREATER_THAN, GREATER_THAN_OR_EQUAL, LESS_THAN, LESS_THAN_OR_EQUAL];
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
  var /* String | PropertyDefinition */ property;
  Operator operator;
  dynamic value;

  _PredicateFilter(/*String | PropertyDefinition */ property, Operator operator, var value) :
    this.property = property,
    this.operator = operator,
    this.value = value;

  @override
  schema.Filter _toSchemaFilter() {
    var propDefn = property as PropertyDefinition;

    schema.Value propValue = new schema.Value();
    propDefn.type._toSchemaValue(propValue, value);

    schema.PropertyFilter propFilter = new schema.PropertyFilter()
      ..property = propDefn._toSchemaPropertyReference()
      ..operator = operator._schemaOperator
      ..value = propValue;
    return new schema.Filter()
      ..propertyFilter = propFilter;
  }

  @override
  void _checkValidFilter(KindDefinition kind) {
    if (property is String) {
      property = Datastore.propByName(kind.name, property);
    } else if (!kind.hasProperty(property)) {
      throw new NoSuchPropertyError(kind, property.name);
    }
    value = (property as PropertyDefinition).type.coerceType(value);
  }

  @override
  String toString() =>
    "${(property is PropertyDefinition ? property.name : property)} $operator $value";


  @override
  Set<PropertyDefinition> get _inequalityProperties {
    var props = new Set();
    if (Operator.inequalities.contains(operator)) {
      props.add(property);
    }
    return props;
  }

}

/**
 * Filters entities who have an ancestor which matches the specified [Key].
 */
class _AncestorFilter implements Filter {
  final Key key;

  _AncestorFilter(this.key);

  @override
  void _checkValidFilter(KindDefinition kind) => null;

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


  @override
  Set<PropertyDefinition> get _inequalityProperties => new Set();
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

  @override
  String toString() => operands.join(" AND ");

  @override
  void _checkValidFilter(KindDefinition kind) {
    operands.forEach((operand) => operand._checkValidFilter(kind));
    if (_inequalityProperties.length > 1) {
      throw new InvalidQueryException(
          "A query may not use an inequality expression more than once"
          " on any of its filters");
    }
  }

  @override
  Set<PropertyDefinition> get _inequalityProperties =>
      new Set.from(operands.expand((oper) => oper._inequalityProperties));
}

