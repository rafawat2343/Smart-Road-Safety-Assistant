import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Service class for uploading images to Cloudinary
class CloudinaryService {
  // TODO: Replace with your Cloudinary credentials
  static const String cloudName = 'dmkutkf8a';
  static const String uploadPreset =
      'drive_mind'; // Create an unsigned upload preset in Cloudinary

  /// Upload an image file to Cloudinary
  /// Returns the secure URL of the uploaded image, or null if upload fails
  static Future<String?> uploadImage(File imageFile, {String? folder}) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri);

      // Add the upload preset (required for unsigned uploads)
      request.fields['upload_preset'] = uploadPreset;

      // Optional: specify a folder
      if (folder != null) {
        request.fields['folder'] = folder;
      }

      // Add the image file
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonData = json.decode(responseData);
        return jsonData['secure_url'] as String?;
      } else {
        print('Cloudinary upload failed: ${response.statusCode}');
        print('Response: $responseData');
        return null;
      }
    } catch (e) {
      print('Cloudinary upload error: $e');
      return null;
    }
  }

  /// Upload a base64 encoded image to Cloudinary
  /// Returns the secure URL of the uploaded image, or null if upload fails
  static Future<String?> uploadBase64Image(
    String base64Image, {
    String? folder,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final response = await http.post(
        uri,
        body: {
          'file': 'data:image/jpeg;base64,$base64Image',
          'upload_preset': uploadPreset,
          if (folder != null) 'folder': folder,
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['secure_url'] as String?;
      } else {
        print('Cloudinary upload failed: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Cloudinary upload error: $e');
      return null;
    }
  }

  /// Delete an image from Cloudinary by public ID
  /// Note: This requires signed requests (API key & secret)
  /// For production, this should be done via your backend server
  static Future<bool> deleteImage(String publicId) async {
    // For security reasons, deletion should be handled by a backend server
    // as it requires your API secret which should never be in client code
    print('Image deletion should be handled by backend server');
    return false;
  }
}
