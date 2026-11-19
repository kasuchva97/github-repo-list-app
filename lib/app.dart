import 'package:flutter/material.dart';

import 'features/home/home_shell.dart';

class GitHubRepoListApp extends StatelessWidget {
  const GitHubRepoListApp({super.key});

  static const _seed = Color(0xFF24292F); // GitHub's dark grey.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub Repositories',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _seed)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeShell(),
    );
  }
}
