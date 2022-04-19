// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:universal_io/io.dart';

import 'base_client.dart';
import 'base_request.dart';

/// The base class for HTTP responses.
///
/// Subclasses of [BaseResponse] are usually not constructed manually; instead,
/// they're returned by [BaseClient.send] or other HTTP client methods.
abstract class BaseResponse {
  /// The (frozen) request that triggered this response.
  final BaseRequest? request;

  /// The HTTP status code for this response.
  final int statusCode;

  /// The reason phrase associated with the status code.
  final String? reasonPhrase;

  /// The size of the response body, in bytes.
  ///
  /// If the size of the request is not known in advance, this is `null`.
  final int? contentLength;

  // TODO(nweiz): make this a HttpHeaders object.
  final Map<String, String> headers;

  /// The cookies parsed from [headers].
  final List<Cookie> cookies = [];

  final bool isRedirect;

  /// Whether the server requested that a persistent connection be maintained.
  final bool persistentConnection;

  /// The regex pattern to split the cookies in `set-cookie`.
  static final _regexSplitSetCookies = RegExp(',(?=[^ ])');

  BaseResponse(this.statusCode,
      {this.contentLength,
      this.request,
      this.headers = const {},
      this.isRedirect = false,
      this.persistentConnection = true,
      this.reasonPhrase}) {
    if (statusCode < 100) {
      throw ArgumentError('Invalid status code $statusCode.');
    } else if (contentLength != null && contentLength! < 0) {
      throw ArgumentError('Invalid content length $contentLength.');
    }

    final setCookie = _getSetCookie(headers);
    if (setCookie.isNotEmpty) {
      for (final cookie in setCookie.split(_regexSplitSetCookies)) {
        cookies.add(Cookie.fromSetCookieValue(cookie));
      }
    }
  }

  /// Returns the value of the `set-cookie` if the [headers] has,
  /// otherwise empty.
  static String _getSetCookie(final Map<String, dynamic> headers) {
    for (final key in headers.keys) {
      // Some systems return "set-cookie" for various cases.
      if (key.toLowerCase() == 'set-cookie') {
        return headers[key] as String;
      }
    }

    return '';
  }
}
