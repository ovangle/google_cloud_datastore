import 'dart:io';
import 'dart:async';
import 'dart:convert' show UTF8;

import 'package:logging/logging.dart';

import 'src/connection.dart';

final Logger logger = new Logger("test_server");

/**
 * Start a new connection to the gcd test server in the given directory
 * connected
 * If the directory does not exist, a new gcd server will be created in the directory.
 */
Future<DatastoreConnection> runTestServer(File gcdScript, Directory directory, String datasetId, {int port: 8080}) {
  return _createServerIfNotExists(gcdScript, directory, datasetId)
      .then((_) {
        return Process.start("bash",
              [ gcdScript.absolute.path, 
                "start", 
                "--port=$port",
                "--allow_remote_shutdown",
                directory.absolute.path]
          ).then((Process process) {
            process.stdout.listen((data) {
              print(UTF8.decode(data));
            });
            process.stderr.listen((data) {
              print(UTF8.decode(data));
            });
            return new DatastoreConnection(directory.absolute.path, datasetId, makeAuthRequests: false, host: "http://localhost: $port");
          });
      });
  
}

Future<Null> _createServerIfNotExists(File gcdScript, Directory directory, datasetId) {
  return directory.exists()
      .then((exists) {
        if (!exists) {
          return directory.create(recursive: true).then((_) {
              return Process.run("bash", 
                  [ gcdScript.absolute.path, 
                    "create",
                    "--dataset_id=$datasetId",
                    directory.absolute.path]);
            })
            .then((processResult) {
              print(processResult.stdout);
              print(processResult.stderr);
            });
        }
      });
}