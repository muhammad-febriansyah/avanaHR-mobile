class LeaveBalance {
  final String? leaveType;
  final int year;
  final double entitled;
  final double used;
  final double pending;
  final double available;

  LeaveBalance({
    required this.year,
    required this.entitled,
    required this.used,
    required this.pending,
    required this.available,
    this.leaveType,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> json) => LeaveBalance(
        leaveType: json['leave_type'],
        year: (json['year'] ?? 0) is int ? json['year'] : int.tryParse('${json['year']}') ?? 0,
        entitled: (json['entitled'] ?? 0).toDouble(),
        used: (json['used'] ?? 0).toDouble(),
        pending: (json['pending'] ?? 0).toDouble(),
        available: (json['available'] ?? 0).toDouble(),
      );
}
