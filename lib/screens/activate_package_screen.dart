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

  // ─── جلب المحفظة ───────────────────────────────────────────
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

  // ─── اختيار صورة ───────────────────────────────────────────
  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() => image = File(picked.path));
    }
  }

  // ─── إرسال الطلب ───────────────────────────────────────────
  Future<void> submit() async {
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

  // ─── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    final title = widget.package['title'] ?? '';
    final amount =
        double.tryParse(widget.package['amount_usdt'].toString())?.toInt() ?? 0;

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

          // ── الخطوات ─────────────────────────────────────────
          _stepsIndicator(),
          const SizedBox(height: 20),

          // ── بطاقة الباقة ─────────────────────────────────────
          _sectionLabel("الباقة المختارة"),
          const SizedBox(height: 8),
          _packageCard(title, amount),
          const SizedBox(height: 20),

          // ── تنبيه الشبكة ─────────────────────────────────────
          _alertBox("يجب الإرسال عبر شبكة TRC20 حصراً"),
          const SizedBox(height: 20),

          // ── عنوان المحفظة ──────────────────────────────────
          _sectionLabel("عنوان محفظة الاستقبال"),
          const SizedBox(height: 8),
          _walletCard(),
          const SizedBox(height: 20),

          // ── TXID ────────────────────────────────────────────
          _sectionLabel("رقم العملية TXID (اختياري)"),
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
          const SizedBox(height: 12),
          _backButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── مؤشر الخطوات الثلاث ───────────────────────────────────
  Widget _stepsIndicator() {
    final steps = ["التحويل", "TXID", "الإثبات"];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              color: Colors.teal.shade200,
            ),
          );
        }
        final idx = i ~/ 2;
        return Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.teal,
              child: Text(
                "${idx + 1}",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
            const SizedBox(height: 4),
            Text(steps[idx],
                style: TextStyle(fontSize: 11, color: Colors.teal.shade700)),
          ],
        );
      }),
    );
  }

  // ─── عنوان القسم ────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF444444)),
      );

  // ─── بطاقة الباقة ───────────────────────────────────────────
  Widget _packageCard(String title, int amount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade100),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: Colors.teal, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("قيمة الباقة",
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "$amount USDT",
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // ─── تنبيه ──────────────────────────────────────────────────
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

  // ─── بطاقة المحفظة ──────────────────────────────────────────
  Widget _walletCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          SelectableText(
            wallet,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
                fontSize: 13, fontFamily: 'monospace', letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          // زر النسخ
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: wallet));
                _showSnack("✅ تم نسخ عنوان المحفظة");
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text("نسخ العنوان"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── حقل TXID ───────────────────────────────────────────────
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
          hintText: "أدخل رقم العملية هنا (اختياري)",
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          prefixIcon:
              const Icon(Icons.tag_rounded, color: Colors.teal, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  // ─── بطاقة صورة الإثبات ─────────────────────────────────────
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
          // معاينة الصورة إن وُجدت
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
          // زر الرفع
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

  // ─── زر الإرسال ─────────────────────────────────────────────
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

  // ─── زر الرجوع ──────────────────────────────────────────────
  Widget _backButton() {
    return OutlinedButton(
      onPressed: () => Navigator.pop(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.teal,
        side: const BorderSide(color: Colors.teal),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Text("رجوع", style: TextStyle(fontSize: 15)),
    );
  }
}
