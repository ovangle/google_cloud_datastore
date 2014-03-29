/**
 * An implementation of the standard datastore example, [1][adams], demonstrating
 * how to create and insert entities into the datastore as well as how 
 * to create and use kinds when using the mirror-free implementation
 * of datastore entities.
 * 
 * The example file is designed to be used with the `gcd` test server. For an example
 * which demonstrates how to connect from inside a compute engine instance, see the 
 * `adams.dart` file.
 * 
 * [1][https://developers.google.com/datastore/docs/getstarted/start_python/]
 */
library adams.mirrorfree;

import 'dart:io';
import 'dart:async';
import 'dart:convert' show UTF8;
import 'package:googleclouddatastore/datastore_mirrorfree.dart';


//TODO: Remove DATASET_ID
String DATASET_ID = "protobuf-api-test";

/**
 * A kind with two properties which 
 */
final Kind triviaKind =
    new Kind("Trivia", 
        [ new Property("question", PropertyType.STRING, indexed: true),
          new Property("answer", PropertyType.INTEGER, indexed: true)
        ]);

void main(List<String> args) {
  if (args.length < 1) {
    print("Usage: adams.dart <DATASET_ID>");
    exit(1);
  }
  
  String datasetId = args[1];
  
  //Connect to a instance of the gcd test server running on localhost
  //on port `6060`.
  DatastoreConnection connection = 
      new DatastoreConnection(
          null, //No client id required for gcd server
          datasetId, 
          makeAuthRequests: false, //gcd server does not accept authenitcation
          host: "http://127.0.0.1:6060");
  //And a new datastore object with reference to the known 
  //datastore kinds
  Datastore datastore = new Datastore(connection, [triviaKind]);
  
  //TODO: Remove logging.
  datastore.logger.onRecord.listen(print);
  
  //A completer to add the completed trivia to.
  Completer triviaCompleter = new Completer();
  
  //Run an insert action in a transaction context.
  //The transaction will automatically be committed
  //once the action returns.
  datastore.withTransaction(
      (Transaction transaction) {
        //Create a new top level key for the `Trivia` kind
        var key = new Key.topLevel("Trivia", name: "hgtg");
        
        // Look up the entity as it was at the start of the transaction
        return datastore.lookup(key, transaction)
            .then((EntityResult entityResult) {
              if (entityResult.hasResult) {
                triviaCompleter.complete(entityResult.entity);
              } else {
                //Create a new Trivia entity and set the values for the
                //two entity properties.
                Entity ent = new Entity(datastore, key)
                    ..setProperty("question", "Meaning of life?")
                    ..setProperty("answer", 42);
                
                //Add the entity to the list of entities to
                //insert when the transaction is committed.
                transaction.insert.add(ent);
                
                triviaCompleter.complete(ent);
              }
            })
            .catchError(triviaCompleter.completeError);
      }
  );
  triviaCompleter.future.then((trivia) {
    print(trivia.getProperty("question"));
    stdout.write("> ");
    stdin.listen((bytes) {
      var input = UTF8.decode(bytes);
      var answer = input.trim().toLowerCase();
      if (answer == trivia.getProperty("answer").toString()) {
        print("Don't panic!");
      } else {
        print( 'fascinating, extraordinary and, '
               'when you think hard about it, completely obvious.');
      }
      stdout.write("> ");
    });
  })
  .catchError((err) {
    //RPCException is raised if any error happened during an RPC.
    // It includes the `method` called ans the `reason` for failure
    // as well as the original http.Response object.
    print("Error while doing datastore operation");
    print("method: ${err.method} reason: ${err.reason}");
  }, test: (err) => err is RPCException);
}