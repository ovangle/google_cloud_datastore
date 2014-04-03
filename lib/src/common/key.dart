part of datastore.common;

/**
 * A [Key] is a reference to an entity in the datastore.
 * 
 */
class Key {
  /**
   * The name of the kind of the [Key].
   */
  final String kind;
  /**
   * A reference to the parent of this key
   */
  final Key parentKey;
  /**
   * The [:id:] of the key, a unique datastore assigned identifier for the key
   */
  final int id;
  /**
   * The [:name:] of a key is an optional user assigned 
   */
  final String name;
  
  List<Key> get path => isTopLevel ? [this] : (parentKey.path..add(this));
  
  /**
   * Test whether this key is at the top level of the datastore.
   */
  bool get isTopLevel => parentKey == null;
  
  /**
   * Gets a reference to the child of this [Key] with the given [:kind:] and [:name:]
   */
  Key getChild(String kind, {String name}) {
    if (name == null) {
      throw new KeyError.incomplete();
    }
    return new Key(kind, parentKey: this, name: name);
  }
  
  
  /**
   * Create a new key with the provided [:parentKey:] and [:name:].
   * 
   * If [:parentKey:] is not provided, the created key is a top level key
   * in the datastore.
   * Raises a [KeyError] if [:name:] is not provided.
   */

  Key(String this.kind, {Key this.parentKey, int this.id, String this.name}) {
    if (id == null && name == null) {
      throw new KeyError.incomplete();
    }
  }
  
  /**
   * Create a new key which refers to the same datastore object as the argument.
   */
  Key.fromKey(Key key) :
    this._(
        key.kind, 
        (key.parentKey != null) ? new Key.fromKey(key.parentKey) : null, 
        id: key.id, 
        name: key.name
    );
    
  /**
   * Restore a [Key] from the datastore key.
   */
  factory Key._fromSchemaKey(schema.Key schemaKey) {
    return new Key._fromPath(schemaKey.pathElement);
  }
  
  /**
   * Resotre a [Key] from the path from the root of the datastore to the key.
   * If the [path] is empty, the [Key] exists at the top level of the datastore.
   */
  factory Key._fromPath(Iterable<schema.Key_PathElement> path) {
    if (path.isEmpty) {
      return null;
    }
    return new Key._fromPathElement(path.take(path.length - 1), path.last);
  }
  
  /**
   * Restore a [Key] from a path element and the path to the parent.
   */
  factory Key._fromPathElement(Iterable<schema.Key_PathElement> pathToParent, schema.Key_PathElement pathElement) {
    var kind = pathElement.kind;
    var parentKey = new Key._fromPath(pathToParent);
    var id   = (pathElement.hasId()) ? pathElement.id.toInt() : null;
    var name = (pathElement.hasName()) ? pathElement.name : null;
    return new Key(kind, parentKey: parentKey, id: id, name: name);
  }
  
  /**
   * Create a path element which represents the current [Key].
   */
  schema.Key_PathElement _toPathElement() {
    var pathElement = new schema.Key_PathElement()
        ..kind = this.kind;
    if (id != null) {
      pathElement.id = new Int64(id);
    }
    if (name != null) {
      pathElement.name = name;
    }
    return pathElement;
  }
  
  /**
   * Create a datastore key representing the current key.
   */
  schema.Key _toSchemaKey() {
    return new schema.Key()
      ..pathElement.addAll(path.map((k)=> k._toPathElement()));
  }
  
  bool operator ==(Object other) {
    if (other is Key) {
      if (kind != other.kind) return false;
      if (parentKey != other.parentKey) return false;
      if (name != null) return name == other.name;
      if (id != null) return id == other.id; 
    }
    return false;
  }
  
  int get hashCode {
    var hashCode = kind.hashCode;
    hashCode = hashCode * 37 + parentKey.hashCode;
    if (name != null)
      hashCode = hashCode * 37 + name.hashCode;
    if (id != null)
      hashCode = hashCode * 37 + id.hashCode;
    return hashCode;
  }
  
  String toString() {
    StringBuffer sbuf = new StringBuffer('Key($kind');
    if (parentKey != null)
      sbuf.write(", $parentKey");
    if (id != null)
      sbuf.write(", id: $id");
    if (name != null)
      sbuf.write(", name: $name");
    sbuf.write(")");
    return sbuf.toString();
  }
}

class KeyError extends Error {
  final String message;
  KeyError(String this.message) : super();
  
  KeyError.incomplete() :
    this("Incomplete key. Either a name or id must be provided");
  
  toString() => "Invalid key: $message";
}