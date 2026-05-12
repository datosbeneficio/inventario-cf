// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rango.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RangoAdapter extends TypeAdapter<Rango> {
  @override
  final int typeId = 0;

  @override
  Rango read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Rango()
      ..id = fields[0] as String
      ..nombre = fields[1] as String
      ..multiplicador = fields[2] as double
      ..activo = fields[3] as bool
      ..creadoEn = fields[4] as DateTime;
  }

  @override
  void write(BinaryWriter writer, Rango obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nombre)
      ..writeByte(2)
      ..write(obj.multiplicador)
      ..writeByte(3)
      ..write(obj.activo)
      ..writeByte(4)
      ..write(obj.creadoEn);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RangoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
