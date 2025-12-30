import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/modules/core/services/api_service.dart';

class SettingsService {
  final ApiService _apiService = ApiService();

  Future<Map<String, String>> fetchSettings() async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/settings'),
      headers: await _apiService.getHeaders(),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data.map((key, value) => MapEntry(key, value.toString()));
    } else {
      throw Exception('Failed to load settings');
    }
  }

  Future<void> updateSettings(Map<String, String> settings) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/settings'),
      headers: await _apiService.getHeaders(),
      body: jsonEncode(settings),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update settings (Status: ${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<String> uploadLogo(dynamic fileObj) async {
    // fileObj is expected to be an XFile from image_picker
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiService.baseUrl}/upload'),
    );

    // Add Auth Header
    final headers = await _apiService.getHeaders();
    request.headers.addAll(headers);

    // internal File from cross_file/image_picker
    // We need to read it as bytes or path depending on platform.
    // Assuming Desktop (Windows): it has a path.
    // But XFile might need to be read as bytes for web, but here we are on desktop.

    // We will assume fileObj has a path (File from dart:io or XFile from image_picker)
    // Actually, let's just take the path as a string to be safe, or CrossFile.
    // For simplicity with frontend logic, let's accept the path string or the File object.
    // Let's assume we pass the XFile path.

    // Wait, the standard way in Flutter desktop `http` package with XFile:
    // request.files.add(await http.MultipartFile.fromPath('images', fileObj.path));

    // I will write it to take the file path String

    request.files.add(
      await http.MultipartFile.fromPath('images', fileObj.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> images = data['images'];
      if (images.isNotEmpty) {
        // Return the full URL
        // The backend returns '/uploads/filename'. We need to prepend base URL (excluding /api)
        // BaseUrl is http://localhost:5000/api
        // We need http://localhost:5000/uploads/...

        final relativePath = images[0].toString();
        // Hacky replace to get root url
        final rootUrl = ApiService.baseUrl.replaceAll('/api', '');
        return '$rootUrl$relativePath';
      }
    }
    throw Exception('Failed to upload logo: ${response.body}');
  }
}
