import 'package:flutter/material.dart';
import 'package:for_shop/models/customer.dart';

class CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onLongPress;
  final VoidCallback onPress;

  /// The arrow on the left edge of the card edits the customer's details.
  final VoidCallback onEdit;

  const CustomerCard({
    super.key,
    required this.customer,
    required this.onLongPress,
    required this.onPress,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPress,
      onLongPress: onLongPress,
      child: Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Color(0xFF513680)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFF3EFFF),
                radius: 26,
                child: Text(
                  customer.name[0],
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF513680),
                  ),
                ),
              ),

              const SizedBox(width: 14),
              // بخش متون (نام، تخلص و شماره تماس)
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // نام
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Text(
                          customer.name,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (customer.nickname != null) ...[
                          const SizedBox(width: 5),
                          Text(
                            customer.nickname!,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (customer.phone != null) ...[
                      const SizedBox(height: 4),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '+93 ${customer.phone!}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tooltip(
                message: 'ویرایش مشخصات مشتری',
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    child: Icon(
                      Icons.mode_edit,
                      size: 18,
                      color: Color(0xFF513680),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
