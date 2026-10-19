import 'package:flutter/material.dart';

import 'package:for_shop/components/auth_text_field.dart';
import 'package:for_shop/services/auth_service.dart';

/// Changing the account password. The old password is verified by the auth
/// provider itself, and nothing is ever kept on the device.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => const ChangePasswordDialog(),
    );

    return changed == true;
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _repeat = TextEditingController();

  bool _reveal = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label را وارد کنید.';

    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;

    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await AuthService.instance.changePassword(
      currentPassword: _current.text,
      newPassword: _next.text,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });

      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF3EFFF),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                color: Color(0xFF513680),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('تغییر رمز عبور', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'رمز عبور حساب خود را عوض کنید. تا زمانی که رمز جدید را '
                  'وارد نکرده‌اید، تغییری اعمال نمی‌شود.',
                  style: TextStyle(fontSize: 13, height: 1.8),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _current,
                  label: 'رمز عبور فعلی',
                  icon: Icons.lock_outline_rounded,
                  obscure: !_reveal,
                  validator: (value) => _required(value, 'رمز عبور فعلی'),
                  onToggleObscure: () => setState(() => _reveal = !_reveal),
                ),
                const SizedBox(height: 12),
                AuthTextField(
                  controller: _next,
                  label: 'رمز عبور جدید',
                  icon: Icons.lock_rounded,
                  obscure: !_reveal,
                  validator: (value) {
                    final empty = _required(value, 'رمز عبور جدید');

                    if (empty != null) return empty;

                    return value!.trim().length < 6
                        ? 'رمز عبور جدید باید حداقل ۶ نویسه باشد.'
                        : null;
                  },
                  onToggleObscure: () => setState(() => _reveal = !_reveal),
                ),
                const SizedBox(height: 12),
                AuthTextField(
                  controller: _repeat,
                  label: 'تکرار رمز عبور جدید',
                  icon: Icons.lock_person_rounded,
                  obscure: !_reveal,
                  validator: (value) {
                    final empty = _required(value, 'تکرار رمز عبور');

                    if (empty != null) return empty;

                    return value != _next.text
                        ? 'رمزهای عبور جدید با هم یکی نیستند.'
                        : null;
                  },
                  onToggleObscure: () => setState(() => _reveal = !_reveal),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFD32F2F),
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF513680),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text('تغییر رمز'),
          ),
        ],
      ),
    );
  }
}
