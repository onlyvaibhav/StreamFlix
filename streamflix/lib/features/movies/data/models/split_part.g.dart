// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'split_part.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SplitPart _$SplitPartFromJson(Map<String, dynamic> json) => _SplitPart(
  fileId: json['fileId'] as String?,
  messageId: (json['messageId'] as num?)?.toInt(),
  partNumber: (json['partNumber'] as num?)?.toInt(),
  fileName: json['fileName'] as String?,
  size: (json['size'] as num?)?.toInt(),
  sizeFormatted: json['sizeFormatted'] as String?,
  duration: (_readDuration(json, 'duration') as num?)?.toDouble(),
);

Map<String, dynamic> _$SplitPartToJson(_SplitPart instance) =>
    <String, dynamic>{
      'fileId': instance.fileId,
      'messageId': instance.messageId,
      'partNumber': instance.partNumber,
      'fileName': instance.fileName,
      'size': instance.size,
      'sizeFormatted': instance.sizeFormatted,
      'duration': instance.duration,
    };
