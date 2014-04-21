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
 * [1]: https://developers.google.com/datastore/docs/getstarted/start_python/
 */
library adams;

import 'dart:async';
import 'dart:convert' show UTF8;
import 'dart:io';

import 'package:google_cloud_datastore/datastore.dart';

@Kind()
class Trivia extends Entity {

  /**
   * A [Kind] must either declare a generative constructor
   * with a single mandatory argument which redirects to `Entity(Key key)`.
   * If the constructor is unnamed, it will be found automatically, otherwise
   * it must be annotated with `constrcutKind`.
   *
   * The entity constructor also accepts an optional [Map] of initial values
   * for properties. These properties can be provided to a kind's constructor
   * as optional values.
   */
  Trivia(key, { question, answer }) :
    super(key, { "question" : question, "answer" : answer});

  /**
   * A property of type [String]. Properties must be annotated with the `@Property`
   * annotation. The `@Property` annotation can be used to provide a custom
   * datastore name for the property and override the `type` inferred from the getter.
   * It can also determine whether the property should be indexed.
   */
  @Property(indexed: true)
  String get question => getProperty("question");
  void set question(String value) => setProperty("question", value);

  //An integer type property
  @Property()
  int get answer => getProperty("answer");
  void set answer(int value) => setProperty("answer", value);
}

void main(List<String> args) {
  if (args.length < 1) {
    print("Usage: adams.dart <DATASET_ID>");
  }

  String datasetId = args[0];


  //Open a connection to the datastore. Only one connection needs to be
  //open for the lifetime of the application.
  DatastoreConnection.open(
      null,
      datasetId,
      host: 'http://127.0.0.1:6060').then((connection) {

    Datastore datastore = new Datastore(connection);

    datastore.logger.onRecord.listen(print);

    Completer<Trivia> triviaCompleter = new Completer<Trivia>();

    //Run an insert action in a transaction context.
    //The transaction will automatically be committed
    //once the transaction returns
    datastore.withTransaction(
        (Transaction transaction) {
          var key = new Key("Trivia", name: "hgtg");

          //Check whether the key is present. Ideally datastore transactions should
          //be idempotent, so look up the entity as it existed at the start of the
          //transaction
          return datastore.lookup(key)
              .then((entityResult) {
                if (entityResult.isPresent) {
                  triviaCompleter.complete(entityResult.entity);
                  return;
                }
                Trivia trivia = new Trivia(
                    key,
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
      print(trivia.question);
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
  });

}