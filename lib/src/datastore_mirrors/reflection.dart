part of datastore;

/**
 * Analyse the current mirror system and return all [Kind] objects associated
 * with 
 */
List<Kind> _entityKinds() {
  return  currentMirrorSystem()
      .libraries.values
      .where((LibraryMirror lib) => lib.uri.scheme != 'dart')
      .expand((lib) => lib.declarations.values.where((cls) => cls is ClassMirror))
      .where((ClassMirror cls) =>
          cls.metadata.any((mdata) => mdata.reflectee is kind)
      )
      .map((cls) => _kindFromClassMirror(cls))
      .toList(growable: false);
}
    
Kind _kindFromClassMirror(ClassMirror cls) {
  var k = cls.metadata
      .singleWhere((mdata) => mdata.reflectee is kind)
      .reflectee;
  String kindName = _kindName(k, cls);
  print("Found kind ($kindName)");
  EntityFactory entityFactory = _entityFactory(kindName, cls);
  List<Property> entityProperties = _entityProperties(kindName, cls);
  return new Kind(kindName, entityProperties, entityFactory);
}

/**
 * Get the name of the kind represented by a class.
 * The name defaults to the name of the class, but can be overriden
 * by declaring a static property or variable with the name of the kind.
 * 
 * eg. 
 * 
 * @kind
 * class Kind {
 *   static const kindName = "MyKind";
 * }
 */
String _kindName(kind kind, ClassMirror cls) =>
    (kind.name != null) ? kind.name : MirrorSystem.getName(cls.simpleName);  

/**
 * Returns a method which constructs the class
 */
EntityFactory _entityFactory(String kind, ClassMirror cls) {
  MethodMirror constructor = cls.declarations[cls.simpleName];
  if (constructor == null) {
    throw new KindError.noValidConstructor(kind);
  }
  assert(constructor.isConstructor);
  if (!constructor.isGenerativeConstructor) {
    throw new KindError.noValidConstructor(kind);
  }
  var mandatoryParams = constructor.parameters.where((param) => !param.isOptional);
  if (mandatoryParams.length != 2) {
    throw new KindError.noValidConstructor(kind);
  }
  
  return (Datastore datastore, Key key) {
    return cls.newInstance(
        constructor.constructorName, 
        [datastore, key]
    ).reflectee;
  };
}


List<Property> _entityProperties(String kind, ClassMirror cls) {
  var annotatedDeclarations = 
      cls.declarations.values
          .where((decl) => decl.metadata.any((mdata) => mdata.reflectee is property));
  List<Property> properties = new List<Property>();
  for (var decl in annotatedDeclarations) {
    if (decl is MethodMirror) {
      properties.add(_propertyFromMethod(kind, decl));
      continue;
    }
    var prop = decl.metadata.singleWhere((mdata) => mdata.reflectee is property).reflectee;
    throw new KindError.invalidProperty(kind,_propertyName(prop, decl));
  }
  return properties;
}

Property _propertyFromMethod(String kind, MethodMirror method) {
  var prop = method.metadata.singleWhere((mdata) => mdata.reflectee is property).reflectee;
    String propertyName = _propertyName(prop, method);
  if (!method.isGetter || method.isStatic) {
    throw new KindError.invalidProperty(kind, propertyName);
  }
  var propertyType = _propertyType(kind, propertyName, method.returnType);
  return new Property(propertyName, propertyType, indexed: prop.indexed);
}

String _propertyName(property property, DeclarationMirror method) =>
    property.name != null ? property.name : MirrorSystem.getName(method.simpleName);

PropertyType _propertyType(String kind, String propertyName, TypeMirror type, [bool isList=false]) {
  if (type is ClassMirror) {
    switch(type.reflectedType) {
      case bool:
        return PropertyType.BOOLEAN;
      case int:
        return PropertyType.INTEGER;
      case double:
      case num:
        return PropertyType.DOUBLE;
      case String:
        return PropertyType.STRING;
      case Uint8List:
        return PropertyType.BLOB;
      case Key:
        return PropertyType.KEY;
      case DateTime:
        return PropertyType.DATE_TIME;
      case List:
        PropertyType genericType = _propertyType(kind, propertyName, type.typeArguments.first, true);
        return PropertyType.LIST(genericType);
      default:
        throw new KindError.unrecognizedPropertyType(kind, propertyName, type);
    }
  }
  logger.warning("dynamic (${isList ? "List generic" : ""}property type: $kind.$propertyName");
  return PropertyType.DYNAMIC;
}

class KindError extends Error {
  final kind;
  final message;
  
  KindError(this.kind, this.message) : super();
  
  KindError.noValidConstructor(String kind) :
    this(kind, 
        "Valid kind must declare an unnamed, generative constructor with "
        "two mandatory arguments "
        "which redirects to Entity(Datastore datastore, Key key)");
  
  KindError.invalidProperty(String kind, String propertyName) :
    this(kind,
        "Property ($propertyName) must be an (non-static) getter on the kind");
  
  KindError.unrecognizedPropertyType(String kind, String propertyName, ClassMirror type) :
    this(kind, 
        """
Property ($propertyName) has an unrecognised property type.
Supported schema property must be one of:
  -bool
  -int
  -num
  -double
  -String
  -Uint8List
  -Key
  -DateTime
  -dynamic
or a List of one of the above types
""");
  
  String toString() => "Malformed Kind ($kind): $message";
}
