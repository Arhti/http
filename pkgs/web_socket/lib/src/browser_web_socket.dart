import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import '../web_socket.dart';
import 'utils.dart';

class BrowserWebSocket implements WebSocket {
  final web.WebSocket _webSocket;
  final _events = StreamController<WebSocketEvent>();

  static Future<BrowserWebSocket> connect(Uri url) async {
    final socket = web.WebSocket(url.toString())..binaryType = 'arraybuffer';
    final htmlSocket = BrowserWebSocket._(socket);
    final readyCompleter = Completer<BrowserWebSocket>();

    if (socket.readyState == web.WebSocket.OPEN) {
      readyCompleter.complete();
    } else {
      if (socket.readyState == web.WebSocket.CLOSING ||
          socket.readyState == web.WebSocket.CLOSED) {
        readyCompleter.completeError(
            WebSocketException('WebSocket state error: ${socket.readyState}'));
      } else {
        // The socket API guarantees that only a single open event will be
        // emitted.
        socket.onOpen.first.then((_) {
          readyCompleter.complete(htmlSocket);
        });
      }
    }

    socket.onError.first.then((e) {
      print('I GOT A REAL ERROR!: $e');
      // Unfortunately, the underlying WebSocket API doesn't expose any
      // specific information about the error itself.
      final error = WebSocketException('WebSocket connection failed.');
      if (!readyCompleter.isCompleted) {
        readyCompleter.completeError(error);
      } else {
        htmlSocket._closed(1006, 'error');
      }
    });

    socket.onMessage.listen((e) {
      final eventData = e.data!;
      late WebSocketEvent data;
      if (eventData.typeofEquals('string')) {
        data = TextDataReceived((eventData as JSString).toDart);
      } else if (eventData.typeofEquals('object') &&
          (eventData as JSObject).instanceOfString('ArrayBuffer')) {
        data = BinaryDataReceived(
            (eventData as JSArrayBuffer).toDart.asUint8List());
      } else {
        throw Exception('test');
      }
      htmlSocket._events.add(data);
    });

    socket.onClose.first.then((event) {
      if (!readyCompleter.isCompleted) {
        readyCompleter.complete(htmlSocket);
      }

      htmlSocket._closed(event.code, event.reason);
    });

    return readyCompleter.future;
  }

  void _closed(int? code, String? reason) {
    print('closing with $code, $reason');
    if (!_events.isClosed) {
      _events
        ..add(CloseReceived(code, reason ?? ''))
        ..close();
    }
  }

  BrowserWebSocket._(this._webSocket);

  @override
  void sendBytes(Uint8List b) {
    if (_events.isClosed) {
      throw StateError('WebSocket is closed');
    }
    // Silently discards the data if the connection is closed.
    _webSocket.send(b.jsify()!);
  }

  @override
  void sendText(String s) {
    if (_events.isClosed) {
      throw StateError('WebSocket is closed');
    }
    // Silently discards the data if the connection is closed.
    _webSocket.send(s.jsify()!);
  }

  /// Closes the stream.
  /// https://datatracker.ietf.org/doc/html/rfc6455#section-5.5.1
  /// Cannot send more data after this.

  //  If an endpoint receives a Close frame and did not previously send a
  //  Close frame, the endpoint MUST send a Close frame in response.  (When
  //  sending a Close frame in response, the endpoint typically echos the
  //  status code it received.)  It SHOULD do so as soon as practical.  An
  //  endpoint MAY delay sending a Close frame until its current message is
  //  sent (for instance, if the majority of a fragmented message is
  //  already sent, an endpoint MAY send the remaining fragments before
  //  sending a Close frame).  However, there is no guarantee that the
  //  endpoint that has already sent a Close frame will continue to process
  //  data.
  @override
  Future<void> close([int? code, String? reason]) async {
    if (_events.isClosed) {
      throw StateError('WebSocket is closed');
    }

    checkCode(code);
    checkReason(reason);

    unawaited(_events.close());
    if ((code, reason) case (final closeCode?, final closeReason?)) {
      _webSocket.close(closeCode, closeReason);
    } else if (code case final closeCode?) {
      _webSocket.close(closeCode);
    } else {
      _webSocket.close();
    }
  }

  @override
  Stream<WebSocketEvent> get events => _events.stream;
}
