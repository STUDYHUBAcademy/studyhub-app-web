import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '💬 الشات',
      icon: Icons.forum_rounded,
    );
  }
}
