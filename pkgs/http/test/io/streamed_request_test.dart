// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/src/progress.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  late Uri serverUrl;
  setUpAll(() async {
    serverUrl = await startServer();
  });

  group('contentLength', () {
    test('controls the Content-Length header', () async {
      var request = http.StreamedRequest('POST', serverUrl)
        ..contentLength = 10
        ..sink.add([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      unawaited(request.sink.close());
      var response = await request.send();
      expect(
          await utf8.decodeStream(response.stream),
          parse(
              containsPair('headers', containsPair('content-length', ['10']))));
    });

    test('defaults to sending no Content-Length', () async {
      var request = http.StreamedRequest('POST', serverUrl);
      request.sink.add([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      unawaited(request.sink.close());
      var response = await request.send();
      expect(await utf8.decodeStream(response.stream),
          parse(containsPair('headers', isNot(contains('content-length')))));
    });
  });

  // Regression test.
  test('.send() with a response with no content length', () async {
    var request =
        http.StreamedRequest('GET', serverUrl.resolve('/no-content-length'));
    unawaited(request.sink.close());
    var response = await request.send();
    expect(await utf8.decodeStream(response.stream), equals('body'));
  });

  test('sends a MultipartRequest with onUploadProgress', () async {
    var totalLoaded = 0;

    var loadedNotifications = <int>[];

    int? contentLength;

    final progress = HttpProgress((e) {
      loadedNotifications.add(e.transferred);
      totalLoaded = e.transferred;
      contentLength = e.total;
    });

    final request = http.MultipartRequest(
        'POST', serverUrl.resolve('/multipart'),
        uploadProgress: progress);

    request.files.add(http.MultipartFile.fromBytes(
        'file', List.generate(1500, (index) => 100)));

    var response = await (await request.send()).stream.bytesToString();

    expect(response, '1739');
    expect(contentLength, 1739);
    expect(totalLoaded, 1739);
    expect(loadedNotifications.length, 6);
    expect(loadedNotifications, [0, 74, 161, 1661, 1663, 1739]);
  });

  test('sends a Streamed Request with onUploadProgress', () async {
    print('this test took ~10 seconds to run');

    var i = 0;

    final progress = HttpProgress.withRecorder(
        recordDuration: const Duration(milliseconds: 1000), (e) {
      // print e to see the progress
      // expected an event every 500 ms with 1 kb.

      // first events are not reliable because of the average calculation
      // so we skip them
      // Also, the last event is not reliable because the stream is closed
      if (i > 5 && 15 > i) {
        // 2 kb/s +- %10
        expect(e.averageSpeed,
            allOf([greaterThan(2 * _kb - 200), lessThan(2 * _kb + 200)]));
      }
      i++;
    });

    final request = http.StreamedRequest('POST', serverUrl.resolve('/streamed'),
        uploadProgress: progress)
      ..contentLength = 20 * _kb;

    _generateStream(20).listen((event) {
      request.sink.add(event);
    }, onDone: () {
      unawaited(request.sink.close());
    });

    var response = await (await request.send()).stream.bytesToString();

    expect(i, greaterThan(0));
    expect(response, (_kb * 20).toString());
  }, timeout: const Timeout(Duration(seconds: 30)), skip: false);

  test('sends a Streamed Request with download', () async {
    print('this test took ~10 seconds to run');

    var i = 0;

    final progress = HttpProgress.withRecorder(
        recordDuration: const Duration(milliseconds: 2000), (e) {
      // print e to see the progress
      // expected an event every 500 ms with 8 kb.

      // first events are not reliable because of the average calculation
      // so we skip them
      // Also, the last event is not reliable because the stream is closed
      if (i > 5 && 15 > i) {
        // 16 kb/s +- %10
        expect(
            e.averageSpeed,
            allOf([
              greaterThan(16 * _kb - 1.6 * _kb),
              lessThan(16 * _kb + 1.6 * _kb)
            ]));
      }
      i++;
    });

    final request = http.Request('GET', serverUrl.resolve('/download'),
        downloadProgress: progress);

    var response = await (await request.send()).stream.bytesToString();

    expect(i, greaterThan(0));
    expect(response.length, 8 * _kb * 20);
  }, timeout: const Timeout(Duration(seconds: 30)));
}

const _kb = 1 << 10;

Stream<List<int>> _generateStream(int length) async* {
  var i = 0;
  while (i < length) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    yield List.generate(_kb, (index) => 0);
    i += 1;
  }

  return;
}
