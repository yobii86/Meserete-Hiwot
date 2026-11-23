import '../network/api_exception.dart';
import 'l10n.dart';

/// Maps stable backend/transport codes to localized, user-friendly text.
/// Unknown codes fall back to a generic message by HTTP status — raw server text is never shown.
String errorText(AppLocalizations l, Object error) {
  if (error is! ApiException) return l.errorGeneric;
  switch (error.code) {
    case ApiException.network:
      return l.errorNetwork;
    case ApiException.timeout:
      return l.errorTimeout;
    case 'INVALID_CREDENTIALS':
      return l.errInvalidCredentials;
    case 'ACCOUNT_LOCKED':
      return l.errAccountLocked;
      
    case 'ACCOUNT_PENDING':
      return l.errAccountPending;
    case 'PROFILE_LOCKED':
      return l.errProfileLocked;
    case 'ACCOUNT_DISABLED':
      return l.errAccountDisabled;
    case 'DEVICE_ALREADY_REGISTERED':
      return l.errDeviceAlreadyRegistered;
    case 'DEVICE_IN_USE':
      return l.errDeviceInUse;
    case 'ACCOUNT_EXISTS':
      return l.errAccountExists;
    case 'INVALID_RESET_CODE':
      return l.errInvalidResetCode;
    case 'PASSWORD_CHANGE_REQUIRED':
      return l.errPasswordChangeRequired;
    case 'TOKEN_EXPIRED':
    case 'SESSION_REVOKED':
    case 'INVALID_TOKEN':
    case 'REFRESH_EXPIRED':
    case 'INVALID_REFRESH_TOKEN':
      return l.errorSessionExpired;
    case 'PROGRAM_FULL':
      return l.errProgramFull;
    case 'EDU_ATTENDANCE_MOVED':
      return (error.message != null && error.message!.isNotEmpty)
          ? error.message!
          : (l.localeName == 'am' ? 'የክፍል አቴንዳንስ መመዝገቢያ ወደ ፕሮግራሞች ተዛውሯል' : 'Class attendance has moved to programs');
    case 'PROGRAM_ENDED':
      return l.errProgramEnded;
    case 'ASSIGNMENT_PAST_DUE':
      return l.localeName == 'am' ? 'የሥራ ማስረከቢያው ቀን አልፏል' : 'The deadline for this assignment has passed';
    case 'RESUBMISSION_DISALLOWED':
      return l.localeName == 'am' ? 'ይህን ሥራ ደግሞ ማስረከብ አይፈቀድም' : 'Resubmission is not permitted for this assignment';
    case 'SCORE_EXCEEDS_MAX':
      return l.localeName == 'am' ? 'የተሰጠው ውጤት ከተፈቀደው ከፍተኛ ነጥብ በላይ ነው' : 'Score exceeds the maximum allowed score';
    case 'ASSIGNMENT_NOT_OPEN':
      return l.localeName == 'am' ? 'ይህ የቤት ሥራ አልተለቀቀም' : 'This assignment is not published yet';
    case 'PERMISSION_DEADLINE_PASSED':
      return l.errPermissionDeadline;
    case 'PERMISSION_MONTHLY_LIMIT':
      return l.errPermissionMonthly;
    case 'PERMISSION_QUARTERLY_LIMIT':
      return l.errPermissionQuarterly;
    case 'PERMISSION_EXISTS':
      return l.errPermissionExists;
    case 'PERMISSION_REJECTED':
      return l.errPermissionRejected;
    case 'PERMISSION_NOT_APPLICABLE':
      return l.errPermissionNotApplicable;
    case 'PERMISSION_DISABLED':
      return l.errPermissionDisabled;
    case 'DUPLICATE_REMINDER':
      return l.errDuplicateReminder;
    case 'INSUFFICIENT_QUANTITY':
      return l.errInsufficientQuantity;
    case 'ITEM_UNAVAILABLE':
      return l.errItemUnavailable;
    case 'ADMIN_FROM_MEMBER_ONLY':
      return l.errAdminFromMemberOnly;
    case 'USER_NOT_ACTIVE':
      return l.errUserNotActive;
    case 'ALREADY_ADMIN':
      return l.errAlreadyAdmin;
    case 'BOOK_IS_DIGITAL':
      return l.errBookIsDigital;
    case 'REQUEST_EXISTS':
      return l.errRequestExists;
    case 'REQUEST_CLOSED':
      return l.errRequestClosed;
    case 'ALREADY_RETURNED':
      return l.errAlreadyReturned;
    case 'SIGNATURE_EXISTS':
      return l.errSignatureExists;
    case 'CATEGORY_NOT_EMPTY':
      return l.errCategoryNotEmpty;
    case 'ITEM_CODE_TAKEN':
      return l.errItemCodeTaken;
    case 'ITEM_HAS_ACTIVE_BORROWINGS':
      return l.errItemHasActiveBorrowings;
    case 'PERMISSION_NOT_GRANTABLE':
      return l.errPermissionNotGrantable;
    case 'ROLE_NOT_ASSIGNABLE':
    case 'ROLE_LEVEL_TOO_HIGH':
      return l.errRoleNotAssignable;
    case 'ADMIN_NOT_MANAGEABLE':
    case 'ROLE_NOT_MANAGEABLE':
      return l.errAdminNotManageable;
    case 'CANNOT_MODIFY_SELF':
      return l.errCannotModifySelf;
    case 'ROLE_IN_USE':
      return l.errRoleInUse;
    case 'ROLE_IS_SYSTEM':
      return l.errRoleIsSystem;
    case 'SYNC_CONFLICT':
      return l.errSyncConflict;
    case 'TELEGRAM_NOT_CONFIGURED':
      return l.errTelegramNotConfigured;
    case 'VERSION_EXISTS':
      return l.errVersionExists;
    case 'FILE_TOO_LARGE':
    case 'PAYLOAD_TOO_LARGE':
      return l.errorFileTooLarge;
    case 'INVALID_FILE_TYPE':
      return l.errorInvalidFileType;
    case 'TOO_MANY_REQUESTS':
      return l.errorTooMany;
    case 'LOGIN_NOT_ALLOWED':
      return l.errLoginNotAllowed;
    case 'PAYMENT_OVERLAP':
      return l.errPaymentOverlap;
    case 'SUBMISSION_OVERLAP':
      return l.localeName == 'am' ? 'ለዚህ ወር የተላከ ደረሰኝ በግምገማ ላይ ይገኛል' : 'A receipt submission for this period is already under review';
    case 'RATE_NOT_SET':
      return l.rateNotSet;
    case 'CHILDREN_EXEMPT':
      return l.errChildrenExempt;
    case 'CHILDREN_NO_DEPARTMENT':
      return l.errChildrenNoDepartment;
    case 'NOT_DEPARTMENT_LEADER':
      return l.errNotDepartmentLeader;
    case 'FUTURE_PERIOD':
      return l.errFuturePeriod;
    case 'NOT_A_MEMBER':
      return l.errNotAMember;
    case 'CHOIR_NOT_ELIGIBLE':
      return l.errChoirNotEligible;
    case 'MEMBER_NOT_EXPECTED':
      return l.errMemberNotExpected;
    case 'ATTENDANCE_TOO_LATE':
      return l.errAttendanceTooLate;
    case 'MEZMUR_TITLE_TAKEN':
      return l.errMezmurTitleTaken;
    case 'SESSION_NOT_FOUND':
      return l.errSessionNotFound;
    case 'MEMBER_NOT_FOUND':
      return l.errMemberNotFound;
    case 'MEMBER_NOT_IN_GROUP':
      return l.errMemberNotInGroup;
    case 'ATTENDANCE_ALREADY_RECORDED':
      return l.attAlreadyRecorded;
    case 'NOT_PROGRAM_TAKER':
      return l.errNotProgramTaker;
    case 'NOT_ATTENDANCE_TAKER':
      return l.errNotAttendanceTaker;
    case 'ATTENDANCE_NOT_REQUIRED':
      return l.errAttendanceNotRequired;
    case 'PROGRAM_CANCELLED':
      return l.errProgramCancelled;
    case 'MEMBER_GROUP_IN_USE':
      return l.errMemberGroupInUse;
    case 'MEMBER_GROUP_BUILT_IN':
      return l.errMemberGroupBuiltIn;
    case 'INVALID_MEMBER_GROUP':
      return l.errInvalidMemberGroup;
    case 'INVALID_URL':
      return l.errInvalidUrl;
    case 'SELF_ATTENDANCE_NOT_ALLOWED':
      return l.errSelfAttendance;
    case 'SESSION_NOT_STARTED':
      return l.errSessionNotStarted;
    case 'SESSION_NOT_AVAILABLE':
      return l.errSessionNotAvailable;
    case 'BEFORE_SESSION_START':
      return l.errBeforeSessionStart;
    case 'NOT_SESSION_TAKER':
      return l.errNotSessionTaker;
    case 'NO_ATTENDANCE_TAKERS_ASSIGNED':
      return l.errNoTakerAssigned;
    case 'SIGNATURE_REQUIRED':
      return l.errSignatureRequired;
    case 'LATE_REMOVED':
    case 'ABSENT_IS_AUTOMATIC':
      return l.errLateRemoved;
    case 'ONE_TAKER_ONLY':
      return l.errOneTakerOnly;
    case 'CAPTURE_TOO_OLD':
      return l.errCaptureTooOld;
    case 'OUTSIDE_OCCURRENCE':
      return l.errOutsideOccurrence;
    case 'CONFLICT_RESOLVED':
    case 'CONFLICT_NOT_FOUND':
      return l.errConflictResolved;
    case 'SELF_APPROVAL_FORBIDDEN':
      return l.errSelfApproval;
    case 'LOCAL_DATA_UNREADABLE':
      return l.errLocalDataUnreadable;
    case 'ATTENDANCE_CLOSED':
      return l.attClosedNotice;
    case 'ATTENDANCE_NOT_ACTIVE':
      return l.errAttendanceNotActive;
    case 'CHAT_FORBIDDEN':
      return l.errChatForbidden;
    case 'CHAT_PRIVATE_NOT_ALLOWED':
      return l.errChatPrivate;
    case 'CHAT_MEDIA_LEADERS_ONLY':
      return l.errChatMedia;
    case 'CHAT_DELETE_FORBIDDEN':
      return l.errChatDelete;
    case 'TASK_UPDATE_FORBIDDEN':
      return l.errTaskUpdateForbidden;
    case 'PROJECT_FORBIDDEN':
      return l.errProjectForbidden;
    case 'OVER_BUDGET':
      return l.errOverBudget;
    case 'TASK_CHANGED':
      return l.errTaskChanged;
    case 'PROJECT_CLOSED':
      return l.errProjectClosed;
    case 'EXPENSE_APPROVE_FORBIDDEN':
      return l.errExpenseApproveForbidden;
    // ትምህርት learning platform
    case 'MODULE_DISABLED':
      return l.errModuleDisabled;
    case 'HAS_RECORDS':
      return l.errHasRecords;
    case 'LESSON_LOCKED':
      return l.errLessonLocked;
    case 'NOT_ENROLLED':
      return l.errNotEnrolledSubject;
    case 'NOT_TEACHER':
      return l.localeName == 'am' ? 'የትምህርቱ አስተማሪ ብቻ ነው ይህን ማድረግ የሚችለው' : 'Only the course teacher can do this';
    case 'NOT_CONTENT_EDITOR':
    case 'NOT_SUBJECT_EDITOR':
      return l.errNotSubjectEditor;
    case 'COURSE_NOT_FOUND':
      return l.localeName == 'am' ? 'የትምህርት ክፍለ ጊዜ አልተገኘም' : 'Course not found';
    case 'LESSON_NOT_FOUND':
      return l.localeName == 'am' ? 'ትምህርቱ አልተገኘም' : 'Lesson not found';
    case 'ASSESSMENT_NOT_FOUND':
      return l.localeName == 'am' ? 'የውጤት መመዝገቢያ አልተገኘም' : 'Assessment not found';
    case 'ASSESSMENT_REQUIRED':
      return l.localeName == 'am' ? 'ለፈተናው የውጤት መመዝገቢያ ያስፈልጋል' : 'An assessment is required for this exam';
    case 'CLOSES_BEFORE_OPENS':
      return l.localeName == 'am' ? 'የመዝጊያ ቀን ከመክፈቻ ቀን በኋላ መሆን አለበት' : 'Closing date must be after opening date';
    case 'QUIZ_NOT_OPEN':
      return l.errQuizNotOpen;
    case 'QUIZ_CLOSED':
      return l.errQuizClosed;
    case 'NO_ATTEMPTS_LEFT':
      return l.errNoAttemptsLeft;
    case 'ATTEMPT_EXPIRED':
      return l.errAttemptExpired;
    case 'ATTEMPT_SUBMITTED':
      return l.errAttemptSubmitted;
    case 'QUIZ_HAS_ATTEMPTS':
      return l.errQuizHasAttempts;
    case 'QUIZ_EMPTY':
      return l.errQuizEmpty;
    case 'QUIZ_NOT_LINKED':
      return l.errQuizNotLinked;
    case 'ALREADY_TRANSFERRED':
      return l.errAlreadyTransferred;
    case 'VALIDATION_ERROR':
      // Surface the first field-level message if we can translate it.
      for (final e in error.fieldErrors.entries) {
        final t = validationText(l, e.value);
        if (t != null) {
          return t;
        }
      }
      // If server provided explicit field messages, return the first one
      if (error.fieldMessages.isNotEmpty) {
        final first = error.fieldMessages.entries.first;
        final f = first.key.isNotEmpty && first.key != 'body' ? '${first.key}: ' : '';
        return '$f${first.value}';
      }
      if (error.message != null && error.message!.isNotEmpty && error.message != 'Validation failed') {
        return error.message!;
      }
      return l.errorValidation;
  }
  if (error.message != null &&
      error.message!.isNotEmpty &&
      !error.message!.contains('SQLSTATE') &&
      !error.message!.contains('Exception') &&
      !error.message!.contains('Connection:') &&
      !error.message!.contains('Stack trace')) {
    return error.message!;
  }
  final s = error.status ?? 0;
  if (s == 401) return l.errorUnauthorized;
  if (s == 403) return l.errorForbidden;
  if (s == 404) return l.errorNotFound;
  if (s == 409) return l.errorValidation;
  if (s == 429) return l.errorTooMany;
  if (s >= 500) return l.errorServer;
  return l.errorGeneric;
}

