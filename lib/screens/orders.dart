import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
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
  bool isProcessing = false; // ✅ منع الضغط المتكرر

  Timer? _dialogTimer;
  int _dialogSeconds = 10;

  @override
  void initState() {
    super.initState();
    print("🟢 initState: بدء تهيئة OrdersScreen");
    init();
  }

  @override
  void dispose() {
    print("🔴 dispose: تنظيف OrdersScreen");
    pollTimer?.cancel();
    _dialogTimer?.cancel();
    super.dispose();
  }

  String format(num n) {
    String result = formatter.format(n);
    print("📊 format: $n -> $result");
    return result;
  }

  Future<void> logout(BuildContext context) async {
    print("🚪 logout: بدء تسجيل الخروج");
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
    print("✅ تم حذف api_token من SharedPreferences");
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    print("📱 تم التوجيه إلى شاشة LoginScreen");
  }

  Future<void> init() async {
    print("🟡 init: بدء عملية التهيئة");
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('api_token');
    print("🔑 التوكن المسترجع: $token");

    if (token == null) {
      print("❌ لا يوجد توكن -> تعيين رسالة خطأ");
      if (!mounted) return;
      setState(() {
        errorMessage = "جلسة غير صالحة";
        isLoading = false;
      });
      print("⚠️ errorMessage = جلسة غير صالحة, isLoading = false");
      return;
    }

    print("✅ التوكن موجود، جلب لوحة المعلومات...");
    await fetchDashboard();
    print("🔄 بدء الـ polling بعد جلب البيانات");
    startPolling();
  }

  Future<void> fetchDashboard() async {
    print("🟡 fetchDashboard: بدء طلب لوحة المعلومات");
    try {
      final url = Api.dashboard();
      print("🔗 URL: $url");
      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      print("📡 Response status: ${res.statusCode}");
      final data = jsonDecode(res.body);
      print("📄 Response body: ${res.body}");

      if (data['success'] == true) {
        print("✅ تم جلب البيانات بنجاح");
        if (!mounted) return;
        setState(() {
          dashboard = data;
          isLoading = false;
        });
        print("📦 dashboard تم تخزينه: $dashboard");
      } else {
        print("❌ فشل جلب البيانات: ${data['message']}");
        if (!mounted) return;
        setState(() {
          errorMessage = data['message'];
          isLoading = false;
        });
      }
    } catch (e) {
      print("🔥 خطأ اتصال: $e");
      if (!mounted) return;
      setState(() {
        errorMessage = "خطأ اتصال";
        isLoading = false;
      });
    }
  }

  void startPolling() {
    print("🟡 startPolling: إعداد الـ polling");
    pollTimer?.cancel();
    print("⏹️ تم إلغاء أي مؤقت سابق");

    final limit = _toDouble(dashboard?['limit']);

    print("💰 limit = $limit");

    if (limit > 0) {
      print("✅ الشروط متاحة: سيبدأ الـ polling كل 5 ثوانٍ");
      pollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => checkOrder(),
      );
    } else {
      print("⛔ الشروط غير متاحة: لن يتم بدء الـ polling");
    }
  }

  Future<void> checkOrder() async {
    if (token == null || isOrderVisible || isDialogOpen) {
      print(
          "⚠️ checkOrder: token = $token, isOrderVisible = $isOrderVisible, isDialogOpen = $isDialogOpen -> تخطي");
      return;
    }

    try {
      final url = Api.checkOrder();
      print("🔍 checkOrder: جلب الطلب من $url");
      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      print("📡 Response status: ${res.statusCode}");
      final data = jsonDecode(res.body);
      print("📄 Response body: ${res.body}");

      if (data['success'] == true && data['found'] == true) {
        final newId = data['id'];
        print("✅ تم العثور على طلب جديد بالـ id = $newId");

        if (seenOrders.contains(newId)) {
          print("⚠️ نفس الطلب السابق -> تجاهل");
          return;
        }

        isOrderVisible = true;

        seenOrders.add(newId);
        currentOrder = data;

        print("🛑 إلغاء الـ polling لحين معالجة الطلب");
        pollTimer?.cancel();

        if (isDialogOpen) return;
        print("📢 عرض حوار الطلب");
        showOrderDialog(data);
      } else {
        print("ℹ️ لا يوجد طلب حالي (found=false أو success=false)");
      }
    } catch (e) {
      print("🔥 خطأ في جلب الطلب: $e");
    }
  }

  Future<void> claimOrder(int orderId, String type) async {
    print("🟡 claimOrder: بدء طلب المطالبة للطلب $orderId من نوع $type");
    final url = Api.post("agent/claim-order.php");
    print("🔗 URL: $url");
    final res = await http.post(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'order_id': orderId.toString(),
        'type': type,
      },
    );
    if (!mounted) return;
    print("📡 Response status: ${res.statusCode}");
    final data = jsonDecode(res.body);
    print("📄 Response body: ${res.body}");
    print("CLAIM RESPONSE: $data");

    if (data['success'] != true) {
      throw Exception(data['message'] ?? "فشل في المطالبة بالطلب");
    }
    print("✅ تمت المطالبة بنجاح");
  }

  void showOrderDialog(Map<String, dynamic> order) {
    if (isDialogOpen || Navigator.canPop(context)) return;
    isDialogOpen = true;
    _dialogSeconds = 10;
    print("📱 showOrderDialog: عرض الـ bottomSheet للطلب");
    print(
        "📋 نوع الطلب: ${order['type']}, المبلغ: ${order['amount']}, الطريقة: ${order['method']}");

    _dialogTimer?.cancel();
    _dialogTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !isDialogOpen) {
        timer.cancel();
        return;
      }
      if (_dialogSeconds > 0) {
        setState(() {
          _dialogSeconds--;
        });
      } else {
        timer.cancel();
        if (isDialogOpen) {
          Navigator.pop(context);
        }
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        print("🎨 بناء محتوى الـ bottomSheet");
        return FractionallySizedBox(
          heightFactor: 0.95,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // 🔹 عنوان
                Text(
                  order['type'] == 'withdrawal' ? "طلب سحب" : "طلب إيداع",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                // 🔹 تفاصيل
                Text("المبلغ: ${order['amount']} IQD",
                    style: const TextStyle(fontSize: 18)),
                Text("الطريقة: ${order['method']}",
                    style: const TextStyle(fontSize: 18)),

                const Spacer(),

                // 🔹 مؤقت القبول
                Text(
                  "ينتهي العرض خلال $_dialogSeconds ثانية",
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _dialogSeconds / 10,
                  backgroundColor: Colors.grey.shade300,
                  color: Colors.teal,
                  minHeight: 6,
                ),

                const SizedBox(height: 16),

                // ✅ زر الضغط المطول (GestureDetector)
                GestureDetector(
                  onLongPress: isProcessing
                      ? null
                      : () async {
                          _dialogTimer?.cancel();
                          isProcessing = true;

                          if (currentOrder == null) {
                            isProcessing = false;
                            return;
                          }

                          final orderData =
                              Map<String, dynamic>.from(currentOrder!);
                          final orderId = orderData['id'] as int;
                          final orderType = orderData['type'] as String;

                          try {
                            await claimOrder(orderId, orderType);

                            final rootContext =
                                Navigator.of(context, rootNavigator: true)
                                    .context;

                            Navigator.pop(context);

                            isOrderVisible = false;
                            currentOrder = null;

                            if (orderType == 'deposit') {
                              await Navigator.of(rootContext).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DepositScreen(order: orderData),
                                ),
                              );
                            } else {
                              await Navigator.of(rootContext).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      WithdrawalScreen(order: orderData),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;

                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("فشل: $e")),
                            );

                            isOrderVisible = false;
                            currentOrder = null;
                            startPolling();
                          } finally {
                            isProcessing = false;
                          }
                        },
                  child: Opacity(
                    opacity: isProcessing ? 0.5 : 1,
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "اضغط مطولاً للقبول",
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      print("🔚 bottomSheet مغلق بالكامل (whenComplete)");
      _dialogTimer?.cancel();
      isOrderVisible = false;
      isDialogOpen = false;
    });
  }

  Future<void> toggleAvailable() async {
    print("🔄 toggleAvailable: تغيير حالة التوفر");
    final url = Api.radar();
    print("🔗 URL: $url");
    final res = await http.post(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
      body: {'toggle_available': '1'},
    );
    print("📡 Response status: ${res.statusCode}");
    final body = res.body;
    print("📄 Response body: $body");

    print("🔄 إعادة جلب لوحة المعلومات بعد التبديل");
    await fetchDashboard();
  }

  void openRaiseLimit() {
    print("📈 openRaiseLimit: فتح شاشة رفع الحد");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RaiseLimitScreen()),
    );
  }

  double _toDouble(dynamic v) {
    double result;
    if (v is num)
      result = v.toDouble();
    else if (v is String)
      result = double.tryParse(v) ?? 0;
    else
      result = 0;
    print("🔢 _toDouble: $v -> $result");
    return result;
  }

  @override
  Widget build(BuildContext context) {
    print(
        "🎨 build: إعادة بناء الواجهة (isLoading=$isLoading, errorMessage='$errorMessage')");
    if (isLoading) {
      print("⏳ عرض مؤشر التحميل");
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (errorMessage.isNotEmpty) {
      print("⚠️ عرض رسالة خطأ: $errorMessage");
      return Scaffold(body: Center(child: Text(errorMessage)));
    }

    final balance = _toDouble(dashboard?['balance']);
    final profit = _toDouble(dashboard?['profit']);
    final limit = _toDouble(dashboard?['limit']);
    final remaining = _toDouble(dashboard?['remaining']);
    final currency = dashboard?['currency'] ?? 'IQD';

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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("مركز التحكم"),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text("الرصيد: ${format(balance)} $currency"),
                      Text("الأرباح: ${format(profit)} $currency"),
                      Text("السقف: ${format(limit)} $currency"),
                      Text("المتبقي: ${format(remaining)} $currency"),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
