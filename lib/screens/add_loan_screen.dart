import 'package:flutter/material.dart';
import 'package:for_shop/db/database_helper.dart';
import 'package:for_shop/models/loan.dart';

class AddLoanScreen extends StatefulWidget {
  final int customerKey;

  const AddLoanScreen({super.key, required this.customerKey});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final List<_LoanRow> rows = [];
  final TextEditingController titleController = TextEditingController();

  double totalAmount = 0;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    addItem();
  }

  @override
  void dispose() {
    titleController.dispose();
    for (final row in rows) {
      row.removeListener(calculateTotal);
      row.dispose();
    }
    super.dispose();
  }

  void addItem() {
    final row = _LoanRow();
    row.addListener(calculateTotal);

    setState(() {
      rows.add(row);
    });
  }

  void calculateTotal() {
    double total = 0;

    for (final row in rows) {
      total += row.lineTotal;
    }

    if (mounted) {
      setState(() {
        totalAmount = total;
      });
    }
  }

  Future<void> saveLoan() async {
    if (isSaving) return;

    final title = titleController.text.trim();
    final loanItems = <LoanItem>[];

    for (final row in rows) {
      final name = row.name.text.trim();

      if (name.isEmpty && row.isEmptyNumbers) {
        continue;
      }

      if (name.isEmpty) {
        showMessage('لطفاً نام جنس را وارد کنید.');
        return;
      }

      final unitPrice = row.unitPrice;

      if (unitPrice == null || unitPrice <= 0) {
        showMessage('قیمت فی واحد باید بیشتر از صفر باشد.');
        return;
      }

      final quantity = row.quantity;

      if (quantity == null || quantity <= 0) {
        showMessage('تعداد باید بیشتر از صفر باشد.');
        return;
      }

      loanItems.add(
        LoanItem(name: name, unitPrice: unitPrice, quantity: quantity),
      );
    }

    if (loanItems.isEmpty) {
      showMessage('لطفاً حداقل یک مورد خرید ثبت کنید.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final box = DatabaseHelper.loans;

      final loan = Loan(
        customerKey: widget.customerKey,
        title: title,
        items: loanItems,
        dateTime: DateTime.now(),
      );

      await box.add(loan);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      showMessage('ثبت قرضه انجام نشد. لطفاً دوباره تلاش کنید.');

      setState(() {
        isSaving = false;
      });
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF513680),
          centerTitle: true,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded, size: 25),
              onPressed: () => Navigator.pop(context),
            ),
          ],
          title: const Text(
            'ثبت قرضه',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Column(
                  children: [
                    Card(
                      elevation: 1,
                      margin: EdgeInsets.zero,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: titleController,
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                decoration: InputDecoration(
                                  hintText: 'نوت ',
                                  hintTextDirection: TextDirection.rtl,
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0xFFF7F5FB),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 13,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(11),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: _summaryBox(
                                title: 'تعداد اقلام',
                                value: '${rows.length}',
                                color: const Color(0xFF513680),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: _summaryBox(
                                title: 'مجموع مبلغ',
                                value: _money(totalAmount),
                                color: const Color(0xFFEF6C00),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // جدول اقلام قرضه
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x09000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            height: 40,
                            color: const Color(0xFF513680),
                            child: const Row(
                              children: [
                                _CellHeader(label: 'نام جنس', flex: 4),
                                _CellDivider(),
                                _CellHeader(label: 'قیمت فی واحد', flex: 3),
                                _CellDivider(),
                                _CellHeader(label: 'تعداد', flex: 2),
                                _CellDivider(),
                                _CellHeader(label: 'قیمت مجموعی', flex: 3),
                              ],
                            ),
                          ),
                          ...List.generate(rows.length, _itemRow),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: TextButton.icon(
                              onPressed: addItem,
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: const Text(
                                'افزودن ',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF513680),
                                backgroundColor: const Color(0xFFFAF8FD),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
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

            // دکمه ثبت قرضه
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              color: const Color(0xFFF5F7FA),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : saveLoan,
                  icon: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    isSaving ? 'در حال ثبت...' : 'ثبت قرضه',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF6C00),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryBox({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Color(0xFF757575)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(int index) {
    final row = rows[index];

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: _cell(controller: row.name, hint: ' ', numeric: false),
          ),
          const _CellDivider(),
          Expanded(
            flex: 3,
            child: _cell(
              controller: row.unitPriceController,
              hint: ' ',
              numeric: true,
            ),
          ),
          const _CellDivider(),
          Expanded(
            flex: 2,
            child: _cell(
              controller: row.quantityController,
              hint: '1',
              numeric: true,
            ),
          ),
          const _CellDivider(),
          Expanded(
            flex: 3,
            child: Container(
              color: const Color(0xFFF7F5FB),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  row.lineTotal == 0 ? '-' : _money(row.lineTotal),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: row.lineTotal == 0
                        ? Colors.grey.shade400
                        : const Color(0xFFEF6C00),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell({
    required TextEditingController controller,
    required String hint,
    required bool numeric,
  }) {
    return TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        hintText: hint,
        hintTextDirection: TextDirection.rtl,
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }
}

class _LoanRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController unitPriceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  double? get unitPrice => double.tryParse(unitPriceController.text.trim());

  // تغییر این گتر برای جایگزینی مقدار ۱ در صورت خالی بودن
  double? get quantity {
    final text = quantityController.text.trim();
    if (text.isEmpty) {
      // اگر قیمت واحد وارد شده باشد اما تعداد خالی باشد، مقدار ۱ برگردانده می‌شود
      return unitPrice != null ? 1.0 : null;
    }
    return double.tryParse(text);
  }

  bool get isEmptyNumbers =>
      unitPriceController.text.trim().isEmpty &&
      quantityController.text.trim().isEmpty;

  double get lineTotal {
    final price = unitPrice;
    final count = quantity;
    if (price == null || count == null) return 0;
    return price * count;
  }

  void addListener(VoidCallback callback) {
    unitPriceController.addListener(callback);
    quantityController.addListener(callback);
  }

  void removeListener(VoidCallback callback) {
    unitPriceController.removeListener(callback);
    quantityController.removeListener(callback);
  }

  void dispose() {
    name.dispose();
    unitPriceController.dispose();
    quantityController.dispose();
  }
}

class _CellHeader extends StatelessWidget {
  const _CellHeader({required this.label, required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _CellDivider extends StatelessWidget {
  const _CellDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: double.infinity,
      color: Colors.grey.shade300,
    );
  }
}

String _money(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
