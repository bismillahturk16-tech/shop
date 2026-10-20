import 'package:flutter/material.dart';
import 'package:for_shop/db/database_helper.dart';
import 'package:for_shop/models/customer.dart';
import 'package:for_shop/models/payment.dart';
import 'package:for_shop/models/loan.dart';
import 'package:for_shop/screens/add_loan_screen.dart';
import 'package:for_shop/screens/loan_details_screen.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;
  final int customerKey;

  const CustomerDetailsScreen({
    super.key,
    required this.customer,
    required this.customerKey,
  });

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  List<Payment> payments = [];
  List<Loan> loans = [];
  List<Object> transactions = [];

  double totalPayment = 0;
  double totalLoan = 0;

  bool isSavingPayment = false;

  double get remainingAmount => totalLoan - totalPayment;

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final paymentBox = DatabaseHelper.payments;
    final loanBox = DatabaseHelper.loans;

    final customerPayments = paymentBox.values
        .where((payment) => payment.customerKey == widget.customerKey)
        .toList();

    final customerLoans = loanBox.values
        .where((loan) => loan.customerKey == widget.customerKey)
        .toList();

    final paymentTotal = customerPayments.fold<double>(
      0,
      (total, payment) => total + payment.amount,
    );

    final loanTotal = customerLoans.fold<double>(
      0,
      (total, loan) => total + loan.totalAmount,
    );

    final allTransactions = <Object>[...customerPayments, ...customerLoans];

    allTransactions.sort((a, b) {
      final dateA = a is Payment ? a.dateTime : (a as Loan).dateTime;
      final dateB = b is Payment ? b.dateTime : (b as Loan).dateTime;

      return dateB.compareTo(dateA);
    });

    if (!mounted) return;

    setState(() {
      payments = customerPayments;
      loans = customerLoans;
      transactions = allTransactions;
      totalPayment = paymentTotal;
      totalLoan = loanTotal;
    });
  }

  String formatDateTime(DateTime dateTime) {
    final jalaliDate = Jalali.fromDateTime(dateTime);

    final hour = dateTime.hour;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'ب.ظ' : 'ق.ظ';

    return '${jalaliDate.formatter.yyyy}/'
        '${jalaliDate.formatter.mm}/'
        '${jalaliDate.formatter.dd}'
        ' - $displayHour:${jalaliDate.formatter.tMM} $period';
  }

  Widget paymentCard(Payment payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.payments_outlined,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${payment.amount.toStringAsFixed(1)} AFN',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  if (payment.description != null &&
                      payment.description!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      payment.description!,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF616161),
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    formatDateTime(payment.dateTime),
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget loanCard(Loan loan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFFE0B2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LoanDetailsScreen(loan: loan)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Color(0xFFEF6C00),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (loan.title.trim().isNotEmpty) ...[
                      Text(
                        loan.title,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF6C00),
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      '${loan.totalAmount.toStringAsFixed(1)} AFN',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF424242),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'تعداد اقلام: ${loan.itemCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formatDateTime(loan.dateTime),
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left, color: Color(0xFF9E9E9E)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showPaymentDialog() async {
    if (!mounted || isSavingPayment) return;

    final result = await showDialog<PaymentFormData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PaymentDialog(),
    );

    if (!mounted || result == null) return;

    setState(() {
      isSavingPayment = true;
    });

    try {
      await savePayment(amount: result.amount, description: result.description);

      if (!mounted) return;

      await loadTransactions();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پرداخت با موفقیت ثبت شد.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ثبت پرداخت ناموفق بود: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSavingPayment = false;
        });
      }
    }
  }

  Future<void> savePayment({
    required double amount,
    String? description,
  }) async {
    final box = DatabaseHelper.payments;

    final payment = Payment(
      customerKey: widget.customerKey,
      amount: amount,
      description: description,
      dateTime: DateTime.now(),
    );

    await box.add(payment);
  }

  Widget summaryCard() {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              child: _summaryItem(
                icon: Icons.shopping_cart_outlined,
                iconColor: const Color(0xFFEF6C00),
                iconBackground: const Color(0xFFFFF3E0),
                title: 'قرض کل',
                amount: totalLoan,
              ),
            ),
            Container(height: 70, width: 1, color: const Color(0xFFE0E0E0)),
            Expanded(
              child: _summaryItem(
                icon: Icons.payments_outlined,
                iconColor: const Color(0xFF2E7D32),
                iconBackground: const Color(0xFFE8F5E9),
                title: 'پرداخت کل',
                amount: totalPayment,
              ),
            ),
            Container(height: 70, width: 1, color: const Color(0xFFE0E0E0)),
            Expanded(
              child: _summaryItem(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF513680),
                iconBackground: const Color(0xFFF3EFFF),
                title: 'باقی‌مانده',
                amount: remainingAmount,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required double amount,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 25),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${amount.toStringAsFixed(1)} AFN',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: iconColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget transactionHistory() {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF3EFFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: Color(0xFF513680),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'هنوز هیچ معامله‌ای ثبت نشده است',
              style: TextStyle(fontSize: 15, color: Color(0xFF757575)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];

        if (transaction is Loan) {
          return loanCard(transaction);
        }

        if (transaction is Payment) {
          return paymentCard(transaction);
        }

        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF513680),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leadingWidth: 56,
        iconTheme: const IconThemeData(color: Colors.white),

        title: Text(
          '${widget.customer.name}'
          '${widget.customer.nickname == null || widget.customer.nickname!.isEmpty ? '' : ' ${widget.customer.nickname}'}',
          style: const TextStyle(
            fontSize: 22,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            summaryCard(),
            const SizedBox(height: 15),

            const Align(
              alignment: Alignment.centerRight,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(Icons.history_outlined, color: Color(0xFF513680)),
                  SizedBox(width: 8),
                  Text(
                    'تاریخچه معاملات',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212121),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(child: transactionHistory()),
          ],
        ),
      ),

      bottomNavigationBar: BottomAppBar(
        elevation: 10,
        color: const Color(0xFFF5F7FA),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: isSavingPayment ? null : showPaymentDialog,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.payments_rounded,
                        color: Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isSavingPayment ? 'در حال ثبت...' : 'ثبت پرداخت',
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddLoanScreen(customerKey: widget.customerKey),
                    ),
                  );

                  if (result == true && mounted) {
                    await loadTransactions();
                  }
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_shopping_cart_rounded,
                        color: Color(0xFFEF6C00),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'ثبت قرضه',
                        style: TextStyle(
                          color: Color(0xFFEF6C00),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentFormData {
  final double amount;
  final String? description;

  const PaymentFormData({required this.amount, this.description});
}

class PaymentDialog extends StatefulWidget {
  const PaymentDialog({super.key});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late final TextEditingController amountController;
  late final TextEditingController descriptionController;

  String? amountError;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();

    amountController = TextEditingController();
    descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();

    super.dispose();
  }

  void submitPayment() {
    if (isSubmitting) return;

    final amountText = amountController.text.trim();
    final descriptionText = descriptionController.text.trim();

    final amount = double.tryParse(amountText);

    if (amountText.isEmpty) {
      setState(() {
        amountError = 'لطفاً مبلغ پرداخت را وارد کنید.';
      });
      return;
    }

    if (amount == null || amount <= 0) {
      setState(() {
        amountError = 'مبلغ پرداخت باید بیشتر از صفر باشد.';
      });
      return;
    }

    Navigator.of(context).pop(
      PaymentFormData(
        amount: amount,
        description: descriptionText.isEmpty ? null : descriptionText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = Jalali.now();

    final displayHour = today.hour > 12
        ? today.hour - 12
        : (today.hour == 0 ? 12 : today.hour);

    final period = today.hour >= 12 ? 'ب.ظ' : 'ق.ظ';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'ثبت پرداخت',
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              enabled: !isSubmitting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              onChanged: (_) {
                if (amountError != null) {
                  setState(() {
                    amountError = null;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'مبلغ پرداخت',
                hintTextDirection: TextDirection.rtl,
                errorText: amountError,
                suffixIcon: const Icon(
                  Icons.payments_outlined,
                  color: Color(0xFF2E7D32),
                ),
                prefixText: 'AFN ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: descriptionController,
              enabled: !isSubmitting,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'توضیحات کوتاه',
                hintTextDirection: TextDirection.rtl,
                suffixIcon: const Icon(
                  Icons.notes_outlined,
                  color: Color(0xFF757575),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF513680),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تاریخ: ${today.formatter.yyyy}/'
                      '${today.formatter.mm}/'
                      '${today.formatter.dd}'
                      ' - $displayHour:${today.formatter.tMM} $period',
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('لغو'),
        ),

        ElevatedButton(
          onPressed: isSubmitting ? null : submitPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
          ),
          child: const Text('ثبت پرداخت'),
        ),
      ],
    );
  }
}
