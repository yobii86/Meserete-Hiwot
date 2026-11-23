import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/network/imunify_solver.dart';

void main() {
  group('ImunifySolver JSFuck decoding', () {
    test('decodes zero expressions correctly', () {
      expect(ImunifySolver.decodeJsFuckNumber('(+![])'), 0);
      expect(ImunifySolver.decodeJsFuckNumber('(+!+[])+(+![])'), 10);
    });

    test('decodes multi-digit numbers correctly', () {
      final expr1 =
          '(+!+[]+!![]+!![])+(+!+[]+[])+(+!+[]+!![]+!![]+!![]+!![])+(+!+[]+!![]+!![]+!![]+!![]+!![]+!![]+!![]+[])+(+!+[]+!![]+!![]+!![]+!![])+(+!+[]+!![]+!![]+!![]+!![]+!![]+!![]+[])+(+!+[]+!![]+!![]+!![]+!![]+!![]+!![]+!![])';
      expect(ImunifySolver.decodeJsFuckNumber(expr1), 3158578);

      final expr2 =
          '(+!+[]+!![]+!![]+!![]+!![]+!![])+(+!+[]+!![]+!![]+!![]+!![]+!![]+[])+(+!+[]+!![]+!![])+(+!+[]+!![]+!![]+[])+(+![])+(+!+[]+!![]+!![]+!![]+!![]+[])+(+!+[]+!![]+!![]+!![]+!![]+!![]+!![])';
      expect(ImunifySolver.decodeJsFuckNumber(expr2), 6633057);

      expect(3158578 + 6633057, 9791635);
    });
  });

  group('ImunifySolver simulated challenge flow', () {
    late HttpServer server;
    late String baseUrl;
    bool verifyReceived = false;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://${server.address.host}:${server.port}';

      server.listen((HttpRequest request) {
        if (request.uri.path == '/') {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write('''<!DOCTYPE html>
<html>
<head><title>One moment, please...</title></head>
<body>
<script>
g=+((+!+[]+!![]+!![])+(+!+[]+[]));
Q=+((+!+[]+!![]+!![]+!![]+!![])+(+!+[]+!![]+[]));
d='pdata';
F='/z0f76a1d14fd21a8fb5fd0d03e0fdc3d3cedae52f';
S['name']='ts';
S['value']='1794285927';
</script>
</body>
</html>''')
            ..close();
        } else if (request.uri.path.startsWith('/z0f76a1d14fd21a8fb5fd0d03e0fdc3d3cedae52f')) {
          verifyReceived = true;
          final wsidchk = request.uri.queryParameters['wsidchk'];
          expect(wsidchk, isNotNull);
          // 31 + 52 = 83
          expect(int.parse(wsidchk!), 83);
          expect(request.uri.queryParameters['ts'], '1794285927');

          request.response
            ..statusCode = 302
            ..headers.set('set-cookie', 'wssplashchk=test_token_12345; Path=/; Domain=localhost')
            ..close();
        } else {
          request.response
            ..statusCode = 404
            ..close();
        }
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('solves simulated splash challenge and returns wssplashchk cookie', () async {
      final cookie = await ImunifySolver.solve(baseUrl);
      expect(verifyReceived, isTrue);
      expect(cookie, equals('wssplashchk=test_token_12345'));
    });
  });
}

