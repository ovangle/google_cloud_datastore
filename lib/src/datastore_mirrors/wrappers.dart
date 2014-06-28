/**
 * Wrappers for mirrorfree classes to provide utilities that are only
 * available with the reflective API
 */

part of datastore;

class Key extends base.Key {
  Key(dynamic /* String | Type | KindDefinition */ kind, {Key parentKey, int id, String name}):
    super(
        kind is Type ? Datastore.kindByType(kind) : kind,
        parentKey: parentKey,
        id: id,
        name: name
    );
}

class Entity extends base.Entity {
  static Map<Type, String> _clsToKindDefn = new Map();

  Entity(Key key, [Map<String,dynamic> propertyInits=const {}]):
      super(key, propertyInits, null, false) {

    var kind = Datastore.kindByType(runtimeType);
    kind.initializeEntity(this);
  }
}

class Filter implements base.Filter {
  /**
   * Returns a filter which compares [:property:] against the given [:value:]
   * in the datastore.
   */
  factory Filter(/* String | PropertyDefinition */ property, Operator operator, dynamic value) =>
      new base.Filter(property, operator, value);

  /**
   * Filters that matches datastore entities who have an ancestor which
   * matches the specified key.
   */
  factory Filter.ancestorIs(Key key) =>
      new base.Filter.ancestorIs(key);

  /**
   * Filters the subkinds of entities
   */
  factory Filter.subkind(dynamic /* Type | String | KindDefinition */ subkind) =>
      new base.Filter.subkind(subkind is Type ? Datastore.kindByType(subkind) : subkind);

  /**
   * Forms a logical conjuction of a collection of filters.
   */
  factory Filter.and(Iterable<Filter> filters) =>
      new base.Filter.and(filters);
}

class Query implements base.Query {
  factory Query(/* String | Type | KindDefinition */ kind, Filter filter, {bool keysOnly: false}) =>
      new base.Query(
          kind is Type ? Datastore.kindByType(kind) : kind,
          filter,
          keysOnly: keysOnly
      );

  @override
  Filter get filter => throw new UnimplementedError('query.filter');

  @override
  void groupBy(property) => throw new UnimplementedError('query.groupBy');

  @override
  bool get keysOnly => throw new UnimplementedError('query.keysOnly');

  @override
  KindDefinition get kind => throw new UnimplementedError('query.kind');

  @override
  void sortBy(property, {bool ascending: true}) =>
      throw new UnimplementedError('query.sortBy');

  @override
  void sortByKey({bool ascending: true}) =>
      throw new UnimplementedError('query.sortByKey');
}