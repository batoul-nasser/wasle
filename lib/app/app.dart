import 'package:flutter/material.dart';

import 'package:wasle/app/router.dart';
import 'package:wasle/core/app_theme.dart';

class WasleApp extends StatelessWidget {
  const WasleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WASLE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
