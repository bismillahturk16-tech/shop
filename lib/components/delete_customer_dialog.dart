import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'package:for_shop/components/identity_confirmation.dart';
import 'package:for_shop/db/database_helper.dart';
import 'package:for_shop/models/customer.dart';
import 'package:for_shop/services/auth_service.dart';

/// Deleting a customer is the one irreversible action in the ledger, so the
/// warning and the proof of identity live in the same dialog.
class DeleteCustomerDialog extends StatefulWidget {
  const DeleteCustomerDialog({
    super.key,
    required this.customer,
    required this.customerKey,
  });

  final Customer customer;

  /// The Hive key of [customer]: rows are not comparable, so the delete has to
  /// be told which one it is about.
  final Object customerKey;

  static Future<bool> show(
    BuildContext context,
    Customer customer,
    Object customerKey,
  ) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (context) =>
          DeleteCustomerDialog(customer: customer, customerKey: customerKey),
    );

    return deleted == true;
  }

  @override
  State<DeleteCustomerDialog> createState() => _DeleteCustomerDialogState();
}

class _DeleteCustomerDialogState extends State<DeleteCustomerDialog> {
  final GlobalKey<IdentityConfirmationState> _identity =
      GlobalKey<IdentityConfirmationState>();

  bool _busy = false;

  bool get _needsIdentity => AuthService.instance.account != null;

  Future<void> _removeCustomer() async {
    final key = widget.customerKey;

    await _deleteChildRows(DatabaseHelper.loans, key);
    await _deleteChildRows(DatabaseHelper.payments, key);

    await DatabaseHelper.markDeleted(DatabaseHelper.customersBox, key);
    await DatabaseHelper.customers.delete(key);

    if (mounted) Navigator.pop(context, true);
  }

  /// The dialog promises to remove the customer with its loans and payments,
  /// and the cloud delete only stays consistent if those rows are tombstoned
  /// too.
  Future<void> _deleteChildRows<T>(Box<T> box, Object customerKey) async {
    final keys = box
        .toMap()
        .entries
        .where((entry) => (entry.value as dynamic).customerKey == customerKey)
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
        // The keyboard plus the fingerprint button is taller than the dialog
        // on small screens, so the body has to scroll.
        scrollable: true,
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
            if (_needsIdentity) ...[
              const SizedBox(height: 16),
              IdentityConfirmation(
                key: _identity,
                action: 'حذف',
                name: name,
                accent: Colors.red.shade700,
                onBusyChanged: (busy) => setState(() => _busy = busy),
                onVerified: _removeCustomer,
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
            // With no account the button deletes straight away, which is what
            // the guest ledger on an unconfigured phone has always done.
            onPressed: _busy
                ? null
                : _needsIdentity
                ? () => _identity.currentState?.confirmWithPassword()
                : _removeCustomer,
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
