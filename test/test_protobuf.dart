library datastore_protobuf.test;

import 'dart:io';

import 'package:fixnum/fixnum.dart';

import '../lib/datastore_protobuf.dart';
import 'package:unittest/unittest.dart';


void defineTests(DatastoreConnection connection) {
  group("protobuf API", () {
    group("with mocked connection:", () {
      test("allocate Ids", () {
        var allocateIds = new List<Key>()
            ..addAll([ new Key()..pathElement.add(new Key_PathElement()..kind = "user"),
                       new Key()..pathElement.add(new Key_PathElement()..kind = "user"..id =new Int64(5))
                     ]);
        return connection
            .allocateIds(new AllocateIdsRequest()..key.addAll(allocateIds))
            .then((response) => expect(response.key, allocateIds));
      });

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

      test("lookup should defer more than 10 requested entities", () {
        var keys = [];
        for (var i =0;i<25;i++) {
          keys.add(new Key()..pathElement.add(new Key_PathElement()..kind="User"..id=new Int64(i)));
        }
        var request = new LookupRequest()..key.addAll(keys);
        return connection.lookup(request).then((response) {

        });
      });
    });
  });
}