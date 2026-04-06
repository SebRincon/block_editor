import 'package:block_editor/block_editor.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'plugins/callout_with_author_block.dart';

void main() {
  BlockRegistry.instance.registerAll([CalloutWithAuthorBlock()]);
  runApp(const App());
}
