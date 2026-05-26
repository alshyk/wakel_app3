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
  // Polling — حارس مزدوج
  // ══════════════════════════════════════
  Timer? _pollTimer;
  bool _pollingActive = false;

  // ══════════════════════════════════════
  // حالة الطلب
  // ══════════════════════════════════════
  Map<String, dynamic>? _currentOrder;
  bool _orderVisible = false; // sheet مفتوح
  bool _orderBusy = false; // في شاشة إيداع/سحب
  bool _orderLocked = false; // ← التعديل 1

  // ══════════════════════════════════════
  // حالة الـ Sheet
  // ══════════════════════════════════════
  Timer? _sheetTimer;
  Timer? _delayTimer; // لإلغاء أي Future.delayed
  int _sheetSeconds = 10;
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
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _sheetTimer?.cancel();
    _delayTimer?.cancel();
    _audioPlayer.stop(); // ← التعديل 7
    _audioPlayer.dispose(); // ← التعديل 7
    super.dispose();
  }

  /// عندما يرجع التطبيق من الخلفية — لا نبدأ polling لو الـ sheet مفتوح
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_orderVisible && !_orderBusy) {
        _startPolling();
      }
    } else if (state == AppLifecycleState.paused) {
      // لما يروح للخلفية — أوقف polling فقط، لا تلمس الـ sheet
      _stopPolling();
    }
  }

  // ══════════════════════════════════════
  // تهيئة
  // ══════════════════════════════════════

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('api_token');

    if (_token == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "جلسة غير صالحة";
        _isLoading = false;
      });
      return;
    }

    await _fetchDashboard();
    if (mounted) _startPolling();
  }

  // ══════════════════════════════════════
  // Dashboard
  // ══════════════════════════════════════

  Future<void> _fetchDashboard() async {
    try {
      final res = await http.get(
        Uri.parse(Api.dashboard()),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (!mounted) return;
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() {
          _dashboard = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = data['message'] ?? "خطأ";
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "خطأ اتصال";
        _isLoading = false;
      });
    }
  }

  // ══════════════════════════════════════
  // Polling
  // ══════════════════════════════════════

  void _startPolling() {
    // شروط البدء — أي شرط ناقص يوقف كل شيء
    if (_pollingActive) return;
    if (_orderLocked) return; // ← أضف هذا السطر

    if (_orderVisible) return;
    if (_orderBusy) return;
    if (!mounted) return;

    final limit = _toDouble(_dashboard?['limit']);
    final isAvailable = _dashboard?['is_available'] == true;
    if (limit <= 0 || !isAvailable) return;

    _pollingActive = true;
    _pollTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _checkOrder());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollingActive = false;
  }

  /// يبدأ polling بعد تأخير قابل للإلغاء
  void _startPollingAfterDelay(int seconds) {
    _delayTimer?.cancel();
    _delayTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      _startPolling();
    });
  }

  Future<void> _checkOrder() async {
    // التعديل 2
    if (_orderLocked || _orderVisible || _orderBusy) return;
    if (_token == null) return;
    if (!mounted) return;

    try {
      final res = await http.get(
        Uri.parse(Api.checkOrder()),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (!mounted) return;
      if (_orderLocked || _orderVisible || _orderBusy)
        return; // فحص ثانٍ بعد الـ await

      final data = jsonDecode(res.body);
      if (data['success'] == true && data['found'] == true) {
        // وصل طلب — أوقف polling فوراً قبل أي شيء
        // التعديل 3
        _orderLocked = true;
        _stopPolling();
        _orderVisible = true;
        _currentOrder = data;

        // تشغيل الصوت بأمان
        try {
          await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
        } catch (_) {}

        // التعديل 4
        if (!mounted) {
          _orderLocked = false;
          return;
        }
        if (!_orderVisible) {
          _orderLocked = false;
          return;
        }

        _showOrderSheet(data);
      }
    } catch (e) {
      debugPrint("checkOrder error: $e");
    }
  }

  // ══════════════════════════════════════
  // Claim
  // ══════════════════════════════════════

  Future<void> _claimOrder(int orderId, String type) async {
    final res = await http.post(
      Uri.parse(Api.post("agent/claim-order.php")),
      headers: {'Authorization': 'Bearer $_token'},
      body: {'order_id': orderId.toString(), 'type': type},
    );
    // التعديل 6
    if (!mounted) return;
    final data = jsonDecode(res.body);
    if (data['success'] != true) {
      throw Exception(data['message'] ?? "فشل حجز الطلب");
    }
  }

  // ══════════════════════════════════════
  // Sheet Timer
  // ══════════════════════════════════════

  void _startSheetTimer(VoidCallback onTimeout) {
    _sheetTimer?.cancel();
    _sheetSeconds = 10;
    _sheetTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_orderVisible) {
        t.cancel();
        return;
      }
      if (_sheetSeconds > 1) {
        setState(() => _sheetSeconds--);
      } else {
        t.cancel();
        onTimeout();
      }
    });
  }

  void _closeSheetByTimeout() {
    _sheetTimer?.cancel();
    if (!mounted || !_orderVisible) return;
    Navigator.of(context).pop();
  }

  // ══════════════════════════════════════
  // Bottom Sheet
  // ══════════════════════════════════════

  void _showOrderSheet(Map<String, dynamic> order) {
    if (!mounted) return;
    if (_orderVisible && !_orderBusy) {
      // تأكيد إضافي — إذا كان sheet مفتوح فعلاً لا تفتح ثانياً
    }

    _isChecked = false;
    _isClaiming = false;
    _claimDone = false;

    _startSheetTimer(_closeSheetByTimeout);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      // منع زر الرجوع من إغلاق الـ sheet
      builder: (_) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            // تحديث آمن للـ sheet والـ state معاً
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

                    // ── عنوان ──
                    Center(
                      child: Text(
                        order['type'] == 'withdrawal' ? "طلب سحب" : "طلب إيداع",
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── تفاصيل ──
                    _detailRow("المبلغ", "${order['amount']} IQD"),
                    _detailRow("الطريقة", "${order['method'] ?? '-'}"),
                    if (order['client_name'] != null)
                      _detailRow("العميل", "${order['client_name']}"),

                    const Spacer(),

                    // ── عداد ──
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
                        value: _sheetSeconds / 10,
                        backgroundColor: Colors.grey.shade200,
                        color: _isChecked ? Colors.teal : Colors.redAccent,
                        minHeight: 6,
                      ),
                    ],

                    // ── رسالة الحجز ──
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

                    // ── Checkbox ──
                    GestureDetector(
                      onTap: (_isChecked || _isClaiming || _claimDone)
                          ? null
                          : () async {
                              _sheetTimer?.cancel();
                              update(() => _isClaiming = true);

                              try {
                                await _claimOrder(order['id'] as int,
                                    order['type'] as String);

                                if (!mounted) return;
                                update(() {
                                  _isChecked = true;
                                  _isClaiming = false;
                                  _claimDone = true;
                                });
                                _startSheetTimer(_closeSheetByTimeout);
                              } catch (e) {
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

                    // ── زر المتابعة ──
                    GestureDetector(
                      onTap: _claimDone
                          ? () async {
                              _sheetTimer?.cancel();
                              _delayTimer?.cancel();

                              if (_currentOrder == null || !mounted) return;

                              final orderData =
                                  Map<String, dynamic>.from(_currentOrder!);
                              final orderType = orderData['type'] as String;

                              // ضع الوكيل مشغول قبل pop لمنع race condition مع whenComplete
                              _orderBusy = true;
                              _orderVisible = false;
                              _currentOrder = null;

                              if (mounted) Navigator.of(context).pop();

                              await Future.delayed(
                                  const Duration(milliseconds: 300));
                              if (!mounted) return;

                              if (orderType == 'deposit') {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          DepositScreen(order: orderData)),
                                );
                              } else {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          WithdrawalScreen(order: orderData)),
                                );
                              }

                              // رجع من الشاشة
                              if (!mounted) return;
                              _orderBusy = false;
                              _startPollingAfterDelay(120);
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
      // التعديل 5
      _orderLocked = false;
      _sheetTimer?.cancel();

      // لو الوكيل ضغط متابعة — _orderBusy = true بالفعل، لا نتدخل
      // لو timeout أو أي سبب آخر — نعيد الضبط ونبدأ polling
      if (!_orderBusy) {
        _orderVisible = false;
        _currentOrder = null;
        _isChecked = false;
        _isClaiming = false;
        _claimDone = false;
        _startPollingAfterDelay(120);
      }
    });
  }

  // ══════════════════════════════════════
  // Toggle Available
  // ══════════════════════════════════════

  Future<void> _toggleAvailable() async {
    try {
      final res = await http.post(
        Uri.parse(Api.radar()),
        headers: {'Authorization': 'Bearer $_token'},
        body: {'toggle_available': '1'},
      );
      debugPrint("toggleAvailable: ${res.statusCode}");
      if (!mounted) return;
      await _fetchDashboard();
      if (!mounted) return;

      if (_dashboard?['is_available'] == true) {
        _startPolling();
      } else {
        _stopPolling();
        _delayTimer?.cancel(); // إلغاء أي delayed polling
      }
    } catch (e) {
      debugPrint("toggleAvailable error: $e");
    }
  }

  // ══════════════════════════════════════
  // Logout
  // ══════════════════════════════════════

  Future<void> _logout() async {
    _stopPolling();
    _delayTimer?.cancel();
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

              // ── مركز التحكم ──
              ElevatedButton(
                onPressed: () => Navigator.push(
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

              // ── بطاقة الأرقام ──
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

              // ── نص الحالة ──
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

              // ── زر مفتوح/مغلق ──
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
