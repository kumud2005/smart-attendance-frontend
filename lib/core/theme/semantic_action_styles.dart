import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared semantic colors for meaningful actions/statuses across the app.
///
/// Design rule:
/// - Green  = positive / approve / activate / accepted / success
/// - Amber  = caution / deactivate / suspend / pending / inactive
/// - Red    = destructive / delete / reject / reset / failed
/// - Purple = normal primary actions such as add, edit, save, navigation
class SemanticActionStyles {
  SemanticActionStyles._();

  static const Color positive = AppColors.success;
  static const Color caution = AppColors.warning;
  static const Color destructive = AppColors.error;
  static const Color primary = AppColors.primary;

  static ButtonStyle outlined(Color color) {
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: 0.06),
    );
  }

  static ButtonStyle filled(Color color) {
    return FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
    );
  }

  static ButtonStyle text(Color color) {
    return TextButton.styleFrom(
      foregroundColor: color,
    );
  }

  static ButtonStyle tonal(Color color) {
    return FilledButton.styleFrom(
      backgroundColor: color.withValues(alpha: 0.12),
      foregroundColor: color,
    );
  }

  static ButtonStyle icon(Color color) {
    return IconButton.styleFrom(
      foregroundColor: color,
      backgroundColor: color.withValues(alpha: 0.09),
    );
  }

  static Color statusColor(String status) {
    switch (status.trim().toUpperCase()) {
      case 'ACTIVE':
      case 'APPROVED':
      case 'ACCEPTED':
      case 'PRESENT':
      case 'COMPLETED':
      case 'SUCCESS':
      case 'VERIFIED':
        return positive;

      case 'PENDING':
      case 'INACTIVE':
      case 'SUSPENDED':
      case 'DEACTIVATED':
      case 'RUNNING':
      case 'WAITING':
        return caution;

      case 'REJECTED':
      case 'DELETED':
      case 'FAILED':
      case 'ERROR':
      case 'CANCELLED':
      case 'BLOCKED':
        return destructive;

      default:
        return AppColors.textSecondary;
    }
  }
}
