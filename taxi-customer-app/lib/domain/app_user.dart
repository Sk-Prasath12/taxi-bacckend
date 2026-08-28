class AppUser {
  static String _displayName = 'User';
  static String get displayName => _displayName;
  static set displayName(String name) => _displayName = name;

  static String _email = '';
  static String get email => _email;
  static set email(String email) => _email = email;

  static String _phoneNumber = '';
  static String get phoneNumber => _phoneNumber;
  static set phoneNumber(String phoneNumber) => _phoneNumber = phoneNumber;

  static String _customerId = '';
  static String get customerId => _customerId;
  static set customerId(String id) => _customerId = id;

  static String _city = 'Select City';
  static String get city => _city;
  static set city(String city) => _city = city;

  static dynamic _profileImageData;
  static dynamic get profileImageData => _profileImageData;
  static set profileImageData(dynamic data) => _profileImageData = data;

  static void applyFromMap(Map<String, dynamic> profile) {
    final name = profile['name']?.toString();
    final email = profile['email']?.toString();
    final phone = profile['phone']?.toString();
    final id = profile['id']?.toString();
    if (name != null && name.isNotEmpty) displayName = name;
    if (email != null && email.isNotEmpty) _email = email;
    if (phone != null) phoneNumber = phone;
    if (id != null && id.isNotEmpty) customerId = id;
  }

  static void reset() {
    _displayName = 'User';
    _email = '';
    _phoneNumber = '';
    _customerId = '';
    _profileImageData = null;
  }
}
