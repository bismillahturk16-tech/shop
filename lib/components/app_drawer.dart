import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'package:for_shop/components/sync_status_bar.dart';
import 'package:for_shop/db/database_helper.dart';
import 'package:for_shop/models/loan.dart';
import 'package:for_shop/models/payment.dart';
import 'package:for_shop/services/auth_service.dart';
import 'package:for_shop/sync/sync_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.onRestore,
    required this.onSignOut,
  });

  final VoidCallback onRestore;
  final VoidCallback onSignOut;

  static void _closeAnd(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final account = AuthService.instance.account;
    final cloudReady = AuthService.instance.isCloudReady;

    final canRestore =
        cloudReady &&
        (DatabaseHelper.hasGuestData || !DatabaseHelper.hasLocalData);

    return Drawer(
      backgroundColor: const Color(0xFF513680),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DrawerHeader(email: account?.email),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SyncStatusBar(),
              ),
              const SizedBox(height: 16),
              const _TotalBalanceCard(),
              const Spacer(),
              if (canRestore)
                _DrawerTile(
                  icon: Icons.cloud_download_rounded,
                  title: 'بازیابی از ابر',
                  subtitle: 'ادغام اطلاعات بدون حساب با داده ابری',
                  onTap: () => _closeAnd(context, onRestore),
                ),
              if (account != null)
                _DrawerTile(
                  icon: Icons.logout_rounded,
                  title: 'خروج از حساب',
                  subtitle: account.email,
                  onTap: () => _closeAnd(context, onSignOut),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'دفترچه قرضه',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email ?? 'بدون حساب کاربری',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncService.instance,
      builder: (context, child) {
        final loans = Hive.box<Loan>(DatabaseHelper.loansBox).values;
        final payments = Hive.box<Payment>(DatabaseHelper.paymentsBox).values;

        final totalLoan = loans.fold<double>(
          0,
          (sum, loan) => sum + loan.totalAmount,
        );

        final totalPayment = payments.fold<double>(
          0,
          (sum, payment) => sum + payment.amount,
        );

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Icon(
                    Icons.summarize_rounded,
                    size: 18,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'خلاصه حساب همه مشتریان',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  Text(
                    '${loans.length} قرض / ${payments.length} پرداخت',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _TotalLine(
                label: 'مجموع قرض',
                amount: totalLoan,
                color: const Color(0xFFFFD54F),
              ),
              const SizedBox(height: 8),
              _TotalLine(
                label: 'مجموع پرداختی',
                amount: totalPayment,
                color: const Color(0xFFA5D6A7),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: Colors.white24),
              ),
              _TotalLine(
                label: 'باقی‌مانده کل',
                amount: totalLoan - totalPayment,
                color: Colors.white,
                emphasized: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.amount,
    required this.color,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: emphasized ? 15 : 13,
              fontWeight: emphasized ? FontWeight.bold : FontWeight.w500,
              color: emphasized ? Colors.white : Colors.white70,
            ),
          ),
        ),
        Text(
          '${amount.toStringAsFixed(1)} افغانی',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: emphasized ? 17 : 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.65),
        ),
      ),
      trailing: const Icon(Icons.chevron_left_rounded, color: Colors.white54),
    );
  }
}
