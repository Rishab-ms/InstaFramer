import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/feedback_service.dart';
import 'settings_card.dart';

/// Feedback tile for sending app feedback via email.
/// 
/// Opens the device's email client with pre-filled:
/// - To address
/// - Subject line
/// - Device information in body
/// 
/// Shows error snackbar if email client unavailable.
class FeedbackTile extends StatelessWidget {
  /// Service for generating feedback email data
  final FeedbackService feedbackService;

  const FeedbackTile({
    super.key,
    required this.feedbackService,
  });

  Future<void> _handleFeedback(BuildContext context) async {
    try {
      final deviceInfo = await feedbackService.generateFeedbackBody();
      final subject = Uri.encodeComponent('InstaFrame Feedback');
      final body = Uri.encodeComponent(deviceInfo);
      final mailtoUrl = 'mailto:rishabms80@gmail.com?subject=$subject&body=$body';
      
      final uri = Uri.parse(mailtoUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No email app found. Please email rishabms80@gmail.com'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open email: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      child: ListTile(
        leading: const Icon(Icons.feedback_outlined),
        title: const Text('Send Feedback'),
        subtitle: const Text('Report issues or suggest features'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _handleFeedback(context),
      ),
    );
  }
}

