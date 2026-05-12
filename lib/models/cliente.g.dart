// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cliente.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClienteAdapter extends TypeAdapter<Cliente> {
  @override
  final int typeId = 3;

  @override
  Cliente read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Cliente()
      ..id = fields[0] as String
      ..nombre = fields[1] as String
      ..activo = fields[2] as bool
      ..creadoEn = fields[3] as DateTime;
  }

  @override
  void write(BinaryWriter writer, Cliente obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nombre)
      ..writeByte(2)
      ..write(obj.activo)
      ..writeByte(3)
      ..write(obj.creadoEn);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClienteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
