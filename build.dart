library build;

import 'dart:io';
import 'package:protobuf_builder/proto_builder.dart';

final List<String> protobufferTemplates =
  ['api.proto',
   'entity.proto',
   'key.proto',
   'service.proto' ];

final Directory protoDir = new Directory('proto');

void main(List<String> args) {
  build('proto', 'lib/src/proto', 'schema_v1_pb2', args);
}