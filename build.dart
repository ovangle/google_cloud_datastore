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
  }
  if (args.every((arg) => !arg.startsWith('--changed=proto/'))) {
    //No need to compile protobuffers, nothing has changed
    return;
  }
  generateMessages()
      .then((exitCode) => exit(exitCode));
}

/**
 * Cleans the '/lib/src/generated' folder
 */
Future clean() {
  return new Directory('lib/src/proto')
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
  return Process.run(
      '/usr/local/bin/protoc',
      [ '--plugin=protoc-gen-dart=bin/protoc-dart-plugin',
        '--dart_out=lib/src'
      ]..addAll(protobufferTemplates.map((tmpl) => "proto/$tmpl")))
      .then((result) {
        if (result.stderr != "") print("error: ${result.stderr}");
        if (result.stdout != "") print(result.stdout);
        return result.exitCode;
      });
}