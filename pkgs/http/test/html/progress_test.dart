// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:test/test.dart';

/// To test this file, run pkgs/mock_server/bin/main.dart
/// and then run this test file with `dart run -p chrome test/html/progress_test.dart`.
final baseUri = Uri.parse('http://localhost:8080');

void main() {
  test('ping test', () async {
    var response = await http.get(baseUri.resolve('/ping'));

    expect(response.statusCode, equals(200));
  }, skip: true);

  test('sends a MultipartRequest with onUploadProgress', () async {
    var totalLoaded = 0;

    var loadedNotifications = <int>[];

    int? contentLength;

    final progress = HttpProgress((e) {
      loadedNotifications.add(e.transferred);
      totalLoaded = e.transferred;
      contentLength = e.total;
    });

    final request = http.MultipartRequest('POST', baseUri.resolve('/multipart'),
        uploadProgress: progress);

    request.files.add(http.MultipartFile.fromBytes(
        'file', List.generate(1500, (index) => 100)));
    var response = await (await request.send()).stream.bytesToString();

    expect(response, '1739');
    expect(contentLength, 1739);
    expect(totalLoaded, 1739);
    expect(loadedNotifications.length, 6);
    expect(loadedNotifications, [0, 74, 161, 1661, 1663, 1739]);
  }, skip: true);

  test('sends a Streamed Request with onUploadProgress', () async {
    final progress = HttpProgress.withRecorder(
      print,
      recordDuration: const Duration(milliseconds: 1000),
    );

    final request = http.StreamedRequest('POST', baseUri.resolve('/streamed'),
        uploadProgress: progress)
      ..contentLength = _kb * 1024 * 20
      ..headers['content-type'] = 'application/octet-stream';

    request.sink.add(List.generate(_kb * 1024 * 20, (index) => 0));
    unawaited(request.sink.close());
    var response = await (await request.send()).stream.bytesToString();

    expect(response, (_kb * 1024 * 20).toString());
  }, timeout: const Timeout(Duration(seconds: 100)), skip: false);

  test('sends a Streamed Request with download', () async {
    final progress = HttpProgress.withRecorder(
        recordDuration: const Duration(milliseconds: 2000), print);

    final request = http.Request('GET', baseUri.resolve('/download'),
        downloadProgress: progress);

    var response = await (await request.send()).stream.bytesToString();

    expect(response.length, 8 * _kb * 20);
  }, timeout: const Timeout(Duration(seconds: 100)));
}

const _kb = 1 << 10;
