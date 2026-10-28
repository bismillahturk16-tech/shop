import 'dart:async';

import 'package:flutter/material.dart';
import 'package:for_shop/components/app_drawer.dart';
import 'package:for_shop/components/change_password_dialog.dart';
import 'package:for_shop/components/customer_card.dart';
import 'package:for_shop/components/delete_customer_dialog.dart';
import 'package:for_shop/components/empty_customer_view.dart';
import 'package:for_shop/db/database_helper.dart';
import 'package:for_shop/screens/add_costomer_screen.dart';
import 'package:for_shop/screens/customer_details_screen.dart';
import 'package:for_shop/services/auth_service.dart';
import 'package:for_shop/sync/sync_service.dart';
import 'package:hive/hive.dart';
import '../models/customer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isSearching = false;
  String searchText = '';
  List<_CustomerRow> customers = [];

  StreamSubscription<BoxEvent>? _customersSub;
  int _customerRows = 0;

  final TextEditingController _searchController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  void openSearch() {
    setState(() {
      isSearching = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && isSearching) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void closeSearch() {
    _searchFocusNode.unfocus();

    setState(() {
      isSearching = false;
      searchText = '';
      _searchController.clear();
    });
  }

  Widget _rtl(Widget dialog) =>
      Directionality(textDirection: TextDirection.rtl, child: dialog);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final auth = AuthService.instance;

    final online = await SyncService.instance.refreshOnline();

    if (!mounted) return;

    if (!online) {
      _showMessage('برای خروج، به انترنت یا وای فای وصل شوید');

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _rtl(
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFEDE7F6),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFF513680),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('خروج از حساب')),
              ],
            ),
            content: Text(
              'با خروج از حساب ${auth.account?.email ?? ''} همه اطلاعات این '
              'گوشی پاک می‌شود. نسخه ابری حساب شما دست‌نخورده می‌ماند و با '
              'ورود دوباره برمی‌گردد.',
              style: const TextStyle(fontSize: 15, height: 1.8),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('لغو'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('خروج'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    final flushError = await SyncService.instance.flushBeforeSignOut();

    if (flushError != null) {
      if (mounted) _showMessage(flushError);

      return;
    }

    await auth.signOut();

    SyncService.instance.scheduleSync();
  }

  Future<void> _changePassword() async {
    final changed = await ChangePasswordDialog.show(context);

    if (changed && mounted) _showMessage('رمز عبور شما تغییر کرد.');
  }

  Future<void> deleteCustomer(int index) async {
    final row = filteredRows[index];

    final deleted = await DeleteCustomerDialog.show(
      context,
      row.customer,
      row.key,
    );

    if (deleted && mounted) loadCustomers();
  }

  void loadCustomers() {
    final rows = DatabaseHelper.customers.toMap().entries.toList();

    rows.sort((a, b) {
      final byCreatedAt = b.value.createdAt.compareTo(a.value.createdAt);

      return byCreatedAt != 0
          ? byCreatedAt
          : (b.key as int).compareTo(a.key as int);
    });

    setState(() {
      _customerRows = rows.length;
      // The key travels with the customer: two customers with the same name and
      // phone are separate rows, and the edit has to land on the right one.
      customers = rows
          .map((row) => _CustomerRow(row.key as int, row.value))
          .toList();
    });
  }

  List<_CustomerRow> get filteredRows {
    if (searchText.isEmpty) {
      return customers;
    }

    final query = searchText.toLowerCase();

    return customers.where((row) {
      final customer = row.customer;

      final nameMatch = customer.name.toLowerCase().contains(query);

      final nicknameMatch = (customer.nickname ?? '').toLowerCase().contains(
        query,
      );

      final phoneMatch = (customer.phone ?? '').contains(query);

      return nameMatch || nicknameMatch || phoneMatch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    loadCustomers();

    _customersSub = DatabaseHelper.customers.watch().listen((_) {
      if (DatabaseHelper.customers.length == _customerRows) return;

      loadCustomers();
    });
  }

  @override
  void dispose() {
    _customersSub?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isSearching) {
          closeSearch();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        // The chip in the drawer has to tell the truth about the network, so
        // opening the drawer asks Firestore instead of trusting the interface.
        onDrawerChanged: (isOpen) {
          if (isOpen) SyncService.instance.probeCloud();
        },
        drawer: AppDrawer(
          onChangePassword: _changePassword,
          onSignOut: _confirmSignOut,
        ),
        appBar: AppBar(
          backgroundColor: const Color(0xFF513680),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'دفترچه قرضه',
            style: TextStyle(
              fontSize: 26,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            children: [
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        textDirection: TextDirection.rtl,
                        onTap: () {
                          if (!isSearching) {
                            openSearch();
                          }
                        },

                        decoration: const InputDecoration(
                          hintTextDirection: TextDirection.rtl,
                          hintText: 'جستجوی مشتری',
                          hintStyle: TextStyle(
                            color: Color(0xFF667781),
                            fontSize: 15,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Color(0xFF667781),
                            size: 22,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 13),
                        ),

                        onChanged: (value) {
                          setState(() {
                            searchText = value.trim();
                          });
                        },
                      ),
                    ),

                    if (isSearching)
                      IconButton(
                        tooltip: 'بستن جستجو',
                        onPressed: closeSearch,
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF667781),
                          size: 22,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: filteredRows.isEmpty
                    ? const EmptyCustomerView()
                    : ListView.builder(
                        itemCount: filteredRows.length,
                        itemBuilder: (context, index) {
                          final row = filteredRows[index];
                          final customer = row.customer;

                          return CustomerCard(
                            onPress: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CustomerDetailsScreen(
                                    customer: customer,
                                    customerKey: row.key,
                                  ),
                                ),
                              ).then((_) {
                                loadCustomers();
                              });
                            },
                            customer: customer,
                            onLongPress: () {
                              deleteCustomer(index);
                            },
                            onEdit: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddCustomerScreen(
                                    existing: customer,
                                    customerKey: row.key,
                                  ),
                                ),
                              ).then((_) {
                                loadCustomers();
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),

        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddCustomerScreen(),
              ),
            );

            loadCustomers();
          },
          backgroundColor: const Color(0xFF513680),
          icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
          label: const Text(
            'ثبت مشتری',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// A customer together with the Hive key it is stored under.
class _CustomerRow {
  const _CustomerRow(this.key, this.customer);

  final int key;
  final Customer customer;
}
