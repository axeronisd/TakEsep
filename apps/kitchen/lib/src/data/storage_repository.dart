import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class StorageRepository {
  final SupabaseClient _supabase;
  final String bucketName;

  StorageRepository(this._supabase, {this.bucketName = 'product_images'});

  /// Uploads an image file to Supabase Storage and returns the public URL.
  Future<String?> uploadProductImage(File file, String fileExtension) async {
    try {
      final fileName = '${const Uuid().v4()}.$fileExtension';

      // Upload the file to the bucket
      await _supabase.storage.from(bucketName).upload(
            fileName,
            file,
            fileOptions: const FileOptions(cacheControl: '31536000', upsert: false),
          );

      // Get the public URL
      final publicUrl =
          _supabase.storage.from(bucketName).getPublicUrl(fileName);

      print('StorageRepository: uploaded image, URL = $publicUrl');
      return publicUrl;
    } catch (e) {
      print('Error uploading image to storage: $e');
      return null;
    }
  }

  /// Deletes an image from the bucket using its URL or path.
  Future<bool> deleteProductImage(String path) async {
    try {
      final fileName = path.split('/').last;
      await _supabase.storage.from(bucketName).remove([fileName]);
      return true;
    } catch (e) {
      print('Error deleting image from storage: $e');
      return false;
    }
  }
}
