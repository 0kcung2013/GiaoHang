import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_model.dart';

class NotificationService {
  NotificationService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _table = 'notifications';

  Future<List<NotificationModel>> getNotifications(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map(NotificationModel.fromJson).toList();
    } catch (error) {
      throw Exception('Failed to load notifications: $error');
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from(_table)
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return response.length;
    } catch (error) {
      throw Exception('Failed to load unread notification count: $error');
    }
  }

  Future<void> markAsRead(String notificationId, String userId) async {
    try {
      await _supabase
          .from(_table)
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', userId);
    } catch (error) {
      throw Exception('Failed to mark notification as read: $error');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from(_table)
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (error) {
      throw Exception('Failed to mark all notifications as read: $error');
    }
  }
}