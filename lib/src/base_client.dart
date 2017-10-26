// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:async/async.dart';

import 'client.dart';
import 'exception.dart';
import 'request.dart';
import 'response.dart';

/// The abstract base class for an HTTP client.
///
/// Subclasses only need to implement [send] and maybe [close], and then they
/// get various convenience methods for free.
abstract class BaseClient implements Client {
  Future<Response> head(url, {Map<String, String> headers}) =>
      send(new Request.head(url, headers: headers));

  Future<Response> get(url, {Map<String, String> headers}) =>
      send(new Request.get(url, headers: headers));

  Future<Response> post(url, body,
          {Map<String, String> headers, Encoding encoding}) =>
      send(new Request.post(url, body, headers: headers, encoding: encoding));

  Future<Response> put(url, body,
          {Map<String, String> headers, Encoding encoding}) =>
      send(new Request.put(url, body, headers: headers, encoding: encoding));

  Future<Response> patch(url, body,
          {Map<String, String> headers, Encoding encoding}) =>
      send(new Request.patch(url, body, headers: headers, encoding: encoding));

  Future<Response> delete(url, {Map<String, String> headers}) =>
      send(new Request.delete(url, headers: headers));

  Future<String> read(url, {Map<String, String> headers}) async {
    var response = await get(url, headers: headers);
    _checkResponseSuccess(url, response);

    return await response.readAsString();
  }

  Future<Uint8List> readBytes(url, {Map<String, String> headers}) async {
    var response = await get(url, headers: headers);
    _checkResponseSuccess(url, response);

    return await collectBytes(response.read());
  }

  Future<Response> send(Request request);

  /// Throws an error if [response] is not successful.
  void _checkResponseSuccess(url, Response response) {
    if (response.statusCode < 400) return;
    var message = "Request to $url failed with status ${response.statusCode}";
    if (response.reasonPhrase != null) {
      message = "$message: ${response.reasonPhrase}";
    }
    if (url is String) url = Uri.parse(url);
    throw new ClientException("$message.", url);
  }

  void close() {}
}
