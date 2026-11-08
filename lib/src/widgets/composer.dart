import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../validators.dart';

/// The message field. Its keyboard follows the question (`phone` opens the
/// phone pad, `email` the email keyboard, `date` a date picker). A quick
/// local check shows a hint before sending; the server validates again.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.strings,
    required this.onSend,
    this.inputKind = InputKind.text,
    this.placeholder,
    this.enabled = true,
    this.validate = true,
  });

  final RaselnaStrings strings;
  final ValueChanged<String> onSend;
  final InputKind inputKind;
  final String? placeholder;
  final bool enabled;

  /// Check the answer against [inputKind] before sending.
  final bool validate;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      if (_error != null) setState(() => _error = null);
    });
  }

  @override
  void didUpdateWidget(Composer old) {
    super.didUpdateWidget(old);
    if (old.inputKind != widget.inputKind) {
      _error = null;
      // The keyboard type changed: re-open it with the right layout.
      if (_focus.hasFocus) {
        _focus.unfocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.enabled) _focus.requestFocus();
        });
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!widget.enabled) return;
    final raw = _text.text;
    if (raw.trim().isEmpty) return;
    if (widget.validate) {
      final error = validateAnswer(widget.inputKind, raw, widget.strings);
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }
    widget.onSend(answerText(widget.inputKind, raw));
    _text.clear();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year + 5),
      helpText: widget.strings.pickDate,
    );
    if (picked == null) return;
    _text.text =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    _submit();
  }

  TextInputType get _keyboard => switch (widget.inputKind) {
    InputKind.number => const TextInputType.numberWithOptions(decimal: true),
    InputKind.phone => TextInputType.phone,
    InputKind.email => TextInputType.emailAddress,
    InputKind.date => TextInputType.datetime,
    _ => TextInputType.multiline,
  };

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final s = widget.strings;
    final ltrValue =
        widget.inputKind == InputKind.phone ||
        widget.inputKind == InputKind.email ||
        widget.inputKind == InputKind.number;
    final isDate = widget.inputKind == InputKind.date;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 6),
            child: Semantics(
              liveRegion: true,
              child: Text(_error!, style: c.style(size: 13, color: c.danger)),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _error != null ? c.danger : c.border,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: AlignmentDirectional.centerStart,
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  readOnly: isDate,
                  onTap: isDate ? _pickDate : null,
                  keyboardType: _keyboard,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  minLines: 1,
                  maxLines: widget.inputKind == InputKind.text ? 5 : 1,
                  maxLength: 1000,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  autocorrect: widget.inputKind == InputKind.text,
                  enableSuggestions: widget.inputKind == InputKind.text,
                  textDirection: ltrValue ? TextDirection.ltr : null,
                  textAlign: ltrValue ? TextAlign.end : TextAlign.start,
                  autofillHints: switch (widget.inputKind) {
                    InputKind.phone => const [AutofillHints.telephoneNumber],
                    InputKind.email => const [AutofillHints.email],
                    _ => null,
                  },
                  cursorColor: c.accent,
                  style: c.style(size: 16, height: 1.4),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    hintText: widget.placeholder ?? s.placeholder,
                    hintTextDirection: Directionality.of(context),
                    hintStyle: c.style(
                      size: 16,
                      color: c.mutedText,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: s.send,
              child: Material(
                color: widget.enabled ? c.primary : c.border,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.enabled ? (isDate ? _pickDate : _submit) : null,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      isDate
                          ? Icons.calendar_month_outlined
                          : Icons.send_rounded,
                      color: widget.enabled ? c.onPrimary : c.mutedText,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
