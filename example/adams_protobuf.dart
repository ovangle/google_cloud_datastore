/**
 * An implementation of the standard datastore example, [adams.dart] which
 * demonstrates how to create and lookup datastore entities and how to use
 * the low level protobuffer API.
 *
 * The example file is designed to be used with an instance of the `gcd`
 * test server running on localhost at port `6060`.
 *
 * [1]: https://developers.google.com/datastore/docs/getstarted/start_python/
 */

library adams_protobuf;

import 'dart:io';
import 'dart:async';
import 'dart:convert' show UTF8;
import 'package:fixnum/fixnum.dart';
import 'package:google_cloud_datastore/datastore_protobuf.dart';

void main(List<String> args) {
  if (args.length < 1) {
    print("Usage: adams_protobuf.dart <DATASET_ID>");
    exit(1);
    return;
  }

  String datasetId = args[0];

  // Open a new connection to the datastore.
  DatastoreConnection.open(
      null,
      datasetId,
      host: 'http://127.0.0.1:6060').then((connection) {

    Completer onInsert = new Completer();

    BeginTransactionRequest beginTransaction = new BeginTransactionRequest();
    connection.beginTransaction(beginTransaction).then((response) {
      //Create a top level datastore key for the question
      var triviaKey = new Key()
          ..pathElement.add(new Key_PathElement()..kind="Trivia"..name="poie");

      //Set a transaction for the lookup, to fetch the entity as it existed
      //at the start of the transaction
      var lookupOptions = new ReadOptions()
          ..transaction.addAll(response.transaction);

      LookupRequest lookupRequest = new LookupRequest()
          ..key.add(triviaKey)
          ..readOptions = lookupOptions;

      //Submit a lookup request
      return connection.lookup(lookupRequest).then((lookupResponse) {
        if (lookupResponse.found.isNotEmpty) {
          onInsert.complete(lookupResponse.found.first.entity);
        } else {
          //Create a property representing the question
          var questionProp = new Property()
              ..name = "question"
              ..value = (new Value()..stringValue="Meaning of life?");

          //Create a property representing the answer
          var answerProp = new Property()
              ..name = "answer"
              ..value = (new Value()..integerValue=new Int64(42));

          //Build a trivia entity from the key
          var trivia = new Entity()
              ..key = triviaKey
              ..property.add(questionProp)
              ..property.add(answerProp);


          //Create a commit request which inserts the entity into the datastore
          var commit = new CommitRequest()
            ..mutation = (new Mutation()..insert.add(trivia))
            ..transaction.addAll(response.transaction);

          return connection.commit(commit).then((response) {
            onInsert.complete(trivia);
          });
        }
      });
    });

    onInsert.future.then((Entity entity) {
      var question = entity.property.singleWhere((prop) => prop.name == "question");
      print(question.value.stringValue);
      stdout.write("> ");
      stdin.listen((bytes) {
        var input = UTF8.decode(bytes);
        if (input.contains('dart')) return;
        var answer = input.trim().toLowerCase();
        var answerProp = entity.property.singleWhere((prop) => prop.name == "answer");
        if (answer == answerProp.value.integerValue.toString()) {
          print("Don't panic!");
        } else {
          print( 'fascinating, extraordinary and, '
                 'when you think hard about it, completely obvious');
        }
        stdout.write("> ");
      });
    });
  });

}