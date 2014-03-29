part of datastore.common;

class _PropertyInstance<T> {
  final PropertyType<T> propertyType;
  T _value;
  
  T get value => propertyType.checkType(_value);
    set value(T value) => _value = propertyType.checkType(value);
    
  _PropertyInstance(PropertyType<T> propertyType, {T initialValue}) :
    this.propertyType = propertyType,
    this._value = propertyType.checkType(initialValue);
  
  _PropertyInstance.fromSchemaProperty(PropertyType this.propertyType, schema.Property schemaProperty) {
    this.value = propertyType._fromSchemaValue(schemaProperty.value);
  }
  
  schema.Property _toSchemaProperty(Property definition) {
    schema.Value schemaValue = propertyType._toSchemaValue(new schema.Value(), _value)
      ..indexed = definition.indexed;
    return new schema.Property()
        ..name = definition.name
        ..value = schemaValue;
  }
}

class _ListPropertyInstance<T> implements _PropertyInstance<List<T>> {
  final PropertyType<List<T>> propertyType;
  _ListValue<T> _value;
  
  List<T> get value => _value;
  void set value(List<T> value) {
    _value.clear();
    _value.addAll(value);
  }
  
  _ListPropertyInstance(_ListPropertyType<List<T>> propertyType, {List<T> initialValue}) :
    this.propertyType = propertyType,
    this._value = new _ListValue(propertyType.generic, initialValue);
  
  _ListPropertyInstance.fromSchemaProperty(PropertyType this.propertyType, schema.Property schemaProperty) {
    this._value = propertyType._fromSchemaValue(schemaValue);
  }
  
  @override
  schema.Property _toSchemaProperty(Property definition) {
    var schemaValue = propertyType._toSchemaValue(_value)
        ..indexed = definition.indexed;
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
      elements.add(generic.create(initialValue: element));
  
  void addAll(Iterable<T> iterable) {
    elements.addAll(iterable.map((e) => generic.create(initialValue: e)));
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
      elements[oldLength++] = generic.create();
    }
  }
}