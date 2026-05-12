// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ingreso.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IngresoAdapter extends TypeAdapter<Ingreso> {
  @override
  final int typeId = 1;

  @override
  Ingreso read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Ingreso()
      ..id = fields[0] as String
      ..rangoId = fields[1] as String
      ..canastillas = fields[2] as int
      ..peso = fields[3] as double
      ..esCola = fields[4] as bool
      ..unidades = fields[5] as int
      ..timestamp = fields[6] as DateTime;
  }

  @override
  void write(BinaryWriter writer, Ingreso obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.rangoId)
      ..writeByte(2)
      ..write(obj.canastillas)
      ..writeByte(3)
      ..write(obj.peso)
      ..writeByte(4)
      ..write(obj.esCola)
      ..writeByte(5)
      ..write(obj.unidades)
      ..writeByte(6)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngresoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
