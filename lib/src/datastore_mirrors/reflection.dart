part of datastore;

/**
 * Analyse the current mirror system and return all [KindDefintionDefinition] objects associated
 * with
 */
Map<Type, KindDefinition> _entityKinds() {
  Iterable<ClassMirror> annotatedClasses = currentMirrorSystem()
      .libraries.values
      .where((LibraryMirror lib) => lib.uri.scheme != 'dart')
      .expand((lib) => lib.declarations.values.where((cls) => cls is ClassMirror))
      .where((ClassMirror cls) =>
          cls.metadata.any((mdata) => mdata.reflectee is Kind)
      );
  Map<Type,KindDefinition> foundKindDefintions = new Map<Type,KindDefinition>();
  for (var cls in annotatedClasses) {
    var kindAnno = _kindAnno(cls);
    var kindName = _kindName(kindAnno, cls);
    if (foundKindDefintions.containsKey(kindName))
      continue;
    foundKindDefintions[cls.reflectedType] = _kindFromClassMirror(kindName, cls, foundKindDefintions);
  }
  return foundKindDefintions;
}

Kind _kindAnno(ClassMirror cls) {
  var kindAnnos = cls.metadata.where((mdata) => mdata.reflectee is Kind);
  if (kindAnnos.isEmpty)
    throw new KindError.noKindDefintionAnnotations(cls);
  if (kindAnnos.length > 1)
    throw new KindError.multipleKindDefintionAnnotations(cls);
  return kindAnnos.single.reflectee;
}

KindDefinition _kindFromClassMirror(String kindName, ClassMirror cls, Map<Type, KindDefinition> foundKindDefintions) {
  var k = cls.metadata
      .singleWhere((mdata) => mdata.reflectee is Kind)
      .reflectee;
  KindDefinition extendsKindDefintion = _extendsKindDefintion(kindName, cls, foundKindDefintions);
  EntityFactory entityFactory = _entityFactory(kindName, cls);
  List<PropertyDefinition> entityProperties = _entityProperties(kindName, cls);
  return new KindDefinition(
      kindName,
      entityProperties,
      extendsKind: extendsKindDefintion,
      concrete: k.concrete,
      entityFactory: entityFactory);
}

final RegExp reservedKey = new RegExp("^__.*__");

/**
 * Get the name of the kind represented by a class.
 * The name defaults to the name of the class, but can be overriden
 * by declaring a static property or variable with the name of the kind.
 *
 * eg.
 *
 * @kind
 * class KindDefintion {
 *   static const kindName = "MyKindDefintion";
 * }
 */
String _kindName(Kind kind, ClassMirror cls) {
  var name =
    (kind.name != null) ? kind.name : MirrorSystem.getName(cls.simpleName);
  if (name == "")
    throw new KindError.emptyName(cls);
  if (name.length >= 500)
    throw new KindError.nameTooLong(name);
  if (reservedKey.hasMatch(name))
    throw new KindError.nameReservedOrReadOnly(name);
  return name;
}

/**
 * Returns a method which constructs an instance of the class from the
 * [Datastore] and [Key] of the class.
 */
EntityFactory _entityFactory(String kind, ClassMirror cls) {
  var constructor;
  var annotatedConstructors =
      cls.declarations.values
      .where((decl) => decl is MethodMirror && decl.isConstructor)
      .where((decl) => decl.metadata.any((mdata) => mdata.reflectee == constructKind));
  if (annotatedConstructors.isEmpty) {
    //Default to the unnamed constructor
    constructor = cls.declarations[cls.simpleName];
  } else if (annotatedConstructors.length > 1) {
    throw new KindError.tooManyConstructors(kind);
  } else {
    constructor = annotatedConstructors.first;
  }
  if (constructor == null) {
    throw new KindError.noValidConstructor(kind);
  }
  assert(constructor.isConstructor);
  if (!constructor.isGenerativeConstructor) {
    throw new KindError.noValidConstructor(kind);
  }
  var mandatoryParams = constructor.parameters.where((param) => !param.isOptional);
  if (mandatoryParams.length != 1) {
    throw new KindError.noValidConstructor(kind);
  }

  return (base.Key key) =>
      cls.newInstance(constructor.constructorName,[key]).reflectee;
}

bool _isKindDefintion(ClassMirror cls) {
  var superCls = cls.superclass;
  if (superCls.reflectedType == Object) {
    return false;
  }
  if (superCls.reflectedType == Entity ||
      superCls.reflectedType == base.Entity) {
    return true;
  }
  return _isKindDefintion(cls.superclass);
}

