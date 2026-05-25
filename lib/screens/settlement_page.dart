import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../core/auth_storage.dart';

class SettlementPage extends StatefulWidget {
  const SettlementPage({super.key});

  @override
  State<SettlementPage> createState() => _SettlementPageState();
}

class _SettlementPageState extends State<SettlementPage> {
  bool loading = true;

  // ✅ حالة التسوية المعلقة
  bool hasPending = false;
  String pendingMessage = '';

  // القيم الحقيقية من السيرفر
  double realCurrent = 0;
  double realProfit = 0;
  double rate = 0;
  String walletAddress = '';

  // القيم المعروضة في الواجهة
  double displayCurrent = 0;
  double displayProfit = 0;

  File? image;
  final txid = TextEditingController();

  // متغيرات للمعاينة
  bool previewShown = false;
  int totalUsdt = 0;
  double currentDeduction = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    txid.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final token = await AuthStorage.getToken();
    final res = await http.get(
      Uri.parse(Api.settlement()),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (!mounted) return;
    final data = jsonDecode(res.body);

    // ✅ السيرفر رفض الطلب = يوجد تسوية قائمة
    if (data['success'] != true) {
      setState(() {
        hasPending = true;
        pendingMessage = data['message'] ?? 'لديك طلب تسوية قائم';
        loading = false;
      });
      return;
    }

    final d = data['data'];
    setState(() {
      realCurrent = (d['current'] ?? 0).toDouble();
      realProfit = (d['profit'] ?? 0).toDouble();
      rate = (d['rate'] ?? 0).toDouble();
      walletAddress = d['wallet_address'] ?? '';
      displayCurrent = realCurrent;
      displayProfit = realProfit;
      loading = false;
      _resetPreview();
    });
  }

  void _resetPreview() {
    previewShown = false;
    totalUsdt = 0;
    currentDeduction = 0;
    displayCurrent = realCurrent;
    displayProfit = realProfit;
  }

  void _calculatePreview() {
    if (rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("سعر الصرف غير صالح")),
      );
      return;
    }

    double transferable = realCurrent - realProfit;

    if (transferable <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لا يوجد رصيد قابل للتحويل")),
      );
      return;
    }

    int usable = (transferable / rate).floor();
    double deducted = usable * rate;
    double remaining = transferable - deducted;

    setState(() {
      currentDeduction = deducted;
      displayCurrent = remaining;
      displayProfit = realProfit;
      totalUsdt = usable;
      previewShown = true;
    });
  }

  Future<void> pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null && mounted) setState(() => image = File(x.path));
  }

  Future<void> submit() async {
    if (!previewShown) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى الضغط على 'احسب المبلغ' أولاً")),
      );
      return;
    }
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى رفع صورة الإثبات")),
      );
      return;
    }

    final token = await AuthStorage.getToken();
    var req = http.MultipartRequest('POST', Uri.parse(Api.settlement()));
    req.headers['Authorization'] = 'Bearer $token';
    req.fields['txid'] = txid.text;
    req.fields['amount_usdt'] = totalUsdt.toString();
    req.fields['current_deduction'] = currentDeduction.toString();

    req.files.add(await http.MultipartFile.fromPath('proof', image!.path));

    final res = await req.send();
    final body = await res.stream.bytesToString();
    final data = jsonDecode(body);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(data['message'] ?? 'تم الإرسال بنجاح')),
    );
    if (data['success'] == true) Navigator.pop(context);
  }

  // ✅ شاشة "لديك تسوية قائمة"
  Widget _buildPendingView() {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("التسوية"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_top,
                      size: 64, color: Colors.orange),
                  const SizedBox(height: 20),
                  Text(
                    pendingMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "يرجى الانتظار حتى تتم معالجة طلبك الحالي",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("رجوع"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ✅ عرض شاشة التسوية القائمة بدل الصفحة
    if (hasPending) return _buildPendingView();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("التسوية"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // عنوان المحفظة
          if (walletAddress.isNotEmpty)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "أرسل إلى هذا العنوان:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(walletAddress),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // بطاقة المعلومات
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow(Icons.account_balance_wallet, "الحساب الجاري",
                      "${displayCurrent.toInt()}"),
                  const SizedBox(height: 12),
                  _infoRow(
                      Icons.savings, "الأرباح", "${displayProfit.toInt()}"),
                  const SizedBox(height: 12),
                  _infoRow(
                      Icons.currency_exchange, "سعر الصرف", "${rate.toInt()}"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // زر "احسب المبلغ"
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _calculatePreview,
                    icon: const Icon(Icons.calculate),
                    label: const Text("احسب المبلغ"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (previewShown) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("يجب إرسال:",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("$totalUsdt USDT",
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // حقل TXID
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: txid,
                decoration: InputDecoration(
                  labelText: "TXID (اختياري)",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // رفع الصورة
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(image!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(image == null ? "رفع صورة" : "تم اختيار صورة"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // زر الإرسال
          ElevatedButton(
            onPressed: submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 4,
            ),
            child: const Text("إرسال",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.teal, size: 32),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
