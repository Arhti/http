// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('()', () {
    test('sets body', () {
      var response = http.Response('Hello, world!', 200);
      expect(response.body, equals('Hello, world!'));
    });

    test('sets bodyBytes', () {
      var response = http.Response('Hello, world!', 200);
      expect(
          response.bodyBytes,
          equals(
              [72, 101, 108, 108, 111, 44, 32, 119, 111, 114, 108, 100, 33]));
    });

    test('respects the inferred encoding', () {
      var response = http.Response('föøbãr', 200,
          headers: {'content-type': 'text/plain; charset=iso-8859-1'});
      expect(response.bodyBytes, equals([102, 246, 248, 98, 227, 114]));
    });
  });

  group('.bytes()', () {
    test('sets body', () {
      var response = http.Response.bytes([104, 101, 108, 108, 111], 200);
      expect(response.body, equals('hello'));
    });

    test('sets bodyBytes', () {
      var response = http.Response.bytes([104, 101, 108, 108, 111], 200);
      expect(response.bodyBytes, equals([104, 101, 108, 108, 111]));
    });

    test('respects the inferred encoding', () {
      var response = http.Response.bytes([102, 246, 248, 98, 227, 114], 200,
          headers: {'content-type': 'text/plain; charset=iso-8859-1'});
      expect(response.body, equals('föøbãr'));
    });
  });

  group('.fromStream()', () {
    test('sets body', () async {
      var controller = StreamController<List<int>>(sync: true);
      var streamResponse =
          http.StreamedResponse(controller.stream, 200, contentLength: 13);
      controller
        ..add([72, 101, 108, 108, 111, 44, 32])
        ..add([119, 111, 114, 108, 100, 33]);
      unawaited(controller.close());
      var response = await http.Response.fromStream(streamResponse);
      expect(response.body, equals('Hello, world!'));
    });

    test('sets bodyBytes', () async {
      var controller = StreamController<List<int>>(sync: true);
      var streamResponse =
          http.StreamedResponse(controller.stream, 200, contentLength: 5);
      controller.add([104, 101, 108, 108, 111]);
      unawaited(controller.close());
      var response = await http.Response.fromStream(streamResponse);
      expect(response.bodyBytes, equals([104, 101, 108, 108, 111]));
    });
  });

  // If multiple set-cookies are included in the response header,
  // the http library will merge them into a comma-separated list
  // and set them in the Response object.
  test('checks multiple set-cookies', () {
    final response = http.Response('', 200, headers: {
      'set-cookie':
          // This response header contains 6 set-cookies
          'AWSALB=AWSALB_TEST; Expires=Tue, 26 Apr 2022 00:26:55 GMT; Path=/,AWSALBCORS=AWSALBCORS_TEST; Expires=Tue, 26 Apr 2022 00:26:55 GMT; Path=/; SameSite=None; Secure,jwt_token=JWT_TEST; Domain=.test.com; Max-Age=31536000; Path=/; expires=Wed, 19-Apr-2023 00:26:55 GMT; SameSite=lax; Secure,csrf_token=CSRF_TOKEN_TEST_1; Domain=.test.com; Max-Age=31536000; Path=/; expires=Wed, 19-Apr-2023 00:26:55 GMT,csrf_token=CSRF_TOKEN_TEST_2; Domain=.test.com; Max-Age=31536000; Path=/; expires=Wed, 19-Apr-2023 00:26:55 GMT,wuuid=WUUID_TEST'
    });

    expect(response.cookies.length, 6);
    for (final cookie in response.cookies) {
      expect(
          cookie.name,
          anyOf([
            'AWSALB',
            'AWSALBCORS',
            'jwt_token',
            'csrf_token',
            'wuuid',
            'csrf_token'
          ]));
      expect(
          cookie.value,
          anyOf([
            'AWSALB_TEST',
            'AWSALBCORS_TEST',
            'JWT_TEST',
            'CSRF_TOKEN_TEST_1',
            'CSRF_TOKEN_TEST_2',
            'WUUID_TEST'
          ]));
    }
  });
}
