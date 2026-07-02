class Payslip {
  final int id;
  final String? period;
  final int? periodMonth;
  final int? periodYear;
  final int gross;
  final int deductions;
  final int tax;
  final int bpjsEmployee;
  final int net;
  final String? issuedAt;
  final List<PayslipLine> lines;

  Payslip({
    required this.id,
    required this.gross,
    required this.deductions,
    required this.tax,
    required this.bpjsEmployee,
    required this.net,
    this.period,
    this.periodMonth,
    this.periodYear,
    this.issuedAt,
    this.lines = const [],
  });

  factory Payslip.fromJson(Map<String, dynamic> json) => Payslip(
        id: json['id'],
        period: json['period'],
        periodMonth: json['period_month'],
        periodYear: json['period_year'],
        gross: json['gross'] ?? 0,
        deductions: json['deductions'] ?? 0,
        tax: json['tax'] ?? 0,
        bpjsEmployee: json['bpjs_employee'] ?? 0,
        net: json['net'] ?? 0,
        issuedAt: json['issued_at'],
        lines: (json['lines'] as List?)
                ?.map((e) => PayslipLine.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );
}

class PayslipLine {
  final String code;
  final String name;
  final String type; // earning / deduction
  final int amount;

  PayslipLine({required this.code, required this.name, required this.type, required this.amount});

  factory PayslipLine.fromJson(Map<String, dynamic> json) => PayslipLine(
        code: json['component_code'] ?? '',
        name: json['component_name'] ?? '',
        type: json['type'] ?? '',
        amount: json['amount'] ?? 0,
      );
}
