import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'sse_event.dart';

/// Configuration for SSE client.
class SSEClientConfig {
  const SSEClientConfig({
    this.receiveTimeout = const Duration(seconds: 30),
    this.maxReconnectAttempts = 3,
    this.reconnectDelay = const Duration(seconds: 1),
  });

  /// Timeout for receiving events (no events for this duration = timeout).
  final Duration receiveTimeout;

  /// Maximum number of reconnection attempts.
  final int maxReconnectAttempts;

  /// Base delay between reconnection attempts (exponential backoff).
  final Duration reconnectDelay;
}

/// Client for handling Server-Sent Events (SSE) connections.
///
/// Used for streaming AI responses with progressive field updates.
/// Supports automatic reconnection with exponential backoff.
class SSEClient {
  SSEClient({Dio? dio, SSEClientConfig config = const SSEClientConfig()})
    : _dio = dio ?? Dio(),
      _config = config;
  final Dio _dio;
  final SSEClientConfig _config;

  CancelToken? _cancelToken;
  bool _isClosed = false;

  /// Whether the client is currently closed.
  bool get isClosed => _isClosed;

  /// Connects to an SSE endpoint and returns a stream of events.
  ///
  /// [url] - The SSE endpoint URL
  /// [headers] - Optional headers to include in the request
  /// [body] - Optional request body for POST requests
  /// [method] - HTTP method (default: POST for AI chat)
  Stream<SSEEvent> connect(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    String method = 'POST',
  }) async* {
    _isClosed = false;
    _cancelToken = CancelToken();

    var reconnectAttempts = 0;
    Timer? timeoutTimer;

    try {
      while (!_isClosed && reconnectAttempts <= _config.maxReconnectAttempts) {
        try {
          final response = await _dio.request<ResponseBody>(
            url,
            data: body,
            cancelToken: _cancelToken,
            options: Options(
              method: method,
              headers: {
                'Accept': 'text/event-stream',
                'Cache-Control': 'no-cache',
                ...?headers,
              },
              responseType: ResponseType.stream,
            ),
          );

          final stream = response.data?.stream;
          if (stream == null) {
            yield const SSEErrorEvent(message: 'No response stream available');
            return;
          }

          // Reset reconnect attempts on successful connection
          reconnectAttempts = 0;

          // Buffer for incomplete events
          var buffer = '';

          await for (final chunk in stream) {
            if (_isClosed) break;

            // Reset timeout timer on each chunk
            timeoutTimer?.cancel();
            timeoutTimer = Timer(_config.receiveTimeout, () {
              if (!_isClosed) {
                _cancelToken!.cancel('Receive timeout');
              }
            });

            // Decode chunk and add to buffer
            final chunkStr = utf8.decode(chunk);
            buffer += chunkStr;

            // Process complete events (separated by double newlines)
            while (buffer.contains('\n\n')) {
              final eventEnd = buffer.indexOf('\n\n');
              final eventStr = buffer.substring(0, eventEnd);
              buffer = buffer.substring(eventEnd + 2);

              final event = SSEEvent.parse(eventStr);
              if (event != null) {
                yield event;

                // If we received a done or error event, we're finished
                if (event is SSEDoneEvent || event is SSEErrorEvent) {
                  timeoutTimer.cancel();
                  return;
                }
              }
            }
          }

          // Process any remaining buffer content
          if (buffer.trim().isNotEmpty) {
            final event = SSEEvent.parse(buffer);
            if (event != null) {
              yield event;
            }
          }

          // Stream completed normally
          timeoutTimer?.cancel();
          return;
        } on DioException catch (e) {
          timeoutTimer?.cancel();

          if (_isClosed || e.type == DioExceptionType.cancel) {
            // Intentionally closed, don't reconnect
            return;
          }

          reconnectAttempts++;

          if (reconnectAttempts > _config.maxReconnectAttempts) {
            yield SSEErrorEvent(
              message:
                  'Connection failed after $reconnectAttempts attempts: ${e.message}',
            );
            return;
          }

          // Exponential backoff before reconnecting
          final delay = _config.reconnectDelay * reconnectAttempts;
          await Future<void>.delayed(delay);

          // Create new cancel token for retry
          _cancelToken = CancelToken();
        }
      }
    } finally {
      timeoutTimer?.cancel();
    }
  }

  /// Closes the current SSE connection.
  void close() {
    _isClosed = true;
    _cancelToken?.cancel('Client closed');
    _cancelToken = null;
  }

  /// Disposes of the client and releases resources.
  void dispose() {
    close();
  }
}
