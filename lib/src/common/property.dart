part of datastore.common;

typedef schema.Value _ToSchemaValue<T>(schema.Value schemaValue, T value);
typedef T _FromSchemaValue<T>(schema.Value value);

/**
 * A persistent value stored on an [Entity].
 */
class PropertyDefinition {
  /**
   * The name of the [PropertyDefinition].
   */
  final String name;
  /**
   * Is the property [indexed] (queryable) in the datastore?
   * Defaults to `false`.
   */
  final bool indexed;
  /**
   * The type of the property.
   */
  final PropertyType type;

  const PropertyDefinition(this.name, PropertyType this.type, {this.indexed: false});

  /**
   * A filter which matches datastore entities where the property value
   * is equal to [:value:]
   */
  Filter filterEquals(var value) => new Filter(this, Operator.EQUAL, value);
  /**
   * A filter which matches datastore entities where the property value
   * is less than [:value:]
   */
  Filter filterLessThan(var value) => new Filter(this, Operator.LESS_THAN, value);
  /**
   * A filter which matches datastore entities where the property value
   * is less than or equal to [:value:]
   */
  Filter filterLessThanOrEquals(var value) => new Filter(this, Operator.LESS_THAN_OR_EQUAL, value);
  /**
   * A filter which matches datastore entities where the property value
   * is greater than [:value:]
   */
  Filter filterGreaterThan(var value) => new Filter(this, Operator.GREATER_THAN, value);
  /**
   * A filter which matches datastore entities where the property value
   * is greater than or equal to [:value:]
   */
  Filter filterGreaterThanOrEquals(var value) => new Filter(this, Operator.GREATER_THAN_OR_EQUAL, value);


  String toString() => "Property($type, indexed: $indexed)";

  bool operator ==(Object other) =>
    other is PropertyDefinition &&
    other.name == name &&
    other.type == type &&
    other.indexed == indexed;

  int get hashCode => qcore.hash3(name, type, indexed);

  schema.PropertyReference _toSchemaPropertyReference() =>
      new schema.PropertyReference()..name = name;
}

/**
 * A property which represents the key of a kind.
 * Used while querying the datastore for a projection which only
 * includes the key in the returned entity.
 */
class _KeyProperty extends PropertyDefinition {
  const _KeyProperty() : super("__key__", PropertyType.KEY, indexed: true);
}

class PropertyType<T> {
  /**
   * A [DYNAMIC] property type admits values from any of the valid property types except [LIST].
   */
  static const PropertyType DYNAMIC = const PropertyType<dynamic>("dynamic", _dynamicToSchemaValue, _dynamicFromSchemaValue);
  /**
   * A [BOOLEAN] property type admits the values `true` and `false`.
   */
  static const PropertyType BOOLEAN = const PropertyType<bool>("boolean", _boolToSchemaValue, _boolFromSchemaValue);
  /**
   * Integer properties accept any valid dart [int] value, however values outside
   * the signed 64 bit integer range will be truncated to a 64 bit integer value
   * before storage in the datastore.
   */
  static const PropertyType INTEGER = const PropertyType<int>("integer", _intToSchemaValue, _intFromSchemaValue);
  /**
   * [DOUBLE] properties admit any valid dart [double] value.
   */
  static const PropertyType DOUBLE = const PropertyType<double>("double", _doubleToSchemaValue, _doubleFromSchemaValue);
  /**
   * A [STRING] character accepts any valid dart string.
   * According to google datastore specifications, indexed [STRING] properties have a maximum length of `500`
   * unicode characters. Unindexed strings have a maximum length of `1MB` of unicode characters.
   */
  static const PropertyType STRING = const PropertyType<String>("string", _stringToSchemaValue, _stringFromSchemaValue);
  /**
   * A [BLOB] property type admits byte lists. Lists of [int]s are not supported as the value
   * of a [BLOB] property, instead the client is expected to use the `dart:typed_data` library.
   *
   * According to google datastore specifications, indexed [BLOB] property have a maximum length of `500` bytes.
   * Unindexed [BLOB] properties have a maximum length of `1MB`.
   */
  static const PropertyType BLOB = const PropertyType<Uint8List>("blob", _blobToSchemaValue, _blobFromSchemaValue);
  /**
   * A [DATE_TIME] value will admit any valid dart [DateTime] value.
   */
  static const PropertyType DATE_TIME = const PropertyType<DateTime>("datetime", _dateTimeToSchemaValue, _dateTimeFromSchemaValue);
  /**
   * A property which stores a fully specified [Key] of a datastore entity.
   */
  static const PropertyType KEY = const PropertyType<Key>("key", _keyToSchemaValue, _keyFromSchemaValue);

  /**
   * A [LIST] property is a multi valued property. The list generic can be any of
   * [DYNAMIC], [BOOLEAN], [INTEGER], [DOUBLE], [STRING], [BLOB], [DATE_TIME] or [KEY].
   */
  static PropertyType LIST([PropertyType genericType = DYNAMIC]) => new PropertyType.list(genericType);

  //The string representation of the type
  final String _repr;
  //Converts values from the underlying dart type to the
  //corresponding datastore schema value
  final _ToSchemaValue<T> _toSchemaValue;
  //Converts values from a datastore schema value to the corresponding
  //dart value.
  final _FromSchemaValue<T> _fromSchemaValue;

  const PropertyType(this._repr, this._toSchemaValue, this._fromSchemaValue);

