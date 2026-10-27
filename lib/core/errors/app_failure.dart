/// User-facing failure categories. Never expose raw exceptions to the UI.
enum FailureKind {
  noInternet,
  slowConnection,
  connectionLost,
  serverError,
  timeout,
  maintenance,
  invalidAction,
  unknown,
}

class AppFailure implements Exception {
  const AppFailure(this.kind, {this.cause});
  final FailureKind kind;
  final Object? cause;

  String get message => switch (kind) {
        FailureKind.noInternet => 'No internet connection.',
        FailureKind.slowConnection => 'Your connection is slow.',
        FailureKind.connectionLost =>
          'Connection lost.\n\nTrying to reconnect...',
        FailureKind.serverError =>
          'Something went wrong on our side. Please try again.',
        FailureKind.timeout =>
          'The request took too long. Please try again.',
        FailureKind.maintenance =>
          'The server is under maintenance. Please check back soon.',
        FailureKind.invalidAction => 'That move is not allowed right now.',
        FailureKind.unknown => 'Something went wrong. Please try again.',
      };
}
