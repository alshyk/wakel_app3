import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'login_screen.dart';
import '../api.dart';
import 'deposit_screen.dart';
import 'withdrawal_screen.dart';
import 'raise_limit_screen.dart';
import 'test_screen.dart';
import 'gate_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with WidgetsBindingObserver {
  // ══════════════════════════════════════
  // بيانات أساسية
  // ══════════════════════════════════════
  String? _token;
  Map<String, dynamic>? _dashboard;
  bool _isLoading = true;
  String _errorMessage = "";
  final NumberFormat _formatter = NumberFormat('#,###', 'en');

  // ══════════════════════════════════════
  // Polling — تايمر واحد يتحكم بكل شيء
  // ══════════════════════════════════════
  Timer? _pollTimer;
  bool _pollingActive = false;

  // ══════════════════════════════════════
  // حالة الطلب
  // ══════════════════════════════════════
  Map<String, dynamic>? _currentOrder;
  bool _orderVisible = false; // sheet مفتوح
  bool _orderBusy = false; // في شاشة إيداع/سحب
  bool _orderLocked = false;

  // ══════════════════════════════════════
  // حالة الـ Sheet
  // ══════════════════════════════════════
  Timer? _sheetTimer;
  Timer? _delayTimer;
  int _sheetSeconds = 60;
  bool _isChecked = false;
  bool _isClaiming = false;
  bool _claimDone = false;

  // ══════════════════════════════════════
  // متفرقات
  // ══════════════════════════════════════
  bool _isToggling = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ══════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════

  @override
  void initState() {
    super.initState();
    print("🟢 initState: بدء تهيئة الشاشة");
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    print("🔴 dispose: تنظيف الشاشة");
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling(); // يطفئ pollTimer و delayTimer
    _sheetTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("📱 didChangeAppLifecycleState: $state");
    if (state == AppLifecycleState.resumed) {
      if (!_orderVisible && !_orderBusy) {
        print("✅ التطبيق عاد من الخلفية → بدء polling");
        _startPolling();
      } else {
        print("⚠️ التطبيق عاد لكن الـ sheet مفتوح أو مشغول → لا نبدأ polling");
      }
    } else if (state == AppLifecycleState.paused) {
      print("⏸️ التطبيق ذهب للخلفية → إيقاف polling");
      _stopPolling();
    }
  }

  // ══════════════════════════════════════
  // تهيئة
  // ══════════════════════════════════════

  Future<void> _init() async {
    print("🟡 _init: بدء التهيئة");
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('api_token');
    print("🔑 التوكن: ${_token != null ? 'موجود' : 'غير موجود'}");

    if (_token == null) {
      print("❌ لا يوجد توكن → عرض خطأ");
      if (!mounted) return;
      setState(() {
        _errorMessage = "جلسة غير صالحة";
        _isLoading = false;
      });
      return;
    }

    print("✅ التوكن موجود → جلب لوحة المعلومات");
    await _fetchDashboard();
    if (mounted) {
      _startPolling(); // يبدأ التايمر الوحيد
    }
  }

  // ══════════════════════════════════════
  // Dashboard
  // ══════════════════════════════════════

  Future<void> _fetchDashboard() async {
    print("🟡 _fetchDashboard: بدء جلب لوحة المعلومات");
    try {
      final res = await http.get(
        Uri.parse(Api.dashboard()),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (!mounted) return;
      final data = jsonDecode(res.body);
      print("📡 Response dashboard: ${res.statusCode} | body: ${res.body}");
      if (data['success'] == true) {
        print("✅ تم جلب لوحة المعلومات بنجاح");
        setState(() {
          _dashboard = data;
          _isLoading = false;
        });
      } else {
        print("❌ فشل جلب لوحة المعلومات: ${data['message']}");
        setState(() {
          _errorMessage = data['message'] ?? "خطأ";
          _isLoading = false;
        });
      }
    } catch (e) {
      print("🔥 خطأ اتصال في dashboard: $e");
      if (!mounted) return;
      setState(() {
        _errorMessage = "خطأ اتصال";
        _isLoading = false;
      });
    }
  }

  // ══════════════════════════════════════
  // Polling - التايمر الوحيد
  // ══════════════════════════════════════

  void _startPolling() {
    print("🟡 _startPolling: بدء polling (يطفئ كل شيء أولاً)");
    // أطفئ كل شيء أولاً
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollingActive = false;
    _delayTimer?.cancel();
    _delayTimer = null;

    if (_orderLocked) {
      print("⚠️ _orderLocked == true → إرجاع");
      return;
    }
    if (_orderVisible) {
      print("⚠️ _orderVisible == true → إرجاع");
      return;
    }
    if (_orderBusy) {
      print("⚠️ _orderBusy == true → إرجاع");
      return;
    }
    if (!mounted) {
      print("⚠️ !mounted → إرجاع");
      return;
    }

    final limit = _toDouble(_dashboard?['limit']);
    final isAvailable = _dashboard?['is_available'] == true;
    print("💰 limit = $limit, isAvailable = $isAvailable");

    if (limit <= 0 || !isAvailable) {
      print("⛔ limit <=0 أو غير متاح → لن نبدأ polling");
      return;
    }

    print("✅ بدء polling كل 30 ثانية (قابل للتعديل لـ 500 لاحقاً)");
    _pollingActive = true;
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30), // بعد التطوير سيصبح 500
      (_) => _checkOrder(),
    );
  }

  void _stopPolling() {
    print("🛑 _stopPolling: إيقاف التايمر الوحيد وتنظيفه");
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollingActive = false;
    _delayTimer?.cancel();
    _delayTimer = null;
  }

  void _startPollingAfterDelay(int seconds) {
    print(
        "⏰ _startPollingAfterDelay: إطفاء الكل ثم بدء polling بعد $seconds ثانية");
    // أطفئ كل شيء أولاً
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollingActive = false;
    _delayTimer?.cancel();

    _delayTimer = Timer(Duration(seconds: seconds), () {
      print("⏰ بعد $seconds ثانية → بدء polling");
      if (!mounted) return;
      _startPolling();
    });
  }

  Future<void> _checkOrder() async {
    print("🔍 _checkOrder: بدء فحص الطلبات");
    if (_orderLocked || _orderVisible || _orderBusy) {
      print("⚠️ _checkOrder: تخطي بسبب حالة الطلب");
      return;
    }
    if (_token == null || !mounted) return;

    // ① فحص حالة الوكيل أولاً
    final statusOk = await _checkAgentStatus();
    if (!statusOk) return;

    // ② فحص الطلبات
    try {
      final res = await http.get(
        Uri.parse(Api.checkOrder()),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (!mounted) return;
      if (_orderLocked || _orderVisible || _orderBusy) {
        print("⚠️ _checkOrder بعد الـ await: حالة تغيرت → تخطي");
        return;
      }

      final data = jsonDecode(res.body);
      print("📡 checkOrder response: ${res.statusCode} | body: ${res.body}");

      if (data['success'] == true && data['found'] == true) {
        print("✅ تم العثور على طلب جديد: id=${data['id']}");
        _orderLocked = true;
        _stopPolling(); // يطفئ التايمر فوراً

        _orderVisible = true;
        _currentOrder = data;

        print("🔊 تشغيل صوت الإشعار");
        try {
          await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
        } catch (e) {
          print("⚠️ فشل تشغيل الصوت: $e");
        }

        if (!mounted) {
          print("❌ _checkOrder: !mounted بعد تشغيل الصوت → إلغاء القفل");
          _orderLocked = false;
          return;
        }
        if (!_orderVisible) {
          print("❌ _checkOrder: _orderVisible أصبح false → إلغاء القفل");
          _orderLocked = false;
          return;
        }

        print("📢 فتح Bottom Sheet للطلب");
        _showOrderSheet(data);
      } else {
        print("ℹ️ لا يوجد طلب جديد");
      }
    } catch (e) {
      print("🔥 _checkOrder error: $e");
    }
  }

  // ══════════════════════════════════════
  // فحص حالة الوكيل وإرجاع bool
  // ══════════════════════════════════════
  Future<bool> _checkAgentStatus() async {
    if (!mounted) return false;
    try {
      final res = await http.get(
        Uri.parse(Api.me()),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (!mounted) return false;
      final data = jsonDecode(res.body);
      if (data['success'] != true) return true; // خطأ سيرفر - كمل

      final d = data['data'];
      final status = d['status'] ?? '';
      final hasDispute = d['has_open_dispute'] == true;
      final hasPayment = d['has_payment_methods'] == true;

      if (status != 'active' || hasDispute || !hasPayment) {
        print("⚠️ _checkAgentStatus: حالة غير نشطة → الرجوع إلى GateScreen");
        _stopPolling();
        _sheetTimer?.cancel();
        _orderVisible = false;
        _orderLocked = false;
        _orderBusy = false;
        if (!mounted) return false;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const GateScreen()),
          (route) => false,
        );
        return false;
      }
      return true;
    } catch (_) {
      return true; // خطأ شبكة - كمل
    }
  }

  // ══════════════════════════════════════
  // Claim
  // ══════════════════════════════════════

  Future<void> _claimOrder(int orderId, String type) async {
    print("🟡 _claimOrder: بدء حجز الطلب $orderId (نوع: $type)");
    final res = await http.post(
      Uri.parse(Api.post("agent/claim-order.php")),
      headers: {'Authorization': 'Bearer $_token'},
      body: {'order_id': orderId.toString(), 'type': type},
    );
    if (!mounted) return;
    final data = jsonDecode(res.body);
    print("📡 claimOrder response: ${res.statusCode} | body: ${res.body}");
    if (data['success'] != true) {
      print("❌ فشل حجز الطلب: ${data['message']}");
      throw Exception(data['message'] ?? "فشل حجز الطلب");
    }
    print("✅ تم حجز الطلب بنجاح");
  }

  // ══════════════════════════════════════
  // Sheet Timer
  // ══════════════════════════════════════

  void _startSheetTimer(VoidCallback onTimeout) {
    print("🟡 _startSheetTimer: بدء مؤقت الـ sheet (60 ثانية)");
    _sheetTimer?.cancel();
    _sheetSeconds = 60;
    _sheetTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_sheetSeconds > 1) {
        setState(() => _sheetSeconds--);
      } else {
        print("⏰ انتهاء وقت الـ sheet → إغلاق");
        t.cancel();
        onTimeout();
      }
    });
  }

  void _closeSheetByTimeout() {
    print("🔄 _closeSheetByTimeout: إغلاق الـ sheet بسبب انتهاء الوقت");
    _sheetTimer?.cancel();
    if (!mounted || !_orderVisible) return;
    Navigator.of(context).pop();
  }

  // ══════════════════════════════════════
  // Bottom Sheet
  // ══════════════════════════════════════

  void _showOrderSheet(Map<String, dynamic> order) {
    print("📢 _showOrderSheet: فتح الـ sheet للطلب رقم ${order['id']}");
    if (!mounted) return;

    _isChecked = false;
    _isClaiming = false;
    _claimDone = false;

    _startSheetTimer(_closeSheetByTimeout);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            void update(VoidCallback fn) {
              if (!mounted) return;
              setState(() {
                fn();
              });
              if (ctx.mounted) setSheet(() {});
            }

            return FractionallySizedBox(
              heightFactor: 0.95,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        order['type'] == 'withdrawal' ? "طلب سحب" : "طلب إيداع",
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _detailRow("المبلغ", "${order['amount']} IQD"),
                    _detailRow("الطريقة", "${order['method'] ?? '-'}"),
                    if (order['client_name'] != null)
                      _detailRow("العميل", "${order['client_name']}"),
                    const Spacer(),
                    if (!_claimDone) ...[
                      Center(
                        child: Text(
                          _isChecked
                              ? "المتابعة خلال $_sheetSeconds ثانية"
                              : "ينتهي العرض خلال $_sheetSeconds ثانية",
                          style: TextStyle(
                            fontSize: 14,
                            color: _isChecked
                                ? Colors.teal.shade700
                                : Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _sheetSeconds / 60,
                        backgroundColor: Colors.grey.shade200,
                        color: _isChecked ? Colors.teal : Colors.redAccent,
                        minHeight: 6,
                      ),
                    ],
                    if (_claimDone)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.teal),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline,
                                color: Colors.teal, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "تم حجز الطلب — جاهز للمتابعة",
                              style: TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: (_isChecked || _isClaiming || _claimDone)
                          ? null
                          : () async {
                              print("🖱️ المستخدم ضغط على مربع التأكيد");
                              _sheetTimer?.cancel();
                              update(() => _isClaiming = true);

                              try {
                                await _claimOrder(order['id'] as int,
                                    order['type'] as String);
                                print("✅ حجز الطلب بنجاح → تحديث الواجهة");
                                if (!mounted) return;
                                update(() {
                                  _isChecked = true;
                                  _isClaiming = false;
                                  _claimDone = true;
                                });
                                _startSheetTimer(_closeSheetByTimeout);
                              } catch (e) {
                                print("❌ فشل حجز الطلب: $e");
                                if (!mounted) return;
                                update(() => _isClaiming = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("فشل الحجز: $e")),
                                );
                                _startSheetTimer(_closeSheetByTimeout);
                              }
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isChecked
                              ? Colors.teal.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                _isChecked ? Colors.teal : Colors.grey.shade400,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            _isClaiming
                                ? const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: Colors.teal),
                                  )
                                : AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: _isChecked
                                          ? Colors.teal
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: _isChecked
                                            ? Colors.teal
                                            : Colors.grey.shade400,
                                        width: 2,
                                      ),
                                    ),
                                    child: _isChecked
                                        ? const Icon(Icons.check_rounded,
                                            color: Colors.white, size: 18)
                                        : null,
                                  ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isClaiming
                                    ? "جاري حجز الطلب..."
                                    : _isChecked
                                        ? "تم تأكيد الاستعداد"
                                        : "ضع علامة صح للاستعداد",
                                style: TextStyle(
                                  fontSize: 15,
                                  color:
                                      _isChecked ? Colors.teal : Colors.black87,
                                  fontWeight: _isChecked
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _claimDone
                          ? () async {
                              print("🖱️ المستخدم ضغط على زر متابعة");
                              _sheetTimer?.cancel();
                              _delayTimer?.cancel();

                              if (_currentOrder == null || !mounted) return;

                              final orderData =
                                  Map<String, dynamic>.from(_currentOrder!);
                              final orderType = orderData['type'] as String;

                              _orderBusy = true;
                              _orderVisible = false;
                              _currentOrder = null;

                              if (mounted) Navigator.of(context).pop();

                              await Future.delayed(
                                  const Duration(milliseconds: 300));
                              if (!mounted) return;

                              if (orderType == 'deposit') {
                                print("💰 التوجيه إلى شاشة الإيداع");
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          DepositScreen(order: orderData)),
                                );
                              } else {
                                print("💰 التوجيه إلى شاشة السحب");
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          WithdrawalScreen(order: orderData)),
                                );
                              }

                              if (!mounted) return;
                              print(
                                  "✅ رجوع من شاشة الإيداع/السحب → إعادة تشغيل polling بعد تأخير");
                              _orderBusy = false;
                              _orderLocked = false; // ← يحل المشكلتين

                              _startPollingAfterDelay(20);
                            }
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: double.infinity,
                        height: 62,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _claimDone
                                      ? const Color(0xFF085041)
                                      : Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 56,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                decoration: BoxDecoration(
                                  color: _claimDone
                                      ? Colors.teal
                                      : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "متابعة",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: _claimDone
                                        ? Colors.white
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ).whenComplete(() {
      print("🗑️ whenComplete: تم إغلاق الـ sheet");
      _sheetTimer?.cancel();

      if (!_orderBusy) {
        print(
            "🔄 whenComplete: إعادة ضبط الحالة وإعادة تشغيل polling بعد تأخير");
        _orderLocked = false;
        _orderVisible = false;
        _currentOrder = null;
        _isChecked = false;
        _isClaiming = false;
        _claimDone = false;
        _startPollingAfterDelay(20);
      } else {
        print("⚠️ whenComplete: _orderBusy == true → لن نعيد الضبط الآن");
      }
    });
  }

  // ══════════════════════════════════════
  // Toggle Available
  // ══════════════════════════════════════

  Future<void> _toggleAvailable() async {
    print("🔄 _toggleAvailable: تبديل حالة التوفر");
    try {
      final res = await http.post(
        Uri.parse(Api.radar()),
        headers: {'Authorization': 'Bearer $_token'},
        body: {'toggle_available': '1'},
      );
      print(
          "📡 toggleAvailable response: ${res.statusCode} | body: ${res.body}");
      if (!mounted) return;
      await _fetchDashboard();
      if (!mounted) return;

      if (_dashboard?['is_available'] == true) {
        print("✅ أصبح متاحاً → بدء polling");
        _startPolling();
      } else {
        print("⏸️ أصبح غير متاح → إيقاف polling وإلغاء أي تأخير");
        _stopPolling();
      }
    } catch (e) {
      print("🔥 _toggleAvailable error: $e");
    }
  }

  // ══════════════════════════════════════
  // Logout
  // ══════════════════════════════════════

  Future<void> _logout() async {
    print("🚪 _logout: تسجيل الخروج");
    _stopPolling();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ══════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  String _format(num n) => _formatter.format(n);

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 16, color: Colors.black54)),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // Build
  // ══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(body: Center(child: Text(_errorMessage)));
    }

    final balance = _toDouble(_dashboard?['balance']);
    final profit = _toDouble(_dashboard?['profit']);
    final limit = _toDouble(_dashboard?['limit']);
    final remaining = _toDouble(_dashboard?['remaining']);
    final currency = _dashboard?['currency'] ?? 'IQD';
    final isAvailable = _dashboard?['is_available'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: isAvailable
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                "أوقف استلام الطلبات أولاً قبل الدخول لمركز التحكم"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TestScreen()),
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("مركز التحكم"),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text("الحساب الجاري: ${_format(balance)} $currency"),
                      Text("الأرباح: ${_format(profit)} $currency"),
                      Text("السقف: ${_format(limit)} $currency"),
                      Text("المتبقي: ${_format(remaining)} $currency"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                isAvailable
                    ? "🟢 أنت الآن متصل — سيتم إرسال الطلبات إليك"
                    : "⏸️ أنت غير متاح حالياً — لن تصلك أي طلبات",
                style: TextStyle(
                  fontSize: 13,
                  color:
                      isAvailable ? Colors.teal.shade700 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isToggling
                    ? null
                    : () async {
                        if (isAvailable) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text(
                                "إيقاف استلام الطلبات",
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              content: const Text(
                                "هل أنت متأكد من إيقاف استلام الطلبات؟\nلن تصلك أي طلبات جديدة.",
                                textAlign: TextAlign.center,
                              ),
                              actionsAlignment: MainAxisAlignment.center,
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text("لا",
                                      style: TextStyle(color: Colors.grey)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: const Text("إيقاف"),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          if (!mounted) return;
                        }

                        if (mounted) setState(() => _isToggling = true);
                        await _toggleAvailable();
                        if (mounted) setState(() => _isToggling = false);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 160,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isToggling
                        ? Colors.grey.shade400
                        : isAvailable
                            ? const Color(0xFF1A56DB)
                            : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isAvailable) ...[
                        const Text("مفتوح",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                              color: Colors.white24, shape: BoxShape.circle),
                          child: const Icon(Icons.power_settings_new,
                              color: Colors.white, size: 22),
                        ),
                      ] else ...[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              shape: BoxShape.circle),
                          child: Icon(Icons.power_settings_new,
                              color: Colors.grey.shade600, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isToggling ? "..." : "مغلق",
                          style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
