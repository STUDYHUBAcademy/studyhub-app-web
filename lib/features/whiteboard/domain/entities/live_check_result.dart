/// One flagged line from a live-check pass — `line` is the badge number
/// rendered on the snapshot sent to the AI (see `rasterizeForLiveCheck`),
/// not a stroke id directly; the caller maps it back to strokes.
class LiveCheckFlag {
  const LiveCheckFlag({
    required this.line,
    required this.severity,
    required this.note,
  });

  final int line;
  final String severity; // 'critical' | 'minor'
  final String note;

  factory LiveCheckFlag.fromJson(Map<String, dynamic> json) {
    return LiveCheckFlag(
      line: (json['line'] as num).toInt(),
      severity: json['severity'] as String? ?? 'minor',
      note: json['note'] as String? ?? '',
    );
  }
}

class LiveCheckResult {
  const LiveCheckResult({
    required this.state,
    required this.flags,
    this.message,
  });

  final String state; // 'empty' | 'on_track' | 'minor_error' | 'critical_error' | 'stuck'
  final List<LiveCheckFlag> flags;
  final String? message;

  factory LiveCheckResult.fromJson(Map<String, dynamic> json) {
    final rawFlags = json['wrong'] as List? ?? [];
    return LiveCheckResult(
      state: json['state'] as String? ?? 'on_track',
      flags: rawFlags
          .map((f) => LiveCheckFlag.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList(),
      message: json['message'] as String?,
    );
  }
}