/// Field validation codes → text. Returns null for unknown codes.
String? validationText(AppLocalizations l, String code) {
  switch (code) {
    case 'REQUIRED':
    case 'DEVICE_REQUIRED':
    case 'TARGET_REQUIRED':
      return l.vRequired;
    case 'LATE_ABOVE_PRESENT':
    case 'ABSENT_ABOVE_LATE':
      return l.errLateAbovePresent;
    case 'NO_CHANGES':
      return l.errNoChanges;
    case 'INVALID_PHONE':
      return l.vInvalidPhone;
    case 'INVALID_EMAIL':
      return l.vInvalidEmail;
    case 'PASSWORD_TOO_SHORT':
      return l.vPasswordShort;
    case 'PASSWORD_WEAK':
      return l.vPasswordWeak;
    case 'TOO_LONG':
    case 'PASSWORD_TOO_LONG':
      return l.vTooLong;
    case 'TOO_SHORT':
      return l.vTooShort;
    case 'INVALID_DATE':
      return l.vInvalidDate;
    case 'END_BEFORE_START':
      return l.vEndBeforeStart;
    case 'WEIGHTS_MUST_TOTAL_100':
      return l.vWeightsTotal;
    case 'MINIMUM_ABOVE_WEIGHT':
      return l.vMinimumAboveWeight;
    case 'INVALID_PERIOD':
      return l.vInvalidDate;
    case 'DEADLINE_BEFORE_BORROW':
      return l.vDeadlineBeforeBorrow;
    case 'RETURN_BEFORE_BORROW':
      return l.vReturnBeforeBorrow;
    case 'NEGATIVE_AMOUNT':
      return l.vNegativeAmount;
    case 'WRONG_PASSWORD':
      return l.vWrongPassword;
    case 'PASSWORD_REUSED':
      return l.vPasswordReused;
    case 'TASK_AFTER_PROJECT_DEADLINE':
      return l.errTaskAfterProjectDeadline;
    case 'PENDING_REASON_REQUIRED':
      return l.errPendingReasonRequired;
    case 'BLOCKER_REQUIRED':
      return l.errBlockerRequired;
    case 'USER_NOT_IN_DEPARTMENT':
      return l.errUserNotInDepartment;
    case 'RESOLUTION_REQUIRED':
      return l.errResolutionRequired;
    case 'INVALID_PIN':
      return l.vInvalidPin;
    case 'PIN_OR_PASSWORD_INVALID':
      return l.vPinOrPassword;
    case 'MEMBER_TYPE_REQUIRED':
      return l.setMemberTypeFirst;
    case 'FUTURE_PERIOD':
      return l.errFuturePeriod;
    case 'NOT_A_MEMBER':
      return l.errNotAMember;
    case 'HTML_NOT_ALLOWED':
      return l.vHtmlNotAllowed;
    case 'INVALID_CODE':
      return l.vInvalidCode;
    case 'INVALID_CONDITION':
      return l.vInvalidCondition;
    case 'INVALID_RETURN_QUANTITY':
      return l.vInvalidReturnQuantity;
    case 'QUANTITY_BELOW_BORROWED':
      return l.vQuantityBelowBorrowed;
    case 'PHONE_TAKEN':
      return l.errPhoneTaken;
    case 'EMAIL_TAKEN':
      return l.errEmailTaken;
    case 'CATEGORY_SELF_PARENT':
    case 'CATEGORY_CYCLE':
      return l.errCategoryCycle;
    case 'ITEM_CODE_TAKEN':
      return l.errItemCodeTaken;
    case 'NO_RECIPIENTS':
      return l.errNoRecipients;
    case 'INVALID_YOUTUBE_URL':
      return l.vInvalidYoutube;
    case 'VERSION_EXISTS':
      return l.errVersionExists;
    case 'INVALID_VERSION':
      return l.vInvalidVersion;
    case 'MESSAGE_EMPTY':
      return l.vMessageEmpty;
    case 'INVALID_MEETING_URL':
      return l.vInvalidMeetingUrl;
    case 'NO_SPACES':
      return l.vNoSpaces;
    case 'INVALID_ID':
    case 'INVALID_VALUE':
    case 'INVALID_TYPE':
      return l.vInvalidValue;
    case 'COURSE_NOT_FOUND':
      return l.localeName == 'am' ? 'የትምህርት ክፍለ ጊዜ አልተገኘም' : 'Course not found';
    case 'LESSON_NOT_FOUND':
      return l.localeName == 'am' ? 'ትምህርቱ አልተገኘም' : 'Lesson not found';
    case 'ASSESSMENT_NOT_FOUND':
      return l.localeName == 'am' ? 'የውጤት መመዝገቢያ አልተገኘም' : 'Assessment not found';
    case 'ASSESSMENT_REQUIRED':
      return l.localeName == 'am' ? 'የውጤት መመዝገቢያ ያስፈልጋል' : 'Assessment is required';
    case 'CLOSES_BEFORE_OPENS':
      return l.localeName == 'am' ? 'የመዝጊያ ቀን ከመክፈቻ ቀን በኋላ መሆን አለበት' : 'Closing date must be after opening date';
    case 'REASON_REQUIRED':
      return l.localeName == 'am' ? 'ውድቅ የተደረገበት ምክንያት ማስገባት ግዴታ ነው' : 'A rejection reason is required';
    case 'MAX_ATTEMPTS_REACHED':
      return l.localeName == 'am' ? 'የተፈቀደው ከፍተኛ የፈተና ሙከራዎች ገደብ አልቋል' : 'Maximum exam attempts reached';
    case 'RESULTS_WITHHELD':
      return l.localeName == 'am' ? 'ውጤቱ እስኪለቀቅ ድረስ አይታይም' : 'Results are withheld until official release';
    case 'NOT_ENROLLED':
      return l.localeName == 'am' ? 'በዚህ ክፍል ውስጥ አልተመዘገቡም' : 'You are not enrolled in this class';
    case 'FILE_REQUIRED':
      return l.localeName == 'am' ? 'ሰነድ ወይም ደረሰኝ ማያያዝ ያስፈልጋል' : 'A document or receipt is required';
    case 'INVALID_MONTHS':
      return l.localeName == 'am' ? 'የወራት ብዛት ከ 1 እስከ 12 መሆን አለበት' : 'Months covered must be between 1 and 12';
    case 'OVERLAPPING_PERIODS':
      return l.localeName == 'am' ? 'የተመረጡት ወራት ቀደም ሲል ከተከፈሉት ጋር ይጋጫሉ' : 'Selected months overlap with previously paid months';
  }
  return null;
}

/// Every field the server rejected, one line each: "Field — reason" (labels from [label]).
/// Used instead of a general "check the information" message so the member sees what to fix.
String? fieldErrorsSummary(AppLocalizations l, Object? error, String Function(String field) label) {
  if (error is! ApiException || error.fieldErrors.isEmpty) return null;
  return error.fieldErrors.entries.map((e) => '${label(e.key)} — ${validationText(l, e.value) ?? (e.value == 'PHONE_TAKEN' || e.value == 'EMAIL_TAKEN' ? errorText(l, error) : l.vInvalidValue)}').join('\n');
}

/// Server-side field error for a form field, translated (or null).
String? serverFieldError(AppLocalizations l, Object? error, String field) {
  if (error is! ApiException) return null;
  final code = error.fieldError(field);
  if (code == null) return null;
  return validationText(l, code) ?? l.vInvalidValue;
}
