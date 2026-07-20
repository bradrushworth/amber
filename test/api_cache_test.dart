import 'package:amber/api_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiCache', () {
    // The cache is a process-wide singleton; isolate each test.
    setUp(ApiCache.instance.clear);
    test('serves a fresh success without re-hitting the network', () async {
      int calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response('[]', 200);
      });
      final uri = Uri.parse('https://api.amber.com.au/v1/sites/1/prices/current');

      final first = await ApiCache.instance.get(uri, client: client);
      final second = await ApiCache.instance.get(uri, client: client);

      expect(first.statusCode, 200);
      expect(second.statusCode, 200);
      // Second call must be served from cache, not the network.
      expect(calls, 1);
    });

    test('re-fetches once the TTL expires', () async {
      int calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response('[]', 200);
      });
      final uri = Uri.parse('https://api.amber.com.au/v1/sites/1/prices/current');

      await ApiCache.instance.get(uri, client: client, ttl: Duration.zero);
      await ApiCache.instance.get(uri, client: client, ttl: Duration.zero);

      expect(calls, 2);
    });

    test('serves stale success on a rate-limited (429) call for the same key', () async {
      int calls = 0;
      final client = MockClient((request) async {
        calls++;
        // First call succeeds, then the API rate-limits us on the same URL.
        if (calls == 1) return http.Response('["good"]', 200);
        return http.Response('too many requests', 429);
      });
      final uri = Uri.parse('https://api.amber.com.au/v1/sites/1/prices/current');

      final good = await ApiCache.instance.get(uri, client: client);
      expect(good.statusCode, 200);

      // The 429 must NOT blank the chart: the cached success is served instead.
      final limited = await ApiCache.instance.get(uri, client: client, ttl: Duration.zero);
      expect(limited.statusCode, 200);
      expect(calls, 2);
    });

    test('returns the 429 when there is no cached success to fall back to', () async {
      final client = MockClient((request) async {
        return http.Response('too many requests', 429);
      });
      final uri = Uri.parse('https://api.amber.com.au/v1/sites/1/prices/current');

      final limited = await ApiCache.instance.get(uri, client: client, ttl: Duration.zero);
      expect(limited.statusCode, 429);
    });

    test('de-duplicates concurrent identical requests', () async {
      int calls = 0;
      final client = MockClient((request) async {
        calls++;
        // Simulate latency so both calls overlap.
        await Future.delayed(const Duration(milliseconds: 20));
        return http.Response('[]', 200);
      });
      final uri = Uri.parse('https://api.amber.com.au/v1/sites/1/prices/current');

      final results = await Future.wait([
        ApiCache.instance.get(uri, client: client),
        ApiCache.instance.get(uri, client: client),
      ]);

      expect(results[0].statusCode, 200);
      expect(results[1].statusCode, 200);
      expect(calls, 1);
    });
  });
}