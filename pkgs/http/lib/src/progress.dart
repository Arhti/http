import 'dart:async';
import 'dart:math';

/// Http download or upload progress.
///
/// [HttpProgress.handler] gives the instances of [HttpProgressEvent]
/// for each progress change.
///
/// To handle progress changes, you can pass `downloadProgress` or
/// `uploadProgress` to http request. For example:
/// ```dart
///
/// http.post(
///   Uri.parse('https://example.com'),
///   downloadProgress: HttpProgress(print),
///   uploadProgress: HttpProgress.withRecorder(print),
///   body: 'Hello World',
/// )
///
/// ```
///
/// There are two types of [HttpProgressEvent]. The other one is
/// [HttpProgressEventWithRecorder]. It can be handled by passing
/// [HttpProgress.withRecorder] to http request.
///
/// [HttpProgressEventWithRecorder] has more information about progress like
/// average speed, last speed, estimated remaining time.
///
class HttpProgressEvent {
  /// Creates a new [HttpProgressEvent].
  const HttpProgressEvent._({
    required this.transferred,
    required this.total,
    required this.start,
  });

  /// Is the length computable. If the content length is known, this will be
  /// true.
  ///
  /// Check [lengthComputable] before using [progressRate].
  bool get lengthComputable => total != null;

  /// The time when the progress started.
  final DateTime start;

  /// The total bytes of the body.
  final int? total;

  /// The bytes transferred.
  final int transferred;

  /// The rate of the progress.
  double get progressRate {
    if (!lengthComputable) {
      throw StateError('Cannot calculate percent when total is not set.');
    }

    return transferred / total!;
  }

  /// The percent of the progress.
  ///
  /// [fractionDigits] is the number of digits after the decimal point.
  ///
  /// Default is 2.
  double percent([int fractionDigits = 2]) {
    if (!lengthComputable) {
      throw StateError('Cannot calculate percent when total is not set.');
    }

    assert(fractionDigits >= 0);

    final p = pow(10, fractionDigits);

    return ((progressRate * 100) * p).floor() / p;
  }

  /// The elapsed time since the progress started.
  Duration get elapsed => DateTime.now().difference(start);

  @override
  String toString() {
    if (lengthComputable) {
      return 'HttpProgressEvent{transferred: $transferred,'
          ' total: $total,'
          ' percent: ${percent(2)}}';
    }

    return 'HttpProgressEvent{lengtComputable: $lengthComputable,'
        ' transferred: $transferred}';
  }
}

/// The implementation of [HttpProgressEvent] with recorder.
///
/// It has records the progress for given duration to
/// [HttpProgress.withRecorder]. By recording the progress, you can get more
/// information about the progress like average speed, last speed, estimated
/// remaining time.
class HttpProgressEventWithRecorder extends HttpProgressEvent {
  const HttpProgressEventWithRecorder._(
      {required super.start,
      required super.total,
      required super.transferred,
      required this.records})
      : super._();

  /// The records of the progress. $1 is the transferred bytes, $2 is the time.
  final List<(int, DateTime)> records;

  // bytes per millisecond. Average of all records.
  double get _bytesPerMilliseconds {
    // prevents argument error
    if (records.isEmpty) {
      return 0;
    }

    var i = 0;
    var sum = 0;
    while (i < records.length - 1) {
      sum += records[i].$1;
      i++;
    }

    // prevents integer division by zero
    if (records.length == 1) {
      if (records.first.$1 == 0) return 0;

      return records.first.$1 /
          records.first.$2.difference(start).inMilliseconds;
    }

    return sum / records.last.$2.difference(records.first.$2).inMilliseconds;
  }

  /// The average speed of the progress. Bytes per second.
  double get averageSpeed => _bytesPerMilliseconds * 1000;

  /// The last speed of the progress. Bytes per second.
  double get lastSpeed {
    if (records.isEmpty) {
      return 0;
    }

    if (records.length == 1) {
      return records.first.$1 /
          records.first.$2.difference(start).inMilliseconds;
    }

    return records.last.$1 /
        records.last.$2
            .difference(records[records.length - 2].$2)
            .inMilliseconds;
  }

  /// The estimated remaining time of the progress. Calculated by average speed.
  Duration get estimatedRemaining {
    // prevents argument error
    if (records.isEmpty) {
      return Duration.zero;
    }

    if (total == null) {
      return Duration.zero;
    }

    var speed = _bytesPerMilliseconds;

    // prevents integer division by zero
    if (speed == 0) {
      return Duration.zero;
    }

    var remaining = total! - transferred;

    return Duration(
      milliseconds: (remaining / speed).round(),
    );
  }

