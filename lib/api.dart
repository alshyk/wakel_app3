class Api {
  // الدومين — مكان واحد فقط
  static String _baseUrl = "https://taskmarket.store/api";

  // تغيير الدومين لاحقاً
  static void setBaseUrl(String url) {
    _baseUrl = url;
  }

  // بناء أي رابط
  static String _url(String path) {
    return "$_baseUrl/$path";
  }

  // ===== Endpoints =====

  /// تسجيل الدخول
  static String login() {
    return _url("agent/login.php");
  }

  /// تسجيل حساب جديد
  static String register() {
    return _url("agent/register.php");
  }

  /// لوحة الوكيل (GET + toggle)
  static String radar() {
    return _url("agent/radar.php");
  }

  /// فحص وجود طلب (polling)
  static String checkOrder() {
    return _url("agent/check-order.php");
  }

  // =========================
  // 🔥 الجديد (رفع السقف)
  // =========================

  /// جلب الباقات
  static String packages() {
    return _url("agent/packages.php");
  }

  /// إرسال طلب رفع السقف
  static String activationRequest() {
    return _url("agent/activation-request.php");
  }

  static String dashboard() {
    return _url("agent/dashboard.php");
  }

  /// قبول الطلب

  static String claimOrder() {
    return _url("agent/claim-order.php");
  }

  static String orderStatus(int orderId, String type) {
    return _url("agent/order-status.php?order_id=$orderId&type=$type");
  }

  static String post(String path) {
    return _url(path);
  }

  static String image(String path) {
    String clean = path.trim();

    // إذا ما بيه uploads → أضفها

    if (!clean.contains('uploads')) {
      clean = 'uploads/proofs/' + clean;
    }

    // إزالة / بالبداية
    if (clean.startsWith('/')) {
      clean = clean.substring(1);
    }

    return _baseUrl.replaceAll('/api', '') + '/' + clean;
  }

  static String notifications() {
    return _url("agent/notifications.php");
  }

  /// جلب حالة الوكيل (Gate)
  static String me() {
    return _url("agent/me.php");
  }

  static String countries() {
    return _url("agent/countries.php"); // ✅
  }

  static String settlement() {
    return _url("agent/settlement.php");
  }

  static String wallet() {
    return _url("agent/wallet.php");
  }

  static String availablePackages() {
    return _url("agent/available-packages.php");
  }

  static String versionCheck() {
    return _baseUrl.replaceAll('/api', '') + '/version.json';
  }

  static String testScreen() {
  return _url("agent/test_screen.php");
}
}
