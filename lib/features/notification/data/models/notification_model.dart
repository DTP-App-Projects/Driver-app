import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';

enum NotificationType { route, order, alert, system }

class NotificationModel {
  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.date,
    this.isRead = false,
  });

  final int id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime date;
  bool isRead;

  IconData get icon => switch (type) {
    NotificationType.route => Icons.route_rounded,
    NotificationType.order => Icons.inventory_2_outlined,
    NotificationType.alert => Icons.warning_amber_rounded,
    NotificationType.system => Icons.campaign_outlined,
  };

  Color get color => switch (type) {
    NotificationType.route => AppColors.primarySwatchColor,
    NotificationType.order => AppColors.secondaryColor,
    NotificationType.alert => AppColors.red,
    NotificationType.system => const Color(0xffE8A317),
  };

  /// Placeholder feed until the notifications endpoint is wired.
  /// The copy is Arabic on purpose: it stands in for server sent content,
  /// which arrives already localised.
  static List<NotificationModel> demoData() {
    final now = DateTime.now();

    return [
      NotificationModel(
        id: 1,
        type: NotificationType.route,
        title: "تم تخصيص خط سير جديد",
        body: "تم تخصيص خط سير اليوم لك من قِبل المشرف، يحتوي على ٨ نقاط تسليم في حي النرجس.",
        date: now.subtract(const Duration(minutes: 12)),
      ),
      NotificationModel(
        id: 2,
        type: NotificationType.order,
        title: "طلب جديد أضيف لخط السير",
        body: "تمت إضافة الطلب رقم ٤٥٢٣٩ إلى نهاية خط سيرك، يرجى مراجعة الترتيب قبل الانطلاق.",
        date: now.subtract(const Duration(hours: 3)),
      ),
      NotificationModel(
        id: 3,
        type: NotificationType.alert,
        title: "تنبيه: ازدحام على الطريق الدائري",
        body: "يوجد ازدحام كثيف على الطريق الدائري الشمالي، ننصح باستخدام مسار بديل لتوفير الوقت.",
        date: now.subtract(const Duration(hours: 6)),
        isRead: true,
      ),
      NotificationModel(
        id: 4,
        type: NotificationType.order,
        title: "تم تأكيد تسليم الطلب",
        body: "تم تأكيد تسليم الطلب رقم ٤٥١١٨ بنجاح، شكراً لالتزامك بالوقت المحدد.",
        date: now.subtract(const Duration(days: 1, hours: 2)),
        isRead: true,
      ),
      NotificationModel(
        id: 5,
        type: NotificationType.system,
        title: "تحديث في سياسة التسليم",
        body: "تم تحديث مدة الانتظار المسموح بها عند نقطة التسليم لتصبح ١٠ دقائق بدلاً من ٥ دقائق.",
        date: now.subtract(const Duration(days: 1, hours: 9)),
        isRead: true,
      ),
      NotificationModel(
        id: 6,
        type: NotificationType.system,
        title: "أهلاً بك في تطبيق المناديب",
        body: "تم تفعيل حسابك بنجاح، يمكنك الآن استلام خطوط السير ومتابعة طلباتك من التطبيق.",
        date: now.subtract(const Duration(days: 4)),
        isRead: true,
      ),
    ];
  }
}
