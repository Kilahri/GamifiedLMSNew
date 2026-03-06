// video_upload_helper.dart
// Create this new file in your lib/helpers/ directory

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VideoUploadHelper {
  /// Pick a video file from device
  static Future<String?> pickVideoFromDevice() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        String sourcePath = result.files.single.path!;

        // Copy video to app's permanent storage
        String? savedPath = await _saveVideoToAppDirectory(sourcePath);
        return savedPath;
      }
      return null;
    } catch (e) {
      print('Error picking video: $e');
      return null;
    }
  }

  /// Save video to app's permanent directory
  static Future<String?> _saveVideoToAppDirectory(String sourcePath) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String videosDir = '${appDir.path}/videos';

      // Create videos directory if it doesn't exist
      final Directory videoDirectory = Directory(videosDir);
      if (!await videoDirectory.exists()) {
        await videoDirectory.create(recursive: true);
      }

      // Generate unique filename
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = path.extension(sourcePath);
      final String fileName = 'video_$timestamp$extension';
      final String destinationPath = '$videosDir/$fileName';

      // Copy file
      final File sourceFile = File(sourcePath);
      await sourceFile.copy(destinationPath);

      // Save mapping in SharedPreferences for future reference
      await _saveVideoPathMapping(fileName, destinationPath);

      return destinationPath;
    } catch (e) {
      print('Error saving video: $e');
      return null;
    }
  }

  /// Save video path mapping
  static Future<void> _saveVideoPathMapping(
    String fileName,
    String fullPath,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    String? mappingJson = prefs.getString('video_path_mappings');
    Map<String, String> mappings = {};

    if (mappingJson != null) {
      try {
        mappings = Map<String, String>.from(jsonDecode(mappingJson));
      } catch (e) {
        mappings = {};
      }
    }

    mappings[fileName] = fullPath;
    await prefs.setString('video_path_mappings', jsonEncode(mappings));
  }

  /// Check if URL is valid
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Check if path is local file
  static bool isLocalFile(String path) {
    return path.startsWith('/') ||
        path.contains('documents/videos/') ||
        File(path).existsSync();
  }

  /// Get video type (url, local, asset)
  static VideoSourceType getVideoSourceType(String videoUrl) {
    if (videoUrl.startsWith('lib/assets/')) {
      return VideoSourceType.asset;
    } else if (isValidUrl(videoUrl)) {
      return VideoSourceType.network;
    } else if (isLocalFile(videoUrl)) {
      return VideoSourceType.file;
    } else {
      return VideoSourceType.unknown;
    }
  }

  /// Delete uploaded video
  static Future<bool> deleteUploadedVideo(String videoPath) async {
    try {
      if (isLocalFile(videoPath) && !videoPath.startsWith('lib/assets/')) {
        final file = File(videoPath);
        if (await file.exists()) {
          await file.delete();
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error deleting video: $e');
      return false;
    }
  }
}

enum VideoSourceType { asset, network, file, unknown }
