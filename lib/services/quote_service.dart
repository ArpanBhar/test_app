import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/quote.dart';

class QuoteService {
  // zenquotes.io — free, actively maintained, valid SSL
  static const String _baseUrl = 'https://zenquotes.io/api/random';

  /// Creates an HTTP client that ignores SSL certificate errors.
  /// Needed when the API endpoint has a self-signed or expired certificate.
  http.Client _buildClient() {
    final httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    return IOClient(httpClient);
  }

  Future<Quote> fetchRandomQuote() async {
    final client = _buildClient();
    try {
      developer.log('QuoteService: fetching from $_baseUrl', name: 'QuoteService');

      final response = await client
          .get(Uri.parse(_baseUrl))
          .timeout(const Duration(seconds: 10));

      developer.log(
        'QuoteService: status=${response.statusCode} body=${response.body}',
        name: 'QuoteService',
      );

      if (response.statusCode == 200) {
        // ZenQuotes returns a JSON array: [{"q": "...", "a": "...", "h": "..."}]
        final list = jsonDecode(response.body) as List<dynamic>;
        final json = list.first as Map<String, dynamic>;

        // ZenQuotes returns this when rate-limited (still status 200!)
        if (json['q'] != null &&
            (json['q'] as String).toLowerCase().contains('too many')) {
          developer.log(
            'QuoteService: RATE LIMITED — response: ${json["q"]}',
            name: 'QuoteService',
            level: 900, // WARNING level
          );
          throw 'Rate limited by zenquotes.io';
        }

        return Quote(
          content: json['q'] as String? ?? '',
          author: json['a'] as String? ?? 'Unknown',
        );
      } else {
        developer.log(
          'QuoteService: non-200 response — ${response.statusCode}: ${response.body}',
          name: 'QuoteService',
          level: 1000, // ERROR level
        );
        throw 'Server error: ${response.statusCode}';
      }
    } catch (e, stack) {
      developer.log(
        'QuoteService: exception — $e',
        name: 'QuoteService',
        level: 1000,
        error: e,
        stackTrace: stack,
      );
      if (e is String) rethrow;
      throw 'Failed to fetch quote: $e';
    } finally {
      client.close();
    }
  }
}

