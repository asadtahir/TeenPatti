import 'dart:io';

import 'package:teen_patti_server/server.dart';

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final host = Platform.environment['HOST'] ?? '0.0.0.0';
  final server = await TeenPattiServer.start(port: port, host: host);
  stdout.writeln('Teen Patti server listening on $host:${server.port}');
}
