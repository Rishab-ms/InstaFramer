import 'package:flutter/material.dart';

import '../../screens/preferences_screen.dart';

/// App bar widget for the editor screen.
/// Simple constant app bar without BLoC dependencies.
class EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const EditorAppBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        // App preferences/settings navigation
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PreferencesScreen(),
              ),
            );
          },
          tooltip: 'Settings',
        ),
      ],
    );
  }
}
