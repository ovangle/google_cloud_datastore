library datastore_protobuf.test;

import 'dart:async';
import 'dart:io';

import 'package:fixnum/fixnum.dart';

import '../lib/datastore_protobuf.dart';
import 'package:unittest/unittest.dart';


void defineTests(DatastoreConnection connection) {
  group("protobuf API", () {
    group("allocate", () {
      test("should be able to allocate new Ids", () {
        var allocateIds =
            [ new Key()..pathElement.add(new Key_PathElement()..kind = "user"),
              new Key()..pathElement.add(new Key_PathElement()..kind = "user")
            ];
        return connection
            .allocateIds(new AllocateIdsRequest()..key.addAll(allocateIds))
            .then((response) {
                expect(response.key.expand((k) => k.pathElement).map((pe) => pe.hasId()), everyElement(isTrue));
            });
      });
    });

    group("lookup", () {
      test("lookup should be return the key with id '1'", () {
        var key = new Key()..pathElement.add(new Key_PathElement()..kind="User"..id=new Int64(1));
        var lookupRequest = new LookupRequest()
            ..key.add(key);
        return connection.lookup(lookupRequest).then((response) {
          expect(response.found.map((result) => result.entity.key), [key], reason: "found keys");
          var found = response.found.first;

          expect(response.missing, [], reason: "missing keys");
        });
      });

      test("lookup should not be able to find the key with id '101'", () {
        var key = new Key()..pathElement.add(new Key_PathElement()..kind="User"..id=new Int64(101));
        var lookupRequest = new LookupRequest()
            ..key.add(key);
        return connection.lookup(lookupRequest).then((response) {
          expect(response.found, [], reason: "found keys");
          expect(response.missing.map((entResult) => entResult.entity.key), [key], reason: "missing keys");
        });
      });

      test("lookup should defer results for more than 10 entities", () {
        var keys = [];
        for (var i =0;i<25;i++) {
          keys.add(new Key()..pathElement.add(new Key_PathElement()..kind="User"..id=new Int64(i)));
        }
        var request = new LookupRequest()..key.addAll(keys);
        return connection.lookup(request).then((response) {
          expect(response.found.length, 10);
          expect(response.missing, []);
          expect(response.deferred.length, 15);
        });
      });
    });

    group("transaction", () {
      test("should be able to begin a transaction", () {
        connection.beginTransaction(new BeginTransactionRequest())
            .then((response) {
          expect(response.hasTransaction(), isTrue);
        });
      });
    });
    group("mutations", () {

      var key = new Key()..pathElement.add(new Key_PathElement()..kind="User"..name="hello");
      var prop = new Property()
          ..name = "prop1"
          ..value = (new Value()..integerValue= new Int64(40));

      test("should be able to insert an entity", () {
        var user = new Entity()
            ..key = key
            ..property.add(prop);
        var mutation = new Mutation()
            ..insert.add(user);
        return _insert(connection, user).then((response) {
          var lookupRequest = new LookupRequest()
              ..key.add(key);
          return connection.lookup(lookupRequest).then((response) {
            expect(response.found.first.entity, user);
          });
        });
      });

      test("should be able to update an entity", () {
        var lookupRequest = new LookupRequest()..key.add(key);
        return connection.lookup(lookupRequest).then((response) {
          var ent = response.found.first.entity.clone();
          var prop = ent.property.firstWhere((p) => p.name == "prop1");
          expect(prop.value.integerValue, new Int64(40));
          prop.value.integerValue = new Int64(50);

          return _update(connection, ent).then((_) {
            return connection.lookup(lookupRequest).then((response) {
              var ent = response.found.first.entity;
              var prop = ent.property.firstWhere((p) => p.name == "prop1");
              expect(prop.value.integerValue, new Int64(50));
            });
          });
        });
      });

      test("should be able to delete an entity", () {
        return _delete(connection, key).then((_) {
          var lookupRequest = new LookupRequest()
              ..key.add(key);
          return connection.lookup(lookupRequest).then((response) {
            expect(response.found, []);
            expect(response.deferred, []);
            expect(response.missing, [new EntityResult()..entity = (new Entity()..key = key)]);
          });
        });
      });
    });

    group("query", () {
      test("friends list", () {
        var key = new Key()
          ..pathElement.add(new Key_PathElement()..kind="User"..id=new Int64(40));
        var filter = new PropertyFilter()
          ..property = (new PropertyReference()..name = "friends")
          ..operator = PropertyFilter_Operator.EQUAL
          ..value = (new Value()..keyValue = key);
        var query = new Query()
            ..filter = (new Filter()..propertyFilter = filter);
        return connection.runQuery(new RunQueryRequest()..query = query).then((response) {
          var batch = response.batch;
          var getFriendsProp = (ent) => ent.property.firstWhere((prop) => prop.name == "friends");
          expect(batch.entityResult.length, 2);
          expect(batch.moreResults, QueryResultBatch_MoreResultsType.NO_MORE_RESULTS);
          expect(batch.entityResult
              .map((result) => getFriendsProp(result.entity).value.listValue),
              everyElement(contains(new Value()..keyValue= key)));
        });
      });
      test("should be able to fetch the users with age <= 25", () {
        var filter = new PropertyFilter()
          ..property = (new PropertyReference()..name="age")
          ..operator = PropertyFilter_Operator.LESS_THAN_OR_EQUAL
          ..value = (new Value()..integerValue = new Int64(25));
        var query = new Query()
            ..filter = (new Filter()..propertyFilter = filter);
        return connection.runQuery(new RunQueryRequest()..query = query).then((response) {
          var batch = response.batch;
          expect(batch.moreResults, QueryResultBatch_MoreResultsType.NOT_FINISHED);
          expect(batch.entityResult.length, 15);
          getAgeProp(Entity ent) => ent.property.firstWhere((prop) => prop.name == "age").value.integerValue;
          expect(batch.entityResult.map((result) => result.entity).map(getAgeProp),
              everyElement(lessThanOrEqualTo(new Int64(25))));
          var endCursor = batch.endCursor;
          query..startCursor = endCursor;
          return connection.runQuery(new RunQueryRequest()..query = query).then((response) {
            var batch2 = response.batch;
            expect(batch2.moreResults, QueryResultBatch_MoreResultsType.NO_MORE_RESULTS);
            expect(batch2.entityResult, everyElement(isNot(isIn(batch.entityResult))));
            expect(batch2.entityResult.map((result) => result.entity).map(getAgeProp),
                   everyElement(lessThanOrEqualTo(new Int64(25))));
          });
        });
      });
    });
  });
}


Future _insert(DatastoreConnection connection, Entity entity) {
  var mutation = new Mutation()..insert.add(entity);
  return connection.beginTransaction(new BeginTransactionRequest()).then((response) {
    var commitRequest = new CommitRequest()
        ..transaction = response.transaction
        ..mutation = mutation;
    return connection.commit(commitRequest);
  });
}

Future _update(DatastoreConnection connection, Entity entity) {
  var mutation = new Mutation()..update.add(entity);
  return connection.beginTransaction(new BeginTransactionRequest()).then((response) {
    var commitRequest = new CommitRequest()
        ..transaction = response.transaction
        ..mutation = mutation;
    return connection.commit(commitRequest);
  });
}

Future _delete(DatastoreConnection connection, Key key) {
  var mutation = new Mutation()..delete.add(key);
  return connection.beginTransaction(new BeginTransactionRequest()).then((response) {
    var commitRequest = new CommitRequest()
        ..transaction = response.transaction
        ..mutation = mutation;
    return connection.commit(commitRequest);
  });
}