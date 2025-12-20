import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';

class FeedbackService {
  static const String _feedbackEmail = 'rishabms80@gmail.com';
  static const String _appName = 'InstaFrame';

  Future<String> generateFeedbackBody() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();
    
    String deviceDetails = '';
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceDetails = '''

---
Device Information:
- App Version: ${packageInfo.version} (${packageInfo.buildNumber})
- Device: ${androidInfo.manufacturer} ${androidInfo.model}
- Android Version: ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})
- Brand: ${androidInfo.brand}
---

Please describe your feedback or issue above this line.
''';
    }
    
    return deviceDetails;
  }

  Future<void> sendFeedback({
    required BuildContext context,
    String? userMessage,
  }) async {
    try {
      final body = await generateFeedbackBody();
      final message = userMessage ?? '';
      
      // For Android, we'll use the native email intent
      // The mailer package is more suited for actual SMTP sending
      // For now, we'll prepare the data and show how to use it
      
      // In a real implementation, you'd open the email app using url_launcher
      // or a similar package with a mailto: URL
      
      final emailData = {
        'to': _feedbackEmail,
        'subject': '$_appName Feedback',
        'body': '$message\n$body',
      };
      
      // For now, we'll just return the email data
      // You can implement the actual email sending using url_launcher
      // with: mailto:$_feedbackEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}
      
      debugPrint('Email data prepared: $emailData');
    } catch (e) {
      throw Exception('Failed to prepare feedback: $e');
    }
  }

  String getMailtoUrl({String? userMessage}) {
    final subject = Uri.encodeComponent('$_appName Feedback');
    final body = Uri.encodeComponent(userMessage ?? '');
    return 'mailto:$_feedbackEmail?subject=$subject&body=$body';
  }
}

