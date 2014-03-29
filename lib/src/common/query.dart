part of datastore.common;

class Query {
  /**
   * A kind or list of kinds to query
   */
  final /* Kind | Iterable<Kind> */ kind;
  final Filter filter;
  final /* Property | Iterable<Property> */ groupBy;
  final /* Ordering | Property | Iterable<Ordering> | Iterable<Property> */ sortBy;
  
  /**
   * Limits the number of results fetched from the datastore.
   * If negative, all results will be fetched.
   */
  final int limit;
  
  Query(
      /* Kind | List<Kind> */ this.kind, 
      Filter this.filter, 
      { /* Property | List<Property> */ this.groupBy: const [],
        /* Ordering | Property | Iterable</*Ordering | Property */ dynamic> */ this.sortBy: const [],
        int this.limit: -1
      });
  
  Iterable<schema.KindExpression> get _kindExpr {
    if (kind is Kind) {
      return [kind._toSchemaKindExpression()];
    } else if (kind is Iterable<Kind>) {
      return kind.map((k) => k._toSchemaKindExpression());
    }
    throw new ArgumentError("Invalid query kind (must be a kind or an Iterable of kinds)");
  }
  
  Iterable<schema.PropertyReference> get _groupByExpr {
    if (groupBy is Property) {
      return [groupBy._toSchemaPropertyReference()];
    } else if (groupBy is Iterable<Property>) {
      return groupBy.map((prop) => prop._toSchemaPropertyReference());
    }
    throw new ArgumentError("Invalid group by expression (must be a property or Iterable of properties");
  }
  
  Iterable<schema.PropertyOrder> get _orderExpr {
    if (sortBy is Property) {
      return [new Ordering.ascending(sortBy)._toSchemaPropertyOrder()];
    } else if (sortBy is Ordering) {
      return [sortBy._toSchemaPropertyOrder()];
    } else if (sortBy is Iterable) {
      return sortBy.map((elem) {
        if (elem is Property) {
          return new Ordering.ascending(elem);
        } else if (elem is Ordering) {
          return elem;
        }
        throw new ArgumentError("Invalid element in sortBy expression: $elem");
      });
    }
    throw new ArgumentError("Invalid sort by expression: $sortBy");
  }
  
  schema.Query _toSchemaQuery() {
    schema.Query schemaQuery = new schema.Query()
        ..kind.addAll(_kindExpr)
        ..filter = filter._toSchemaFilter()
        ..groupBy.addAll(_groupByExpr)
        ..order.addAll(_orderExpr);
    if (limit >= 0) {
      schemaQuery.limit = limit;
    }
    return schemaQuery;
  }
}