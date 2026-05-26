import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import 'gate_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final fullNameController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  int? countryId;

  bool isLoading = false;
  String error = "";

  List countries = [];
  bool isLoadingCountries = true;

  @override
  void initState() {
    super.initState();
    fetchCountries();
  }

  Future<void> fetchCountries() async {
    try {
      final res = await http.get(Uri.parse(Api.countries()));
      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        final List fetchedCountries = data['data']['countries'];
        setState(() {
          countries = fetchedCountries;
          isLoadingCountries = false;
        });

        // البحث عن الدولة العراق (ID 1) أو باسم "العراق"
        int? iraqId;
        for (var c in fetchedCountries) {
          if (c['country_name'] == 'العراق' || c['id'] == 1) {
            iraqId = int.parse(c['id'].toString());
            break;
          }
        }
        if (iraqId != null && mounted) {
          setState(() {
            countryId = iraqId;
          });
        }
      } else {
        setState(() => isLoadingCountries = false);
      }
    } catch (e) {
      setState(() => isLoadingCountries = false);
    }
  }

  Future<void> register() async {
    final fullName = fullNameController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (fullName.isEmpty ||
        username.isEmpty ||
        password.isEmpty ||
        countryId == null) {
      setState(() => error = "املأ جميع الحقول");
      return;
    }

    setState(() {
      isLoading = true;
      error = "";
    });

    try {
      final response = await http.post(
        Uri.parse(Api.register()),
        body: {
          "country_id": countryId.toString(),
          "full_name": fullName,
          "username": username,
          "password": password,
        },
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        final token = data['data']['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('api_token', token);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GateScreen()),
        );
      } else {
        setState(() {
          error = data['message'] ?? "فشل التسجيل";
        });
      }
    } catch (e) {
      setState(() {
        error = "فشل الاتصال بالسيرفر";
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    fullNameController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("تسجيل حساب"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // أيقونة ترحيبية
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_add_alt_rounded,
                      size: 40, color: Colors.teal.shade700),
                ),
                const SizedBox(height: 24),
                Text(
                  "إنشاء حساب جديد",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "أدخل بياناتك لبدء العمل",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                // Dropdown الدولة
                if (isLoadingCountries)
                  const Center(child: CircularProgressIndicator())
                else
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<int>(
                      value: countryId,
                      hint: const Text("اختر الدولة"),
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon:
                            Icon(Icons.flag, color: Colors.teal.shade600),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Colors.black), // ✅ حد أسود
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Colors.black), // ✅ حد أسود
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: Colors.black, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                      ),
                      items: countries.map<DropdownMenuItem<int>>((c) {
                        return DropdownMenuItem(
                          value: int.parse(c['id'].toString()),
                          child: Text(c['country_name']),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => countryId = v),
                    ),
                  ),
                const SizedBox(height: 20),
                // حقل الاسم الكامل
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: fullNameController,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: "الاسم الكامل",
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixIcon:
                          Icon(Icons.badge, color: Colors.teal.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Colors.black), // ✅ حد أسود
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Colors.black), // ✅ حد أسود
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Colors.black, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // حقل اسم المستخدم
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: usernameController,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: "اسم المستخدم",
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixIcon: Icon(Icons.person_outline,
                          color: Colors.teal.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Colors.black), // ✅ حد أسود
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Colors.black), // ✅ حد أسود
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Colors.black, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // حقل كلمة المرور
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: passwordController,
                    obscureText: true,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: "كلمة المرور",
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixIcon:
                          Icon(Icons.lock_outline, color: Colors.teal.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Colors.black), // ✅ حد أسود
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Colors.black), // ✅ حد أسود
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Colors.black, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // رسالة الخطأ
                if (error.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                // زر التسجيل
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.teal.shade300,
                      elevation: 4,
                      shadowColor: Colors.teal.shade200,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "تسجيل",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                // رابط العودة لتسجيل الدخول
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    "لديك حساب؟ تسجيل الدخول",
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
