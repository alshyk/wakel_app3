import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import '../api.dart';
import 'orders.dart';
import 'deposit_limit_info_screen.dart';
import 'payment_methods_screen.dart';
import 'activation_request_screen.dart';

class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  bool isLoading = true;

  String status = '';
  bool hasPaymentMethods = false;
  bool hasOpenDispute = false;
  bool hasActivationRequest = false;

  String error = '';

  Timer? timer;

  // متغيرات التحديث
  double downloadProgress = 0.0;
  bool isDownloading = false;
  String updateUrl = '';

  @override
  void initState() {
    super.initState();
    checkUpdate(); // ✅ تحقق من التحديث أول شيء
    fetchGate();

    timer = Timer.periodic(const Duration(hours: 6), (t) {
      fetchGate();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchGate();
  }

  // ✅ دالة التحقق من التحديث (معدلة)
  Future<void> checkUpdate() async {
    try {
      final res = await http.get(Uri.parse(Api.versionCheck()));
      if (!mounted) return;

      final data = jsonDecode(res.body);

      int latest = data['version_code'];
      String url = data['apk_url'];

      final info = await PackageInfo.fromPlatform();
      int current = int.tryParse(info.buildNumber) ?? 1;

      if (!mounted) return;

      if (latest > current) {
        setState(() {
          updateUrl = url;
        });
      }
    } catch (e) {}
  }

  // ✅ دالة التحميل والتثبيت
  Future<void> downloadAndInstall() async {
    try {
      setState(() {
        isDownloading = true;
        downloadProgress = 0;
      });

      final dir = await getApplicationDocumentsDirectory();
      final path = "${dir.path}/update.apk";

      await Dio().download(
        updateUrl,
        path,
        onReceiveProgress: (rec, total) {
          if (total != -1) {
            setState(() {
              downloadProgress = rec / total;
            });
          }
        },
      );

      setState(() {
        isDownloading = false;
      });

      await OpenFile.open(path);
    } catch (e) {
      setState(() {
        isDownloading = false;
      });
    }
  }

  Future<void> fetchGate() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');

    try {
      final res = await http.get(
        Uri.parse(Api.me()),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      final data = jsonDecode(res.body);

      print("GATE RESPONSE: $data");

      if (data['success'] == true) {
        final d = data['data'];

        setState(() {
          status = d['status'] ?? '';
          hasPaymentMethods = d['has_payment_methods'] ?? false;
          hasOpenDispute = d['has_open_dispute'] ?? false;
          hasActivationRequest = d['has_activation_request'] ?? false;
          isLoading = false;
        });
      } else {
        setState(() {
          error = data['message'] ?? 'خطأ';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'فشل الاتصال بالسيرفر';
        isLoading = false;
      });
    }
  }

  Widget buildContent() {
    // 1) نزاع
    if (hasOpenDispute) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: const [
                  Icon(Icons.warning_amber_rounded,
                      size: 48, color: Colors.orange),
                  SizedBox(height: 16),
                  Text(
                    "تم إيقاف الحساب مؤقتاً",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text("لديك نزاع قيد المعالجة، لا يمكنك العمل حالياً"),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 2) غير مفعل وليس لديه طلب رفع سقف معلق
    if (status != 'active' && !hasActivationRequest) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      size: 48, color: Colors.teal),
                  const SizedBox(height: 16),
                  const Text("يجب عليك أولاً رفع سقف حسابك"),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DepositLimitInfoScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("رفع السقف"),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 3) غير مفعل ولكن لديه طلب رفع سقف معلق
    if (status != 'active' && hasActivationRequest) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: const [
                  Icon(Icons.hourglass_empty, size: 48, color: Colors.teal),
                  SizedBox(height: 16),
                  Text("تم إرسال طلب رفع السقف"),
                  SizedBox(height: 10),
                  Text("بانتظار موافقة الإدارة"),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 4) مفعل لكن ما عنده وسيلة دفع
    if (!hasPaymentMethods) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.payment, size: 48, color: Colors.teal),
                  const SizedBox(height: 16),
                  const Text(
                    "خطوة أخيرة",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text("يجب إضافة وسيلة دفع لبدء العمل"),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaymentMethodsScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("إضافة وسيلة دفع"),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 5) جاهز للعمل
    return const OrdersScreen();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("بوابة الوكيل v3"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: fetchGate, // ← زر الرفرش
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ActivationRequestScreen(),
                ),
              );
            },
            icon: const Icon(Icons.arrow_back),
          ),
        ],
      ),
      body: updateUrl.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.system_update, size: 80),
                    const SizedBox(height: 20),
                    const Text("يوجد تحديث جديد",
                        style: TextStyle(fontSize: 20)),
                    const SizedBox(height: 20),
                    if (isDownloading) ...[
                      LinearProgressIndicator(value: downloadProgress),
                      const SizedBox(height: 10),
                      Text("${(downloadProgress * 100).toStringAsFixed(0)} %"),
                    ] else ...[
                      ElevatedButton(
                        onPressed: downloadAndInstall,
                        child: const Text("تحديث الآن"),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : Center(
              child: isLoading
                  ? const CircularProgressIndicator()
                  : error.isNotEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(error),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: fetchGate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("إعادة المحاولة"),
                            )
                          ],
                        )
                      : buildContent(),
            ),
    );
  }
}
