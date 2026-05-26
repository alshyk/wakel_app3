import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List methods = [];
  List myMethods = [];

  bool isLoading = true;
  String error = "";

  int? selectedMethodId;
  final accountController = TextEditingController();
  final newMethodController = TextEditingController();
  final newAccountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  // جلب البيانات
  Future<void> fetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');

    final url = Api.post("agent/payment-methods.php");
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        final inner = data['data'] ?? {};
        setState(() {
          methods = inner['methods'] ?? [];
          myMethods = inner['my_methods'] ?? [];
          isLoading = false;
          selectedMethodId = null; // إعادة تعيين القيمة المختارة
        });
      } else {
        setState(() {
          error = data['message'] ?? 'خطأ';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  // إضافة وسيلة موجودة
  Future<void> saveMethod() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');

    if (selectedMethodId == null || accountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر وسيلة وأدخل رقم الحساب')),
      );
      return;
    }

    try {
      final res = await http.post(
        Uri.parse(Api.post("agent/add-payment-method.php")),
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'mode': 'existing',
          'payment_method_id': selectedMethodId.toString(),
          'account_number': accountController.text,
        },
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        accountController.clear();
        setState(
            () => selectedMethodId = null); // إعادة تعيين قبل إعادة التحميل
        fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت الإضافة بنجاح')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'فشل الإضافة')),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  // طلب وسيلة جديدة
  Future<void> requestNewMethod() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');

    if (newMethodController.text.isEmpty || newAccountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('املأ جميع الحقول')),
      );
      return;
    }

    try {
      final res = await http.post(
        Uri.parse(Api.post("agent/add-payment-method.php")),
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'mode': 'new',
          'method_name': newMethodController.text,
          'account_number': newAccountController.text,
        },
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        newMethodController.clear();
        newAccountController.clear();
        fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال الطلب بنجاح')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'فشل إرسال الطلب')),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  // تعديل رقم الحساب لوسيلة موجودة
  Future<void> editMethod(Map method) async {
    final TextEditingController editController =
        TextEditingController(text: method['account_number']);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل ${method['method_name']}'),
        content: TextField(
          controller: editController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'رقم الحساب',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == true && editController.text.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم التعديل محلياً (API قيد التطوير)')),
      );
      setState(() {
        final index = myMethods.indexWhere((m) => m['id'] == method['id']);
        if (index != -1)
          myMethods[index]['account_number'] = editController.text;
      });
    }
  }

  void goNext() {
    if (myMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف وسيلة أولاً')),
      );
      return;
    }
    Navigator.pop(context); // يرجع للـ GateScreen
  }

  void _showNewMethodDialog() {
    newMethodController.clear();
    newAccountController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة وسيلة جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newMethodController,
              decoration: InputDecoration(
                labelText: 'اسم الوسيلة',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newAccountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'رقم الحساب',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              requestNewMethod();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error.isNotEmpty) {
      return Scaffold(
        body: Center(child: Text(error)),
      );
    }

    // فلترة الوسائل المتاحة (غير المضافة)
    final addedMethodIds = myMethods.map((m) {
      final id = m['payment_method_id'] is int
          ? m['payment_method_id'] as int
          : int.tryParse(m['payment_method_id'].toString()) ?? 0;
      return id;
    }).toSet();

    final availableMethods = methods.where((m) {
      final id = m['id'] is int
          ? m['id'] as int
          : int.tryParse(m['id'].toString()) ?? 0;
      return !addedMethodIds.contains(id);
    }).toList();

    // إذا كان selectedMethodId لا يزال في القائمة المتاحة، احتفظ به، وإلا صفره
    if (selectedMethodId != null &&
        availableMethods.every((m) {
          final id = m['id'] is int
              ? m['id'] as int
              : int.tryParse(m['id'].toString()) ?? 0;
          return id != selectedMethodId;
        })) {
      selectedMethodId = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('وسائل الدفع'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // الوسائل المضافة (تظهر فوق)
            // =========================
            if (myMethods.isNotEmpty) ...[
              const Text(
                'وسائلي المضافة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...myMethods.map((method) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: method['logo_path'] != null
                          ? Image.network(
                              Api.post(method['logo_path']),
                              width: 32,
                              height: 32,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.payment),
                            )
                          : const Icon(Icons.payment, color: Colors.teal),
                      title: Text(method['method_name'] ?? ''),
                      subtitle: Text(method['account_number'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.teal),
                        onPressed: () => editMethod(method),
                      ),
                    ),
                  )),
              const SizedBox(height: 16),
            ],

            // =========================
            // إضافة وسيلة موجودة (تظهر فقط إذا كانت هناك وسائل متاحة)
            // =========================
            if (availableMethods.isNotEmpty) ...[
              const Text(
                'إضافة وسيلة موجودة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: selectedMethodId,
                        hint: const Text('اختر وسيلة دفع'),
                        items: availableMethods.map<DropdownMenuItem<int>>((m) {
                          final id = m['id'] is int
                              ? m['id'] as int
                              : int.tryParse(m['id'].toString()) ?? 0;
                          return DropdownMenuItem(
                            value: id,
                            child: Row(
                              children: [
                                if (m['logo_path'] != null)
                                  Image.network(
                                    Api.post(m['logo_path']),
                                    width: 24,
                                    height: 24,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(),
                                  ),
                                const SizedBox(width: 8),
                                Text(m['method_name']),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => selectedMethodId = v),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: accountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'رقم الحساب',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: saveMethod,
                        icon: const Icon(Icons.save),
                        label: const Text('حفظ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // =========================
            // زر "هل لديك وسيلة أخرى؟"
            // =========================
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showNewMethodDialog,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('هل لديك وسيلة أخرى؟'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // زر التالي
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: goNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'التالي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
