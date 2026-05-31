import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/network/api_result.dart';
import '../data/safety_repository.dart';

/// Shared UI for App Store 1.2 report/block flows, reused by the feed,
/// comments and member profiles.
class SafetyActions {
  const SafetyActions._();

  /// Shows the report reason picker and submits the chosen reason.
  static Future<void> reportContent(
    BuildContext context,
    WidgetRef ref, {
    required Future<ApiResult<void>> Function(String reason) submit,
  }) async {
    final l10n = context.l10n;
    final reasons = <String>[
      l10n.reportReasonSpam,
      l10n.reportReasonHarassment,
      l10n.reportReasonHate,
      l10n.reportReasonExplicit,
      l10n.reportReasonViolence,
      l10n.reportReasonOther,
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                l10n.reportContentTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(l10n.reportContentSubtitle),
            ),
            for (final reason in reasons)
              ListTile(
                title: Text(reason),
                onTap: () => Navigator.of(sheetContext).pop(reason),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null) return;
    final result = await submit(reason);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok ? l10n.reportSubmittedMessage : l10n.reportFailedMessage,
        ),
      ),
    );
  }

  /// Confirms and blocks [userId]; returns true when the block succeeds.
  static Future<bool> blockUser(
    BuildContext context,
    WidgetRef ref, {
    required int userId,
    required String displayName,
  }) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.blockUserAction),
        content: Text(l10n.blockUserConfirm(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.blockUserConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    final result = await ref.read(safetyRepositoryProvider).blockUser(userId);
    if (!context.mounted) return result.ok;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? l10n.userBlockedMessage(displayName)
              : l10n.blockFailedMessage,
        ),
      ),
    );
    return result.ok;
  }

  static Future<bool> unblockUser(
    BuildContext context,
    WidgetRef ref, {
    required int userId,
    required String displayName,
  }) async {
    final l10n = context.l10n;
    final result = await ref.read(safetyRepositoryProvider).unblockUser(userId);
    if (!context.mounted) return result.ok;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? l10n.userUnblockedMessage(displayName)
              : l10n.unblockFailedMessage,
        ),
      ),
    );
    return result.ok;
  }
}
