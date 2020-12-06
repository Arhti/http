// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'utils.dart';

void main() {

  setUp(startServer);
  tearDown(stopServer);

  // We use a self-signed certificate. If we do not allow
  // bad certificates, we would fail on any call to the [_httpsServer]
  http.Client().setBadCertificateCallback((cr, host, port) => true);

  // Since http and https server basically behave the same,
  // we check for the same base-functionality
  for (var serverType in ['http', 'https']) {
    group('$serverType.', () {
      test('head', () async {
        var response = await http.head(getServerUrl(serverType));
        expect(response.statusCode, equals(200));
        expect(response.body, equals(''));
      });

      test('get', () async {
        var response = await http.get(getServerUrl(serverType), headers: {
          'X-Random-Header': 'Value',
          'X-Other-Header': 'Other Value',
          'User-Agent': 'Dart'
        });
        expect(response.statusCode, equals(200));
        expect(
            response.body,
            parse(equals({
              'method': 'GET',
              'path': '/',
              'headers': {
                'content-length': ['0'],
                'accept-encoding': ['gzip'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              },
            })));
      });

      test('post', () async {
        var response = await http.post(getServerUrl(serverType), headers: {
          'X-Random-Header': 'Value',
          'X-Other-Header': 'Other Value',
          'Content-Type': 'text/plain',
          'User-Agent': 'Dart'
        });
        expect(response.statusCode, equals(200));
        expect(
            response.body,
            parse(equals({
              'method': 'POST',
              'path': '/',
              'headers': {
                'accept-encoding': ['gzip'],
                'content-length': ['0'],
                'content-type': ['text/plain'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              }
            })));
      });

      test('post with string', () async {
        var response = await http.post(getServerUrl(serverType),
            headers: {
              'X-Random-Header': 'Value',
              'X-Other-Header': 'Other Value',
              'User-Agent': 'Dart'
            },
            body: 'request body');
        expect(response.statusCode, equals(200));
        expect(
            response.body,
            parse(equals({
              'method': 'POST',
              'path': '/',
              'headers': {
                'content-type': ['text/plain; charset=utf-8'],
                'content-length': ['12'],
                'accept-encoding': ['gzip'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              },
              'body': 'request body'
            })));
      });

      test('post with bytes', () async {
        var response = await http.post(getServerUrl(serverType), headers: {
          'X-Random-Header': 'Value',
          'X-Other-Header': 'Other Value',
          'User-Agent': 'Dart'
        }, body: [
          104,
          101,
          108,
          108,
          111
        ]);
        expect(response.statusCode, equals(200));
        expect(
            response.body,
            parse(equals({
              'method': 'POST',
              'path': '/',
              'headers': {
                'content-length': ['5'],
                'accept-encoding': ['gzip'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              },
              'body': [104, 101, 108, 108, 111]
            })));
      });

      test('post with fields', () async {
        var response = await http.post(getServerUrl(serverType), headers: {
          'X-Random-Header': 'Value',
          'X-Other-Header': 'Other Value',
          'User-Agent': 'Dart'
        }, body: {
          'some-field': 'value',
          'other-field': 'other value'
        });
        expect(response.statusCode, equals(200));
        expect(
            response.body,
            parse(equals({
              'method': 'POST',
              'path': '/',
              'headers': {
                'content-type': [
                  'application/x-www-form-urlencoded; charset=utf-8'
                ],
                'content-length': ['40'],
                'accept-encoding': ['gzip'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              },
              'body': 'some-field=value&other-field=other+value'
            })));
      });

      test('put', () async {
        var response = await http.put(getServerUrl(serverType), headers: {
          'X-Random-Header': 'Value',
          'X-Other-Header': 'Other Value',
          'Content-Type': 'text/plain',
          'User-Agent': 'Dart'
        });
        expect(response.statusCode, equals(200));
        expect(
            response.body,
            parse(equals({
              'method': 'PUT',
              'path': '/',
              'headers': {
                'accept-encoding': ['gzip'],
                'content-length': ['0'],
                'content-type': ['text/plain'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              }
            })));
      });

      test('put with string', () async {
        var response = await http.put(getServerUrl(serverType),
            headers: {
              'X-Random-Header': 'Value',
              'X-Other-Header': 'Other Value',
              'User-Agent': 'Dart'
            },
            body: 'request body');
        expect(response.statusCode, equals(200));
        expect(
            response.body,
            parse(equals({
              'method': 'PUT',
              'path': '/',
              'headers': {
                'content-type': ['text/plain; charset=utf-8'],
                'content-length': ['12'],
                'accept-encoding': ['gzip'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              },
              'body': 'request body'
            })));
      });

      test('put with bytes', () async {
        var response = await http.put(getServerUrl(serverType), headers: {
          'X-Random-Header': 'Value',
          'X-Other-Header': 'Other Value',
          'User-Agent': 'Dart'
        }, body: [
          104,
          101,
          108,
          108,
          111
        ]);
        expect(response.statusCode, equals(200));
        expect(
            response.body,
            parse(equals({
              'method': 'PUT',
              'path': '/',
              'headers': {
                'content-length': ['5'],
                'accept-encoding': ['gzip'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              },
              'body': [104, 101, 108, 108, 111]
            })));
      });

      test('put with fields', () async {
        var response = await http.put(getServerUrl(serverType), headers: {
          'X-Random-Header': 'Value',
          'X-Other-Header': 'Other Value',
          'User-Agent': 'Dart'
        }, body: {
          'some-field': 'value',
          'other-field': 'other value'
        });
        expect(response.statusCode, equals(200));
        expect(
            response.body,
            parse(equals({
              'method': 'PUT',
              'path': '/',
              'headers': {
                'content-type': [
                  'application/x-www-form-urlencoded; charset=utf-8'
                ],
                'content-length': ['40'],
                'accept-encoding': ['gzip'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              },
              'body': 'some-field=value&other-field=other+value'
            })));
      });

      test('patch', () async {
        var response = await http.patch(getServerUrl(serverType), headers: {
          'X-Random-Header': 'Value',
          'X-Other-Header': 'Other Value',
          'Content-Type': 'text/plain',
          'User-Agent': 'Dart'
        });
        expect(response.statusCode, equals(200));
        expect(
            response.body,
            parse(equals({
              'method': 'PATCH',
              'path': '/',
              'headers': {
                'accept-encoding': ['gzip'],
                'content-length': ['0'],
                'content-type': ['text/plain'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              }
            })));
      });

      test('patch with string', () async {
        var response = await http.patch(getServerUrl(serverType),
            headers: {
              'X-Random-Header': 'Value',
              'X-Other-Header': 'Other Value',
              'User-Agent': 'Dart'
            },
            body: 'request body');
        expect(response.statusCode, equals(200));
        expect(
            response.body,
            parse(equals({
              'method': 'PATCH',
              'path': '/',
              'headers': {
                'content-type': ['text/plain; charset=utf-8'],
                'content-length': ['12'],
                'accept-encoding': ['gzip'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              },
              'body': 'request body'
            })));
      });

      test('patch with bytes', () async {
        var response = await http.patch(getServerUrl(serverType), headers: {
          'X-Random-Header': 'Value',
          'X-Other-Header': 'Other Value',
          'User-Agent': 'Dart'
        }, body: [
          104,
          101,
          108,
          108,
          111
        ]);
        expect(response.statusCode, equals(200));
        expect(
            response.body,
            parse(equals({
              'method': 'PATCH',
              'path': '/',
              'headers': {
                'content-length': ['5'],
                'accept-encoding': ['gzip'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              },
              'body': [104, 101, 108, 108, 111]
            })));
      });

      test('patch with fields', () async {
        var response = await http.patch(getServerUrl(serverType), headers: {
          'X-Random-Header': 'Value',
          'X-Other-Header': 'Other Value',
          'User-Agent': 'Dart'
        }, body: {
          'some-field': 'value',
          'other-field': 'other value'
        });
        expect(response.statusCode, equals(200));
        expect(
            response.body,
            parse(equals({
              'method': 'PATCH',
              'path': '/',
              'headers': {
                'content-type': [
                  'application/x-www-form-urlencoded; charset=utf-8'
                ],
                'content-length': ['40'],
                'accept-encoding': ['gzip'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              },
              'body': 'some-field=value&other-field=other+value'
            })));
      });

      test('delete', () async {
        var response = await http.delete(getServerUrl(serverType), headers: {
          'X-Random-Header': 'Value',
          'X-Other-Header': 'Other Value',
          'User-Agent': 'Dart'
        });
        expect(response.statusCode, equals(200));
        expect(
            response.body,
            parse(equals({
              'method': 'DELETE',
              'path': '/',
              'headers': {
                'content-length': ['0'],
                'accept-encoding': ['gzip'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              }
            })));
      });

      test('read', () async {
        var response = await http.read(getServerUrl(serverType), headers: {
          'X-Random-Header': 'Value',
          'X-Other-Header': 'Other Value',
          'User-Agent': 'Dart'
        });
        expect(
            response,
            parse(equals({
              'method': 'GET',
              'path': '/',
              'headers': {
                'content-length': ['0'],
                'accept-encoding': ['gzip'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              },
            })));
      });

      test('read throws an error for a 4** status code', () {
        expect(
            http.read(httpServerUrl.resolve('/error')), throwsClientException);
      });

      test('readBytes', () async {
        var bytes = await http.readBytes(getServerUrl(serverType), headers: {
          'X-Random-Header': 'Value',
          'X-Other-Header': 'Other Value',
          'User-Agent': 'Dart'
        });

        expect(
            String.fromCharCodes(bytes),
            parse(equals({
              'method': 'GET',
              'path': '/',
              'headers': {
                'content-length': ['0'],
                'accept-encoding': ['gzip'],
                'user-agent': ['Dart'],
                'x-random-header': ['Value'],
                'x-other-header': ['Other Value']
              },
            })));
      });

      test('readBytes throws an error for a 4** status code', () {
        expect(
            http.readBytes(httpServerUrl.resolve('/error')),
            throwsClientException);
      });
    });
  }
}
