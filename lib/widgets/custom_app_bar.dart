import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackArrow;
  final List<Widget>? actions;
  final Widget? preferredSizeChild;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackArrow = false,
    this.actions,
    this.preferredSizeChild,
  });

  @override
  Widget build(BuildContext context) {
    // Accessing the theme to ensure 60-30-10 consistency

    return AppBar(
      // 30% Brand Color Usage (Text & Icons)
      title: Text(title),
      centerTitle: true,

      // 60% Background Usage
      elevation: 0,
      scrolledUnderElevation: 0,

      // Custom Back Button (10% Accent if needed, or standard theme color)
      leading: showBackArrow
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/'); // Fallback to home
                }
              },
            )
          : null, // If false, shows Drawer icon if Drawer exists, or nothing

      actions: actions,

      // Optional: Add a subtle bottom border to separate from content
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: preferredSizeChild ?? Container(height: 1.0),
      ),
      toolbarHeight: 60,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 20); // +1 for the bottom border
}
