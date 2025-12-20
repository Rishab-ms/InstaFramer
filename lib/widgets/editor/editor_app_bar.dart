import 'package:flutter/material.dart';

import '../../screens/preferences_screen.dart';

/// App bar widget for the editor screen.
/// Simple constant app bar without BLoC dependencies.
class EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EditorAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Edit Photos'),
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
