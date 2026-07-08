import 'dart:convert';

class FileInfo {
  final String fileId;
  final int fileSize;
  final String mimeType;
  final String fileName;
  final int? dcId;
  final FileLocation? fileLocation;

  FileInfo({
    required this.fileId,
    required this.fileSize,
    required this.mimeType,
    required this.fileName,
    this.dcId,
    this.fileLocation,
  });

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      fileId: json['fileId'] as String,
      fileSize: (json['fileSize'] as num).toInt(),
      mimeType: json['mimeType'] as String? ?? 'video/mp4',
      fileName: json['fileName'] as String? ?? '',
      dcId: json['dcId'] as int?,
      fileLocation: json['fileLocation'] != null
          ? FileLocation.fromJson(json['fileLocation'] as Map<String, dynamic>)
          : null,
    );
  }
}

class FileLocation {
  final int id;
  final String accessHash;
  final List<int> fileReference;
  final String? thumbSize;

  FileLocation({
    required this.id,
    required this.accessHash,
    required this.fileReference,
    this.thumbSize,
  });

  factory FileLocation.fromJson(Map<String, dynamic> json) {
    return FileLocation(
      id: int.parse(json['id'].toString()),
      accessHash: json['accessHash'] as String,
      fileReference: base64Decode(json['fileReference'] as String),
      thumbSize: json['thumbSize'] as String?,
    );
  }
}
