library build;

import 'dart:io';
import 'dart:async';

import 'package:quiver/async.dart';

final List<String> protobufferTemplates =
  ['api.proto',
   'entity.proto',
   'key.proto',
   'service.proto' ];

final Directory protoDir = new Directory('proto');

void main(List<String> args) {
  if (args.contains('--clean')) {
    clean().then((_) => exit(0));
    return;
  } else {
    generateMessages()
      .then((exitCode) => exit(exitCode));
  }
}

/**
 * Cleans the '/lib/src/generated' folder
 */
Future clean() {
  return new Directory('lib/src/generated')
      .list().toList()
      .then((files) {
        return forEachAsync(
            files,
            (f) => f.remove());
      });
}

/**
 * Compile the protobuffer templates into  'lib/src/generated'
 */
Future<int> generateMessages() {
  Directory.current = protoDir;
  return Process.run(
      'protoc',
      [ '--plugin=protoc-gen-dart=../bin/protoc-dart-plugin',
        '--dart_out=../lib/src/generated'
      ]..addAll(protobufferTemplates))
      .then((result) {
        if (result.stderr != "") print("error: ${result.stderr}");
        if (result.stdout != "") print(result.stdout);
        return result.exitCode;
      });
}