import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List notifications = [];
  bool isLoading = true;
  String error = "";
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  bool isSuccess(Map data) {
    return data['success'] == true || data['ok'] == true;
  }

  Future<void> fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');

    if (token == null || token.isEmpty) {
      setState(() {
        error = "جلسة غير صالحة";
        isLoading = false;
      });
      return;
    }

    try {
      final res = await http.get(
        Uri.parse(Api.notifications()),
        headers: {'Authorization': 'Bearer $token'},
      );

      // ✅ التعديل الأساسي: استخدام utf8.decode لضمان الترميز الصحيح
      final String responseBody = utf8.decode(res.bodyBytes);
      final data = jsonDecode(responseBody);

      if (isSuccess(data)) {
        setState(() {
          notifications = data['notifications'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          error = data['message'] ?? "خطأ";
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

  String formatDate(String date) {
    if (date.isEmpty) return "";
    if (date.length >= 16) {
      return date.substring(0, 16).replaceFirst(' ', '  ');
    }
    return date;
  }

  Future<void> markAsRead(int index) async {
    final notification = notifications[index];
    if (notification['is_read'] == 1) return;
    setState(() {
      notifications[index]['is_read'] = 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('تم تحديد الإشعار كمقروء'),
          duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
                error = "";
              });
              fetchNotifications();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: fetchNotifications,
        color: Colors.teal,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(error, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: fetchNotifications,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off,
                size: 70, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('لا توجد إشعارات',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final n = notifications[index];
        final isRead = n['is_read'] == 1;

        return GestureDetector(
          onTap: () => markAsRead(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: isRead ? Colors.grey.shade50 : Colors.white,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor:
                      isRead ? Colors.grey.shade300 : Colors.teal.shade100,
                  child: Icon(
                    isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: isRead ? Colors.grey.shade600 : Colors.teal,
                  ),
                ),
                title: Text(
                  n['title'] ?? '',
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    n['message'] ?? '',
                    style: TextStyle(
                        color: isRead ? Colors.grey.shade600 : Colors.black87),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(isRead ? Icons.done_all : Icons.circle,
                        size: 14, color: isRead ? Colors.teal : Colors.orange),
                    const SizedBox(height: 4),
                    Text(formatDate(n['created_at'] ?? ''),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
                isThreeLine: true,
              ),
            ),
          ),
        );
      },
    );
  }
}
