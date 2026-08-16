import 'package:flutter/material.dart';

import 'core/theme/theme_data.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TA MUSIC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _PlaceholderHomeScreen(),
    );
  }
}

class _PlaceholderHomeScreen extends StatelessWidget {
  const _PlaceholderHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'TA MUSIC',
          style: Theme.of(context).textTheme.displayLarge,
        ),
      ),
    );
  }
}
