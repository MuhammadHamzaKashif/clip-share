import 'package:flutter/material.dart';

import 'platform/config_store.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

void main() {
  runApp(const ClipShareApp());
}

class ClipShareApp extends StatelessWidget {
  const ClipShareApp({super.key, this.store});

  final ConfigStore? store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClipShare',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: HomeScreen(store: store),
    );
  }
}
