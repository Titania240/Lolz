import 'package:flutter/material.dart';
import '../widgets/meme_editor.dart';

class MemeEditorScreen extends StatelessWidget {
  const MemeEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: MemeEditor(),
    );
  }
}
