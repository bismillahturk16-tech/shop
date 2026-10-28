import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'package:for_shop/services/auth_service.dart';

class IdentityConfirmation extends StatefulWidget {
  const IdentityConfirmation({
    super.key,
    required this.action,
    required this.name,
    required this.onVerified,
    this.onBusyChanged,
    this.accent = const Color(0xFF513680),
  });

  final String action;

  final String name;

  final VoidCallback onVerified;
  final ValueChanged<bool>? onBusyChanged;
  final Color accent;

  @override
  State<IdentityConfirmation> createState() => IdentityConfirmationState();
}

class IdentityConfirmationState extends State<IdentityConfirmation> {
  final TextEditingController _passwordController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  String? _error;
  String? _biometricError;
  bool _busy = false;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();

    _checkBiometrics();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    var ready = false;

    try {
      ready =
          await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } on PlatformException {
      ready = false;
    }

    if (mounted) setState(() => _canUseBiometrics = ready);
  }

  void _setBusy(bool busy) {
    setState(() => _busy = busy);
    widget.onBusyChanged?.call(busy);
  }

  void _startAttempt() {
    _setBusy(true);
    setState(() {
      _error = null;
      _biometricError = null;
    });
  }

  Future<void> confirmWithPassword() async {
    if (_busy) return;

    _startAttempt();

    final error = await AuthService.instance.confirmPassword(
      _passwordController.text,
    );

    if (!mounted) return;

    if (error != null) {
      _setBusy(false);
      setState(() => _error = error);

      return;
    }

    widget.onVerified();
  }

  Future<void> _confirmWithBiometric() async {
    if (_busy) return;

    _startAttempt();

    var verified = false;
    var failed = false;

    try {
      verified = await _localAuth.authenticate(
        localizedReason:
            'برای ${widget.action} «${widget.name}» اثر انگشت خود را تایید کنید',
        biometricOnly: true,
      );
    } on PlatformException {
      failed = true;
    }

    if (!mounted) return;

    if (!verified) {
      _setBusy(false);
      setState(() {
        _biometricError = failed
            ? 'اثر انگشت روی این گوشی در دسترس نیست.'
            : 'تایید با اثر انگشت انجام نشد.';
      });

      return;
    }

    widget.onVerified();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _canUseBiometrics
              ? 'برای تایید ${widget.action}، رمز عبور خود را وارد کنید '
                    'یا اثر انگشت بگذارید.'
              : 'برای تایید ${widget.action}، رمز عبور حساب خود را وارد کنید.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF667781)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: true,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: 'رمز عبور',
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
        ),
        if (_canUseBiometrics) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _confirmWithBiometric,
            icon: const Icon(Icons.fingerprint_rounded, size: 26),
            label: Text('${widget.action} با اثر انگشت'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.accent,
              side: BorderSide(color: widget.accent.withValues(alpha: 0.35)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          if (_biometricError != null) ...[
            const SizedBox(height: 8),
            Text(
              _biometricError!,
              style: TextStyle(fontSize: 12.5, color: Colors.red.shade700),
            ),
          ],
        ],
      ],
    );
  }
}

class ConfirmIdentityDialog extends StatefulWidget {
  const ConfirmIdentityDialog({
    super.key,
    required this.action,
    required this.name,
  });

  final String action;
  final String name;

  static Future<bool> show(
    BuildContext context, {
    required String action,
    required String name,
  }) async {
    if (AuthService.instance.account == null) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmIdentityDialog(action: action, name: name),
    );

    return confirmed == true;
  }

  @override
  State<ConfirmIdentityDialog> createState() => _ConfirmIdentityDialogState();
}

class _ConfirmIdentityDialogState extends State<ConfirmIdentityDialog> {
  final GlobalKey<IdentityConfirmationState> _identity =
      GlobalKey<IdentityConfirmationState>();

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        scrollable: true,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFEDE7F6),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                color: Color(0xFF513680),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('تایید هویت')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'برای ${widget.action} مشخصات «${widget.name}» هویت خود را '
              'تایید کنید.',
              style: const TextStyle(fontSize: 15, height: 1.8),
            ),
            const SizedBox(height: 16),
            IdentityConfirmation(
              key: _identity,
              action: widget.action,
              name: widget.name,
              onBusyChanged: (busy) => setState(() => _busy = busy),
              onVerified: () => Navigator.pop(context, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: _busy
                ? null
                : () => _identity.currentState?.confirmWithPassword(),
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
                : const Text('تایید'),
          ),
        ],
      ),
    );
  }
}
