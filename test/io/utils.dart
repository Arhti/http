// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:http/src/utils.dart';
import 'package:pedantic/pedantic.dart';
import 'package:test/test.dart';

export '../utils.dart';

/// The current server instance.
HttpServer? _httpServer;

/// The current https server instance
HttpServer? _httpsServer;

/// The URL for the current server instance.
Uri get httpServerUrl => Uri.parse('http://localhost:${_httpServer!.port}');

/// The URL for the current https server instance.
Uri get httpsServerUrl => Uri.parse('https://localhost:${_httpsServer!.port}');

/// Gets the `http´ or `https´ server url
///
/// [serverType] can be either `http´ or `https´
Uri getServerUrl(String serverType) {
  if (serverType == 'http') {
    return httpServerUrl;
  } else {
    return httpsServerUrl;
  }
}

/// Starts a new HTTP server.
Future<void> startServer() async {
  _httpServer = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      await handleRequest(request);
    });

  // build a secured server

  // load the self-signed(!) certificates which are valid for 'localhost'
  var securityContext = SecurityContext()
    ..useCertificateChain('./test/data/certificate/localhost.crt')
    ..usePrivateKey('./test/data/certificate/localhost.key');

  // Create the secured server object and serve
  _httpsServer = (await HttpServer.bindSecure('localhost', 0, securityContext))
    ..listen((request) async {
      await handleRequest(request, true);
    });
}

/// Stops the current HTTP server.
void stopServer() {
  if (_httpServer != null) {
    _httpServer!.close();
    _httpServer = null;
  }

  if (_httpsServer != null) {
    _httpsServer!.close();
    _httpsServer = null;
  }
}

/// simulates the action the mocked server should perform given a [request]
///
/// the general logic for secured and non-secured requests is the same
/// if you need to adjust the behaviour, usr [isHttps]
Future<void> handleRequest(HttpRequest request, [bool isHttps = false]) async {
  var path = request.uri.path;
  var response = request.response;

  if (path == '/error') {
    response
      ..statusCode = 400
      ..contentLength = 0;
    unawaited(response.close());
    return;
  }

  if (path == '/loop') {
    var n = int.parse(request.uri.query);
    response
      ..statusCode = 302
      ..headers
          .set('location', httpServerUrl.resolve('/loop?${n + 1}').toString())
      ..contentLength = 0;
    unawaited(response.close());
    return;
  }

  if (path == '/redirect') {
    response
      ..statusCode = 302
      ..headers.set('location', httpServerUrl.resolve('/').toString())
      ..contentLength = 0;
    unawaited(response.close());
    return;
  }

  if (path == '/no-content-length') {
    response
      ..statusCode = 200
      ..contentLength = -1
      ..write('body');
    unawaited(response.close());
    return;
  }

  var requestBodyBytes = await ByteStream(request).toBytes();
  var encodingName = request.uri.queryParameters['response-encoding'];
  var outputEncoding =
      encodingName == null ? ascii : requiredEncodingForCharset(encodingName);

  response.headers.contentType =
      ContentType('application', 'json', charset: outputEncoding.name);
  response.headers.set('single', 'value');

  dynamic requestBody;
  if (requestBodyBytes.isEmpty) {
    requestBody = null;
  } else if (request.headers.contentType?.charset != null) {
    var encoding =
        requiredEncodingForCharset(request.headers.contentType!.charset!);
    requestBody = encoding.decode(requestBodyBytes);
  } else {
    requestBody = requestBodyBytes;
  }

  var content = <String, dynamic>{
    'method': request.method,
    'path': request.uri.path,
    'headers': {}
  };
  if (requestBody != null) content['body'] = requestBody;
  request.headers.forEach((name, values) {
    // These headers are automatically generated by dart:io, so we don't
    // want to test them here.
    if (name == 'cookie' || name == 'host') return;

    content['headers'][name] = values;
  });

  var body = json.encode(content);
  response
    ..contentLength = body.length
    ..write(body);

  unawaited(response.close());
}

/// A matcher for functions that throw HttpException.
Matcher get throwsClientException =>
    throwsA(const TypeMatcher<ClientException>());

/// A matcher for functions that throw SocketException.
final Matcher throwsSocketException =
    throwsA(const TypeMatcher<SocketException>());

/// A matcher for functions that throw [HandshakeException].
final Matcher throwsHandshakeException =
    throwsA(const TypeMatcher<HandshakeException>());
