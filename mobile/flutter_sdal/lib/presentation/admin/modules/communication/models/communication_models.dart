enum BroadcastTargetSegment { allMembers, graduatesOnly, teachersOnly, cohort }

class BroadcastDraft {
  const BroadcastDraft({
    required this.segment,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.deepLink,
    required this.cohort,
  });

  final BroadcastTargetSegment segment;
  final String title;
  final String body;
  final String imageUrl;
  final String deepLink;
  final String cohort;

  BroadcastDraft copyWith({
    BroadcastTargetSegment? segment,
    String? title,
    String? body,
    String? imageUrl,
    String? deepLink,
    String? cohort,
  }) {
    return BroadcastDraft(
      segment: segment ?? this.segment,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      deepLink: deepLink ?? this.deepLink,
      cohort: cohort ?? this.cohort,
    );
  }
}

class BroadcastDryRunResult {
  const BroadcastDryRunResult({
    required this.estimatedRecipients,
    required this.validationMessage,
  });

  final int estimatedRecipients;
  final String validationMessage;
}

class CommunicationSnapshot {
  const CommunicationSnapshot({required this.draft, required this.dryRun});

  final BroadcastDraft draft;
  final BroadcastDryRunResult dryRun;
}

String broadcastTargetLabel(BroadcastTargetSegment segment) {
  return switch (segment) {
    BroadcastTargetSegment.allMembers => 'Tüm Üyeler',
    BroadcastTargetSegment.graduatesOnly => 'Sadece Mezunlar',
    BroadcastTargetSegment.teachersOnly => 'Sadece Öğretmenler',
    BroadcastTargetSegment.cohort => 'Cohort Bazlı',
  };
}
