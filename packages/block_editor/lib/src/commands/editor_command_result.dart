library;

import 'package:meta/meta.dart';

/// The result of executing an editor command.
@immutable
final class EditorCommandResult {
  const EditorCommandResult._({
    required this.handled,
    required this.shouldRunPostCommand,
  });

  /// Creates a result for a command that handled the request.
  const EditorCommandResult.handled({bool shouldRunPostCommand = true})
    : this._(handled: true, shouldRunPostCommand: shouldRunPostCommand);

  /// Creates a result for a command that did not handle the request.
  const EditorCommandResult.ignored()
    : this._(handled: false, shouldRunPostCommand: false);

  /// Whether the command consumed the request.
  final bool handled;

  /// Whether the caller should run common post-command hooks.
  final bool shouldRunPostCommand;
}
