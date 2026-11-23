import 'dart:convert';
import 'dart:io';

/// Automated resolver for Imunify360 WebShield Anti-Bot challenge.
///
/// When a mobile IP is placed into the challenge pool by OpenResty / Imunify360 WebShield,
/// all API requests receive HTTP 403 ("Access denied by Imunify360 bot-protection") unless
/// the client completes the splash arithmetic challenge and sends the `wssplashchk` cookie.
class ImunifySolver {
  static const bool isWeb = bool.fromEnvironment('dart.library.js_interop') ||
      bool.fromEnvironment('dart.library.html') ||
      identical(0, 0.0);

  static const String defaultUserAgent =
      'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';

  static int decodeJsFuckNumber(String expr) {
    final groupRegex = RegExp(r'\(([^)]+)\)');
    final digits = StringBuffer();
    for (final match in groupRegex.allMatches(expr)) {
      final inner = match.group(1)!;
      if ((inner.contains('+![]') || inner.contains('![]')) &&
          !inner.contains('!+[]') &&
          !inner.contains('!![]')) {
        digits.write('0');
      } else {
        final count = RegExp(r'!\+\[\]|!!\[\]').allMatches(inner).length;
        if (count > 0) {
          digits.write(count);
        }
      }
    }
    return int.tryParse(digits.toString()) ?? 0;
  }

  /// Solves the WebShield splash challenge and returns the `wssplashchk=...` cookie string.
  static Future<String?> solve(String baseUrl, {String userAgent = defaultUserAgent}) async {
    if (isWeb) return null;

    final client1 = HttpClient();
    client1.badCertificateCallback = (cert, host, port) => true;

    try {
      // Step 1: GET splash HTML page from base URL origin
      final challengePageUri = Uri.parse('$baseUrl/');
      final req = await client1.getUrl(challengePageUri);
      req.headers.set('User-Agent', userAgent);
      req.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
      req.headers.set('Accept-Language', 'en-US,en;q=0.9');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client1.close(force: true);

      if (!body.contains('wsidchk') && !body.contains('One moment, please...') && !body.contains('bot-protection')) {
        return null;
      }

      // Step 2: Extract action URL (modern /z... or legacy o='/...')
      final actionMatch = RegExp(r"""['"](\/z[a-f0-9]{30,})['"]""").firstMatch(body) ??
          RegExp(r"""o=['"](\/[^'"]+)['"]""").firstMatch(body) ??
          RegExp(r"""action=['"](\/[^'"]+)['"]""").firstMatch(body);
      if (actionMatch == null) {
        return null;
      }
      final action = actionMatch.group(1)!;

      // Step 3: Extract JSFuck expressions (support both modern =\+\((\([+!...]+?\))\) and legacy e=\+\(...))
      final exprMatches = RegExp(r'=\+\((\([+!\[\]\(\)\s]+?\))\)').allMatches(body).toList();
      var wsidchk = 0;
      if (exprMatches.isNotEmpty) {
        for (final m in exprMatches) {
          wsidchk += decodeJsFuckNumber(m.group(1)!);
        }
      } else {
        final eExprMatch = RegExp(r'e=\+\(([\s\S]*?)\),\s*\w+=').firstMatch(body);
        final lExprMatch = RegExp(r'L=\+\(([\s\S]*?)\),\s*\w+=').firstMatch(body);
        if (eExprMatch != null && lExprMatch != null) {
          final e = decodeJsFuckNumber(eExprMatch.group(1)!);
          final l = decodeJsFuckNumber(lExprMatch.group(1)!);
          wsidchk = e + l;
        }
      }
      if (wsidchk == 0) return null;

      // Step 4: Extract timestamp
      final tsMatch = RegExp(r"""['"]ts['"]\s*,\s*['"](\d+)['"]""").firstMatch(body) ??
          RegExp(r"""['"](\d{10})['"]""").firstMatch(body);
      final ts = tsMatch?.group(1) ?? '${DateTime.now().millisecondsSinceEpoch ~/ 1000}';

      // Step 5: Extract or generate pdata
      final pdataMatch = RegExp(r"""['"](https%3A%2F%2F[^'"]+)['"]""").firstMatch(body);
      final pdata = pdataMatch?.group(1) ?? Uri.encodeComponent(baseUrl);

      // Step 6: Extract ID or use reliable fallback
      final idMatch = RegExp(r"""['"]([a-f0-9]{32})['"]""").firstMatch(body);
      final id = idMatch?.group(1) ?? '7fa3b767c460b54a2be4d49030b349c7';

      // Step 7: Submit verification GET request with separate client
      final client2 = HttpClient();
      client2.badCertificateCallback = (cert, host, port) => true;

      try {
        final verifyUrl = '$baseUrl$action?wsidchk=$wsidchk&pdata=$pdata&id=$id&ts=$ts&cttl=0';
        final cReq = await client2.getUrl(Uri.parse(verifyUrl));
        cReq.headers.set('User-Agent', userAgent);
        cReq.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
        cReq.headers.set('Referer', '$baseUrl/');
        cReq.followRedirects = false;
        final cRes = await cReq.close();

        final rawCookies = cRes.headers['set-cookie'] ?? [];
        await cRes.drain<void>();

        for (final sc in rawCookies) {
          if (sc.contains('wssplashchk=')) {
            return sc.split(';').first.trim();
          }
        }
      } finally {
        client2.close(force: true);
      }

      return null;
    } catch (_) {
      return null;
    } finally {
      client1.close(force: true);
    }
  }
}
