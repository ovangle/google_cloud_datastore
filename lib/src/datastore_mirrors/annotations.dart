part of datastore;

/**
 * An annotation which marks a class definition as a kind.
 * 
 * If [:name:] is provided, used as the name of the datastore kind. Otherwise the name of the
 * annnotated class is used instead.
 * 
 * It is an error if a `kind` annotated class does not define an unnamed, two-argument constructor which
 * redirects to `Entity(Datastore datastore, Key key)`.
 */
class kind {
  final String name;
  const kind({String this.name});
}

/**
 * An annotation which marks a getter method on a [:kind:] annotated class as an entity property
 * Must be applied to a getter method on the annotated class. 
 * 
 * Calling `getProperty(<property_name>)` and `setProperty(<property_name>, <value>)` will
 * get/set the appropriate property as required.
 * 
 * If [name] is provided, it is used as the datastore name for the property, otherwise the
 * name of the annotated method is used.
 * 
 * [:indexed:] determines whether the datastore property should be indexed (default is `false`)
 * 
 * The type of the schema property is inferred from the type of the dart property's return type.
 * Only a limited set of property types are supported by the library, these are:
 * - [dynamic]
 * - [bool]
 * - [int]
 * - [double]/[num] (both interpreted as a schema `double` property)
 * - [String]
 * - [Uint8List] (interpreted as a schema `blob` property)
 * or a [List] of values of any of these types.
 */
class property {
  final String name;
  final bool indexed;
  const property({String this.name, bool this.indexed: false});
}

/**
 * An annotation which marks a final variable on a [:kind:] annotated class as 
 * representing the name of the entity. The variable must be a [String].
 * 
 * NOTE: Currently ignored by the library.
 */
const keyName = const _KeyName();
//TODO: Implement this.
class _KeyName {
  const _KeyName();
}