  @override
  String toString() {
    if (lengthComputable) {
      return 'HttpProgressEventWithRecorder{transferred: $transferred,'
          ' total: $total,'
          ' percent: ${percent(2)},'
          ' speed: $averageSpeed,'
          ' estimatedRemaining: $estimatedRemaining}';
    }

    return 'HttpProgressEventWithRecorder{lengthComputable: $lengthComputable,'
        ' transferred: $transferred,'
        ' speed: $averageSpeed}';
  }
}

/// The handler of [HttpProgressEvent].
typedef HttpProgressHandler = void Function(HttpProgressEvent event);

/// The handler of [HttpProgressEventWithRecorder].
typedef HttpProgressHandlerWithRecords = void Function(
    HttpProgressEventWithRecorder event);

/// The base class of [HttpProgress] and [HttpProgressWithRecorder].
///
/// You can use [HttpProgress] or [HttpProgress.withRecorder] to create.
///
/// [HttpProgress] is the basic implementation of [HttpProgress].
///
/// [HttpProgress.withRecorder] is the implementation of [HttpProgress] with
/// recorder. It records the progress for given duration. By recording the
/// progress, you can get more information about the progress like average
/// speed, last speed, estimated remaining time.
abstract class HttpProgress {
  HttpProgress._(this.handler);

  factory HttpProgress(
    HttpProgressHandler handler, {
    bool withRecorder = false,
    Duration recordDuration = const Duration(seconds: 5),
  }) {
    if (withRecorder) {
      return HttpProgressWithRecorder._(handler, recordDuration);
    } else {
      return BasicHttpProgress._(handler);
    }
  }

  /// Creates a new [HttpProgress] with recorder.
  ///
  /// [recordDuration] is the duration of the records. The records will be
  /// removed after the duration.
  ///
  /// [handler] is the handler of [HttpProgressEventWithRecorder].
  ///
  static HttpProgressWithRecorder withRecorder(
          HttpProgressHandlerWithRecords handler,
          {Duration recordDuration = const Duration(seconds: 5)}) =>
      HttpProgressWithRecorder._(handler, recordDuration);

  /// The handler of [HttpProgressEvent].
  final Function handler;

  int? _total;

  set _current(int value);

  int _transferred = 0;

  late DateTime _start;

  HttpProgressEvent _getEvent() => HttpProgressEvent._(
        start: _start,
        total: _total,
        transferred: _transferred,
      );
}

/// The implementation of [HttpProgress] with recorder.
///
///
class HttpProgressWithRecorder extends HttpProgress {
  HttpProgressWithRecorder._(super.handler, this._recordDuration) : super._();

  final Duration _recordDuration;

  final List<(int transferred, DateTime date)> _records = [];

  @override
  set _current(int value) {
    _transferred += value;

    final now = DateTime.now();

    _records.add(
      (
        value,
        now,
      ),
    );

    while (true) {
      if (_records.isEmpty) {
        break;
      }

      if (now.difference(_records.first.$2) > _recordDuration) {
        _records.removeAt(0);
      } else {
        break;
      }
    }
  }

  @override
  HttpProgressEventWithRecorder _getEvent() => HttpProgressEventWithRecorder._(
        start: _start,
        total: _total,
        transferred: _transferred,
        records: _records,
      );
}

/// The basic implementation of [HttpProgress].
///
class BasicHttpProgress extends HttpProgress {
  BasicHttpProgress._(super.handler) : super._();

  @override
  set _current(int value) {
    _transferred += value;
  }
}

/// Sets the total bytes of the body.
void setLength(HttpProgress progress, int? length) {
  progress
    .._total = length
    .._start = DateTime.now()
    ..handler(progress._getEvent());
}

/// Adds the transferred bytes.
void addTransfer(HttpProgress progress, int transferred) {
  progress
    .._current = transferred
    ..handler(progress._getEvent());
}

/// Sets the transferred bytes. For browser.
void setTransferred(HttpProgress progress, int transferred) {
  progress
    .._current = transferred - progress._transferred
    ..handler(progress._getEvent());
}

/// Get the [StreamTransformer] for progress.
StreamTransformer<List<int>, List<int>> getProgressTransformer(
        HttpProgress progress) =>
    StreamTransformer.fromBind((e) async* {
      await for (var bytes in e) {
        addTransfer(progress, bytes.length);
        yield bytes;
      }
    });
