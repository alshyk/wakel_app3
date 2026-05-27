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
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    fetchWallet();
  }

  @override
  void dispose() {
    txidController.dispose();
    super.dispose();
  }

  Future<void> fetchWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');

    final res = await http.get(
      Uri.parse(Api.post("agent/get-wallet.php")),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(res.body);

    if (data['success'] == true) {
      setState(() {
        wallet = data['data']['wallet'];
        isLoading = false;
      });
    } else {
      setState(() {
        msg = data['message'] ?? '';
        isLoading = false;
      });
    }
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() => image = File(picked.path));
    }
  }

  Future<void> submit() async {
    if (txidController.text.trim().isEmpty) {
      _showSnack("يرجى إدخال رقم العملية TXID");
      return;
    }
    if (image == null) {
      _showSnack("يرجى رفع صورة الإثبات أولاً");
      return;
    }

    setState(() => isSubmitting = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(Api.post("agent/activate-package.php")),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['package_id'] = widget.package['id'].toString();
    request.fields['txid'] = txidController.text.trim();
    request.files.add(
      await http.MultipartFile.fromPath('proof', image!.path),
    );

    final res = await request.send();
    final body = await res.stream.bytesToString();
    final data = jsonDecode(body);

    if (!mounted) return;
    setState(() => isSubmitting = false);

    _showSnack(data['message'] ?? 'تم الإرسال');

    if (data['success'] == true) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text("تفعيل الباقة",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ── رسالة خطأ ──────────────────────────────────────
          if (msg.isNotEmpty) ...[
            _alertBox(msg, isError: true),
            const SizedBox(height: 16),
          ],

          // ── صورة TRC20 ──────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/trc20.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
          ),
          const SizedBox(height: 20),

          // ── تنبيه الشبكة ─────────────────────────────────────
          _alertBox("يجب الإرسال عبر شبكة TRC20 حصراً"),
          const SizedBox(height: 20),

          // ── زر نسخ عنوان المحفظة ───────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: wallet));
                _showSnack("✅ تم نسخ عنوان المحفظة");
              },
              icon: const Icon(Icons.copy_rounded, size: 20),
              label: const Text(
                "نسخ عنوان محفظة الاستقبال",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── عنوان المحفظة قابل للتحديد ─────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SelectableText(
              wallet,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 20),

          // ── TXID إلزامي ─────────────────────────────────────
          _sectionLabel("رقم العملية TXID (إلزامي)"),
          const SizedBox(height: 8),
          _txidField(),
          const SizedBox(height: 20),

          // ── صورة الإثبات ─────────────────────────────────────
          _sectionLabel("صورة الإثبات (إلزامي)"),
          const SizedBox(height: 8),
          _proofImageCard(),
          const SizedBox(height: 32),

          // ── زر الإرسال ──────────────────────────────────────
          _submitButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF444444)),
      );

  Widget _alertBox(String text, {bool isError = false}) {
    final color = isError ? Colors.red : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.warning_amber_rounded,
            color: color.shade700,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(color: color.shade800, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _txidField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: txidController,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          hintText: "أدخل رقم العملية هنا",
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _proofImageCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: image != null ? Colors.teal : Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (image != null)
            Stack(
              children: [
                Image.file(image!,
                    height: 180, width: double.infinity, fit: BoxFit.cover),
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => image = null),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          GestureDetector(
            onTap: pickImage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              color: image != null ? Colors.teal.shade50 : Colors.white,
              child: Column(
                children: [
                  Icon(
                    image != null
                        ? Icons.check_circle_rounded
                        : Icons.upload_file_rounded,
                    color: Colors.teal,
                    size: 32,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    image != null
                        ? "تم الاختيار — اضغط لتغيير الصورة"
                        : "اضغط لرفع screenshot التحويل",
                    style: TextStyle(
                        color: Colors.teal.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return ElevatedButton(
      onPressed: isSubmitting ? null : submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.teal.shade200,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: isSubmitting
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send_rounded, size: 20),
                SizedBox(width: 8),
                Text("إرسال الطلب",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
    );
  }
}