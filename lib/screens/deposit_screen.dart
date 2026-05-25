import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';

class DepositScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const DepositScreen({super.key, required this.order});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  String status = "waiting_handshake";
  String? proofImage;
  Timer? timer;
  String? token;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('api_token');

    timer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchStatus();
    });
  }

  Future<void> fetchStatus() async {
    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse(Api.orderStatus(widget.order['id'], 'deposit')),
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = jsonDecode(res.body);

      if (!mounted) return;

      if (data['ok'] == true || data['success'] == true) {
        setState(() {
          status = data['status'];
          proofImage = data['data']?['proof_path'];
        });
      }
    } catch (e) {
      print("ERROR: $e");
    }
  }

  Future<void> post(String path) async {
    if (token == null) return;

    await http.post(
      Uri.parse(Api.post(path)),
      headers: {'Authorization': 'Bearer $token'},
      body: {'order_id': widget.order['id'].toString()},
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("إيداع"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // المبلغ كبير وواضح
            Center(
              child: Column(
                children: [
                  const Text(
                    "المبلغ المطلوب",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${order['amount']} IQD",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // الربح بلون أخضر
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "ربحك: ",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                Text(
                  "${order['profit']} IQD",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // بطاقة المعلومات (الطريقة ورقم الحساب)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow("طريقة الدفع", order['method']),
                    const Divider(),
                    _infoRow("رقم الحساب", order['account_number']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // الحالات والأزرار (نفس المنطق الأصلي ولكن بتنسيق أفضل)
            Expanded(
              child: _buildStatusWidget(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusWidget() {
    if (status == "waiting_handshake") {
      return const Center(
        child: Text(
          "بانتظار تأكيد الزبون...",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    if (status == "user_ready") {
      return Center(
        child: ElevatedButton(
          onPressed: () => post("/agent/handshake.php"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text("أنا مستعد", style: TextStyle(fontSize: 18)),
        ),
      );
    }

    if (status == "waiting_proof") {
      return const Center(
        child: Text(
          "بانتظار إثبات الدفع...",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    if (status == "proof_uploaded") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (proofImage != null && proofImage!.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: Colors.black,
                      appBar: AppBar(),
                      body: Center(
                        child: InteractiveViewer(
                          child: Image.network(
                            Api.image(proofImage!),
                            errorBuilder: (context, error, stackTrace) {
                              print("❌ IMAGE ERROR: $error");
                              print("🔗 URL: ${Api.image(proofImage!)}");
                              return Column(
                                children: [
                                  const Text("فشل تحميل الصورة"),
                                  Text(
                                    "$error",
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                height: 150,
                margin: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    Api.image(proofImage!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print("❌ IMAGE ERROR: $error");
                      print("🔗 URL: ${Api.image(proofImage!)}");
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Text("فشل تحميل الصورة"),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ElevatedButton(
            onPressed: () => post("/agent/confirm-received.php"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("تأكيد الاستلام", style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("تأكيد الإنكار"),
                  content: const Text("هل أنت متأكد من إنكار الاستلام؟"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("إلغاء"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text("نعم"),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;
              await post("/agent/deny-received.php");
              if (mounted) Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("إنكار الاستلام", style: TextStyle(fontSize: 16)),
          ),
        ],
      );
    }

    if (status == "completed") {
      Future.microtask(() {
        if (mounted) Navigator.pop(context, true);
      });
      return const Center(
        child: Text(
          "تمت العملية بنجاح",
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
        ),
      );
    }

    if (status == "disputed") {
      Future.microtask(() {
        if (mounted) Navigator.pop(context, true);
      });
      return const Center(
        child: Text(
          "العملية قيد النزاع",
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
