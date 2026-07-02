class Employment {
  final String? company;
  final String? branch;
  final String? department;
  final String? position;
  final String? jobGrade;
  final String? employmentType;

  Employment({
    this.company,
    this.branch,
    this.department,
    this.position,
    this.jobGrade,
    this.employmentType,
  });

  factory Employment.fromJson(Map<String, dynamic> json) => Employment(
        company: json['company'],
        branch: json['branch'],
        department: json['department'],
        position: json['position'],
        jobGrade: json['job_grade'],
        employmentType: json['employment_type'],
      );
}

class Profile {
  final int id;
  final String employeeNo;
  final String fullName;
  final String? email;
  final String? phone;
  final String? address;
  final String status;
  final String? joinDate;
  final String? photoUrl;
  final Employment? employment;

  Profile({
    required this.id,
    required this.employeeNo,
    required this.fullName,
    required this.status,
    this.email,
    this.phone,
    this.address,
    this.joinDate,
    this.photoUrl,
    this.employment,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'],
        employeeNo: json['employee_no'] ?? '',
        fullName: json['full_name'] ?? '',
        email: json['email'],
        phone: json['phone'],
        address: json['address'],
        status: json['status'] ?? '',
        joinDate: json['join_date'],
        photoUrl: json['photo_url'],
        employment: json['employment'] != null
            ? Employment.fromJson(Map<String, dynamic>.from(json['employment']))
            : null,
      );
}
