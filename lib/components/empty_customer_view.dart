import 'package:flutter/material.dart';

class EmptyCustomerView extends StatelessWidget {
  const EmptyCustomerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 70, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            'هنوز مشتری ای ثبت نشده است',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'برای شروع یک مشتری جدید اضافه کنید',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
