import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/services/api_service.dart';

class BooksService {
  BooksService();

  Future<Book> upsertBook(BookLookupResult lookup) async {
    if (!EnvConfig.isConfigured) {
      throw Exception(
        'API is not configured. Set API_BASE_URL (e.g. http://localhost:3000).',
      );
    }
    return ApiService.upsertBook(lookup);
  }
}
