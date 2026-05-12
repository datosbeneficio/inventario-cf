// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'salida.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SalidaAdapter extends TypeAdapter<Salida> {
  @override
  final int typeId = 2;

  @override
  Salida read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Salida()
      ..id = fields[0] as String
      ..rangoId = fields[1] as String
      ..canastillas = fields[2] as int
      ..peso = fields[3] as double
      ..esCola = fields[4] as bool
      ..unidades = fields[5] as int
      ..timestamp = fields[6] as DateTime
      ..clienteId = fields[7] as String?;
  }

  @override
  void write(BinaryWriter writer, Salida obj) {
    writer
      ..writeByte(8)
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
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.clienteId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalidaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
