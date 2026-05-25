// lib/screens/secure_payment_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SecurePaymentScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const SecurePaymentScreen({super.key, required this.order});

  @override
  State<SecurePaymentScreen> createState() => _SecurePaymentScreenState();
}

class _SecurePaymentScreenState extends State<SecurePaymentScreen> {
  String status = "waiting_handshake";

  String? proofPath;

  Timer? timer;
  String? token;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('api_token');

    timer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchStatus();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String _apiUrl(String path) {
    return "https://taskmarket.store/api$path";
  }

  Future<void> fetchStatus() async {
    if (token == null || token!.isEmpty) return;

    try {
      final res = await http.get(
        Uri.parse(
            _apiUrl("/agent/order-status.php?order_id=${widget.order['id']}")),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(res.body);

      print("STATUS RESPONSE:");
      print(data);

      if (data['ok'] == true) {
        setState(() {
          status = data['status'];
          proofPath = data['data']['proof_path'];
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> post(String path) async {
    if (token == null || token!.isEmpty) return;

    await http.post(
      Uri.parse(_apiUrl(path)),
      headers: {
        'Authorization': 'Bearer $token',
      },
      body: {
        'order_id': widget.order['id'].toString(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      appBar: AppBar(title: const Text("Secure Payment")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("ربحك من العملية: ${order['profit']} IQD"),
              const SizedBox(height: 10),
              const Text("نوع العملية"),
              Text(order['type'] == 'deposit' ? "إيداع" : "سحب"),
              const SizedBox(height: 10),
              const Text("المبلغ"),
              Text("${order['amount']} IQD"),
              const SizedBox(height: 10),
              const Text("وسيلة الدفع"),
              Text(order['method'] ?? ''),
              const SizedBox(height: 10),
              const Text("رقم الحساب"),
              Text(order['account_number'] ?? '---'),
              const SizedBox(height: 20),
              if (status == "waiting_handshake")
                const Text("بانتظار جاهزية الزبون..."),
              if (status == "user_ready")
                ElevatedButton(
                  onPressed: () => post("/agent/handshake.php"),
                  child: const Text("مستعد للاستلام"),
                ),
              if (status == "waiting_proof")
                const Text(
                    "بانتظار رفع الزبون للإثبات ...ملاحظة :-لاتعتمد  على  صورة الاثبات  فقط  بل  راجع  حسابك ايضا  وتاكد من المبلغ  قد وصلك فعلا ..."),
              if (status == "proof_uploaded")
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (proofPath != null && proofPath!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _apiUrl("").replaceAll('/api', '') +
                                "/uploads/proofs/$proofPath",
                            fit: BoxFit.cover,
                            height: 220,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              height: 220,
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Text("تعذر تحميل الصورة"),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ElevatedButton(
                        onPressed: () => post("/agent/confirm-received.php"),
                        child: const Text("تأكيد الاستلام"),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          final confirmAction = await showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("تأكيد الإنكار"),
                              content: const Text(
                                "هل أنت متأكد من إنكار الاستلام؟\n\n"
                                "في حال ثبوت أن الزبون قام بالدفع:\n"
                                "سيتم خصم مبلغ العملية من رصيدك\n\n"
                                "سيتم تحويل العملية إلى منازعة\n\n"
                                "هل تريد المتابعة؟",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("إلغاء"),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("نعم، إنكار"),
                                ),
                              ],
                            ),
                          );

                          if (confirmAction == null || confirmAction == false)
                            return;

                          final res = await http.post(
                            Uri.parse(_apiUrl("/agent/deny-received.php")),
                            headers: {
                              'Authorization': 'Bearer $token',
                            },
                            body: {
                              'order_id': order['id'].toString(),
                            },
                          );

                          final data = jsonDecode(res.body);

                          print("DENY RESPONSE:");
                          print(data);

                          if (data['success'] != true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(data['message'] ?? 'فشل الإنكار'),
                              ),
                            );
                            return;
                          }

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar:
                                    AppBar(title: const Text("حالة العملية")),
                                body: const Center(
                                  child: Text(
                                    "تم تحويل العملية إلى منازعة\n\n"
                                    "ستظهر لك نتائج الحكم لاحقاً",
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: const Text("إنكار الاستلام"),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
