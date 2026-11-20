class Attachment {
  final String id;
  final String uploaderId;
  final String name;
  final String contentType;
  final int size;
  final String sha256;
  final String purpose;
  final int createdMs;

  Attachment({
    required this.id,
    required this.uploaderId,
    required this.name,
    required this.contentType,
    required this.size,
    required this.sha256,
    this.purpose = 'file',
    required this.createdMs,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String,
      uploaderId: json['uploader_id'] as String? ?? '',
      name: json['name'] as String,
      contentType: json['content_type'] as String? ?? 'application/octet-stream',
      size: json['size'] as int? ?? 0,
      sha256: json['sha256'] as String? ?? '',
      purpose: json['purpose'] as String? ?? 'file',
      createdMs: json['created_ms'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uploader_id': uploaderId,
    'name': name,
    'content_type': contentType,
    'size': size,
    'sha256': sha256,
    'purpose': purpose,
    'created_ms': createdMs,
  };
}
