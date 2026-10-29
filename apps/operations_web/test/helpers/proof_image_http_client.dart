import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A real decoded PNG delivered through Flutter's debug network-image client.
class ProofImageHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _ImageRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _ImageResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  static final _bytes = base64Decode(
    // Flutter's 50x50 blue square PNG fixture (BSD-3-Clause).
    'iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAASElEQVR42u3PMQ0AMAgAsGFjL/4tYQU08JLWQSN/9TsgREREREREREREREREREREREREREREREREREREREREREREREREREQ2BgNuaUcSjuqqAAAAAElFTkSuQmCC',
  );

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
