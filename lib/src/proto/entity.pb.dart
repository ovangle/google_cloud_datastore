///
//  Generated code. Do not modify.
///
library pb_entity;

import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart';
import 'key.pb.dart';

class Value extends GeneratedMessage {
  static final BuilderInfo _i = new BuilderInfo('Value')
    ..a(1, 'booleanValue', GeneratedMessage.OB)
    ..a(2, 'integerValue', GeneratedMessage.O6, () => makeLongInt(0))
    ..a(3, 'doubleValue', GeneratedMessage.OD)
    ..a(4, 'timestampMicrosecondsValue', GeneratedMessage.O6, () => makeLongInt(0))
    ..a(5, 'keyValue', GeneratedMessage.OM, () => new Key(), () => new Key())
    ..a(16, 'blobKeyValue', GeneratedMessage.OS)
    ..a(17, 'stringValue', GeneratedMessage.OS)
    ..a(18, 'blobValue', GeneratedMessage.OY)
    ..a(6, 'entityValue', GeneratedMessage.OM, () => new Entity(), () => new Entity())
    ..m(7, 'listValue', () => new Value(), () => new PbList<Value>())
    ..a(14, 'meaning', GeneratedMessage.O3)
    ..a(15, 'indexed', GeneratedMessage.OB, () => true)
  ;

  Value() : super();
  Value.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromBuffer(i, r);
  Value.fromJson(String i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromJson(i, r);
  Value clone() => new Value()..mergeFromMessage(this);
  BuilderInfo get info_ => _i;

  bool get booleanValue => getField(1);
  void set booleanValue(bool v) { setField(1, v); }
  bool hasBooleanValue() => hasField(1);
  void clearBooleanValue() => clearField(1);

  Int64 get integerValue => getField(2);
  void set integerValue(Int64 v) { setField(2, v); }
  bool hasIntegerValue() => hasField(2);
  void clearIntegerValue() => clearField(2);

  double get doubleValue => getField(3);
  void set doubleValue(double v) { setField(3, v); }
  bool hasDoubleValue() => hasField(3);
  void clearDoubleValue() => clearField(3);

  Int64 get timestampMicrosecondsValue => getField(4);
  void set timestampMicrosecondsValue(Int64 v) { setField(4, v); }
  bool hasTimestampMicrosecondsValue() => hasField(4);
  void clearTimestampMicrosecondsValue() => clearField(4);

  Key get keyValue => getField(5);
  void set keyValue(Key v) { setField(5, v); }
  bool hasKeyValue() => hasField(5);
  void clearKeyValue() => clearField(5);

  String get blobKeyValue => getField(16);
  void set blobKeyValue(String v) { setField(16, v); }
  bool hasBlobKeyValue() => hasField(16);
  void clearBlobKeyValue() => clearField(16);

  String get stringValue => getField(17);
  void set stringValue(String v) { setField(17, v); }
  bool hasStringValue() => hasField(17);
  void clearStringValue() => clearField(17);

  List<int> get blobValue => getField(18);
  void set blobValue(List<int> v) { setField(18, v); }
  bool hasBlobValue() => hasField(18);
  void clearBlobValue() => clearField(18);

  Entity get entityValue => getField(6);
  void set entityValue(Entity v) { setField(6, v); }
  bool hasEntityValue() => hasField(6);
  void clearEntityValue() => clearField(6);

  List<Value> get listValue => getField(7);

  int get meaning => getField(14);
  void set meaning(int v) { setField(14, v); }
  bool hasMeaning() => hasField(14);
  void clearMeaning() => clearField(14);

  bool get indexed => getField(15);
  void set indexed(bool v) { setField(15, v); }
  bool hasIndexed() => hasField(15);
  void clearIndexed() => clearField(15);
}

class Property extends GeneratedMessage {
  static final BuilderInfo _i = new BuilderInfo('Property')
    ..a(1, 'name', GeneratedMessage.QS)
    ..a(4, 'value', GeneratedMessage.QM, () => new Value(), () => new Value())
  ;

  Property() : super();
  Property.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromBuffer(i, r);
  Property.fromJson(String i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromJson(i, r);
  Property clone() => new Property()..mergeFromMessage(this);
  BuilderInfo get info_ => _i;

  String get name => getField(1);
  void set name(String v) { setField(1, v); }
  bool hasName() => hasField(1);
  void clearName() => clearField(1);

  Value get value => getField(4);
  void set value(Value v) { setField(4, v); }
  bool hasValue() => hasField(4);
  void clearValue() => clearField(4);
}

class Entity extends GeneratedMessage {
  static final BuilderInfo _i = new BuilderInfo('Entity')
    ..a(1, 'key', GeneratedMessage.OM, () => new Key(), () => new Key())
    ..m(2, 'property', () => new Property(), () => new PbList<Property>())
  ;

  Entity() : super();
  Entity.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromBuffer(i, r);
  Entity.fromJson(String i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromJson(i, r);
  Entity clone() => new Entity()..mergeFromMessage(this);
  BuilderInfo get info_ => _i;

  Key get key => getField(1);
  void set key(Key v) { setField(1, v); }
  bool hasKey() => hasField(1);
  void clearKey() => clearField(1);

  List<Property> get property => getField(2);
}

