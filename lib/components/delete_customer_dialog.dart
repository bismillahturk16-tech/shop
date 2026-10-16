import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'package:for_shop/db/database_helper.dart';
import 'package:for_shop/models/customer.dart';
import 'package:for_shop/services/auth_service.dart';

/// Deleting a customer is the one irreversible action in the ledger, so the
/// warning and the account password live in the same dialog.
class DeleteCustomerDialog extends StatefulWidget {
  const DeleteCustomerDialog({super.key, required this.customer});

  final Customer customer;

  static Future<bool> show(BuildContext context, Customer customer) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteCustomerDialog(customer: customer),
    );

    return deleted == true;
  }

  @override
  State<DeleteCustomerDialog> createState() => _DeleteCustomerDialogState();
}

class _DeleteCustomerDialogState extends State<DeleteCustomerDialog> {
  final TextEditingController _passwordController = TextEditingController();

  String? _error;
  bool _busy = false;

  bool get _needsPassword => AuthService.instance.account != null;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    String? error;

    if (_needsPassword) {
      error = await AuthService.instance.confirmPassword(
        _passwordController.text,
      );
    }

    if (error != null) {
      if (!mounted) return;

      setState(() {
        _busy = false;
        _error = error;
      });

      return;
    }

    final box = Hive.box<Customer>(DatabaseHelper.customersBox);
    final key = box.keys.firstWhere((key) => box.get(key) == widget.customer);

    await _deleteChildRows(DatabaseHelper.loans, key);
    await _deleteChildRows(DatabaseHelper.payments, key);

    await DatabaseHelper.markDeleted(DatabaseHelper.customersBox, key);
    await box.delete(key);

    if (mounted) Navigator.pop(context, true);
  }

  /// The dialog promises to remove the customer with its loans and payments,
  /// and the cloud delete only stays consistent if those rows are tombstoned
  /// too.
  Future<void> _deleteChildRows<T>(Box<T> box, Object customerKey) async {
    final keys = box
        .toMap()
        .entries
        .where(
          (entry) => (entry.value as dynamic).customerKey == customerKey,
        )
        .map((entry) => entry.key)
        .toList();

    for (final key in keys) {
      await DatabaseHelper.markDeleted(box.name, key);
      await box.delete(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.customer.name;

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
                color: Colors.red.shade50,
              ),
              child: Icon(Icons.delete_outline, color: Colors.red.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('حذف مشتری', overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '«$name» با همه قرضه‌ها و پرداخت‌هایش حذف می‌شود. '
              'این کار قابل بازگشت نیست.',
              style: const TextStyle(fontSize: 15, height: 1.8),
            ),
            if (_needsPassword) ...[
              const SizedBox(height: 16),
              const Text(
                'برای تایید، رمز عبور حساب خود را وارد کنید.',
                style: TextStyle(fontSize: 13, color: Color(0xFF667781)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                enabled: !_busy,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'رمز عبور',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: _busy ? null : _delete,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
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
                : const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
