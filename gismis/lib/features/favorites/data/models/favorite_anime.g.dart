// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_anime.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FavoriteAnimeAdapter extends TypeAdapter<FavoriteAnime> {
  @override
  final int typeId = 10;

  @override
  FavoriteAnime read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FavoriteAnime(
      animeId: fields[0] as String,
      title: fields[1] as String,
      coverUrl: fields[2] as String,
      addedAt: fields[4] as DateTime,
      status: fields[3] as AnimeStatus,
      syncedAt: fields[5] as DateTime?,
      customOrder: fields[6] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, FavoriteAnime obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.animeId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.coverUrl)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.addedAt)
      ..writeByte(5)
      ..write(obj.syncedAt)
      ..writeByte(6)
      ..write(obj.customOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteAnimeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