  factory PropertyType.list(PropertyType<T> generic) {
    return new _ListPropertyType<T>(generic);
  }

  /**
   * Check that the given value is valid for the property type and return the value.
   *
   * The following coersions are implicitly performed by the method.
   * If this is a [PropertyType.BLOB] property, [List<int>]s are automatically converted
   * to Uint8List via the [:Uint8List.fromList:]  constructor.
   */
  T checkType(var value) {
    if (this == BLOB && value is List<int>) {
      value = new Uint8List.fromList(value);
    }
    try {
      assert(value == null || value is T);
    } on AssertionError {
      throw new PropertyTypeError(this, value);
    }
    return value;
  }

  _PropertyInstance create({T initialValue}) => new _PropertyInstance(this, initialValue: initialValue);

  static _boolToSchemaValue(schema.Value value, bool b) {
    if (b != null)
      value.booleanValue = b;
    return value;
  }
  static _boolFromSchemaValue(schema.Value s) => s.booleanValue;

  static _intToSchemaValue(schema.Value value, int i) {
    if (i != null)
      value.integerValue = new Int64(i);
    return value;
  }
  static _intFromSchemaValue(schema.Value s) => s.integerValue.toInt();

  static _doubleToSchemaValue(schema.Value value, double d) {
    if (d != null)
      value.doubleValue = d;
    return value;
  }
  static _doubleFromSchemaValue(schema.Value s) => s.doubleValue;

  static _stringToSchemaValue(schema.Value value, String s) {
    if (s != null)
      value.stringValue = s;
    return value;
  }
  static _stringFromSchemaValue(schema.Value s) => s.stringValue;

  static _blobToSchemaValue(schema.Value value, Uint8List blob) {
    if (blob != null)
      value.blobValue..clear()..addAll(blob);
    return value;
  }
  static _blobFromSchemaValue(schema.Value s) => new Uint8List.fromList(s.blobValue);

  static _keyToSchemaValue(schema.Value value, Key k) {
    if (k != null)
      value.keyValue = k._toSchemaKey();
    return value;
  }
  static _keyFromSchemaValue(schema.Value s) => new Key._fromSchemaKey(s.keyValue);

  static _dateTimeToSchemaValue(schema.Value value, DateTime d) {
    if (d != null)
        value.timestampMicrosecondsValue = new Int64(d.toUtc().millisecondsSinceEpoch * 1000);
    return value;
  }
  static _dateTimeFromSchemaValue(schema.Value s) {
    return new DateTime.fromMillisecondsSinceEpoch(
        s.timestampMicrosecondsValue.toInt() ~/ 1000,
        isUtc: true);
  }

  static _dynamicToSchemaValue(schema.Value schemaValue, dynamic value) {
    if (value is bool)
      return _boolToSchemaValue(schemaValue, value);
    if (value is int)
      return _intToSchemaValue(schemaValue, value);
    if (value is num)
      return _doubleToSchemaValue(schemaValue, value);
    if (value is String)
      return _stringToSchemaValue(schemaValue, value);
    if (value is Uint8List)
      return _blobToSchemaValue(schemaValue, value);
    if (value is DateTime)
      return _dateTimeToSchemaValue(schemaValue, value);
    if (value == null) {
      //null schema values have none of the typed values set.
      return schemaValue;
    }
    throw new PropertyException("Invalid value for dynamic property: $value");
  }

  static _dynamicFromSchemaValue(schema.Value value) {
    if (value.hasBooleanValue())
      return _boolFromSchemaValue(value);
    if (value.hasIntegerValue())
      return _intFromSchemaValue(value);
    if (value.hasDoubleValue())
      return _doubleFromSchemaValue(value);
    if (value.hasStringValue())
      return _stringFromSchemaValue(value);
    if (value.hasBlobValue())
      return _blobFromSchemaValue(value);
    if (value.hasKeyValue())
      return _keyFromSchemaValue(value);
    //A property which has none of the typed values set is intended
    //to be interpreted as `null`.
    return null;
  }

  String toString() => _repr;



}

class _ListPropertyType<T> implements PropertyType<List<T>> {

  final PropertyType generic;
  //Unused.
  String _repr;

  _ToSchemaValue get _toSchemaValue {
    return (schema.Value value, _ListValue<T> listValue) {
      value.listValue.addAll(
          listValue.map((elem) => generic._toSchemaValue(new schema.Value(), elem))
      );
      return value;
    };
  }

  _FromSchemaValue get _fromSchemaValue {
    return (schema.Value schemaValue) {
      _ListValue<T> list = new _ListValue<T>(generic)
        ..addAll(schemaValue.listValue.map(generic._fromSchemaValue));
      return list;
    };
  }

  _ListPropertyType(PropertyType this.generic) {
    if (generic is _ListPropertyType) {
      throw new PropertyException("Invalid property type (nested list)");
    }
  }

  _PropertyInstance create({List<T> initialValue}) =>
      new _ListPropertyInstance(this, initialValue: initialValue);

  T checkType(var value) {
    if (value is List<T>) {
      return value;
    }
    throw new PropertyTypeError(this, value);
  }

  toString() => "list<${generic._repr}>";

  //TODO: Remove this if statics are ever const-able
  bool operator ==(Object other) =>
      other is _ListPropertyType && other.generic == generic;

  int get hashCode => 37 * generic.hashCode;
}

class PropertyException implements Exception {
  final String message;
  PropertyException(this.message);

  String toString() => "Invalid Property: $message";

}