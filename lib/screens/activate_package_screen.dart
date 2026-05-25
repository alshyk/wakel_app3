import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';







class ActivatePackageScreen extends StatefulWidget {
  final Map package;

  const ActivatePackageScreen({super.key, required this.package});

  @override
  State<ActivatePackageScreen> createState() => _ActivatePackageScreenState();
}

class _ActivatePackageScreenState extends State<ActivatePackageScreen> {
  final txidController = TextEditingController();
  File? image;
  String wallet = "";
  String msg = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    print("ACTIVATE SCREEN OPENED"); // 👈 هنا

    fetchWallet();
  }

  // =========================
  // جلب المحفظة
  // =========================
  Future<void> fetchWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');

    final res = await http.get(
      Uri.parse(Api.post("agent/get-wallet.php")),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(res.body);

    // ✅ طباعة الرد بالكامل لرؤية "مرحباً"
    print("🔍 Response from get-wallet.php: $data");
    // طباعة حقل message إذا وجد
    if (data['message'] != null) {
      print("📢 Message: ${data['message']}");
    }
    // إذا كانت هناك كلمة "مرحباً" في أي حقل، اطبعها
    if (data.toString().contains('مرحباً')) {
      print("🎉 تم العثور على كلمة 'مرحباً' في الرد");
    }

    if (data['success'] == true) {
      setState(() {
        wallet = data['data']['wallet'];
        isLoading = false;
      });
    } else {
      setState(() {
        msg = data['message'] ?? '';
        isLoading = false; // 👈 هذا أهم سطر
      });
    }
  }

  // =========================
  // اختيار صورة
  // =========================
  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        image = File(picked.path);
      });
    }
  }

  // =========================
  // إرسال الطلب
  // =========================
  Future<void> submit() async {
    if (image == null) {
      setState(() => msg = "ارفع صورة الإثبات");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(Api.post("agent/activate-package.php")),
    );

    request.headers['Authorization'] = 'Bearer $token';

    request.fields['package_id'] = widget.package['id'].toString();
    request.fields['txid'] = txidController.text;

    request.files.add(
      await http.MultipartFile.fromPath('proof', image!.path),
    );

    final res = await request.send();
    final body = await res.stream.bytesToString();
    final data = jsonDecode(body);

    setState(() {
      msg = data['message'] ?? '';
    });

    if (data['success'] == true) {
      setState(() {
        txidController.clear();
        image = null;
      });

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.package['title'] ?? '';
    final amount =
        double.tryParse(widget.package['amount_usdt'].toString())?.toInt() ?? 0;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("تفعيل الباقة"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // رسالة
            if (msg.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(msg),
              ),

            // جدول الباقة والقيمة
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text("الباقة",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text("\u200F$title",
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text("القيمة",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text("\u200F$amount USDT",
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // تنبيه الشبكة
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "يجب الإرسال عبر شبكة TRC20 حصراً. أي تحويل على شبكة أخرى لن يتم قبوله.",
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text("حوّل المبلغ إلى العنوان التالي:",
                style: TextStyle(fontSize: 16)),

            const SizedBox(height: 8),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SelectableText(
                      wallet,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: wallet));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("تم نسخ العنوان")),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text("نسخ العنوان"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          side: const BorderSide(color: Colors.teal),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // TXID (اختياري)
            const Text("TXID (اختياري)",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: txidController,
              decoration: InputDecoration(
                hintText: "يمكنك تركه فارغاً",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // صورة
            const Text("صورة الإثبات",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (image != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  image!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.image),
              label: const Text("اختيار صورة"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            if (image != null) const SizedBox(height: 8),
            if (image != null)
              Text("تم اختيار صورة",
                  style: TextStyle(color: Colors.green.shade700)),

            const SizedBox(height: 20),

            // إرسال
            ElevatedButton(
              onPressed: submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("إرسال الطلب"),
            ),

            const SizedBox(height: 10),

            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("رجوع"),
            ),
          ],
        ),
      ),
    );
  }
}
