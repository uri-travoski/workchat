import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileService {
  static Future<void> openAttachment({
    required String serverUrl,
    required String token,
    required String attachmentId,
    required String fileName,
  }) async {
    try {
      final cacheDir = await getApplicationDocumentsDirectory();
      final targetFile = File(p.join(cacheDir.path, 'downloads', fileName));

      if (!await targetFile.exists()) {
        await targetFile.parent.create(recursive: true);
        final downloadUrl = Uri.parse('$serverUrl/api/v1/files/$attachmentId?token=$token');
        final response = await http.get(downloadUrl);
        if (response.statusCode == 200) {
          await targetFile.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('Failed to download file: HTTP ${response.statusCode}');
        }
      }

      // Launch default viewer or OS app chooser via open_filex
      final result = await OpenFilex.open(targetFile.path);
      if (result.type != ResultType.done) {
        // Fallback for desktop Linux if needed
        if (Platform.isLinux) {
          await Process.run('xdg-open', [targetFile.path]);
        }
      }
    } catch (e) {
      // ignore or log
      rethrow;
    }
  }
}