KindDefinition _extendsKindDefintion(String kindName, ClassMirror cls, Map<Type,KindDefinition> foundKindDefintions) {
  if (!_isKindDefintion(cls))
    throw new KindError.mustExtendEntity(kindName);
  var supercls = cls.superclass;

  if (supercls.reflectedType == Entity ||
      supercls.reflectedType == base.Entity)
    return null;

  var superKindDefintionAnno = _kindAnno(supercls);
  var superKindDefintionName = _kindName(superKindDefintionAnno, supercls);

  var existingKindDefintion = foundKindDefintions[supercls.reflectedType];
  if (existingKindDefintion == null) {
    existingKindDefintion = foundKindDefintions[supercls.reflectedType] = _kindFromClassMirror(superKindDefintionName, supercls, foundKindDefintions);
  }
  return existingKindDefintion;
}

List<PropertyDefinition> _entityProperties(String kind, ClassMirror cls) {
  var annotatedDeclarations =
      cls.declarations.values
          .where((decl) => decl.metadata.any((mdata) => mdata.reflectee is Property));
  List<PropertyDefinition> properties = new List<PropertyDefinition>();
  for (var decl in annotatedDeclarations) {
    if (decl is MethodMirror) {
      properties.add(_propertyFromMethod(kind, decl));
      continue;
    }
    var prop = decl.metadata.singleWhere((mdata) => mdata.reflectee is Property).reflectee;
    throw new KindError.invalidProperty(kind,_propertyName(prop, decl));
  }
  return properties;
}

PropertyDefinition _propertyFromMethod(String kind, MethodMirror method) {
  var prop = method.metadata.singleWhere((mdata) => mdata.reflectee is Property).reflectee;
    String propertyName = _propertyName(prop, method);
  if (!method.isGetter || method.isStatic) {
    throw new KindError.invalidProperty(kind, propertyName);
  }
  var propertyType = _propertyType(kind, propertyName, method.returnType);
  return new PropertyDefinition(propertyName, propertyType, indexed: prop.indexed);
}

String _propertyName(Property property, DeclarationMirror method) =>
    property.name != null ? property.name : MirrorSystem.getName(method.simpleName);

final _LIST_TYPE = reflectClass(List);

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
      case base.Key:
        return PropertyType.KEY;
      case DateTime:
        return PropertyType.DATE_TIME;
    }
    if (type.originalDeclaration == _LIST_TYPE) {
      PropertyType genericType = _propertyType(kind, propertyName, type.typeArguments.first, true);
      return PropertyType.LIST(genericType);
    } else {
      throw new KindError.unrecognizedPropertyType(kind, propertyName, type);
    }
  }
  return PropertyType.DYNAMIC;
}

class KindError extends base.KindError {

  KindError(String kind, String message) : super(kind, message);

  KindError.noKindDefintionAnnotations(ClassMirror cls) :
    this(MirrorSystem.getName(cls.simpleName),
        "No @Kind annotation found on class");

  KindError.multipleKindDefintionAnnotations(ClassMirror cls) :
    this(MirrorSystem.getName(cls.simpleName),
        "Multiple @Kind annotations on class");

  KindError.emptyName(ClassMirror cls):
    this(MirrorSystem.getName(cls.simpleName), "Name cannot be the empty string");

  KindError.nameTooLong(String kind) :
    this(kind, "Datastore names are limited to 500 characters");

  KindError.nameReservedOrReadOnly(String kind) :
    this(kind, "Names matching regex __.*__ are reserved/read only on the datastore");

  KindError.mustExtendEntity(String kind) :
    this(kind, "A valid kind must extend `Entity`");

  KindError.superClassNotKindDefintion(String kind, ClassMirror superCls) :
    this(kind,
        "The superclass of a kind must either be entity or a valid kind "
        "(got ${MirrorSystem.getName(superCls.simpleName)}");

  KindError.noValidConstructor(String kind) :
    this(kind,
        "Valid kind must either declare an unnamed generative constructor "
        "or a named generative constructor (annotated with @constructKind) "
        "which accept two mandatory arguments "
        "and which redirects to Entity(Datastore datastore, Key key)");

  KindError.tooManyConstructors(String kind) :
    this(kind,
        "Only one constructor can be annotated with the @constructKind"
        "annotation");


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

  String toString() => "Malformed kind ($kind): $message";
}
