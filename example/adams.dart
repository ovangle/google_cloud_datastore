/**
 * An implementation of the standard datastore example, [1][adams], demonstrating
 * how to create and insert entities into the datastore as well as how 
 * to create and use kinds when using the reflection based implementation
 * of datastore entities.
 * 
 * The example file is designed to be used with the `gcd` test server. For an example
 * which demonstrates how to connect from inside a compute engine instance, see the 
 * `adams.dart` file.
 * 
 * [1][https://developers.google.com/datastore/docs/getstarted/start_python/]
 */
library adams;

import 'dart:async';
import 'dart:convert' show UTF8;
import 'dart:io';

import 'package:googleclouddatastore/datastore.dart';

//TODO: Remove DATASET_ID;
String DATASET_ID = "protobuf-api-test";

@kind()
class Trivia extends Entity {
  
  //Kinds must declare a two argument constructor which
  //redirects to Entity(Datastore, Key)
  //This constructor may also initialise entity properties
  //by providing them as as optional or named properties
  //and passing them to the super constructor as a map.
  Trivia(datastore, key, { question, answer }) : 
    super(datastore, key, { "question" : question, "answer" : answer});
  
  // A string type property 
  @property()
  String get question => getProperty("question");
  void set question(String value) => setProperty("question", value);
  
  //An integer type property
  @property()
  int get answer => getProperty("answer");
  void set answer(int value) => setProperty("answer", value);
}

void main(List<String> args) {
  /*
  if (args.length < 1) {
    print("Usage: adams.dart <DATASET_ID>");
  }
  
  String datasetId = args[0];
  */
  String datasetId = DATASET_ID;
  
  //TODO: Needs to be changed to a compute engine connection
  DatastoreConnection connection =
      new DatastoreConnection(
          null,
          datasetId,
          makeAuthRequests: false,
          host: "http://127.0.0.1:6060");
  
  Datastore datastore = new Datastore(connection);
  
  datastore.logger.onRecord.listen(print);
  
  Completer<Trivia> triviaCompleter = new Completer<Trivia>();
  
  //Run an insert action in a transaction context.
  //The transaction will automatically be committed
  //once the transaction returns
  datastore.withTransaction(
      (Transaction transaction) {
        var key = new Key("Trivia", name: "hgtg");
        
        return datastore.lookup(key)
            .then((entityResult) {
              if (entityResult.hasResult) {
                triviaCompleter.complete(entityResult.entity);
                return;
              }
              Trivia trivia = new Trivia(datastore, key,
                  question: "Meaning of life?",
                  answer: 42);
              
              // Add the enitity to the list of entities
              // to insert when the transaction is committed.
              transaction.insert.add(trivia);
              triviaCompleter.complete(trivia);
            });
      })
      .catchError(triviaCompleter.completeError);
  
  triviaCompleter.future.then((Trivia trivia) {
    print(trivia.getProperty("question"));
    stdout.write("> ");
    stdin.listen((bytes) {
      var input = UTF8.decode(bytes);
      var answer = input.trim().toLowerCase();
      if (answer == trivia.answer.toString()) {
        print("Don't panic!");
      } else {
        print( 'fascinating, extraordinary and, '
               'when you think hard about it, completely obvious.');
      }
      stdout.write("> ");
    });
  });
  
}