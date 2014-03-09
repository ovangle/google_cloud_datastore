import '../lib/datastore.dart';
import 'dart:convert' show UTF8;

void main() {
  var datastore = new Datastore('crucial-matter-487', host: 'http://localhost:8080');
  var request = new BeginTransactionRequest()
      ..isolationLevel = BeginTransactionRequest_IsolationLevel.SNAPSHOT;
  datastore.beginTransaction(request)
      .then((BeginTransactionResponse response) {
        print("Transaction ID: ${UTF8.decode(response.transaction)}");
      });


}