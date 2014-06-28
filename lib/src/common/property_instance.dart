part of datastore.common;

class _PropertyInstance<T> {
  final String propertyName;
  final PropertyType<T> propertyType;
  T _value;

  T get value => propertyType.checkType(propertyName, _value);
    set value(T value) => _value = propertyType.checkType(propertyName, value);

  _PropertyInstance(String propertyName, PropertyType<T> propertyType, {T initialValue}) :
    this.propertyName = propertyName,
    this.propertyType = propertyType,
    this._value = propertyType.checkType(propertyName, initialValue);

  _PropertyInstance.fromSchemaProperty(String this.propertyName, PropertyType this.propertyType, schema.Property schemaProperty) {
    this.value = propertyType._fromSchemaValue(propertyName, schemaProperty.value);
  }

  schema.Property _toSchemaProperty(PropertyDefinition definition) {
    schema.Value schemaValue = propertyType._toSchemaValue(new schema.Value(), _value)
      ..indexed = definition.indexed;
    return new schema.Property()
        ..name = definition.name
        ..value = schemaValue;
  }
}

class _ListPropertyInstance<T> implements _PropertyInstance<List<T>> {
  final String propertyName;
  final PropertyType<List<T>> propertyType;
  _ListValue<T> _value;

  List<T> get value => _value;
  void set value(List<T> value) {
    _value.clear();
    if (value != null)
      _value.addAll(value);
  }

  _ListPropertyInstance(String propertyName, _ListPropertyType<T> propertyType, {List<T> initialValue}) :
    this.propertyName = propertyName,
    this.propertyType = propertyType,
    this._value = new _ListValue(propertyType.generic, initialValue);

  _ListPropertyInstance.fromSchemaProperty(String this.propertyName, PropertyType this.propertyType, schema.Property schemaProperty) {
    this._value = propertyType._fromSchemaValue(schemaProperty.value);
  }

  @override
  schema.Property _toSchemaProperty(PropertyDefinition definition) {
    if (definition.indexed) {
      throw new PropertyException("A list property cannot be indexed");
    }
    var schemaValue = propertyType._toSchemaValue(new schema.Value(), _value);
    return new schema.Property()
      ..name = definition.name
      ..value = schemaValue;
  }
}

class _ListValue<T> extends ListMixin<T> {
  PropertyType<T> generic;
  final List<_PropertyInstance<T>> elements;

  _ListValue(PropertyType<T> this.generic, [List<T> initialValue]) :
    this.elements = new List<_PropertyInstance<T>>() {
    if (initialValue != null) {
      addAll(initialValue);
    }
  }

  //Implementation of List<T>

  void add(T element) =>
      elements.add(generic.create("list element", initialValue: element));

  void addAll(Iterable<T> iterable) {
    elements.addAll(iterable.map((e) => generic.create("list element", initialValue: e)));
  }

  T operator [](int i) => elements[i].value;
  void operator []=(int i, T value) {
    this.elements[i].value = value;
  }

  int get length => elements.length;
  void set length(int value) {
    var oldLength = length;
    elements.length = length;
    while (oldLength < length) {
      elements[oldLength++] = generic.create("list element");
    }
  }
}