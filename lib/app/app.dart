import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class TeenPattiApp extends StatefulWidget {
  const TeenPattiApp({super.key});

  @override
  State<TeenPattiApp> createState() => _TeenPattiAppState();
}

class _TeenPattiAppState extends State<TeenPattiApp> {
  final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
