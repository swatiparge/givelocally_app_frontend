class InputSanitizer {
  static final phoneRegex = RegExp(r'^\+91[6-9]\d{9}$');
  static final nameRegex = RegExp(r"^[a-zA-Z\s]{2,50}$");
  static final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  static String sanitizePhone(String input) {
    return input.replaceAll(RegExp(r'[^\d+]'), '');
  }

  static bool isValidPhone(String phone) {
    return phoneRegex.hasMatch(phone);
  }

  static bool isValidName(String name) {
    return nameRegex.hasMatch(name.trim());
  }

  static bool isValidEmail(String email) {
    return emailRegex.hasMatch(email.trim());
  }

  static String sanitizeText(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('"', '"')
        .replaceAll("'", "'");
  }

  static String truncate(String input, int maxLength) {
    if (input.length <= maxLength) return input;
    return '${input.substring(0, maxLength - 3)}...';
  }

  static String cleanSearchQuery(String query) {
    return sanitizeText(query).replaceAll(RegExp(r'[^\w\s]'), '').trim();
  }
}
