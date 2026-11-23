/// A failed API call, normalised from the backend envelope `{ success, code, message, errors[] }`
/// or from a transport failure. `code` is stable and is translated in `core/l10n/error_text.dart`.
class ApiException implements Exception {
  const ApiException({required this.code, this.status, this.message, this.fieldErrors = const {}, this.fieldMessages = const {}, this.serverData});

  /// Transport-level codes (not produced by the backend).
  static const network = 'NETWORK_ERROR';
  static const timeout = 'TIMEOUT';
  static const cancelled = 'CANCELLED';
  static const unknown = 'UNKNOWN';

  final String code;
  final int? status;
  final String? message;

  /// field name → validation code (e.g. `phone` → `INVALID_PHONE`).
  final Map<String, String> fieldErrors;

  /// field name → validation message (e.g. `phone` → `Phone number is required`).
  final Map<String, String> fieldMessages;

  /// Extra payload (e.g. the server copy on a sync conflict).
  final Object? serverData;

  /// Server answers that really end a sign-in (signed out elsewhere, device reset, theft detected,
  /// account disabled). Nothing else — offline, timeouts, server errors — ever signs a member out.
  static const sessionEndingCodes = ['SESSION_REVOKED', 'INVALID_TOKEN', 'REFRESH_EXPIRED', 'INVALID_REFRESH_TOKEN'];

  bool get isNetwork => code == network || code == timeout;
  bool get endsSession => (status == 401 && sessionEndingCodes.contains(code)) || (status == 403 && code == 'ACCOUNT_DISABLED');
  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;
  bool get isNotFound => status == 404;
  bool get isValidation => status == 422 || code == 'VALIDATION_ERROR';

  String? fieldError(String field) => fieldErrors[field];

  @override
  String toString() => 'ApiException($status, $code, $message)';
}
