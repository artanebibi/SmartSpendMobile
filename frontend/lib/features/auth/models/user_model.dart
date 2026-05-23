class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String? username;
  final String? googleEmail;
  final String? appleEmail;
  final String? avatarUrl;
  final double balance;
  final double monthlySavingGoal;
  final String preferredCurrency;

  const UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.username,
    this.googleEmail,
    this.appleEmail,
    this.avatarUrl,
    required this.balance,
    required this.monthlySavingGoal,
    required this.preferredCurrency,
  });

  String get email => googleEmail ?? appleEmail ?? '';
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return '$f$l'.toUpperCase();
  }
  String get fullName => '$firstName $lastName'.trim();

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id']?.toString() ?? '',
        firstName: j['first_name'] ?? '',
        lastName: j['last_name'] ?? '',
        username: j['username'],
        googleEmail: j['google_email'],
        appleEmail: j['apple_email'],
        avatarUrl: j['avatar_url'],
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        monthlySavingGoal: (j['monthly_saving_goal'] as num?)?.toDouble() ?? 0,
        preferredCurrency: j['preferred_currency'] ?? 'USD',
      );

  UserModel copyWith({
    double? balance,
    double? monthlySavingGoal,
    String? preferredCurrency,
  }) =>
      UserModel(
        id: id,
        firstName: firstName,
        lastName: lastName,
        username: username,
        googleEmail: googleEmail,
        appleEmail: appleEmail,
        avatarUrl: avatarUrl,
        balance: balance ?? this.balance,
        monthlySavingGoal: monthlySavingGoal ?? this.monthlySavingGoal,
        preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      );
}
