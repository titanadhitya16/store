import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

// Top-level function for background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request permission for iOS
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('Notification permission status: ${settings.authorizationStatus}');
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Initialize local notifications
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        
        const DarwinInitializationSettings initializationSettingsIOS =
            DarwinInitializationSettings(
              requestAlertPermission: true,
              requestBadgePermission: true,
              requestSoundPermission: true,
            );

        const InitializationSettings initializationSettings =
            InitializationSettings(
              android: initializationSettingsAndroid,
              iOS: initializationSettingsIOS,
            );

        await _localNotifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );

        // Create notification channel for Android
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'stock_alerts',
          'Stock Alerts',
          description: 'Notifications for stock level alerts',
          importance: Importance.high,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

        // Set up message handlers
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // Get FCM token
        String? token = await _firebaseMessaging.getToken();
        if (kDebugMode) {
          print('FCM Token: $token');
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          if (kDebugMode) {
            print('FCM Token refreshed: $newToken');
          }
        });

        _isInitialized = true;
      } else {
        if (kDebugMode) {
          print('Notification permission denied');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notifications: $e');
      }
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Received foreground message: ${message.messageId}');
    }
    
    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'Stock Alert',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  // Handle message opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print('Message opened app: ${message.messageId}');
    }
    // You can navigate to a specific screen here if needed
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
    // You can navigate to a specific screen here if needed
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'stock_alerts',
      'Stock Alerts',
      channelDescription: 'Notifications for stock level alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // Show notification for out of stock items
  Future<void> showOutOfStockNotification({
    required String itemName,
  }) async {
    await _showLocalNotification(
      title: '⚠️ Stock Alert: Out of Stock',
      body: '$itemName is now out of stock!',
      payload: 'out_of_stock:$itemName',
    );
  }

  // Show notification for low stock items
  Future<void> showLowStockNotification({
    required String itemName,
    required int quantity,
  }) async {
    await _showLocalNotification(
      title: '⚠️ Stock Alert: Low Stock',
      body: '$itemName is running low (only $quantity left)',
      payload: 'low_stock:$itemName',
    );
  }

  // Get FCM token
  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }
}
