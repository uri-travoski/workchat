import 'package:flutter/material.dart';

class FileTypeInfo {
  final IconData icon;
  final Color color;
  final String label;
  final Color badgeBg;
  final Color badgeTextColor;

  const FileTypeInfo({
    required this.icon,
    required this.color,
    required this.label,
    required this.badgeBg,
    required this.badgeTextColor,
  });
}

class FileTypeHelper {
  static FileTypeInfo getInfo(String filename) {
    final lower = filename.toLowerCase();
    final ext = lower.contains('.') ? lower.split('.').last : '';

    switch (ext) {
      // Excel / Spreadsheets
      case 'xlsx':
      case 'xls':
      case 'csv':
      case 'tsv':
      case 'ods':
        return const FileTypeInfo(
          icon: Icons.table_chart_rounded,
          color: Color(0xFF107C41),
          label: 'EXCEL',
          badgeBg: Color(0xFFE8F5E9),
          badgeTextColor: Color(0xFF107C41),
        );

      // Word / Documents
      case 'docx':
      case 'doc':
      case 'rtf':
      case 'odt':
      case 'pages':
        return const FileTypeInfo(
          icon: Icons.article_rounded,
          color: Color(0xFF2B579A),
          label: 'WORD',
          badgeBg: Color(0xFFE3F2FD),
          badgeTextColor: Color(0xFF1E40AF),
        );

      // PDF
      case 'pdf':
        return const FileTypeInfo(
          icon: Icons.picture_as_pdf_rounded,
          color: Color(0xFFE5252A),
          label: 'PDF',
          badgeBg: Color(0xFFFFEBEE),
          badgeTextColor: Color(0xFFC62828),
        );

      // PowerPoint / Slides
      case 'pptx':
      case 'ppt':
      case 'odp':
      case 'key':
        return const FileTypeInfo(
          icon: Icons.slideshow_rounded,
          color: Color(0xFFD24726),
          label: 'SLIDES',
          badgeBg: Color(0xFFFBE9E7),
          badgeTextColor: Color(0xFFD24726),
        );

      // Archives / Zip
      case 'zip':
      case 'tar':
      case 'gz':
      case '7z':
      case 'rar':
      case 'bz2':
      case 'xz':
        return const FileTypeInfo(
          icon: Icons.folder_zip_rounded,
          color: Color(0xFFD97706),
          label: 'ZIP',
          badgeBg: Color(0xFFFEF3C7),
          badgeTextColor: Color(0xFFB45309),
        );

      // Images
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
      case 'gif':
      case 'bmp':
      case 'svg':
        return const FileTypeInfo(
          icon: Icons.image_rounded,
          color: Color(0xFF8B5CF6),
          label: 'IMAGE',
          badgeBg: Color(0xFFEDE9FE),
          badgeTextColor: Color(0xFF6D28D9),
        );

      // Videos
      case 'mp4':
      case 'mov':
      case 'mkv':
      case 'webm':
      case 'avi':
      case 'flv':
      case 'm4v':
        return const FileTypeInfo(
          icon: Icons.movie_rounded,
          color: Color(0xFF06B6D4),
          label: 'VIDEO',
          badgeBg: Color(0xFFECFEFF),
          badgeTextColor: Color(0xFF0E7490),
        );

      // Audio
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'm4a':
      case 'flac':
      case 'aac':
        return const FileTypeInfo(
          icon: Icons.audiotrack_rounded,
          color: Color(0xFFEC4899),
          label: 'AUDIO',
          badgeBg: Color(0xFFFDF2F8),
          badgeTextColor: Color(0xFFBE185D),
        );

      // Code
      case 'go':
      case 'rs':
      case 'py':
      case 'js':
      case 'ts':
      case 'html':
      case 'css':
      case 'json':
      case 'yaml':
      case 'yml':
      case 'sh':
      case 'bash':
      case 'sql':
      case 'c':
      case 'cpp':
      case 'h':
      case 'dart':
        return const FileTypeInfo(
          icon: Icons.code_rounded,
          color: Color(0xFF10B981),
          label: 'CODE',
          badgeBg: Color(0xFFD1FAE5),
          badgeTextColor: Color(0xFF047857),
        );

      // Generic
      default:
        return FileTypeInfo(
          icon: Icons.insert_drive_file_rounded,
          color: const Color(0xFF64748B),
          label: ext.isNotEmpty ? ext.toUpperCase() : 'FILE',
          badgeBg: const Color(0xFFF1F5F9),
          badgeTextColor: const Color(0xFF475569),
        );
    }
  }
}
