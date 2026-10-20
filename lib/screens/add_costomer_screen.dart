import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:for_shop/components/identity_confirmation.dart';
import 'package:for_shop/db/database_helper.dart';
import 'package:for_shop/models/customer.dart';
import 'package:hive/hive.dart';

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key, this.existing, this.customerKey});

  /// When set, the screen edits this customer instead of adding a new one.
  final Customer? existing;
  final Object? customerKey;

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final nameController = TextEditingController();
  final nicknameController = TextEditingController();
  final phoneController = TextEditingController();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final customer = widget.existing;

    if (customer == null) return;

    nameController.text = customer.name;
    nicknameController.text = customer.nickname ?? '';
    phoneController.text = customer.phone ?? '';
  }

  Future<void> saveCustomer() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لطفاً نام مشتری را وارد کنید',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final previous = widget.existing;

    if (previous != null) {
      // Changing a customer that is already in the ledger needs the same proof
      // of identity as deleting one.
      final confirmed = await ConfirmIdentityDialog.show(
        context,
        action: 'ویرایش',
        name: previous.name,
      );

      if (!confirmed || !mounted) return;
    }

    final customer = Customer(
      name: nameController.text.trim(),
      nickname: nicknameController.text.trim().isEmpty
          ? null
          : nicknameController.text.trim(),
      phone: phoneController.text.trim().isEmpty
          ? null
          : phoneController.text.trim(),
      createdAt: previous?.createdAt,
      // An edited row has to leave the device again, so it loses the flag that
      // said the old version was already uploaded.
      isSynced: false,
    );

    final box = Hive.box<Customer>(DatabaseHelper.customersBox);

    if (previous != null) {
      await box.put(widget.customerKey!, customer);
    } else {
      await box.add(customer);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    nicknameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: const Color(0xFF513680),
          iconTheme: const IconThemeData(color: Colors.white),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded, size: 25),
              onPressed: () => Navigator.pop(context),
            ),
          ],
          title: Text(
            _isEditing ? 'ویرایش مشتری' : 'افزودن مشتری',
            style: const TextStyle(
              fontSize: 26,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EFFF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        _isEditing
                            ? Icons.edit_rounded
                            : Icons.person_add_alt_1_rounded,
                        size: 38,
                        color: const Color(0xFF513680),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _isEditing ? 'ویرایش مشخصات' : 'اطلاعات مشتری جدید',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isEditing
                          ? 'نام، تخلص یا شماره تماس را تغییر دهید'
                          : 'اطلاعات مشتری را وارد کنید',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 28),
                    MyTextField(
                      controller: nameController,
                      textFieldLabel: 'نام مشتری',
                      textFieldIcon: Icons.person_outline_rounded,
                      iconColor: const Color(0xFF513680),
                      maxLength: 20,
                    ),
                    const SizedBox(height: 16),
                    MyTextField(
                      controller: nicknameController,
                      textFieldLabel: 'تخلص',
                      textFieldIcon: Icons.badge_outlined,
                      iconColor: const Color(0xFF513680),
                      maxLength: 20,
                    ),
                    const SizedBox(height: 16),
                    MyTextField(
                      controller: phoneController,
                      textFieldLabel: 'شماره تماس',
                      textFieldIcon: Icons.phone,
                      iconColor: const Color(0xFF513680),
                      isNumber: true,
                      suffixText: '93+ ',
                      maxLength: 9,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: saveCustomer,
                        label: Text(
                          _isEditing ? 'ذخیره تغییرات' : 'ذخیره مشتری',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        icon: const Icon(Icons.save_rounded),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF513680),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyTextField extends StatelessWidget {
  final String textFieldLabel;
  final IconData textFieldIcon;
  final Color iconColor;
  final TextEditingController controller;
  final int? maxLength;
  final bool isNumber;
  final String? suffixText;

  const MyTextField({
    super.key,
    required this.textFieldLabel,
    required this.textFieldIcon,
    required this.iconColor,
    required this.controller,
    this.maxLength,
    this.isNumber = false,
    this.suffixText,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
        inputFormatters: [
          if (isNumber) FilteringTextInputFormatter.digitsOnly,
          if (maxLength != null) LengthLimitingTextInputFormatter(maxLength!),
        ],
        decoration: InputDecoration(
          labelText: textFieldLabel,
          prefixIcon: Icon(textFieldIcon, color: iconColor),
          suffixText: suffixText,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF513680), width: 2),
          ),
        ),
      ),
    );
  }
}
