import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool hasPending = false;
  String pendingMessage = '';

  double realCurrent = 0;
  double realProfit = 0;
  double rate = 0;
  String walletAddress = '';

  int totalUsdt = 0;
  double currentDeduction = 0;
  double remainder = 0;

  int currentStep = 0;

  File? image;
  final txid = TextEditingController();
  bool submitting = false;
  bool _pickingImage = false; // ✅ حماية من الضغط المزدوج

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

    if (data['success'] != true) {
      setState(() {
        hasPending = true;
        pendingMessage = data['message'] ?? 'لديك طلب تسوية قائم';
        loading = false;
      });
      return;
    }

    final d = data['data'];
    double current = (d['current'] ?? 0).toDouble();
    double profit = (d['profit'] ?? 0).toDouble();
    double r = (d['rate'] ?? 0).toDouble();

    // الحساب الصحيح:
    // نقسم الحساب الجاري كاملاً على سعر الصرف (بلا كسور)
    // الباقي يرجع للحساب الجاري
    int usable = (d['usdt'] ?? 0) as int;
    double deducted = (d['local_deduction'] ?? 0).toDouble();
    double remain = (d['remainder'] ?? 0).toDouble();

    setState(() {
      realCurrent = current;
      realProfit = profit;
      rate = r;
      walletAddress = d['wallet_address'] ?? '';
      totalUsdt = usable;
      currentDeduction = deducted;
      remainder = remain;
      loading = false;
    });
  }

  Future<void> pickImage() async {
    if (_pickingImage) return; // ✅ منع الاستدعاء المزدوج
    _pickingImage = true;
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x != null && mounted) setState(() => image = File(x.path));
    } finally {
      _pickingImage = false;
    }
  }

  Future<void> submit() async {
    if (txid.text.trim().isEmpty) {
      _snack("يرجى إدخال رقم العملية TXID");
      return;
    }
    if (image == null) {
      _snack("يرجى رفع صورة الإثبات");
      return;
    }

    setState(() => submitting = true);

    final token = await AuthStorage.getToken();
    var req = http.MultipartRequest('POST', Uri.parse(Api.settlement()));
    req.headers['Authorization'] = 'Bearer $token';
    req.fields['txid'] = txid.text.trim();
    req.fields['amount_usdt'] = totalUsdt.toString();
    req.fields['local_deduction'] = currentDeduction.toString();
    req.files.add(await http.MultipartFile.fromPath('proof', image!.path));

    final res = await req.send();
    final body = await res.stream.bytesToString();
    final data = jsonDecode(body);
    if (!mounted) return;

    setState(() => submitting = false);
    _snack(data['message'] ?? 'تم الإرسال بنجاح');

    if (data['success'] == true) Navigator.pop(context);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // شاشة الانتظار
  // ─────────────────────────────────────────────
  Widget _buildPendingView() {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _appBar("التسوية"),
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
                    style: _btnStyle(),
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

  // ─────────────────────────────────────────────
  // شاشة ١: معلوماتي كوكيل
  // ─────────────────────────────────────────────
  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // صورة trc20 بدل البطاقة القديمة
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/trc20.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
          ),
          const SizedBox(height: 12),

          // بطاقة الأرقام
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow(Icons.account_balance_wallet, "حساب جاري",
                      "${realCurrent.toInt()}"),
                  const Divider(height: 20),
                  _infoRow(Icons.savings, "أرباحي", "${realProfit.toInt()}"),
                  const Divider(height: 20),
                  _infoRow(
                      Icons.currency_exchange, "سعر الصرف", "${rate.toInt()}"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // بطاقة المبلغ القابل للتسوية
          Card(
            elevation: 2,
            color: Colors.teal.shade50,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("المبلغ القابل للتسوية",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        "$totalUsdt USDT",
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${realCurrent.toInt()} ÷ ${rate.toInt()} = $totalUsdt USDT",
                    style: TextStyle(color: Colors.teal.shade700, fontSize: 13),
                  ),
                  Text(
                    "يرجع للحساب: ${remainder.toInt()}",
                    style: TextStyle(color: Colors.teal.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // تفسير
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "الحساب الجاري كاملاً ÷ سعر الصرف، الباقي يرجع للحساب",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // زر التالي بلا سهم
          ElevatedButton(
            onPressed: () => setState(() => currentStep = 1),
            style: _btnStyle(size: const Size(double.infinity, 50)),
            child: const Text("التالي",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // شاشة ٢: كيف أرسل المبلغ
  // ─────────────────────────────────────────────
  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // بطاقة USDT مضغوطة
          Card(
            elevation: 3,
            color: Colors.teal,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("يجب إرسال",
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(
                    "$totalUsdt USDT",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // تحذير TRC20
          Card(
            elevation: 2,
            color: Colors.red.shade50,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red.shade700, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    "فقط شبكة TRC20",
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // زر نسخ عنوان المحفظة + العنوان
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // زر النسخ بدل عنوان "عنوان المحفظة:"
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: walletAddress));
                        _snack("تم نسخ العنوان");
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text("نسخ عنوان المحفظة"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    walletAddress,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // خطوات
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("الخطوات:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  _step("١", "افتح محفظتك"),
                  const SizedBox(height: 8),
                  _step("٢", "أرسل $totalUsdt USDT إلى العنوان أعلاه"),
                  const SizedBox(height: 8),
                  _step("٣", "احفظ رقم العملية (TXID)"),
                ],
              ),
            ),
          ),

          const Spacer(),

          // أزرار: التالي يمين — رجوع يسار
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => currentStep = 0),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: Colors.teal),
                    foregroundColor: Colors.teal,
                  ),
                  child: const Text("رجوع"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => setState(() => currentStep = 2),
                  style: _btnStyle(size: const Size(double.infinity, 50)),
                  child: const Text("التالي",
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // شاشة ٣: إثبات الدفع
  // ─────────────────────────────────────────────
  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // TXID إلزامي
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text("رقم العملية (TXID)",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: const Text("إلزامي",
                            style: TextStyle(color: Colors.red, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: txid,
                    decoration: InputDecoration(
                      hintText: "أدخل TXID هنا...",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.teal, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // صورة الإثبات إلزامية
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text("صورة الإثبات",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: const Text("إلزامي",
                            style: TextStyle(color: Colors.red, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (image != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(image!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 8),
                  ],
                  GestureDetector(
                    onTap: pickImage,
                    child: Container(
                      height: image == null ? 80 : 40,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color:
                            image == null ? Colors.teal.shade50 : Colors.teal,
                        borderRadius: BorderRadius.circular(12),
                        border: image == null
                            ? Border.all(
                                color: Colors.teal.shade200, width: 1.5)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            image == null
                                ? Icons.upload_file
                                : Icons.check_circle,
                            color: image == null ? Colors.teal : Colors.white,
                            size: image == null ? 28 : 20,
                          ),
                          if (image == null) ...[
                            const SizedBox(height: 4),
                            const Text("اضغط لرفع الصورة",
                                style: TextStyle(
                                    color: Colors.teal, fontSize: 13)),
                            const Text("screenshot التحويل",
                                style: TextStyle(
                                    color: Colors.teal, fontSize: 11)),
                          ] else
                            const Text("تم اختيار صورة",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ملخص الطلب
          Card(
            elevation: 2,
            color: Colors.teal.shade50,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ملخص الطلب:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  _summaryRow("المبلغ:", "$totalUsdt USDT"),
                  const SizedBox(height: 4),
                  _summaryRow("الشبكة:", "TRC20"),
                  const SizedBox(height: 4),
                  _summaryRow(
                      "الخصم:", "${currentDeduction.toInt()} (من الحساب)"),
                ],
              ),
            ),
          ),

          const Spacer(),

          // أزرار: إرسال يمين — رجوع يسار
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      submitting ? null : () => setState(() => currentStep = 1),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: Colors.teal),
                    foregroundColor: Colors.teal,
                  ),
                  child: const Text("رجوع"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: submitting ? null : submit,
                  style: _btnStyle(size: const Size(double.infinity, 50)),
                  child: submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("إرسال الطلب",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Build الرئيسي
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (hasPending) return _buildPendingView();

    final titles = ["معلوماتي كوكيل", "كيف أرسل المبلغ", "إثبات الدفع"];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _appBar(titles[currentStep]),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: KeyedSubtree(
            key: ValueKey(currentStep),
            child: currentStep == 0
                ? _buildStep1()
                : currentStep == 1
                    ? _buildStep2()
                    : _buildStep3(),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────
  AppBar _appBar(String title) => AppBar(
        title: Text(title),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      );

  ButtonStyle _btnStyle({Size? size}) => ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        minimumSize: size ?? const Size(120, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
      );

  Widget _infoRow(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, color: Colors.teal, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      );

  Widget _step(String num, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.teal,
            child: Text(num,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text, style: const TextStyle(fontSize: 14)),
            ),
          ),
        ],
      );

  Widget _summaryRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.black54, fontSize: 14)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      );
}
