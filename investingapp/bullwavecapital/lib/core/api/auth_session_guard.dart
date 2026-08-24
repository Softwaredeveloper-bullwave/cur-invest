import 'token_storage.dart';

/// Skip authenticated API calls when there is no stored access token.
Future<bool> hasStoredAccessToken() async {
  final token = await TokenStorage.getAccessToken();
  return token != null && token.isNotEmpty;
}
