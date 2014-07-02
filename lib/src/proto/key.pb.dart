///
//  Generated code. Do not modify.
///
library pb_key;

import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart';

class PartitionId extends GeneratedMessage {
  static final BuilderInfo _i = new BuilderInfo('PartitionId')
    ..a(3, 'datasetId', GeneratedMessage.OS)
    ..a(4, 'namespace', GeneratedMessage.OS)
    ..hasRequiredFields = false
  ;

  PartitionId() : super();
  PartitionId.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromBuffer(i, r);
  PartitionId.fromJson(String i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromJson(i, r);
  PartitionId clone() => new PartitionId()..mergeFromMessage(this);
  BuilderInfo get info_ => _i;

  String get datasetId => getField(3);
  void set datasetId(String v) { setField(3, v); }
  bool hasDatasetId() => hasField(3);
  void clearDatasetId() => clearField(3);

  String get namespace => getField(4);
  void set namespace(String v) { setField(4, v); }
  bool hasNamespace() => hasField(4);
  void clearNamespace() => clearField(4);
}

class Key_PathElement extends GeneratedMessage {
  static final BuilderInfo _i = new BuilderInfo('Key_PathElement')
    ..a(1, 'kind', GeneratedMessage.QS)
    ..a(2, 'id', GeneratedMessage.O6, () => makeLongInt(0))
    ..a(3, 'name', GeneratedMessage.OS)
  ;

  Key_PathElement() : super();
  Key_PathElement.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromBuffer(i, r);
  Key_PathElement.fromJson(String i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromJson(i, r);
  Key_PathElement clone() => new Key_PathElement()..mergeFromMessage(this);
  BuilderInfo get info_ => _i;

  String get kind => getField(1);
  void set kind(String v) { setField(1, v); }
  bool hasKind() => hasField(1);
  void clearKind() => clearField(1);

  Int64 get id => getField(2);
  void set id(Int64 v) { setField(2, v); }
  bool hasId() => hasField(2);
  void clearId() => clearField(2);

  String get name => getField(3);
  void set name(String v) { setField(3, v); }
  bool hasName() => hasField(3);
  void clearName() => clearField(3);
}

class Key extends GeneratedMessage {
  static final BuilderInfo _i = new BuilderInfo('Key')
    ..a(1, 'partitionId', GeneratedMessage.OM, () => new PartitionId(), () => new PartitionId())
    ..m(2, 'pathElement', () => new Key_PathElement(), () => new PbList<Key_PathElement>())
  ;

  Key() : super();
  Key.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromBuffer(i, r);
  Key.fromJson(String i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromJson(i, r);
  Key clone() => new Key()..mergeFromMessage(this);
  BuilderInfo get info_ => _i;

  PartitionId get partitionId => getField(1);
  void set partitionId(PartitionId v) { setField(1, v); }
  bool hasPartitionId() => hasField(1);
  void clearPartitionId() => clearField(1);

  List<Key_PathElement> get pathElement => getField(2);
}

