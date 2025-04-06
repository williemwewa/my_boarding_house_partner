import 'package:flutter/material.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';

class LoadingDialog extends StatelessWidget {
  final String message;
  final bool dismissible;

  const LoadingDialog({Key? key, required this.message, this.dismissible = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => dismissible,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor)),
            const SizedBox(height: 24),
            Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            const SizedBox(height: 16),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// For more complex operations that need progress reporting,
// you can use this variant:

class ProgressLoadingDialog extends StatelessWidget {
  final String message;
  final double progress;
  final bool dismissible;

  const ProgressLoadingDialog({
    Key? key,
    required this.message,
    required this.progress, // 0.0 to 1.0
    this.dismissible = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progressPercentage = (progress * 100).toStringAsFixed(0);

    return WillPopScope(
      onWillPop: () async => dismissible,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(height: 80, width: 80, child: CircularProgressIndicator(value: progress, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor), strokeWidth: 8)),
                Text('$progressPercentage%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 24),
            Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            const SizedBox(height: 16),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
