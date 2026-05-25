import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';

class WithdrawalScreen extends StatefulWidget {
  final Map order;

  const WithdrawalScreen({super.key, required this.order});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  File? image;
  Map<String, dynamic>? details;
  bool loading = true;
  String? token;

  int seconds = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    print("🟢 initState: بدء تحميل الشاشة");
    loadTokenAndFetch();
  }

  @override
  void dispose() {
    print("🔴 dispose: إلغاء المؤقت");
    timer?.cancel();
    super.dispose();
  }

  Future<void> loadTokenAndFetch() async {
    print("🟡 loadTokenAndFetch: جلب التوكن من SharedPreferences");
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('api_token');
    print("TOKEN: $token");

    if (token != null) {
      print("✅ التوكن موجود، سيتم جلب التفاصيل");
      await fetchDetails();
    } else {
      print("❌ لا يوجد توكن، إنهاء التحميل");
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> fetchDetails() async {
    print("🟡 fetchDetails: بدء جلب تفاصيل الطلب");
    try {
      final orderId = widget.order['id'];
      print("📦 orderId: $orderId");
      final url = Api.post("withdraw/details.php?order_id=$orderId");
      print("🔗 DETAILS URL: $url");

      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      print("📡 Response status: ${res.statusCode}");
      print("📄 Response body: ${res.body}");

      final data = jsonDecode(res.body);
      print("🔍 Parsed data: $data");

      if (data['success'] == true) {
        print("✅ تم جلب التفاصيل بنجاح");
        setState(() {
          details = data['data'];
          loading = false;
        });
        print("📋 details: $details");
        _startTimerFromDeadline();
      } else {
        print("❌ فشل جلب التفاصيل: ${data['message']}");
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      print("🔥 خطأ في جلب التفاصيل: $e");
      setState(() {
        loading = false;
      });
    }
  }

  void _startTimerFromDeadline() {
    print("🟡 _startTimerFromDeadline: بدء تشغيل المؤقت");
    if (details == null) {
      print("⚠️ details == null, لا يمكن بدء المؤقت");
      return;
    }

    setState(() {
      seconds = details!['remaining_seconds'] ?? 0;
      print("⏱️ seconds المستلمة من API: $seconds");

      if (seconds < 60) {
        seconds = 600; // 10 دقائق
        print("⚠️ seconds أقل من 60 -> تم ضبطه إلى 600 ثانية (10 دقائق)");
      }
      print("⏱️ seconds النهائية: $seconds");
    });

    startTimer();
  }

  void startTimer() {
    print("🟡 startTimer: بدء العد التنازلي");
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (seconds <= 0) {
        print("⏰ Timer: انتهى الوقت");
        timer?.cancel();
        if (mounted) {
          print("📢 عرض SnackBar انتهاء الوقت والخروج من الشاشة");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('انتهى الوقت المخصص للتحويل')),
          );
          Navigator.pop(context, false);
        }
      } else {
        setState(() => seconds--);
        if (seconds % 10 == 0) print("⏳ Timer: $seconds ثانية متبقية");
      }
    });
  }

  String formatTime() {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  Future<void> pickImage() async {
    print("🟡 pickImage: فتح المعرض لاختيار صورة");
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (picked != null) {
      print("✅ تم اختيار الصورة: ${picked.path}");
      setState(() {
        image = File(picked.path);
      });
    } else {
      print("❌ لم يتم اختيار أي صورة");
    }
  }

  Future<void> confirmProof() async {
    print("🟡 confirmProof: بدء رفع الإثبات");
    if (image == null) {
      print("⚠️ لا توجد صورة مرفوعة، لن يتم الرفع");
      return;
    }

    print("📤 إعداد طلب Multipart...");
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(Api.post("withdraw/upload-proof.php")),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['order_id'] = widget.order['id'].toString();
    print("➕ إضافة order_id: ${widget.order['id']}");

    request.files.add(
      await http.MultipartFile.fromPath('proof', image!.path),
    );
    print("➕ إضافة ملف proof من المسار: ${image!.path}");

    print("🚀 إرسال الطلب...");
    final res = await request.send();
    final body = await res.stream.bytesToString();
    print("📡 Response status: ${res.statusCode}");
    print("📄 Response body: $body");

    final data = jsonDecode(body);
    print("🔍 Parsed data: $data");

    if (data['success'] == true) {
      print("✅ تم رفع الإثبات بنجاح");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم إرسال الإثبات")),
      );

      timer?.cancel();
      Navigator.pop(context, true);
    } else {
      print("❌ فشل رفع الإثبات: ${data['message']}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'])),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print("🎨 build: إعادة بناء الواجهة (loading=$loading, details=${details != null})");
    if (loading) {
      print("🔄 عرض شاشة التحميل");
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (details == null) {
      print("⚠️ عرض رسالة خطأ لعدم وجود details");
      return Scaffold(
        body: Center(child: Text('حدث خطأ في تحميل تفاصيل الطلب')),
      );
    }

    print("✅ عرض المحتوى الأساسي للشاشة");

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("سحب آمن", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // بطاقة رأسية ترحيبية بسيطة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade700, Colors.teal.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet, size: 48, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    "طلب سحب برقم #${widget.order['id']}",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // بطاقات المعلومات (إعادة تصميم box)
            _buildInfoCard(
              title: "ربحك من العملية",
              value: "${(details!['profit'] as num).toStringAsFixed(0)} IQD",
              icon: Icons.trending_up,
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: "المبلغ",
              value: "${details!['amount'] ?? widget.order['amount']} IQD",
              icon: Icons.attach_money,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: "وسيلة الدفع",
              value: details!['method'] ?? "-",
              icon: Icons.payment,
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: "رقم الحساب",
              value: details!['account_number'] ?? "-",
              icon: Icons.account_balance,
              color: Colors.purple,
            ),
            const SizedBox(height: 20),

            // الوقت المتبقي
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, size: 32, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("الوقت المتبقي", style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          formatTime(),
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      print("➕ ضغط على زر 'امنحني وقتاً إضافياً'");
                      setState(() {
                        seconds += 60;
                        print("⏱️ تم إضافة 60 ثانية، seconds الآن = $seconds");
                      });
                      if (timer == null || !timer!.isActive) {
                        print("🔄 المؤقت غير نشط، إعادة تشغيله");
                        startTimer();
                      }
                    },
                    icon: const Icon(Icons.access_time),
                    label: const Text("تمديد الوقت"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // رفع الصورة
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("إثبات التحويل", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  GestureDetector(
                    onTap: pickImage,
                    child: Container(
                      height: 160,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400, width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      ),
                      child: Center(
                        child: image == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_upload, size: 48, color: Colors.grey.shade600),
                                  const SizedBox(height: 8),
                                  Text("اضغط لاختيار صورة", style: TextStyle(color: Colors.grey.shade600)),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(image!, fit: BoxFit.cover, width: double.infinity),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (image != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: confirmProof,
                          icon: const Icon(Icons.send),
                          label: const Text("تأكيد إرسال الإثبات", style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String value, required IconData icon, required Color color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}