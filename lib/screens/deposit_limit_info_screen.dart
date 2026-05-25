import 'package:flutter/material.dart';
import 'activation_request_screen.dart';

class DepositLimitInfoScreen extends StatelessWidget {
  const DepositLimitInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("رفع السقف"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ActivationRequestScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          child: const Text(
            "موافق",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة التعريف
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 40, color: Colors.teal),
                    const SizedBox(height: 12),
                    const Text(
                      "ما هو سقف الإيداع؟",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "سقف الإيداع هو الحد الأقصى للمبلغ الذي يمكنك التعامل معه داخل النظام، سواء في استقبال الطلبات أو تنفيذها.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // بطاقة البداية
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 40, color: Colors.teal),
                    const SizedBox(height: 12),
                    const Text(
                      "في البداية",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "يكون سقف الحساب غير مفعل أو محدود، وذلك لضمان جاهزية الوكيل والتحقق من بياناته.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // بطاقة المطلوب
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.send, size: 40, color: Colors.teal),
                    const SizedBox(height: 12),
                    const Text(
                      "كيف ترفع السقف؟",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "لن تتمكن من استقبال الطلبات أو العمل داخل النظام ما لم يتم رفع هذا السقف وتفعيل حسابك.\n\nلرفع السقف، يجب عليك تقديم طلب إلى الإدارة. بعد إرسال الطلب، سيتم مراجعته والتأكد من جاهزيتك للعمل، مثل توفر وسائل الدفع والالتزام بالتعليمات.\n\nعند الموافقة على طلبك، سيتم تفعيل حسابك وزيادة سقف الإيداع، وبذلك يمكنك البدء في استقبال الطلبات وتنفيذ العمليات بشكل طبيعي.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // بطاقة الدفع USDT
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.currency_bitcoin,
                        size: 40, color: Colors.teal),
                    const SizedBox(height: 12),
                    const Text(
                      "طريقة الدفع",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "يكون الدفع للإدارة عبر عملة USDT حصراً.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // بطاقة باختصار
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 40, color: Colors.teal),
                    const SizedBox(height: 12),
                    const Text(
                      "🔸 باختصار",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "سقفك يحدد قيمة الطلبات التي تصلك.\nإذا كان سقفك صغيراً، ستستلم طلبات صغيرة فقط.\nوكلما زاد سقفك، زادت قيمة الطلبات التي يمكنك استقبالها.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            // مساحة لآخر محتوى ليظهر فوق الزر العائم
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
