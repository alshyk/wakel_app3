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

class _OrdersScreenState extends State<OrdersScreen> {
  String? token;
  Map<String, dynamic>? dashboard;

  bool isLoading = true;
  String errorMessage = "";

  Timer? pollTimer;

  final formatter = NumberFormat('#,###', 'en');

  Map<String, dynamic>? currentOrder;
  bool isOrderVisible = false;
  bool isDialogOpen = false;
  Set<int> seenOrders = {};
  bool isProcessing = false;
  bool isToggling = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // حالة الـ bottom sheet
  Timer? _sheetTimer;
  int _sheetSeconds = 10;
  bool _isChecked = false;
  bool _isClaiming = false;
  bool _claimDone = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    _sheetTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String format(num n) => formatter.format(n);

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('api_token');

    if (token == null) {
      if (!mounted) return;
      setState(() {
        errorMessage = "جلسة غير صالحة";
        isLoading = false;
      });
      return;
    }

    await fetchDashboard();
    startPolling();
  }

  Future<void> fetchDashboard() async {
    try {
      final url = Api.dashboard();
      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        setState(() {
          dashboard = data;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = data['message'];
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = "خطأ اتصال";
        isLoading = false;
      });
    }
  }

  void startPolling() {
    pollTimer?.cancel();
    final limit = _toDouble(dashboard?['limit']);
    final isAvailable = dashboard?['is_available'] == true;

    if (limit > 0 && isAvailable) {
      pollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => checkOrder(),
      );
    }
  }

  Future<void> checkOrder() async {
    if (token == null || isOrderVisible || isDialogOpen) return;

    try {
      final url = Api.checkOrder();
      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      final data = jsonDecode(res.body);

      if (data['success'] == true && data['found'] == true) {
        final newId = data['id'];
        if (seenOrders.contains(newId)) return;

        isOrderVisible = true;
        seenOrders.add(newId);
        currentOrder = data;
        pollTimer?.cancel();

        await _audioPlayer.play(AssetSource('sounds/notification.mp3'));

        if (!isDialogOpen) showOrderDialog(data);
      }
    } catch (e) {
      print("🔥 checkOrder error: $e");
    }
  }

  Future<void> claimOrder(int orderId, String type) async {
    final url = Api.post("agent/claim-order.php");
    final res = await http.post(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
      body: {'order_id': orderId.toString(), 'type': type},
    );
    if (!mounted) return;
    final data = jsonDecode(res.body);
    if (data['success'] != true) {
      throw Exception(data['message'] ?? "فشل في المطالبة بالطلب");
    }
  }

  void _startSheetTimer(VoidCallback onTimeout) {
    _sheetTimer?.cancel();
    _sheetSeconds = 10;
    _sheetTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !isDialogOpen) {
        t.cancel();
        return;
      }
      if (_sheetSeconds > 0) {
        setState(() => _sheetSeconds--);
      } else {
        t.cancel();
        onTimeout();
      }
    });
  }

  void _closeSheet() {
    _sheetTimer?.cancel();
    if (isDialogOpen && mounted) {
      Navigator.pop(context);
    }
  }

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

  void showOrderDialog(Map<String, dynamic> order) {
    if (isDialogOpen) return;
    isDialogOpen = true;

    _isChecked = false;
    _isClaiming = false;
    _claimDone = false;

    _startSheetTimer(_closeSheet);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
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
                    _detailRow("الطريقة", "${order['method']}"),
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
                        value: _sheetSeconds / 10,
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
                              _sheetTimer?.cancel();
                              setSheet(() => _isClaiming = true);
                              // ✅ التعديل المطلوب
                              if (mounted) setState(() => _isClaiming = true);
                              final orderId = order['id'] as int;
                              final orderType = order['type'] as String;
                              try {
                                await claimOrder(orderId, orderType);
                                setSheet(() {
                                  _isChecked = true;
                                  _isClaiming = false;
                                  _claimDone = true;
                                });
                                setState(() {
                                  _isChecked = true;
                                  _isClaiming = false;
                                  _claimDone = true;
                                });
                                _startSheetTimer(_closeSheet);
                              } catch (e) {
                                setSheet(() => _isClaiming = false);
                                setState(() => _isClaiming = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("فشل الحجز: $e")),
                                  );
                                }
                                _startSheetTimer(_closeSheet);
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
                      onTap: (_claimDone && !isProcessing)
                          ? () async {
                              _sheetTimer?.cancel();
                              if (currentOrder == null) return;
                              if (mounted) setState(() => isProcessing = true);
                              final orderData =
                                  Map<String, dynamic>.from(currentOrder!);
                              final orderType = orderData['type'] as String;
                              if (mounted) Navigator.pop(context);
                              isOrderVisible = false;
                              currentOrder = null;
                              isDialogOpen = false;
                              await Future.delayed(
                                  const Duration(milliseconds: 300));
                              if (!mounted) return;
                              if (orderType == 'deposit') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DepositScreen(order: orderData),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        WithdrawalScreen(order: orderData),
                                  ),
                                );
                              }
                              if (mounted) setState(() => isProcessing = false);
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
                                child: isProcessing
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5),
                                      )
                                    : Text(
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
        );
      },
    ).whenComplete(() {
      _sheetTimer?.cancel();
      isOrderVisible = false;
      isDialogOpen = false;
      _isChecked = false;
      _isClaiming = false;
      _claimDone = false;
      final limit = _toDouble(dashboard?['limit']);
      if (limit > 0 && dashboard?['is_available'] == true) {
        startPolling();
      }
    });
  }

  Future<void> toggleAvailable() async {
    final url = Api.radar();
    final res = await http.post(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
      body: {'toggle_available': '1'},
    );
    print("📡 toggleAvailable: ${res.statusCode}");
    await fetchDashboard();
  }

  void openRaiseLimit() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const RaiseLimitScreen()));
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (errorMessage.isNotEmpty) {
      return Scaffold(body: Center(child: Text(errorMessage)));
    }

    final balance = _toDouble(dashboard?['balance']);
    final profit = _toDouble(dashboard?['profit']);
    final limit = _toDouble(dashboard?['limit']);
    final remaining = _toDouble(dashboard?['remaining']);
    final currency = dashboard?['currency'] ?? 'IQD';
    final isAvailable = dashboard?['is_available'] == true;

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
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TestScreen())),
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
                      Text("الحساب الجاري: ${format(balance)} $currency"),
                      Text("الأرباح: ${format(profit)} $currency"),
                      Text("السقف: ${format(limit)} $currency"),
                      Text("المتبقي: ${format(remaining)} $currency"),
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
                onTap: isToggling
                    ? null
                    : () async {
                        final isAvailableNow =
                            dashboard?['is_available'] == true;
                        if (isAvailableNow) {
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
                        setState(() => isToggling = true);
                        try {
                          await toggleAvailable();
                          startPolling();
                          if (dashboard?['is_available'] != true) {
                            pollTimer?.cancel();
                          }
                        } finally {
                          if (mounted) setState(() => isToggling = false);
                        }
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 160,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isToggling
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
                          isToggling ? "..." : "مغلق",
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
