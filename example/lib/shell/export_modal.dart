import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A modal bottom sheet that displays exported document content.
///
/// Shows [content] in a scrollable monospace code block. A copy-to-clipboard
/// button sits in the header row beside [title]. Used for both JSON and
/// Markdown export without modification.
class ExportModal extends StatefulWidget {
  /// Creates an [ExportModal].
  const ExportModal({super.key, required this.title, required this.content});

  final String title;
  final String content;

  /// Opens the modal as a bottom sheet above [context].
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      builder: (_) => ExportModal(title: title, content: content),
    );
  }

  @override
  State<ExportModal> createState() => _ExportModalState();
}

class _ExportModalState extends State<ExportModal> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.75,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ModalHandle(colors: colors),
          _ModalHeader(
            title: widget.title,
            copied: _copied,
            onCopy: _copy,
            colors: colors,
          ),
          Divider(height: 1, color: colors.border),
          Expanded(
            child: _ContentArea(content: widget.content, colors: colors),
          ),
        ],
      ),
    );
  }
}

class _ModalHandle extends StatelessWidget {
  const _ModalHandle({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: colors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  const _ModalHeader({
    required this.title,
    required this.copied,
    required this.onCopy,
    required this.colors,
  });

  final String title;
  final bool copied;
  final VoidCallback onCopy;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          _CopyButton(copied: copied, onCopy: onCopy, colors: colors),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.copied,
    required this.onCopy,
    required this.colors,
  });

  final bool copied;
  final VoidCallback onCopy;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: copied
            ? const Color(0xFF22C55E).withValues(alpha: 0.12)
            : colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: copied ? const Color(0xFF22C55E) : colors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onCopy,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  copied ? Icons.check : Icons.copy_outlined,
                  size: 15,
                  color: copied ? const Color(0xFF22C55E) : colors.textMuted,
                ),
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: copied ? const Color(0xFF22C55E) : colors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  child: Text(copied ? 'Copied' : 'Copy'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentArea extends StatefulWidget {
  const _ContentArea({required this.content, required this.colors});

  final String content;
  final AppColors colors;

  @override
  State<_ContentArea> createState() => _ContentAreaState();
}

class _ContentAreaState extends State<_ContentArea> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          widget.content,
          style: TextStyle(
            color: widget.colors.text,
            fontSize: 13,
            fontFamily: 'monospace',
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
