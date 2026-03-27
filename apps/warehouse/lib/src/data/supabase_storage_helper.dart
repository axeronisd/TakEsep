import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class SupabaseStorageHelper {
  /// Uploads a local file to the Supabase 'images' bucket and returns its public URL.
  /// Throws an exception with the error message if it fails.
  static Future<String> uploadImage(File file) async {
    try {
      final ext = p.extension(file.path);
      final fileName = '${const Uuid().v4()}$ext';
      final storage = Supabase.instance.client.storage.from('images');

      // Upload file to the bucket
      await storage.upload(fileName, file);

      // Return public URL
      return storage.getPublicUrl(fileName);
    } catch (e) {
      print('SupabaseStorageHelper.uploadImage error: $e');
      throw Exception('Supabase upload error: $e');
    }
  }

  /// Deletes an image from the bucket given its public URL
  static Future<void> deleteImage(String publicUrl) async {
    try {
      final uri = Uri.parse(publicUrl);
      final segments = uri.pathSegments;
      // The file name is usually the last segment in the path
      final fileName = segments.last;
      await Supabase.instance.client.storage.from('images').remove([fileName]);
    } catch (e) {
      print('SupabaseStorageHelper.deleteImage error: $e');
    }
  }
}
