import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api.dart';
import '../core/auth_storage.dart';
import 'activation_request_screen.dart'; // ✅ استيراد الصفحة الجديدة

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  bool loading = true;

  double current = 0;
  double profit = 0;
  double totalProfit = 0;
  double limit = 0;

  List ledger = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final token = await AuthStorage.getToken();

    final res = await http.get(
      Uri.parse(Api.wallet()),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(res.body);

    if (!mounted) return;

    if (data['success'] == true) {
      final d = data['data'];

      setState(() {
        current = _toDouble(d['current']);
        profit = _toDouble(d['profit']);
        totalProfit = _toDouble(d['total_profit']);
        limit = _toDouble(d['limit']);
        ledger = d['ledger'] ?? [];
        loading = false;
      });
    } else {
      loading = false;
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Widget rowItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget ledgerItem(Map row, int i) {
    final amount = _toDouble(row['amount_local']);
    final profitVal = _toDouble(row['profit_local']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("#${i + 1}"),
                Text(row['created_at'] ?? ''),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(row['type']),
                Text("ID: ${row['operation_id']}"),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "المبلغ: ${amount.toStringAsFixed(0)}",
                  style:
                      TextStyle(color: amount >= 0 ? Colors.green : Colors.red),
                ),
                Text(
                  "الربح: ${profitVal.toStringAsFixed(0)}",
                  style: TextStyle(
                      color: profitVal >= 0 ? Colors.green : Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("قبل: ${row['balance_before'] ?? '-'}"),
                Text("بعد: ${row['balance_after']}"),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text("الأرباح: ${row['profit_after']}"),
            ),
            if (row['note'] != null && row['note'] != '')
              Align(
                alignment: Alignment.centerRight,
                child: Text("ملاحظة: ${row['note']}"),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("المحفظة")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("💼 المحفظة",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                rowItem("الحساب الجاري", "${current.toStringAsFixed(0)} IQD"),
                const Divider(height: 1),
                rowItem(
                    "أرباح الدورة الحالية", "${profit.toStringAsFixed(0)} IQD"),
                const Divider(height: 1),
                rowItem("إجمالي الأرباح التاريخية",
                    "${totalProfit.toStringAsFixed(0)} IQD"),
                const Divider(height: 1),
                rowItem("السقف", "${limit.toStringAsFixed(0)} IQD"),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("📊 السجل المحاسبي",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (ledger.isEmpty)
            const Center(child: Text("لا توجد حركات"))
          else
            ...List.generate(ledger.length, (i) {
              return ledgerItem(ledger[i], i);
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const ActivationRequestScreen(), // ✅ الصفحة الجديدة
            ),
          );
        },
        label: const Text("رفع السقف"),
        icon: const Icon(Icons.arrow_upward),
      ),
    );
  }
}
