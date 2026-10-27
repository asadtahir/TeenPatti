import 'dart:async';
import 'dart:io';

import 'app_failure.dart';

/// Converts any thrown object into an [AppFailure] safe to show users.
AppFailure mapError(Object error) {
  if (error is AppFailure) return error;
  if (error is TimeoutException) {
    return AppFailure(FailureKind.timeout, cause: error);
  }
  if (error is SocketException) {
    return AppFailure(FailureKind.noInternet, cause: error);
  }
  if (error is WebSocketException) {
    return AppFailure(FailureKind.connectionLost, cause: error);
  }
  return AppFailure(FailureKind.unknown, cause: error);
}
