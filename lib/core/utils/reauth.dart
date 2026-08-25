import 'package:flutter/material.dart';

import '../network/supabase_client.dart';
import '../theme/app_colors.dart';

/// Prompts the signed-in owner to re-type their account password before a
/// destructive action (e.g. permanently deleting a tutor). Returns true only
/// if the password was verified against Supabase Auth.
Future<bool> confirmWithPassword(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) =>
        _PasswordConfirmDialog(title: title, message: message),
  );
  return result ?? false;
}

class _PasswordConfirmDialog extends StatefulWidget {
  const _PasswordConfirmDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  State<_PasswordConfirmDialog> createState() => _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState extends State<_PasswordConfirmDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = AppSupabase.client.auth.currentUser?.email;
    if (email == null || _controller.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppSupabase.client.auth.signInWithPassword(
        email: email,
        password: _controller.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      setState(() {
        _error = 'كلمة المرور غلط';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              contentPadding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: _loading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('تأكيد الحذف'),
        ),
      ],
    );
  }
}
