part of datastore.common;

/**
 * Represents a 
 */
class Ordering {
  final bool isAscending;
  final Property orderBy;
  
  Ordering.ascending(Property this.orderBy) :
    this.isAscending = true;
  
  Ordering.descending(Property this.orderBy) :
    this.isAscending = false;
  
  schema.PropertyOrder _toSchemaPropertyOrder() =>
    new schema.PropertyOrder()
        ..property = orderBy._toSchemaPropertyReference()
        ..direction = (
            isAscending 
                ? schema.PropertyOrder_Direction.ASCENDING 
                : schema.PropertyOrder_Direction.DESCENDING
        );
  
}