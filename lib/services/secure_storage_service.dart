import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // No init needed
  Future<void> initialize() async {}

  // Generic write
  Future<void> writeKey(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  // Generic read
  Future<String?> readKey(String key) async {
    return await _storage.read(key: key);
  }

  // Optional: Convenience methods (you can keep or remove)
  Future<void> writeRunpodApiKey(String apiKey) async {
    await writeKey('runpod_api_key', apiKey);
  }

  Future<String?> readRunpodApiKey() async {
    return await readKey('runpod_api_key');
  }

  Future<void> writeOpenAIApiKey(String apiKey) async {
    await writeKey('openai_api_key', apiKey);
  }

  Future<String?> readOpenAIApiKey() async {
    return await readKey('openai_api_key');
  }
}
