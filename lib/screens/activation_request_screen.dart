import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import 'activate_package_screen.dart';

class ActivationRequestScreen extends StatefulWidget {
  const ActivationRequestScreen({super.key});

  @override
  State<ActivationRequestScreen> createState() =>
      _ActivationRequestScreenState();
}

class _ActivationRequestScreenState extends State<ActivationRequestScreen> {
  bool isLoading = true;
  double currentLimit = 0;
  List packages = [];
  String debugInfo = ''; // لعرض معلومات التصحيح مؤقتاً

  @override
  void initState() {
    super.initState();
    fetchPackages();
  }

  Future<void> fetchPackages() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');

    try {
      final res = await http.get(
        Uri.parse(Api.post("agent/available-packages.php")),
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = jsonDecode(res.body);
      // ✅ طباعة الرد كاملاً في وحدة التحكم
      print('🔍 Response from available-packages.php: $data');

      if (data['success'] == true && mounted) {
        final d = data['data'] ?? {};
        setState(() {
          currentLimit = (d['current_limit'] ?? 0).toDouble();
          packages = d['packages'] ?? [];
          isLoading = false;
          if (d['debug'] != null) {
            debugInfo = 'Debug: ${d['debug']}';
          } else {
            debugInfo = '';
          }
        });
      } else if (mounted) {
        setState(() {
          isLoading = false;
          debugInfo = 'Server error: ${data['message']}';
        });
      }
    } catch (e) {
      print('🔥 Exception: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          debugInfo = 'Exception: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("رفع السقف"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet,
                        color: Colors.teal, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "السقف الحالي: ${currentLimit.toInt()} USDT",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (packages.isEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Center(
                        child: Text("لا توجد باقات أعلى متاحة حالياً",
                            style: TextStyle(fontSize: 16)),
                      ),
                      if (debugInfo.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            debugInfo,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              ...packages.map((p) {
                final amount =
                    double.tryParse(p['amount_usdt'].toString()) ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.workspace_premium,
                            color: Colors.teal, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['title'] ?? '',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${amount.toInt()} USDT",
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.teal),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ActivatePackageScreen(package: p),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("اختيار"),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            // عرض معلومات التصحيح في نهاية القائمة (مؤقت)
            if (debugInfo.isNotEmpty && packages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  debugInfo,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
