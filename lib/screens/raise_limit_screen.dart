import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';

class RaiseLimitScreen extends StatefulWidget {
  const RaiseLimitScreen({super.key});

  @override
  State<RaiseLimitScreen> createState() => _RaiseLimitScreenState();
}

class _RaiseLimitScreenState extends State<RaiseLimitScreen> {
  final txidController = TextEditingController();
  final walletController = TextEditingController();

  List packages = [];
  int? selectedPackageId;

  bool isLoading = true;
  bool isSubmitting = false;

  String? token;

  /// 🔴 إذا عنده طلب pending
  bool hasPendingRequest = false;

  @override
  void initState() {
    super.initState();
    loadPackages();
  }

  Future<void> loadPackages() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');

    try {
      final res = await http.get(
        Uri.parse(Api.packages()),
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        setState(() {
          packages = data['data']['packages'];
          isLoading = false;
        });
      } else {
        isLoading = false;
      }
    } catch (_) {
      isLoading = false;
    }
  }

  Future<void> submit() async {
    if (selectedPackageId == null) {
      showMsg("اختر الباقة");
      return;
    }

    if (txidController.text.isEmpty || walletController.text.isEmpty) {
      showMsg("املأ جميع الحقول");
      return;
    }

    setState(() => isSubmitting = true);

    final res = await http.post(
      Uri.parse(Api.activationRequest()),
      headers: {'Authorization': 'Bearer $token'},
      body: {
        "package_id": selectedPackageId.toString(),
        "txid": txidController.text,
        "wallet_address": walletController.text,
      },
    );

    final data = jsonDecode(res.body);

    setState(() => isSubmitting = false);

    showMsg(data['message']);

    /// 🔴 إذا عنده طلب مسبق
    if (data['success'] == false && data['message'].contains("قيد المراجعة")) {
      setState(() {
        hasPendingRequest = true;
      });
    }

    if (data['success'] == true) {
      Navigator.pop(context);
    }
  }

  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// ✅ تنظيف الرقم
  String formatAmount(dynamic value) {
    final numVal = double.tryParse(value.toString()) ?? 0;

    if (numVal == numVal.roundToDouble()) {
      return numVal.toInt().toString();
    }

    return numVal.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("رفع السقف")),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          /// 🔴 إذا عنده طلب قيد المراجعة
          : hasPendingRequest
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  "لديك طلب قيد المراجعة\nيرجى انتظار موافقة الإدارة",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            )
          /// 🟢 الفورم
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  /// الباقات
                  DropdownButtonFormField<int>(
                    value: selectedPackageId,
                    hint: const Text("اختر الباقة"),
                    items: packages.map<DropdownMenuItem<int>>((p) {
                      return DropdownMenuItem<int>(
                        value: int.parse(p['id']),
                        child: Text(
                          "${p['title']} - ${formatAmount(p['amount_usdt'])} USDT",
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        selectedPackageId = v;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: walletController,
                    decoration: const InputDecoration(
                      labelText: "عنوان المحفظة",
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: txidController,
                    decoration: const InputDecoration(labelText: "TXID"),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : submit,
                      child: isSubmitting
                          ? const CircularProgressIndicator()
                          : const Text("إرسال الطلب"),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
