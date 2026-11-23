import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('am'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In am, this message translates to:
  /// **'መሠረተ ሕይወት'**
  String get appName;

  /// No description provided for @schoolName.
  ///
  /// In am, this message translates to:
  /// **'መሠረተ ሕይወት ሰንበት ት/ቤት'**
  String get schoolName;

  /// No description provided for @churchName.
  ///
  /// In am, this message translates to:
  /// **'ደብረ እንቁ ቅድስት ልደታ ለማርያም ቤተ ክርስቲያን'**
  String get churchName;

  /// No description provided for @navHome.
  ///
  /// In am, this message translates to:
  /// **'መነሻ'**
  String get navHome;

  /// No description provided for @navPrograms.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራሞች'**
  String get navPrograms;

  /// No description provided for @navLibrary.
  ///
  /// In am, this message translates to:
  /// **'የእኔ'**
  String get navLibrary;

  /// No description provided for @navNotifications.
  ///
  /// In am, this message translates to:
  /// **'ማሳወቂያ'**
  String get navNotifications;

  /// No description provided for @navSettings.
  ///
  /// In am, this message translates to:
  /// **'ማስተካከያ'**
  String get navSettings;

  /// No description provided for @ok.
  ///
  /// In am, this message translates to:
  /// **'እሺ'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In am, this message translates to:
  /// **'ይቅር'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In am, this message translates to:
  /// **'አስቀምጥ'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In am, this message translates to:
  /// **'ሰርዝ'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In am, this message translates to:
  /// **'አስተካክል'**
  String get edit;

  /// No description provided for @retry.
  ///
  /// In am, this message translates to:
  /// **'እንደገና ሞክር'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In am, this message translates to:
  /// **'ዝጋ'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In am, this message translates to:
  /// **'አረጋግጥ'**
  String get confirm;

  /// No description provided for @yes.
  ///
  /// In am, this message translates to:
  /// **'አዎ'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In am, this message translates to:
  /// **'አይ'**
  String get no;

  /// No description provided for @search.
  ///
  /// In am, this message translates to:
  /// **'ፈልግ'**
  String get search;

  /// No description provided for @open.
  ///
  /// In am, this message translates to:
  /// **'ክፈት'**
  String get open;

  /// No description provided for @seeAll.
  ///
  /// In am, this message translates to:
  /// **'ሁሉንም እይ'**
  String get seeAll;

  /// No description provided for @loading.
  ///
  /// In am, this message translates to:
  /// **'በመጫን ላይ…'**
  String get loading;

  /// No description provided for @next.
  ///
  /// In am, this message translates to:
  /// **'ቀጣይ'**
  String get next;

  /// No description provided for @back.
  ///
  /// In am, this message translates to:
  /// **'ተመለስ'**
  String get back;

  /// No description provided for @create.
  ///
  /// In am, this message translates to:
  /// **'ፍጠር'**
  String get create;

  /// No description provided for @add.
  ///
  /// In am, this message translates to:
  /// **'ጨምር'**
  String get add;

  /// No description provided for @send.
  ///
  /// In am, this message translates to:
  /// **'ላክ'**
  String get send;

  /// No description provided for @select.
  ///
  /// In am, this message translates to:
  /// **'ምረጥ'**
  String get select;

  /// No description provided for @selectAll.
  ///
  /// In am, this message translates to:
  /// **'የሚታዩትን ሁሉ ምረጥ'**
  String get selectAll;

  /// No description provided for @clearSelection.
  ///
  /// In am, this message translates to:
  /// **'ምርጫ አጽዳ'**
  String get clearSelection;

  /// No description provided for @apply.
  ///
  /// In am, this message translates to:
  /// **'ተግብር'**
  String get apply;

  /// No description provided for @filter.
  ///
  /// In am, this message translates to:
  /// **'አጣራ'**
  String get filter;

  /// No description provided for @remove.
  ///
  /// In am, this message translates to:
  /// **'አስወግድ'**
  String get remove;

  /// No description provided for @share.
  ///
  /// In am, this message translates to:
  /// **'አጋራ'**
  String get share;

  /// No description provided for @none.
  ///
  /// In am, this message translates to:
  /// **'ምንም'**
  String get none;

  /// No description provided for @all.
  ///
  /// In am, this message translates to:
  /// **'ሁሉም'**
  String get all;

  /// No description provided for @optional.
  ///
  /// In am, this message translates to:
  /// **'አማራጭ'**
  String get optional;

  /// No description provided for @saved.
  ///
  /// In am, this message translates to:
  /// **'ተቀምጧል'**
  String get saved;

  /// No description provided for @deleted.
  ///
  /// In am, this message translates to:
  /// **'ተሰርዟል'**
  String get deleted;

  /// No description provided for @done.
  ///
  /// In am, this message translates to:
  /// **'ተጠናቋል'**
  String get done;

  /// No description provided for @deleteConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህን መሰረዝ ይፈልጋሉ? ይህ ተግባር ሊቀለበስ አይችልም።'**
  String get deleteConfirm;

  /// No description provided for @continueAction.
  ///
  /// In am, this message translates to:
  /// **'ቀጥል'**
  String get continueAction;

  /// No description provided for @details.
  ///
  /// In am, this message translates to:
  /// **'ዝርዝር'**
  String get details;

  /// No description provided for @notes.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻ'**
  String get notes;

  /// No description provided for @status.
  ///
  /// In am, this message translates to:
  /// **'ሁኔታ'**
  String get status;

  /// No description provided for @date.
  ///
  /// In am, this message translates to:
  /// **'ቀን'**
  String get date;

  /// No description provided for @time.
  ///
  /// In am, this message translates to:
  /// **'ሰዓት'**
  String get time;

  /// No description provided for @from.
  ///
  /// In am, this message translates to:
  /// **'ከ'**
  String get from;

  /// No description provided for @to.
  ///
  /// In am, this message translates to:
  /// **'እስከ'**
  String get to;

  /// No description provided for @change.
  ///
  /// In am, this message translates to:
  /// **'ቀይር'**
  String get change;

  /// No description provided for @pickDate.
  ///
  /// In am, this message translates to:
  /// **'ቀን ይምረጡ'**
  String get pickDate;

  /// No description provided for @pickTime.
  ///
  /// In am, this message translates to:
  /// **'ሰዓት ይምረጡ'**
  String get pickTime;

  /// No description provided for @copied.
  ///
  /// In am, this message translates to:
  /// **'ተቀድቷል'**
  String get copied;

  /// No description provided for @errorNetwork.
  ///
  /// In am, this message translates to:
  /// **'የኢንተርኔት ግንኙነት የለም። እባክዎ ግንኙነትዎን ያረጋግጡ።'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In am, this message translates to:
  /// **'ምላሽ ለማግኘት ጊዜው አልፏል። እባክዎ የኢንተርኔት  ግንኙነት ያረጋግጡና እንደገና ይሞክሩ።'**
  String get errorTimeout;

  /// No description provided for @errorUnauthorized.
  ///
  /// In am, this message translates to:
  /// **'እባክዎ እንደገና ይግቡ።'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In am, this message translates to:
  /// **'ይህን ለማድረግ ፈቃድ የለዎትም።'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In am, this message translates to:
  /// **'የተጠየቀው መረጃ አልተገኘም።'**
  String get errorNotFound;

  /// No description provided for @errorValidation.
  ///
  /// In am, this message translates to:
  /// **'እባክዎ ያስገቡትን መረጃ ያረጋግጡ።'**
  String get errorValidation;

  /// No description provided for @errorServer.
  ///
  /// In am, this message translates to:
  /// **'ችግር ተፈጥሯል። ትንሽ ቆይተው እንደገና ይሞክሩ።'**
  String get errorServer;

  /// No description provided for @errorSessionExpired.
  ///
  /// In am, this message translates to:
  /// **'ክፍለ ጊዜዎ አብቅቷል። እባክዎ እንደገና ይግቡ።'**
  String get errorSessionExpired;

  /// No description provided for @errorOffline.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ ነዎት'**
  String get errorOffline;

  /// No description provided for @errorTooMany.
  ///
  /// In am, this message translates to:
  /// **'በጣም ብዙ ሙከራዎች ተደርገዋል። ትንሽ ቆይተው ይሞክሩ።'**
  String get errorTooMany;

  /// No description provided for @errorGeneric.
  ///
  /// In am, this message translates to:
  /// **'ያልተጠበቀ ስህተት ተፈጥሯል።'**
  String get errorGeneric;

  /// No description provided for @errorFileTooLarge.
  ///
  /// In am, this message translates to:
  /// **'ፋይሉ በጣም ትልቅ ነው።'**
  String get errorFileTooLarge;

  /// No description provided for @errorInvalidFileType.
  ///
  /// In am, this message translates to:
  /// **'የዚህ ዓይነት ፋይል አይፈቀድም።'**
  String get errorInvalidFileType;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In am, this message translates to:
  /// **'ስልክ ቁጥር/ኢሜይል ወይም ፒን ትክክል አይደለም።'**
  String get errInvalidCredentials;

  /// No description provided for @errAccountLocked.
  ///
  /// In am, this message translates to:
  /// **'በተደጋጋሚ የተሳሳተ ሙከራ ምክንያት መለያዎ ለጊዜው ተቆልፏል። ከ15 ደቂቃ በኋላ እንደገና ይሞክሩ።'**
  String get errAccountLocked;

  /// No description provided for @errAccountDisabled.
  ///
  /// In am, this message translates to:
  /// **'መለያዎ ታግዷል። እባክዎ አስተዳዳሪውን ያነጋግሩ።'**
  String get errAccountDisabled;

  /// No description provided for @errDeviceAlreadyRegistered.
  ///
  /// In am, this message translates to:
  /// **'ይህ መለያ በሌላ መሣሪያ ላይ ተመዝግቧል። በዚህ መሣሪያ ለመግባት አስተዳዳሪው መሣሪያዎን ዳግም እንዲያስጀምርልዎ ይጠይቁ።'**
  String get errDeviceAlreadyRegistered;

  /// No description provided for @errDeviceInUse.
  ///
  /// In am, this message translates to:
  /// **'ይህ መሣሪያ በሌላ መለያ ተመዝግቧል። እባክዎ አስተዳዳሪውን ያነጋግሩ።'**
  String get errDeviceInUse;

  /// No description provided for @errAccountExists.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ስልክ ቁጥር ወይም ኢሜይል መለያ አስቀድሞ አለ።'**
  String get errAccountExists;

  /// No description provided for @errPhoneTaken.
  ///
  /// In am, this message translates to:
  /// **'ይህ ስልክ ቁጥር አስቀድሞ ተመዝግቧል'**
  String get errPhoneTaken;

  /// No description provided for @errEmailTaken.
  ///
  /// In am, this message translates to:
  /// **'ይህ ኢሜይል አስቀድሞ ተመዝግቧል'**
  String get errEmailTaken;

  /// No description provided for @errInvalidResetCode.
  ///
  /// In am, this message translates to:
  /// **'ኮዱ ትክክል አይደለም ወይም ጊዜው አልፏል።'**
  String get errInvalidResetCode;

  /// No description provided for @errPasswordChangeRequired.
  ///
  /// In am, this message translates to:
  /// **'ለመቀጠል አዲስ ፒን ማዘጋጀት አለብዎት።'**
  String get errPasswordChangeRequired;

  /// No description provided for @errProgramFull.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራሙ ሞልቷል።'**
  String get errProgramFull;

  /// No description provided for @errProgramEnded.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራሙ ተጠናቋል።'**
  String get errProgramEnded;

  /// No description provided for @errDuplicateReminder.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ሰዓት ማስታወሻ አስቀድሞ አለ።'**
  String get errDuplicateReminder;

  /// No description provided for @errInsufficientQuantity.
  ///
  /// In am, this message translates to:
  /// **'በቂ እቃ በክምችት የለም።'**
  String get errInsufficientQuantity;

  /// No description provided for @errItemUnavailable.
  ///
  /// In am, this message translates to:
  /// **'እቃው ለውሰት አይገኝም።'**
  String get errItemUnavailable;

  /// No description provided for @errAlreadyReturned.
  ///
  /// In am, this message translates to:
  /// **'ይህ ውሰት አስቀድሞ ተመልሷል።'**
  String get errAlreadyReturned;

  /// No description provided for @errSignatureExists.
  ///
  /// In am, this message translates to:
  /// **'ለዚህ ውሰት ፊርማ አስቀድሞ ተሰጥቷል።'**
  String get errSignatureExists;

  /// No description provided for @errCategoryNotEmpty.
  ///
  /// In am, this message translates to:
  /// **'ምድቡ ንዑስ ምድቦች ወይም መዝሙሮች ስላሉት መሰረዝ አይቻልም። በምትኩ ያቦዝኑት።'**
  String get errCategoryNotEmpty;

  /// No description provided for @errCategoryCycle.
  ///
  /// In am, this message translates to:
  /// **'ምድብን በራሱ ወይም በንዑስ ምድቡ ስር ማድረግ አይቻልም።'**
  String get errCategoryCycle;

  /// No description provided for @errItemCodeTaken.
  ///
  /// In am, this message translates to:
  /// **'ይህ የእቃ ኮድ አስቀድሞ አለ።'**
  String get errItemCodeTaken;

  /// No description provided for @errItemHasActiveBorrowings.
  ///
  /// In am, this message translates to:
  /// **'እቃው ያልተመለሱ ውሰቶች አሉት።'**
  String get errItemHasActiveBorrowings;

  /// No description provided for @errPermissionNotGrantable.
  ///
  /// In am, this message translates to:
  /// **'እርስዎ የሌለዎትን ፈቃድ መስጠት አይችሉም።'**
  String get errPermissionNotGrantable;

  /// No description provided for @errRoleNotAssignable.
  ///
  /// In am, this message translates to:
  /// **'ከእርስዎ ደረጃ እኩል ወይም በላይ የሆነ ሚና መስጠት አይቻልም።'**
  String get errRoleNotAssignable;

  /// No description provided for @errAdminNotManageable.
  ///
  /// In am, this message translates to:
  /// **'ይህን አስተዳዳሪ ማስተዳደር አይችሉም።'**
  String get errAdminNotManageable;

  /// No description provided for @errCannotModifySelf.
  ///
  /// In am, this message translates to:
  /// **'የራስዎን ሚና፣ ፈቃድ ወይም ሁኔታ መቀየር አይችሉም።'**
  String get errCannotModifySelf;

  /// No description provided for @errNoRecipients.
  ///
  /// In am, this message translates to:
  /// **'ምንም ተቀባይ አልተመረጠም።'**
  String get errNoRecipients;

  /// No description provided for @errSyncConflict.
  ///
  /// In am, this message translates to:
  /// **'ይህ መረጃ በሌላ ቦታ ተቀይሯል።'**
  String get errSyncConflict;

  /// No description provided for @errRoleInUse.
  ///
  /// In am, this message translates to:
  /// **'ሚናው ለአስተዳዳሪዎች ተሰጥቷል።'**
  String get errRoleInUse;

  /// No description provided for @errRoleIsSystem.
  ///
  /// In am, this message translates to:
  /// **'መሠረታዊ ሚናዎችን መሰረዝ አይቻልም።'**
  String get errRoleIsSystem;

  /// No description provided for @vRequired.
  ///
  /// In am, this message translates to:
  /// **'ይህ መስክ ያስፈልጋል'**
  String get vRequired;

  /// No description provided for @vInvalidPhone.
  ///
  /// In am, this message translates to:
  /// **'ትክክለኛ የኢትዮጵያ ስልክ ቁጥር ያስገቡ (ለምሳሌ 0911223344)'**
  String get vInvalidPhone;

  /// No description provided for @vInvalidEmail.
  ///
  /// In am, this message translates to:
  /// **'ትክክለኛ ኢሜይል ያስገቡ'**
  String get vInvalidEmail;

  /// No description provided for @vPasswordShort.
  ///
  /// In am, this message translates to:
  /// **'ፒኑ ከ4 እስከ 6 ቁጥሮች መሆን አለበት'**
  String get vPasswordShort;

  /// No description provided for @vPasswordWeak.
  ///
  /// In am, this message translates to:
  /// **'ፒኑ ቁጥሮች ብቻ መሆን አለበት'**
  String get vPasswordWeak;

  /// No description provided for @vPasswordMismatch.
  ///
  /// In am, this message translates to:
  /// **'ፒኖቹ አይመሳሰሉም'**
  String get vPasswordMismatch;

  /// No description provided for @vTooLong.
  ///
  /// In am, this message translates to:
  /// **'በጣም ረጅም ነው'**
  String get vTooLong;

  /// No description provided for @vTooShort.
  ///
  /// In am, this message translates to:
  /// **'በጣም አጭር ነው'**
  String get vTooShort;

  /// No description provided for @vInvalidDate.
  ///
  /// In am, this message translates to:
  /// **'ትክክለኛ ቀን ያስገቡ'**
  String get vInvalidDate;

  /// No description provided for @vEndBeforeStart.
  ///
  /// In am, this message translates to:
  /// **'የማብቂያ ጊዜ ከመጀመሪያው ጊዜ በፊት መሆን አይችልም'**
  String get vEndBeforeStart;

  /// No description provided for @vDeadlineBeforeBorrow.
  ///
  /// In am, this message translates to:
  /// **'የመመለሻ ቀን ከተወሰደበት ቀን በፊት መሆን አይችልም'**
  String get vDeadlineBeforeBorrow;

  /// No description provided for @vReturnBeforeBorrow.
  ///
  /// In am, this message translates to:
  /// **'የተመለሰበት ቀን ከተወሰደበት ቀን በፊት መሆን አይችልም'**
  String get vReturnBeforeBorrow;

  /// No description provided for @vNegativeAmount.
  ///
  /// In am, this message translates to:
  /// **'መጠኑ ከዜሮ በታች መሆን አይችልም'**
  String get vNegativeAmount;

  /// No description provided for @vInvalidNumber.
  ///
  /// In am, this message translates to:
  /// **'ትክክለኛ ቁጥር ያስገቡ'**
  String get vInvalidNumber;

  /// No description provided for @vWrongPassword.
  ///
  /// In am, this message translates to:
  /// **'የአሁኑ ፒን ትክክል አይደለም'**
  String get vWrongPassword;

  /// No description provided for @vPasswordReused.
  ///
  /// In am, this message translates to:
  /// **'አዲሱ ፒን ከቀድሞው የተለየ መሆን አለበት'**
  String get vPasswordReused;

  /// No description provided for @vHtmlNotAllowed.
  ///
  /// In am, this message translates to:
  /// **'ልዩ ምልክቶች (< >) አይፈቀዱም'**
  String get vHtmlNotAllowed;

  /// No description provided for @vInvalidCode.
  ///
  /// In am, this message translates to:
  /// **'ባለ 6 አሃዝ ኮድ ያስገቡ'**
  String get vInvalidCode;

  /// No description provided for @vInvalidCondition.
  ///
  /// In am, this message translates to:
  /// **'የተመለሰበትን ሁኔታ ይምረጡ'**
  String get vInvalidCondition;

  /// No description provided for @vInvalidReturnQuantity.
  ///
  /// In am, this message translates to:
  /// **'የተመለሰው ብዛት ትክክል አይደለም'**
  String get vInvalidReturnQuantity;

  /// No description provided for @vQuantityBelowBorrowed.
  ///
  /// In am, this message translates to:
  /// **'ብዛቱ በውሰት ካለው ብዛት ማነስ አይችልም'**
  String get vQuantityBelowBorrowed;

  /// No description provided for @vInvalidValue.
  ///
  /// In am, this message translates to:
  /// **'ትክክለኛ ያልሆነ ዋጋ'**
  String get vInvalidValue;

  /// No description provided for @vReminderInPast.
  ///
  /// In am, this message translates to:
  /// **'ያለፈ ጊዜ መምረጥ አይቻልም'**
  String get vReminderInPast;

  /// No description provided for @loginTitle.
  ///
  /// In am, this message translates to:
  /// **'እንኳን ደህና መጡ'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In am, this message translates to:
  /// **'ለመቀጠል ወደ መለያዎ ይግቡ'**
  String get loginSubtitle;

  /// No description provided for @phoneOrEmail.
  ///
  /// In am, this message translates to:
  /// **'ስልክ ቁጥር ወይም ኢሜይል'**
  String get phoneOrEmail;

  /// No description provided for @password.
  ///
  /// In am, this message translates to:
  /// **'ፒን (PIN)'**
  String get password;

  /// No description provided for @login.
  ///
  /// In am, this message translates to:
  /// **'ግባ'**
  String get login;

  /// No description provided for @noAccount.
  ///
  /// In am, this message translates to:
  /// **'መለያ የለዎትም?'**
  String get noAccount;

  /// No description provided for @register.
  ///
  /// In am, this message translates to:
  /// **'ይመዝገቡ'**
  String get register;

  /// No description provided for @registerTitle.
  ///
  /// In am, this message translates to:
  /// **'አዲስ መለያ ይክፈቱ'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In am, this message translates to:
  /// **'መዝሙሮችን፣ ፕሮግራሞችንና ማሳወቂያዎችን ለማግኘት ይመዝገቡ'**
  String get registerSubtitle;

  /// No description provided for @fullName.
  ///
  /// In am, this message translates to:
  /// **'ሙሉ ስም'**
  String get fullName;

  /// No description provided for @phone.
  ///
  /// In am, this message translates to:
  /// **'ስልክ ቁጥር'**
  String get phone;

  /// No description provided for @email.
  ///
  /// In am, this message translates to:
  /// **'ኢሜይል'**
  String get email;

  /// No description provided for @emailOptional.
  ///
  /// In am, this message translates to:
  /// **'ኢሜይል (አማራጭ)'**
  String get emailOptional;

  /// No description provided for @confirmPassword.
  ///
  /// In am, this message translates to:
  /// **'ፒኑን ያረጋግጡ'**
  String get confirmPassword;

  /// No description provided for @passwordHelp.
  ///
  /// In am, this message translates to:
  /// **'ቢያንስ 8 ፊደላት፤ ፊደልና ቁጥር ይያዝ'**
  String get passwordHelp;

  /// No description provided for @haveAccount.
  ///
  /// In am, this message translates to:
  /// **'መለያ አለዎት?'**
  String get haveAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In am, this message translates to:
  /// **'ፒን ረሱ?'**
  String get forgotPassword;

  /// No description provided for @forgotTitle.
  ///
  /// In am, this message translates to:
  /// **'ፒን መመለሻ'**
  String get forgotTitle;

  /// No description provided for @forgotHint.
  ///
  /// In am, this message translates to:
  /// **'ስልክ ቁጥርዎን ወይም ኢሜይልዎን ያስገቡ። ባለ 6 አሃዝ ኮድ በቴሌግራም (ካገናኙ) ወይም በኢሜይል ይላክልዎታል።'**
  String get forgotHint;

  /// No description provided for @sendCode.
  ///
  /// In am, this message translates to:
  /// **'ኮድ ላክ'**
  String get sendCode;

  /// No description provided for @codeSent.
  ///
  /// In am, this message translates to:
  /// **'መለያው ካለ የማረጋገጫ ኮድ ተልኳል።'**
  String get codeSent;

  /// No description provided for @resetCode.
  ///
  /// In am, this message translates to:
  /// **'የማረጋገጫ ኮድ'**
  String get resetCode;

  /// No description provided for @newPassword.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ፒን'**
  String get newPassword;

  /// No description provided for @resetPassword.
  ///
  /// In am, this message translates to:
  /// **'ፒን ቀይር'**
  String get resetPassword;

  /// No description provided for @passwordResetDone.
  ///
  /// In am, this message translates to:
  /// **'ፒንዎ ተቀይሯል። አሁን መግባት ይችላሉ።'**
  String get passwordResetDone;

  /// No description provided for @changePasswordTitle.
  ///
  /// In am, this message translates to:
  /// **'ፒን ቀይር'**
  String get changePasswordTitle;

  /// No description provided for @currentPassword.
  ///
  /// In am, this message translates to:
  /// **'የአሁኑ ፒን'**
  String get currentPassword;

  /// No description provided for @mustChangePasswordHint.
  ///
  /// In am, this message translates to:
  /// **'ለደህንነትዎ ሲባል የራስዎን ፒን (ከ4 እስከ 6 ቁጥሮች) አሁን ያዘጋጁ።'**
  String get mustChangePasswordHint;

  /// No description provided for @passwordChanged.
  ///
  /// In am, this message translates to:
  /// **'ፒን ተቀይሯል'**
  String get passwordChanged;

  /// No description provided for @logout.
  ///
  /// In am, this message translates to:
  /// **'ውጣ'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In am, this message translates to:
  /// **'ከመለያዎ መውጣት ይፈልጋሉ?'**
  String get logoutConfirm;

  /// No description provided for @syncPendingLogoutTitle.
  ///
  /// In am, this message translates to:
  /// **'{count} ያልተመሳሰሉ መረጃዎች አሉ'**
  String syncPendingLogoutTitle(int count);

  /// No description provided for @syncPendingLogoutBody.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ የተመዘገቡ {count} መረጃዎች ወደ አገልጋዩ አልተላኩም። አሁን ከወጡ እና ካጠፏቸው በቋሚነት ይጠፋሉ።'**
  String syncPendingLogoutBody(int count);

  /// No description provided for @syncStaySignedIn.
  ///
  /// In am, this message translates to:
  /// **'ሳልወጣ ልቆይ'**
  String get syncStaySignedIn;

  /// No description provided for @syncDiscardAndLogout.
  ///
  /// In am, this message translates to:
  /// **'መረጃዎችን አጥፍተህ ውጣ'**
  String get syncDiscardAndLogout;

  /// No description provided for @syncDiscardConfirmBody.
  ///
  /// In am, this message translates to:
  /// **'በእርግጥ {count} ያልተመሳሰሉ ከመስመር ውጭ የተመዘገቡ መረጃዎች እንዲጠፉ ይፈልጋሉ? ይህን እርምጃ መመለስ አይቻልም።'**
  String syncDiscardConfirmBody(int count);

  /// No description provided for @syncDiscardConfirmBtn.
  ///
  /// In am, this message translates to:
  /// **'አጥፍተህ ውጣ'**
  String get syncDiscardConfirmBtn;

  /// No description provided for @selContribUseCustomRange.
  ///
  /// In am, this message translates to:
  /// **'ብጁ የኢትዮጵያ ወራት ወሰን ተጠቀም'**
  String get selContribUseCustomRange;

  /// No description provided for @selContribUseCustomRangeHint.
  ///
  /// In am, this message translates to:
  /// **'በምርጫው ቀናት ምትክ ለተወሰኑ የኢትዮጵያ ወራት ክፍያዎችን ይቁጠሩ'**
  String get selContribUseCustomRangeHint;

  /// No description provided for @selContribEthYear.
  ///
  /// In am, this message translates to:
  /// **'ዓመተ ምሕረት'**
  String get selContribEthYear;

  /// No description provided for @selContribStartMonth.
  ///
  /// In am, this message translates to:
  /// **'ከወር'**
  String get selContribStartMonth;

  /// No description provided for @selContribEndMonth.
  ///
  /// In am, this message translates to:
  /// **'እስከ ወር'**
  String get selContribEndMonth;

  /// No description provided for @selContribCountsRange.
  ///
  /// In am, this message translates to:
  /// **'ይቆጠራል፡ {startMonth} – {endMonth} {year} ({months} ወራት)'**
  String selContribCountsRange(
    String startMonth,
    String endMonth,
    int year,
    int months,
  );

  /// No description provided for @selContribPaidMonthsCount.
  ///
  /// In am, this message translates to:
  /// **'የተከፈሉ ወራት፡ {paid} / {total} ({unpaid} ያልተከፈሉ)'**
  String selContribPaidMonthsCount(int paid, int total, int unpaid);

  /// No description provided for @deviceLockedTitle.
  ///
  /// In am, this message translates to:
  /// **'መለያው በሌላ መሣሪያ ላይ ነው'**
  String get deviceLockedTitle;

  /// No description provided for @sessionExpiredTitle.
  ///
  /// In am, this message translates to:
  /// **'ክፍለ ጊዜው አብቅቷል'**
  String get sessionExpiredTitle;

  /// No description provided for @searchHint.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር ወይም ምድብ ይፈልጉ'**
  String get searchHint;

  /// No description provided for @categories.
  ///
  /// In am, this message translates to:
  /// **'ምድቦች'**
  String get categories;

  /// No description provided for @categoriesCount.
  ///
  /// In am, this message translates to:
  /// **'{count} ምድቦች'**
  String categoriesCount(String count);

  /// No description provided for @featured.
  ///
  /// In am, this message translates to:
  /// **'የተመረጡ መዝሙሮች'**
  String get featured;

  /// No description provided for @recentlyAdded.
  ///
  /// In am, this message translates to:
  /// **'አዲስ የተጨመሩ'**
  String get recentlyAdded;

  /// No description provided for @popular.
  ///
  /// In am, this message translates to:
  /// **'ተወዳጅ መዝሙሮች'**
  String get popular;

  /// No description provided for @upcomingPrograms.
  ///
  /// In am, this message translates to:
  /// **'መጪ ፕሮግራሞች'**
  String get upcomingPrograms;

  /// No description provided for @mezmurCount.
  ///
  /// In am, this message translates to:
  /// **'{count, plural, =0{መዝሙር የለም} =1{1 መዝሙር} other{{count} መዝሙሮች}}'**
  String mezmurCount(int count);

  /// No description provided for @minutesShort.
  ///
  /// In am, this message translates to:
  /// **'{count} ደቂቃ'**
  String minutesShort(int count);

  /// No description provided for @offlineBanner.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ ነዎት — የወረዱ መዝሙሮች ይገኛሉ'**
  String get offlineBanner;

  /// No description provided for @offlineBannerWithSync.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ · ለመጨረሻ ጊዜ የተመሳሰለው {time} · {count, plural, =1{1 ያልተላከ ለውጥ} other{{count} ያልተላኩ ለውጦች}}'**
  String offlineBannerWithSync(String time, int count);

  /// No description provided for @offlineBannerNoPending.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ · ለመጨረሻ ጊዜ የተመሳሰለው {time}'**
  String offlineBannerNoPending(String time);

  /// No description provided for @offlineBannerNoSync.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ · {count, plural, =1{1 ያልተላከ ለውጥ} other{{count} ያልተላኩ ለውጦች}}'**
  String offlineBannerNoSync(int count);

  /// No description provided for @syncStatusTitle.
  ///
  /// In am, this message translates to:
  /// **'የማመሳሰል ሁኔታ'**
  String get syncStatusTitle;

  /// No description provided for @lastSync.
  ///
  /// In am, this message translates to:
  /// **'የመጨረሻው ማመሳሰል'**
  String get lastSync;

  /// No description provided for @syncStatusPending.
  ///
  /// In am, this message translates to:
  /// **'{count, plural, =1{1 ያልተላከ ለውጥ} other{{count} ያልተላኩ ለውጦች}}'**
  String syncStatusPending(int count);

  /// No description provided for @syncStatusNoPending.
  ///
  /// In am, this message translates to:
  /// **'ምንም ያልተላኩ ለውጦች የሉም'**
  String get syncStatusNoPending;

  /// No description provided for @syncStatusCaptured.
  ///
  /// In am, this message translates to:
  /// **'የተመዘገበው፦ {time}'**
  String syncStatusCaptured(String time);

  /// No description provided for @syncNow.
  ///
  /// In am, this message translates to:
  /// **'አሁን አመሳስል'**
  String get syncNow;

  /// No description provided for @syncStatusLastError.
  ///
  /// In am, this message translates to:
  /// **'የመጨረሻው የማመሳሰል ስህተት'**
  String get syncStatusLastError;

  /// No description provided for @needsConnection.
  ///
  /// In am, this message translates to:
  /// **'ኢንተርኔት ያስፈልጋል'**
  String get needsConnection;

  /// No description provided for @offlineNotCached.
  ///
  /// In am, this message translates to:
  /// **'ወደፊት ከመስመር ውጭ ለመጠቀም አልተቀመጠም'**
  String get offlineNotCached;

  /// No description provided for @notAvailableForAccount.
  ///
  /// In am, this message translates to:
  /// **'ለመለያዎ አይፈቀድም'**
  String get notAvailableForAccount;

  /// No description provided for @syncWhatLesson.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ማጠናቀቅ'**
  String get syncWhatLesson;

  /// No description provided for @syncWhatLibrary.
  ///
  /// In am, this message translates to:
  /// **'የቤተ-መጻሕፍት ውሰት/መመለስ'**
  String get syncWhatLibrary;

  /// No description provided for @emptyCategories.
  ///
  /// In am, this message translates to:
  /// **'ገና ምድብ አልተጨመረም'**
  String get emptyCategories;

  /// No description provided for @playAll.
  ///
  /// In am, this message translates to:
  /// **'ሁሉንም አጫውት'**
  String get playAll;

  /// No description provided for @shuffle.
  ///
  /// In am, this message translates to:
  /// **'በዘፈቀደ አጫውት'**
  String get shuffle;

  /// No description provided for @subcategories.
  ///
  /// In am, this message translates to:
  /// **'ንዑስ ምድቦች'**
  String get subcategories;

  /// No description provided for @lyricsOnly.
  ///
  /// In am, this message translates to:
  /// **'ግጥም ብቻ'**
  String get lyricsOnly;

  /// No description provided for @noMezmursInCategory.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ምድብ ውስጥ መዝሙር የለም'**
  String get noMezmursInCategory;

  /// No description provided for @mezmurLabel.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር'**
  String get mezmurLabel;

  /// No description provided for @lyrics.
  ///
  /// In am, this message translates to:
  /// **'ግጥም'**
  String get lyrics;

  /// No description provided for @addFavorite.
  ///
  /// In am, this message translates to:
  /// **'ወደ ተወዳጆች ጨምር'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In am, this message translates to:
  /// **'ከተወዳጆች አስወግድ'**
  String get removeFavorite;

  /// No description provided for @addedToFavorites.
  ///
  /// In am, this message translates to:
  /// **'ወደ ተወዳጆች ተጨምሯል'**
  String get addedToFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In am, this message translates to:
  /// **'ከተወዳጆች ተወግዷል'**
  String get removedFromFavorites;

  /// No description provided for @download.
  ///
  /// In am, this message translates to:
  /// **'አውርድ'**
  String get download;

  /// No description provided for @downloaded.
  ///
  /// In am, this message translates to:
  /// **'ወርዷል'**
  String get downloaded;

  /// No description provided for @downloading.
  ///
  /// In am, this message translates to:
  /// **'በማውረድ ላይ'**
  String get downloading;

  /// No description provided for @removeDownload.
  ///
  /// In am, this message translates to:
  /// **'ውርዱን አስወግድ'**
  String get removeDownload;

  /// No description provided for @related.
  ///
  /// In am, this message translates to:
  /// **'ተዛማጅ መዝሙሮች'**
  String get related;

  /// No description provided for @fontSize.
  ///
  /// In am, this message translates to:
  /// **'የፊደል መጠን'**
  String get fontSize;

  /// No description provided for @noAudio.
  ///
  /// In am, this message translates to:
  /// **'ለዚህ መዝሙር ድምጽ የለም'**
  String get noAudio;

  /// No description provided for @openPlayer.
  ///
  /// In am, this message translates to:
  /// **'ማጫወቻ ክፈት'**
  String get openPlayer;

  /// No description provided for @downloadWithAudio.
  ///
  /// In am, this message translates to:
  /// **'ከድምጽ ጋር አውርድ'**
  String get downloadWithAudio;

  /// No description provided for @downloadLyricsOnly.
  ///
  /// In am, this message translates to:
  /// **'ግጥሙን ብቻ አውርድ'**
  String get downloadLyricsOnly;

  /// No description provided for @offlineCopy.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ ቅጂ'**
  String get offlineCopy;

  /// No description provided for @nowPlaying.
  ///
  /// In am, this message translates to:
  /// **'በመጫወት ላይ'**
  String get nowPlaying;

  /// No description provided for @play.
  ///
  /// In am, this message translates to:
  /// **'አጫውት'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In am, this message translates to:
  /// **'አቁም'**
  String get pause;

  /// No description provided for @nextTrack.
  ///
  /// In am, this message translates to:
  /// **'ቀጣይ'**
  String get nextTrack;

  /// No description provided for @previousTrack.
  ///
  /// In am, this message translates to:
  /// **'ቀዳሚ'**
  String get previousTrack;

  /// No description provided for @repeat.
  ///
  /// In am, this message translates to:
  /// **'ድገም'**
  String get repeat;

  /// No description provided for @viewLyrics.
  ///
  /// In am, this message translates to:
  /// **'ግጥሙን እይ'**
  String get viewLyrics;

  /// No description provided for @audioError.
  ///
  /// In am, this message translates to:
  /// **'ድምጹን ማጫወት አልተቻለም'**
  String get audioError;

  /// No description provided for @searchTitle.
  ///
  /// In am, this message translates to:
  /// **'ፈልግ'**
  String get searchTitle;

  /// No description provided for @recentSearches.
  ///
  /// In am, this message translates to:
  /// **'የቅርብ ጊዜ ፍለጋዎች'**
  String get recentSearches;

  /// No description provided for @results.
  ///
  /// In am, this message translates to:
  /// **'ውጤቶች'**
  String get results;

  /// No description provided for @noResults.
  ///
  /// In am, this message translates to:
  /// **'ምንም ውጤት አልተገኘም'**
  String get noResults;

  /// No description provided for @categoryResult.
  ///
  /// In am, this message translates to:
  /// **'ምድብ · {count}'**
  String categoryResult(String count);

  /// No description provided for @mezmurResult.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር · {category}'**
  String mezmurResult(String category);

  /// No description provided for @clearRecent.
  ///
  /// In am, this message translates to:
  /// **'አጽዳ'**
  String get clearRecent;

  /// No description provided for @searchOfflineNote.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ — በወረዱ መዝሙሮች ውስጥ ብቻ ተፈልጓል'**
  String get searchOfflineNote;

  /// No description provided for @searchPrompt.
  ///
  /// In am, this message translates to:
  /// **'የመዝሙር ርዕስ ወይም የግጥም ቃል ይጻፉ'**
  String get searchPrompt;

  /// No description provided for @favorites.
  ///
  /// In am, this message translates to:
  /// **'ተወዳጆች'**
  String get favorites;

  /// No description provided for @downloads.
  ///
  /// In am, this message translates to:
  /// **'የወረዱ'**
  String get downloads;

  /// No description provided for @noFavorites.
  ///
  /// In am, this message translates to:
  /// **'ገና ተወዳጅ መዝሙር አልመረጡም'**
  String get noFavorites;

  /// No description provided for @noDownloads.
  ///
  /// In am, this message translates to:
  /// **'ምንም የወረደ መዝሙር የለም'**
  String get noDownloads;

  /// No description provided for @storageUsed.
  ///
  /// In am, this message translates to:
  /// **'ያገለገለ ማከማቻ፦ {size}'**
  String storageUsed(String size);

  /// No description provided for @downloadAllFavorites.
  ///
  /// In am, this message translates to:
  /// **'ሁሉንም ተወዳጆች አውርድ'**
  String get downloadAllFavorites;

  /// No description provided for @retryDownload.
  ///
  /// In am, this message translates to:
  /// **'እንደገና አውርድ'**
  String get retryDownload;

  /// No description provided for @downloadFailed.
  ///
  /// In am, this message translates to:
  /// **'ማውረድ አልተሳካም'**
  String get downloadFailed;

  /// No description provided for @downloadQueued.
  ///
  /// In am, this message translates to:
  /// **'በመጠባበቅ ላይ'**
  String get downloadQueued;

  /// No description provided for @removeAllDownloads.
  ///
  /// In am, this message translates to:
  /// **'ሁሉንም ውርዶች አስወግድ'**
  String get removeAllDownloads;

  /// No description provided for @confirmRemoveDownload.
  ///
  /// In am, this message translates to:
  /// **'ይህን ውርድ ማስወገድ ይፈልጋሉ?'**
  String get confirmRemoveDownload;

  /// No description provided for @confirmRemoveAllDownloads.
  ///
  /// In am, this message translates to:
  /// **'ሁሉንም ውርዶች ማስወገድ ይፈልጋሉ?'**
  String get confirmRemoveAllDownloads;

  /// No description provided for @staleDownload.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ስሪት አለ — እንደገና ያውርዱ'**
  String get staleDownload;

  /// No description provided for @wifiOnlyBlocked.
  ///
  /// In am, this message translates to:
  /// **'በWi-Fi ብቻ ለማውረድ ተመርጧል። ከWi-Fi ጋር ይገናኙ።'**
  String get wifiOnlyBlocked;

  /// No description provided for @unavailableDownload.
  ///
  /// In am, this message translates to:
  /// **'ይህ መዝሙር ከአሁን በኋላ አይገኝም'**
  String get unavailableDownload;

  /// No description provided for @programs.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራሞች'**
  String get programs;

  /// No description provided for @upcoming.
  ///
  /// In am, this message translates to:
  /// **'መጪ'**
  String get upcoming;

  /// No description provided for @past.
  ///
  /// In am, this message translates to:
  /// **'ያለፉ'**
  String get past;

  /// No description provided for @mine.
  ///
  /// In am, this message translates to:
  /// **'የእኔ'**
  String get mine;

  /// No description provided for @noPrograms.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራም የለም'**
  String get noPrograms;

  /// No description provided for @location.
  ///
  /// In am, this message translates to:
  /// **'ቦታ'**
  String get location;

  /// No description provided for @capacity.
  ///
  /// In am, this message translates to:
  /// **'የቦታ ብዛት፦ {count}'**
  String capacity(int count);

  /// No description provided for @registerProgram.
  ///
  /// In am, this message translates to:
  /// **'ይመዝገቡ'**
  String get registerProgram;

  /// No description provided for @cancelRegistration.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባ ሰርዝ'**
  String get cancelRegistration;

  /// No description provided for @registeredForProgram.
  ///
  /// In am, this message translates to:
  /// **'ለፕሮግራሙ ተመዝግበዋል'**
  String get registeredForProgram;

  /// No description provided for @registered.
  ///
  /// In am, this message translates to:
  /// **'ተመዝግበዋል'**
  String get registered;

  /// No description provided for @invited.
  ///
  /// In am, this message translates to:
  /// **'ተጋብዘዋል'**
  String get invited;

  /// No description provided for @attPresent.
  ///
  /// In am, this message translates to:
  /// **'ተገኝተዋል'**
  String get attPresent;

  /// No description provided for @attLate.
  ///
  /// In am, this message translates to:
  /// **'ዘግይተው ተገኝተዋል'**
  String get attLate;

  /// No description provided for @attAbsent.
  ///
  /// In am, this message translates to:
  /// **'አልተገኙም'**
  String get attAbsent;

  /// No description provided for @attExcused.
  ///
  /// In am, this message translates to:
  /// **'በፈቃድ'**
  String get attExcused;

  /// No description provided for @setReminder.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻ አዘጋጅ'**
  String get setReminder;

  /// No description provided for @programCancelled.
  ///
  /// In am, this message translates to:
  /// **'ተሰርዟል'**
  String get programCancelled;

  /// No description provided for @programCompleted.
  ///
  /// In am, this message translates to:
  /// **'ተጠናቋል'**
  String get programCompleted;

  /// No description provided for @moreInfo.
  ///
  /// In am, this message translates to:
  /// **'ተጨማሪ መረጃ'**
  String get moreInfo;

  /// No description provided for @participantsCount.
  ///
  /// In am, this message translates to:
  /// **'{count} ተሳታፊዎች'**
  String participantsCount(int count);

  /// No description provided for @registrationRequired.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባ ያስፈልጋል'**
  String get registrationRequired;

  /// No description provided for @myAttendanceStatus.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት ሁኔታዎ'**
  String get myAttendanceStatus;

  /// No description provided for @reminders.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻዎች'**
  String get reminders;

  /// No description provided for @newReminder.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ማስታወሻ'**
  String get newReminder;

  /// No description provided for @editReminder.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻ አስተካክል'**
  String get editReminder;

  /// No description provided for @reminderTitle.
  ///
  /// In am, this message translates to:
  /// **'ርዕስ'**
  String get reminderTitle;

  /// No description provided for @reminderNote.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻ (አማራጭ)'**
  String get reminderNote;

  /// No description provided for @repeatLabel.
  ///
  /// In am, this message translates to:
  /// **'ድግግሞሽ'**
  String get repeatLabel;

  /// No description provided for @repeatNone.
  ///
  /// In am, this message translates to:
  /// **'አንድ ጊዜ'**
  String get repeatNone;

  /// No description provided for @repeatDaily.
  ///
  /// In am, this message translates to:
  /// **'በየቀኑ'**
  String get repeatDaily;

  /// No description provided for @repeatWeekly.
  ///
  /// In am, this message translates to:
  /// **'በየሳምንቱ'**
  String get repeatWeekly;

  /// No description provided for @enabled.
  ///
  /// In am, this message translates to:
  /// **'ንቁ'**
  String get enabled;

  /// No description provided for @noReminders.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻ የለም'**
  String get noReminders;

  /// No description provided for @reminderSaved.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻ ተቀምጧል'**
  String get reminderSaved;

  /// No description provided for @reminderDefaultTitle.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራም፦ {title}'**
  String reminderDefaultTitle(String title);

  /// No description provided for @notifications.
  ///
  /// In am, this message translates to:
  /// **'ማሳወቂያዎች'**
  String get notifications;

  /// No description provided for @markAllRead.
  ///
  /// In am, this message translates to:
  /// **'ሁሉንም እንደተነበበ ምልክት አድርግ'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In am, this message translates to:
  /// **'ምንም ማሳወቂያ የለም'**
  String get noNotifications;

  /// No description provided for @justNow.
  ///
  /// In am, this message translates to:
  /// **'አሁን'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In am, this message translates to:
  /// **'ከ{count} ደቂቃ በፊት'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In am, this message translates to:
  /// **'ከ{count} ሰዓት በፊት'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In am, this message translates to:
  /// **'ከ{count} ቀን በፊት'**
  String daysAgo(int count);

  /// No description provided for @unreadOnly.
  ///
  /// In am, this message translates to:
  /// **'ያልተነበቡ'**
  String get unreadOnly;

  /// No description provided for @settings.
  ///
  /// In am, this message translates to:
  /// **'ማስተካከያ'**
  String get settings;

  /// No description provided for @account.
  ///
  /// In am, this message translates to:
  /// **'መለያ'**
  String get account;

  /// No description provided for @appSection.
  ///
  /// In am, this message translates to:
  /// **'መተግበሪያ'**
  String get appSection;

  /// No description provided for @language.
  ///
  /// In am, this message translates to:
  /// **'ቋንቋ'**
  String get language;

  /// No description provided for @amharic.
  ///
  /// In am, this message translates to:
  /// **'አማርኛ'**
  String get amharic;

  /// No description provided for @english.
  ///
  /// In am, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @darkMode.
  ///
  /// In am, this message translates to:
  /// **'ጨለማ ገጽታ'**
  String get darkMode;

  /// No description provided for @autoplay.
  ///
  /// In am, this message translates to:
  /// **'በራስ-ሰር አጫውት'**
  String get autoplay;

  /// No description provided for @notificationsSection.
  ///
  /// In am, this message translates to:
  /// **'ማሳወቂያዎች'**
  String get notificationsSection;

  /// No description provided for @pushEnabled.
  ///
  /// In am, this message translates to:
  /// **'ማሳወቂያዎችን ፍቀድ'**
  String get pushEnabled;

  /// No description provided for @eventReminders.
  ///
  /// In am, this message translates to:
  /// **'የፕሮግራም ማስታወሻዎች'**
  String get eventReminders;

  /// No description provided for @borrowingReminders.
  ///
  /// In am, this message translates to:
  /// **'የውሰት ማስታወሻዎች'**
  String get borrowingReminders;

  /// No description provided for @reminderTime.
  ///
  /// In am, this message translates to:
  /// **'የማስታወሻ ሰዓት'**
  String get reminderTime;

  /// No description provided for @downloadsSection.
  ///
  /// In am, this message translates to:
  /// **'ውርዶች'**
  String get downloadsSection;

  /// No description provided for @wifiOnly.
  ///
  /// In am, this message translates to:
  /// **'በWi-Fi ብቻ አውርድ'**
  String get wifiOnly;

  /// No description provided for @downloadAudio.
  ///
  /// In am, this message translates to:
  /// **'ድምጽንም አብሮ አውርድ'**
  String get downloadAudio;

  /// No description provided for @manageDownloads.
  ///
  /// In am, this message translates to:
  /// **'ውርዶችን አስተዳድር'**
  String get manageDownloads;

  /// No description provided for @about.
  ///
  /// In am, this message translates to:
  /// **'ስለ'**
  String get about;

  /// No description provided for @aboutApp.
  ///
  /// In am, this message translates to:
  /// **'ስለ መተግበሪያው'**
  String get aboutApp;

  /// No description provided for @aboutBody.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር ዘልደታ የመሠረተ ሕይወት ሰንበት ት/ቤት የመዝሙር፣ የፕሮግራምና የቤተ መጻሕፍት መተግበሪያ ነው። መዝሙሮችን ያንብቡ፣ ያዳምጡ፣ ከመስመር ውጭ ለመጠቀም ያውርዱ፣ እንዲሁም የሰንበት ት/ቤቱን ፕሮግራሞች ይከታተሉ።'**
  String get aboutBody;

  /// No description provided for @version.
  ///
  /// In am, this message translates to:
  /// **'እትም'**
  String get version;

  /// No description provided for @profile.
  ///
  /// In am, this message translates to:
  /// **'መገለጫ'**
  String get profile;

  /// No description provided for @editProfile.
  ///
  /// In am, this message translates to:
  /// **'መገለጫ አስተካክል'**
  String get editProfile;

  /// No description provided for @myAttendance.
  ///
  /// In am, this message translates to:
  /// **'የተገኘሁባቸው ፕሮግራሞች'**
  String get myAttendance;

  /// No description provided for @myBorrowings.
  ///
  /// In am, this message translates to:
  /// **'የተዋስኳቸው እቃዎች'**
  String get myBorrowings;

  /// No description provided for @adminPanel.
  ///
  /// In am, this message translates to:
  /// **'የአስተዳዳሪ ፓነል'**
  String get adminPanel;

  /// No description provided for @profileSaved.
  ///
  /// In am, this message translates to:
  /// **'መገለጫ ተቀምጧል'**
  String get profileSaved;

  /// No description provided for @changePhoto.
  ///
  /// In am, this message translates to:
  /// **'ፎቶ ቀይር'**
  String get changePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In am, this message translates to:
  /// **'ፎቶ አስወግድ'**
  String get removePhoto;

  /// No description provided for @preferredCategories.
  ///
  /// In am, this message translates to:
  /// **'ተመራጭ ምድቦች'**
  String get preferredCategories;

  /// No description provided for @preferredCategoriesHint.
  ///
  /// In am, this message translates to:
  /// **'ማሳወቂያና ምክረ-ሐሳብ ለማግኘት የሚወዷቸውን ምድቦች ይምረጡ'**
  String get preferredCategoriesHint;

  /// No description provided for @myActivity.
  ///
  /// In am, this message translates to:
  /// **'የእኔ እንቅስቃሴ'**
  String get myActivity;

  /// No description provided for @calendarEthiopian.
  ///
  /// In am, this message translates to:
  /// **'ዓ.ም'**
  String get calendarEthiopian;

  /// No description provided for @calendarGregorian.
  ///
  /// In am, this message translates to:
  /// **'እ.ኤ.አ'**
  String get calendarGregorian;

  /// No description provided for @borrowings.
  ///
  /// In am, this message translates to:
  /// **'ውሰቶች'**
  String get borrowings;

  /// No description provided for @borrowedOn.
  ///
  /// In am, this message translates to:
  /// **'የተወሰደበት ቀን'**
  String get borrowedOn;

  /// No description provided for @dueOn.
  ///
  /// In am, this message translates to:
  /// **'የመመለሻ ቀን'**
  String get dueOn;

  /// No description provided for @daysRemaining.
  ///
  /// In am, this message translates to:
  /// **'{count} ቀን ቀርቷል'**
  String daysRemaining(int count);

  /// No description provided for @dueToday.
  ///
  /// In am, this message translates to:
  /// **'ዛሬ መመለስ አለበት'**
  String get dueToday;

  /// No description provided for @overdueDays.
  ///
  /// In am, this message translates to:
  /// **'በ{count} ቀን ዘግይቷል'**
  String overdueDays(int count);

  /// No description provided for @bStatusActive.
  ///
  /// In am, this message translates to:
  /// **'በውሰት ላይ'**
  String get bStatusActive;

  /// No description provided for @bStatusReturned.
  ///
  /// In am, this message translates to:
  /// **'ተመልሷል'**
  String get bStatusReturned;

  /// No description provided for @bStatusPartial.
  ///
  /// In am, this message translates to:
  /// **'በከፊል ተመልሷል'**
  String get bStatusPartial;

  /// No description provided for @bStatusLost.
  ///
  /// In am, this message translates to:
  /// **'ጠፍቷል'**
  String get bStatusLost;

  /// No description provided for @fine.
  ///
  /// In am, this message translates to:
  /// **'ቅጣት'**
  String get fine;

  /// No description provided for @fineAmountValue.
  ///
  /// In am, this message translates to:
  /// **'{amount} {currency}'**
  String fineAmountValue(String amount, String currency);

  /// No description provided for @fineNone.
  ///
  /// In am, this message translates to:
  /// **'ቅጣት የለም'**
  String get fineNone;

  /// No description provided for @finePending.
  ///
  /// In am, this message translates to:
  /// **'ያልተከፈለ'**
  String get finePending;

  /// No description provided for @finePaid.
  ///
  /// In am, this message translates to:
  /// **'ተከፍሏል'**
  String get finePaid;

  /// No description provided for @fineWaived.
  ///
  /// In am, this message translates to:
  /// **'ተሰርዟል'**
  String get fineWaived;

  /// No description provided for @quantity.
  ///
  /// In am, this message translates to:
  /// **'ብዛት'**
  String get quantity;

  /// No description provided for @returnCondition.
  ///
  /// In am, this message translates to:
  /// **'የተመለሰበት ሁኔታ'**
  String get returnCondition;

  /// No description provided for @signature.
  ///
  /// In am, this message translates to:
  /// **'ፊርማ'**
  String get signature;

  /// No description provided for @signedAt.
  ///
  /// In am, this message translates to:
  /// **'የተፈረመበት ጊዜ'**
  String get signedAt;

  /// No description provided for @notSigned.
  ///
  /// In am, this message translates to:
  /// **'አልተፈረመም'**
  String get notSigned;

  /// No description provided for @noBorrowings.
  ///
  /// In am, this message translates to:
  /// **'ምንም ውሰት የለም'**
  String get noBorrowings;

  /// No description provided for @noAttendance.
  ///
  /// In am, this message translates to:
  /// **'ገና የተመዘገበ መገኘት የለም'**
  String get noAttendance;

  /// No description provided for @item.
  ///
  /// In am, this message translates to:
  /// **'እቃ'**
  String get item;

  /// No description provided for @eventDate.
  ///
  /// In am, this message translates to:
  /// **'የዝግጅት ቀን'**
  String get eventDate;

  /// No description provided for @ethMonth1.
  ///
  /// In am, this message translates to:
  /// **'መስከረም'**
  String get ethMonth1;

  /// No description provided for @ethMonth2.
  ///
  /// In am, this message translates to:
  /// **'ጥቅምት'**
  String get ethMonth2;

  /// No description provided for @ethMonth3.
  ///
  /// In am, this message translates to:
  /// **'ኅዳር'**
  String get ethMonth3;

  /// No description provided for @ethMonth4.
  ///
  /// In am, this message translates to:
  /// **'ታኅሣሥ'**
  String get ethMonth4;

  /// No description provided for @ethMonth5.
  ///
  /// In am, this message translates to:
  /// **'ጥር'**
  String get ethMonth5;

  /// No description provided for @ethMonth6.
  ///
  /// In am, this message translates to:
  /// **'የካቲት'**
  String get ethMonth6;

  /// No description provided for @ethMonth7.
  ///
  /// In am, this message translates to:
  /// **'መጋቢት'**
  String get ethMonth7;

  /// No description provided for @ethMonth8.
  ///
  /// In am, this message translates to:
  /// **'ሚያዝያ'**
  String get ethMonth8;

  /// No description provided for @ethMonth9.
  ///
  /// In am, this message translates to:
  /// **'ግንቦት'**
  String get ethMonth9;

  /// No description provided for @ethMonth10.
  ///
  /// In am, this message translates to:
  /// **'ሰኔ'**
  String get ethMonth10;

  /// No description provided for @ethMonth11.
  ///
  /// In am, this message translates to:
  /// **'ሐምሌ'**
  String get ethMonth11;

  /// No description provided for @ethMonth12.
  ///
  /// In am, this message translates to:
  /// **'ነሐሴ'**
  String get ethMonth12;

  /// No description provided for @ethMonth13.
  ///
  /// In am, this message translates to:
  /// **'ጳጉሜን'**
  String get ethMonth13;

  /// No description provided for @weekday1.
  ///
  /// In am, this message translates to:
  /// **'ሰኞ'**
  String get weekday1;

  /// No description provided for @weekday2.
  ///
  /// In am, this message translates to:
  /// **'ማክሰኞ'**
  String get weekday2;

  /// No description provided for @weekday3.
  ///
  /// In am, this message translates to:
  /// **'ረቡዕ'**
  String get weekday3;

  /// No description provided for @weekday4.
  ///
  /// In am, this message translates to:
  /// **'ሐሙስ'**
  String get weekday4;

  /// No description provided for @weekday5.
  ///
  /// In am, this message translates to:
  /// **'ዓርብ'**
  String get weekday5;

  /// No description provided for @weekday6.
  ///
  /// In am, this message translates to:
  /// **'ቅዳሜ'**
  String get weekday6;

  /// No description provided for @weekday7.
  ///
  /// In am, this message translates to:
  /// **'እሑድ'**
  String get weekday7;

  /// No description provided for @timeMorning.
  ///
  /// In am, this message translates to:
  /// **'ጠዋት'**
  String get timeMorning;

  /// No description provided for @timeAfternoon.
  ///
  /// In am, this message translates to:
  /// **'ከሰዓት'**
  String get timeAfternoon;

  /// No description provided for @admin.
  ///
  /// In am, this message translates to:
  /// **'አስተዳደር'**
  String get admin;

  /// No description provided for @dashboard.
  ///
  /// In am, this message translates to:
  /// **'ዳሽቦርድ'**
  String get dashboard;

  /// No description provided for @users.
  ///
  /// In am, this message translates to:
  /// **'ተጠቃሚዎች'**
  String get users;

  /// No description provided for @mezmurs.
  ///
  /// In am, this message translates to:
  /// **'መዝሙሮች'**
  String get mezmurs;

  /// No description provided for @advertisements.
  ///
  /// In am, this message translates to:
  /// **'ማስታወቂያዎች'**
  String get advertisements;

  /// No description provided for @pages.
  ///
  /// In am, this message translates to:
  /// **'ውስጣዊ ገጾች'**
  String get pages;

  /// No description provided for @attendance.
  ///
  /// In am, this message translates to:
  /// **'መገኘት'**
  String get attendance;

  /// No description provided for @sendNotification.
  ///
  /// In am, this message translates to:
  /// **'ማሳወቂያ ላክ'**
  String get sendNotification;

  /// No description provided for @borrowing.
  ///
  /// In am, this message translates to:
  /// **'ውሰት'**
  String get borrowing;

  /// No description provided for @items.
  ///
  /// In am, this message translates to:
  /// **'እቃዎች'**
  String get items;

  /// No description provided for @fines.
  ///
  /// In am, this message translates to:
  /// **'ቅጣቶች'**
  String get fines;

  /// No description provided for @reports.
  ///
  /// In am, this message translates to:
  /// **'ሪፖርቶች'**
  String get reports;

  /// No description provided for @auditLogs.
  ///
  /// In am, this message translates to:
  /// **'የአስተዳደር መዝገብ'**
  String get auditLogs;

  /// No description provided for @activityLogs.
  ///
  /// In am, this message translates to:
  /// **'የተጠቃሚ ሪፖርቶች (እንቅስቃሴ)'**
  String get activityLogs;

  /// No description provided for @admins.
  ///
  /// In am, this message translates to:
  /// **'አስተዳዳሪዎች'**
  String get admins;

  /// No description provided for @roles.
  ///
  /// In am, this message translates to:
  /// **'ሚናዎች'**
  String get roles;

  /// No description provided for @permissions.
  ///
  /// In am, this message translates to:
  /// **'ፈቃዶች'**
  String get permissions;

  /// No description provided for @systemSettings.
  ///
  /// In am, this message translates to:
  /// **'የሲስተም ማስተካከያ'**
  String get systemSettings;

  /// No description provided for @totalUsers.
  ///
  /// In am, this message translates to:
  /// **'ጠቅላላ ተጠቃሚዎች'**
  String get totalUsers;

  /// No description provided for @activeUsers.
  ///
  /// In am, this message translates to:
  /// **'ንቁ ተጠቃሚዎች (30 ቀን)'**
  String get activeUsers;

  /// No description provided for @newUsers.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ተጠቃሚዎች (30 ቀን)'**
  String get newUsers;

  /// No description provided for @totalMezmurs.
  ///
  /// In am, this message translates to:
  /// **'መዝሙሮች'**
  String get totalMezmurs;

  /// No description provided for @totalCategories.
  ///
  /// In am, this message translates to:
  /// **'ምድቦች'**
  String get totalCategories;

  /// No description provided for @upcomingProgramsStat.
  ///
  /// In am, this message translates to:
  /// **'መጪ ፕሮግራሞች'**
  String get upcomingProgramsStat;

  /// No description provided for @attendance30.
  ///
  /// In am, this message translates to:
  /// **'መገኘት (30 ቀን)'**
  String get attendance30;

  /// No description provided for @activeBorrowings.
  ///
  /// In am, this message translates to:
  /// **'ያልተመለሱ ውሰቶች'**
  String get activeBorrowings;

  /// No description provided for @overdueBorrowings.
  ///
  /// In am, this message translates to:
  /// **'ጊዜ ያለፈባቸው ውሰቶች'**
  String get overdueBorrowings;

  /// No description provided for @pendingFines.
  ///
  /// In am, this message translates to:
  /// **'ያልተከፈለ ቅጣት'**
  String get pendingFines;

  /// No description provided for @recentActivity.
  ///
  /// In am, this message translates to:
  /// **'የቅርብ እንቅስቃሴ'**
  String get recentActivity;

  /// No description provided for @recentNotifications.
  ///
  /// In am, this message translates to:
  /// **'የቅርብ ማሳወቂያዎች'**
  String get recentNotifications;

  /// No description provided for @signups30.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባ (30 ቀን)'**
  String get signups30;

  /// No description provided for @statusActive.
  ///
  /// In am, this message translates to:
  /// **'ንቁ'**
  String get statusActive;

  /// No description provided for @statusDisabled.
  ///
  /// In am, this message translates to:
  /// **'የታገደ'**
  String get statusDisabled;

  /// No description provided for @device.
  ///
  /// In am, this message translates to:
  /// **'መሣሪያ'**
  String get device;

  /// No description provided for @noDevice.
  ///
  /// In am, this message translates to:
  /// **'መሣሪያ አልተመዘገበም'**
  String get noDevice;

  /// No description provided for @lastLogin.
  ///
  /// In am, this message translates to:
  /// **'መጨረሻ የገባበት'**
  String get lastLogin;

  /// No description provided for @registeredAt.
  ///
  /// In am, this message translates to:
  /// **'የተመዘገበበት'**
  String get registeredAt;

  /// No description provided for @resetDevice.
  ///
  /// In am, this message translates to:
  /// **'መሣሪያ ዳግም አስጀምር'**
  String get resetDevice;

  /// No description provided for @resetDeviceConfirm.
  ///
  /// In am, this message translates to:
  /// **'የዚህ ተጠቃሚ መሣሪያ ዳግም ይጀመራል፤ በአሁኑ መሣሪያ ያለው ክፍለ ጊዜ ወዲያውኑ ይዘጋል። ይቀጥሉ?'**
  String get resetDeviceConfirm;

  /// No description provided for @resetReason.
  ///
  /// In am, this message translates to:
  /// **'ምክንያት (አማራጭ)'**
  String get resetReason;

  /// No description provided for @deviceResetDone.
  ///
  /// In am, this message translates to:
  /// **'መሣሪያው ዳግም ተጀምሯል'**
  String get deviceResetDone;

  /// No description provided for @forceLogout.
  ///
  /// In am, this message translates to:
  /// **'ከሁሉም ክፍለ ጊዜዎች አስወጣ'**
  String get forceLogout;

  /// No description provided for @forceLogoutConfirm.
  ///
  /// In am, this message translates to:
  /// **'ተጠቃሚው ከሁሉም ክፍለ ጊዜዎች ይወጣል። ይቀጥሉ?'**
  String get forceLogoutConfirm;

  /// No description provided for @disable.
  ///
  /// In am, this message translates to:
  /// **'አግድ'**
  String get disable;

  /// No description provided for @enable.
  ///
  /// In am, this message translates to:
  /// **'አንቃ'**
  String get enable;

  /// No description provided for @disableConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህን መለያ ማገድ ይፈልጋሉ?'**
  String get disableConfirm;

  /// No description provided for @resetUserPassword.
  ///
  /// In am, this message translates to:
  /// **'ጊዜያዊ ፒን ስጥ'**
  String get resetUserPassword;

  /// No description provided for @tempPasswordTitle.
  ///
  /// In am, this message translates to:
  /// **'ጊዜያዊ ፒን'**
  String get tempPasswordTitle;

  /// No description provided for @tempPasswordBody.
  ///
  /// In am, this message translates to:
  /// **'{password}\n\nይህ ፒን አንድ ጊዜ ብቻ ይታያል። ተጠቃሚው ሲገባ የራሱን ፒን እንዲያዘጋጅ ይጠየቃል።'**
  String tempPasswordBody(String password);

  /// No description provided for @deviceHistory.
  ///
  /// In am, this message translates to:
  /// **'የመሣሪያ ታሪክ'**
  String get deviceHistory;

  /// No description provided for @selectedCount.
  ///
  /// In am, this message translates to:
  /// **'{count} ተመርጠዋል'**
  String selectedCount(int count);

  /// No description provided for @selectAllMatching.
  ///
  /// In am, this message translates to:
  /// **'ከማጣሪያው ጋር የሚዛመዱትን ሁሉ ምረጥ'**
  String get selectAllMatching;

  /// No description provided for @allMatchingSelected.
  ///
  /// In am, this message translates to:
  /// **'ሁሉም የሚዛመዱ ተመርጠዋል ({count})'**
  String allMatchingSelected(int count);

  /// No description provided for @bulkNotify.
  ///
  /// In am, this message translates to:
  /// **'ማሳወቂያ ላክ'**
  String get bulkNotify;

  /// No description provided for @bulkInvite.
  ///
  /// In am, this message translates to:
  /// **'ወደ ፕሮግራም ጋብዝ'**
  String get bulkInvite;

  /// No description provided for @bulkBorrow.
  ///
  /// In am, this message translates to:
  /// **'እቃ አዋስ'**
  String get bulkBorrow;

  /// No description provided for @bulkConfirm.
  ///
  /// In am, this message translates to:
  /// **'{count} ተጠቃሚዎች ተመርጠዋል። ይቀጥሉ?'**
  String bulkConfirm(int count);

  /// No description provided for @createUser.
  ///
  /// In am, this message translates to:
  /// **'ተጠቃሚ ፍጠር'**
  String get createUser;

  /// No description provided for @devBound.
  ///
  /// In am, this message translates to:
  /// **'ተመዝግቧል'**
  String get devBound;

  /// No description provided for @devLogin.
  ///
  /// In am, this message translates to:
  /// **'ገብቷል'**
  String get devLogin;

  /// No description provided for @devLoginRejected.
  ///
  /// In am, this message translates to:
  /// **'ውድቅ ተደርጓል'**
  String get devLoginRejected;

  /// No description provided for @devReset.
  ///
  /// In am, this message translates to:
  /// **'ዳግም ተጀምሯል'**
  String get devReset;

  /// No description provided for @devForceLogout.
  ///
  /// In am, this message translates to:
  /// **'እንዲወጣ ተደርጓል'**
  String get devForceLogout;

  /// No description provided for @hasActiveBorrowing.
  ///
  /// In am, this message translates to:
  /// **'ያልመለሰ እቃ ያለው'**
  String get hasActiveBorrowing;

  /// No description provided for @stats.
  ///
  /// In am, this message translates to:
  /// **'አኃዞች'**
  String get stats;

  /// No description provided for @newMezmur.
  ///
  /// In am, this message translates to:
  /// **'አዲስ መዝሙር'**
  String get newMezmur;

  /// No description provided for @editMezmur.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር አስተካክል'**
  String get editMezmur;

  /// No description provided for @title.
  ///
  /// In am, this message translates to:
  /// **'ርዕስ'**
  String get title;

  /// No description provided for @description.
  ///
  /// In am, this message translates to:
  /// **'መግለጫ'**
  String get description;

  /// No description provided for @category.
  ///
  /// In am, this message translates to:
  /// **'ምድብ'**
  String get category;

  /// No description provided for @noCategory.
  ///
  /// In am, this message translates to:
  /// **'ምድብ የለም'**
  String get noCategory;

  /// No description provided for @tagsHint.
  ///
  /// In am, this message translates to:
  /// **'መለያ ቃላት (በኮማ ይለዩ)'**
  String get tagsHint;

  /// No description provided for @statusDraft.
  ///
  /// In am, this message translates to:
  /// **'ረቂቅ'**
  String get statusDraft;

  /// No description provided for @statusPublished.
  ///
  /// In am, this message translates to:
  /// **'የታተመ'**
  String get statusPublished;

  /// No description provided for @statusArchived.
  ///
  /// In am, this message translates to:
  /// **'የተቀመጠ'**
  String get statusArchived;

  /// No description provided for @featuredFlag.
  ///
  /// In am, this message translates to:
  /// **'የተመረጠ (በመነሻ ላይ ይታይ)'**
  String get featuredFlag;

  /// No description provided for @audio.
  ///
  /// In am, this message translates to:
  /// **'ድምጽ'**
  String get audio;

  /// No description provided for @uploadAudio.
  ///
  /// In am, this message translates to:
  /// **'ድምጽ ጫን'**
  String get uploadAudio;

  /// No description provided for @removeAudio.
  ///
  /// In am, this message translates to:
  /// **'ድምጽ አስወግድ'**
  String get removeAudio;

  /// No description provided for @coverImage.
  ///
  /// In am, this message translates to:
  /// **'የሽፋን ምስል'**
  String get coverImage;

  /// No description provided for @uploadImage.
  ///
  /// In am, this message translates to:
  /// **'ምስል ጫን'**
  String get uploadImage;

  /// No description provided for @removeImage.
  ///
  /// In am, this message translates to:
  /// **'ምስል አስወግድ'**
  String get removeImage;

  /// No description provided for @audioDuration.
  ///
  /// In am, this message translates to:
  /// **'የድምጽ ርዝመት (ሰከንድ)'**
  String get audioDuration;

  /// No description provided for @uploadDone.
  ///
  /// In am, this message translates to:
  /// **'ተጭኗል'**
  String get uploadDone;

  /// No description provided for @uploading.
  ///
  /// In am, this message translates to:
  /// **'በመጫን ላይ…'**
  String get uploading;

  /// No description provided for @saveFirstToUpload.
  ///
  /// In am, this message translates to:
  /// **'ፋይል ለመጫን መጀመሪያ ያስቀምጡ'**
  String get saveFirstToUpload;

  /// No description provided for @chooseCategory.
  ///
  /// In am, this message translates to:
  /// **'ምድብ ይምረጡ'**
  String get chooseCategory;

  /// No description provided for @newCategory.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ምድብ'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In am, this message translates to:
  /// **'ምድብ አስተካክል'**
  String get editCategory;

  /// No description provided for @parentCategory.
  ///
  /// In am, this message translates to:
  /// **'ዋና ምድብ'**
  String get parentCategory;

  /// No description provided for @topLevel.
  ///
  /// In am, this message translates to:
  /// **'ከፍተኛ ደረጃ (ዋና ምድብ)'**
  String get topLevel;

  /// No description provided for @icon.
  ///
  /// In am, this message translates to:
  /// **'አዶ'**
  String get icon;

  /// No description provided for @displayOrder.
  ///
  /// In am, this message translates to:
  /// **'ቅደም ተከተል'**
  String get displayOrder;

  /// No description provided for @active.
  ///
  /// In am, this message translates to:
  /// **'ንቁ'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In am, this message translates to:
  /// **'የቦዘነ'**
  String get inactive;

  /// No description provided for @addSubcategory.
  ///
  /// In am, this message translates to:
  /// **'ንዑስ ምድብ ጨምር'**
  String get addSubcategory;

  /// No description provided for @categoryImage.
  ///
  /// In am, this message translates to:
  /// **'የምድብ ሥዕል'**
  String get categoryImage;

  /// No description provided for @moveUp.
  ///
  /// In am, this message translates to:
  /// **'ወደ ላይ'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In am, this message translates to:
  /// **'ወደ ታች'**
  String get moveDown;

  /// No description provided for @newAd.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ማስታወቂያ'**
  String get newAd;

  /// No description provided for @editAd.
  ///
  /// In am, this message translates to:
  /// **'ማስታወቂያ አስተካክል'**
  String get editAd;

  /// No description provided for @adKind.
  ///
  /// In am, this message translates to:
  /// **'ዓይነት'**
  String get adKind;

  /// No description provided for @kindAdvertisement.
  ///
  /// In am, this message translates to:
  /// **'ማስተዋወቂያ'**
  String get kindAdvertisement;

  /// No description provided for @kindEvent.
  ///
  /// In am, this message translates to:
  /// **'ዝግጅት'**
  String get kindEvent;

  /// No description provided for @kindAnnouncement.
  ///
  /// In am, this message translates to:
  /// **'ማስታወቂያ'**
  String get kindAnnouncement;

  /// No description provided for @kindCampaign.
  ///
  /// In am, this message translates to:
  /// **'ዘመቻ'**
  String get kindCampaign;

  /// No description provided for @kindInfo.
  ///
  /// In am, this message translates to:
  /// **'መረጃ'**
  String get kindInfo;

  /// No description provided for @shortDescription.
  ///
  /// In am, this message translates to:
  /// **'አጭር መግለጫ'**
  String get shortDescription;

  /// No description provided for @startsAt.
  ///
  /// In am, this message translates to:
  /// **'የሚጀምርበት'**
  String get startsAt;

  /// No description provided for @endsAt.
  ///
  /// In am, this message translates to:
  /// **'የሚያበቃበት'**
  String get endsAt;

  /// No description provided for @linkedPage.
  ///
  /// In am, this message translates to:
  /// **'የሚከፈተው ውስጣዊ ገጽ'**
  String get linkedPage;

  /// No description provided for @linkedProgram.
  ///
  /// In am, this message translates to:
  /// **'የሚከፈተው ፕሮግራም'**
  String get linkedProgram;

  /// No description provided for @noExternalLinks.
  ///
  /// In am, this message translates to:
  /// **'ማስታወቂያዎች ወደ ውስጣዊ ገጽ ወይም ፕሮግራም ብቻ ይወስዳሉ።'**
  String get noExternalLinks;

  /// No description provided for @newPage.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ገጽ'**
  String get newPage;

  /// No description provided for @editPage.
  ///
  /// In am, this message translates to:
  /// **'ገጽ አስተካክል'**
  String get editPage;

  /// No description provided for @summary.
  ///
  /// In am, this message translates to:
  /// **'ማጠቃለያ'**
  String get summary;

  /// No description provided for @content.
  ///
  /// In am, this message translates to:
  /// **'ይዘት'**
  String get content;

  /// No description provided for @ctaLabel.
  ///
  /// In am, this message translates to:
  /// **'የቁልፉ ጽሑፍ'**
  String get ctaLabel;

  /// No description provided for @ctaAction.
  ///
  /// In am, this message translates to:
  /// **'የቁልፉ ተግባር'**
  String get ctaAction;

  /// No description provided for @ctaNone.
  ///
  /// In am, this message translates to:
  /// **'ቁልፍ የለም'**
  String get ctaNone;

  /// No description provided for @ctaOpenProgram.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራም ክፈት'**
  String get ctaOpenProgram;

  /// No description provided for @ctaRegisterProgram.
  ///
  /// In am, this message translates to:
  /// **'ለፕሮግራም ምዝገባ'**
  String get ctaRegisterProgram;

  /// No description provided for @ctaOpenMezmur.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር ክፈት'**
  String get ctaOpenMezmur;

  /// No description provided for @ctaOpenCategory.
  ///
  /// In am, this message translates to:
  /// **'ምድብ ክፈት'**
  String get ctaOpenCategory;

  /// No description provided for @ctaTarget.
  ///
  /// In am, this message translates to:
  /// **'የቁልፉ ዒላማ'**
  String get ctaTarget;

  /// No description provided for @gallery.
  ///
  /// In am, this message translates to:
  /// **'ምስሎች'**
  String get gallery;

  /// No description provided for @addImage.
  ///
  /// In am, this message translates to:
  /// **'ምስል ጨምር'**
  String get addImage;

  /// No description provided for @newProgram.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ፕሮግራም'**
  String get newProgram;

  /// No description provided for @editProgram.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራም አስተካክል'**
  String get editProgram;

  /// No description provided for @requiresRegistration.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባ ያስፈልጋል'**
  String get requiresRegistration;

  /// No description provided for @requiresAttendance.
  ///
  /// In am, this message translates to:
  /// **'መገኘት ይመዘገባል'**
  String get requiresAttendance;

  /// No description provided for @capacityLabel.
  ///
  /// In am, this message translates to:
  /// **'የቦታ ብዛት (አማራጭ)'**
  String get capacityLabel;

  /// No description provided for @audience.
  ///
  /// In am, this message translates to:
  /// **'የማስታወሻ ተቀባዮች'**
  String get audience;

  /// No description provided for @audienceAll.
  ///
  /// In am, this message translates to:
  /// **'ሁሉም ተጠቃሚዎች'**
  String get audienceAll;

  /// No description provided for @audienceParticipants.
  ///
  /// In am, this message translates to:
  /// **'ተሳታፊዎች ብቻ'**
  String get audienceParticipants;

  /// No description provided for @reminderEnabled.
  ///
  /// In am, this message translates to:
  /// **'ራስ-ሰር ማስታወሻ'**
  String get reminderEnabled;

  /// No description provided for @reminderDaysBefore.
  ///
  /// In am, this message translates to:
  /// **'ከፕሮግራሙ ስንት ቀን በፊት'**
  String get reminderDaysBefore;

  /// No description provided for @reminderTitleLabel.
  ///
  /// In am, this message translates to:
  /// **'የማስታወሻ ርዕስ (አማራጭ)'**
  String get reminderTitleLabel;

  /// No description provided for @reminderBodyLabel.
  ///
  /// In am, this message translates to:
  /// **'የማስታወሻ መልዕክት (አማራጭ)'**
  String get reminderBodyLabel;

  /// No description provided for @statusCancelled.
  ///
  /// In am, this message translates to:
  /// **'የተሰረዘ'**
  String get statusCancelled;

  /// No description provided for @statusCompleted.
  ///
  /// In am, this message translates to:
  /// **'የተጠናቀቀ'**
  String get statusCompleted;

  /// No description provided for @participants.
  ///
  /// In am, this message translates to:
  /// **'ተሳታፊዎች'**
  String get participants;

  /// No description provided for @inviteUsers.
  ///
  /// In am, this message translates to:
  /// **'ተጠቃሚዎችን ጋብዝ'**
  String get inviteUsers;

  /// No description provided for @notifyInvited.
  ///
  /// In am, this message translates to:
  /// **'ለተጋበዙት ማሳወቂያ ላክ'**
  String get notifyInvited;

  /// No description provided for @invitedResult.
  ///
  /// In am, this message translates to:
  /// **'{count} ተጠቃሚዎች ተጋብዘዋል'**
  String invitedResult(int count);

  /// No description provided for @attendanceRoster.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት መዝገብ'**
  String get attendanceRoster;

  /// No description provided for @unmarked.
  ///
  /// In am, this message translates to:
  /// **'ያልተመዘገበ'**
  String get unmarked;

  /// No description provided for @showAllUsers.
  ///
  /// In am, this message translates to:
  /// **'ሁሉንም ተጠቃሚዎች አሳይ'**
  String get showAllUsers;

  /// No description provided for @markSelectedAs.
  ///
  /// In am, this message translates to:
  /// **'የተመረጡትን መዝግብ፦'**
  String get markSelectedAs;

  /// No description provided for @attendanceSaved.
  ///
  /// In am, this message translates to:
  /// **'መገኘቱ ተመዝግቧል'**
  String get attendanceSaved;

  /// No description provided for @removeParticipant.
  ///
  /// In am, this message translates to:
  /// **'ከተሳታፊዎች አስወግድ'**
  String get removeParticipant;

  /// No description provided for @notificationKind.
  ///
  /// In am, this message translates to:
  /// **'የመልዕክት ዓይነት'**
  String get notificationKind;

  /// No description provided for @kindReminder.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻ'**
  String get kindReminder;

  /// No description provided for @kindProgramInfo.
  ///
  /// In am, this message translates to:
  /// **'የፕሮግራም መረጃ'**
  String get kindProgramInfo;

  /// No description provided for @kindAdminMessage.
  ///
  /// In am, this message translates to:
  /// **'የአስተዳዳሪ መልዕክት'**
  String get kindAdminMessage;

  /// No description provided for @message.
  ///
  /// In am, this message translates to:
  /// **'መልዕክት'**
  String get message;

  /// No description provided for @recipients.
  ///
  /// In am, this message translates to:
  /// **'ተቀባዮች'**
  String get recipients;

  /// No description provided for @targetSelected.
  ///
  /// In am, this message translates to:
  /// **'የተመረጡ ተጠቃሚዎች'**
  String get targetSelected;

  /// No description provided for @targetFilter.
  ///
  /// In am, this message translates to:
  /// **'በማጣሪያ'**
  String get targetFilter;

  /// No description provided for @targetAll.
  ///
  /// In am, this message translates to:
  /// **'ሁሉም ተጠቃሚዎች'**
  String get targetAll;

  /// No description provided for @pickUsers.
  ///
  /// In am, this message translates to:
  /// **'ተጠቃሚዎችን ምረጥ'**
  String get pickUsers;

  /// No description provided for @sendConfirm.
  ///
  /// In am, this message translates to:
  /// **'ለ{count} ተጠቃሚዎች ይላክ?'**
  String sendConfirm(int count);

  /// No description provided for @sentTo.
  ///
  /// In am, this message translates to:
  /// **'ለ{count} ተጠቃሚዎች ተልኳል'**
  String sentTo(int count);

  /// No description provided for @history.
  ///
  /// In am, this message translates to:
  /// **'ታሪክ'**
  String get history;

  /// No description provided for @readOf.
  ///
  /// In am, this message translates to:
  /// **'{read}/{total} አንብበዋል'**
  String readOf(int read, int total);

  /// No description provided for @linkTo.
  ///
  /// In am, this message translates to:
  /// **'የሚከፈተው (አማራጭ)'**
  String get linkTo;

  /// No description provided for @filterStatus.
  ///
  /// In am, this message translates to:
  /// **'በሁኔታ'**
  String get filterStatus;

  /// No description provided for @filterProgram.
  ///
  /// In am, this message translates to:
  /// **'በፕሮግራም ተሳታፊነት'**
  String get filterProgram;

  /// No description provided for @newItem.
  ///
  /// In am, this message translates to:
  /// **'አዲስ እቃ'**
  String get newItem;

  /// No description provided for @editItem.
  ///
  /// In am, this message translates to:
  /// **'እቃ አስተካክል'**
  String get editItem;

  /// No description provided for @itemName.
  ///
  /// In am, this message translates to:
  /// **'የእቃ ስም'**
  String get itemName;

  /// No description provided for @itemCode.
  ///
  /// In am, this message translates to:
  /// **'የእቃ ኮድ'**
  String get itemCode;

  /// No description provided for @itemCategory.
  ///
  /// In am, this message translates to:
  /// **'የእቃ ዓይነት'**
  String get itemCategory;

  /// No description provided for @condition.
  ///
  /// In am, this message translates to:
  /// **'ሁኔታ'**
  String get condition;

  /// No description provided for @availableOf.
  ///
  /// In am, this message translates to:
  /// **'{available}/{total} ይገኛል'**
  String availableOf(int available, int total);

  /// No description provided for @storageLocation.
  ///
  /// In am, this message translates to:
  /// **'የሚቀመጥበት ቦታ'**
  String get storageLocation;

  /// No description provided for @itemStatusRetired.
  ///
  /// In am, this message translates to:
  /// **'ከአገልግሎት ውጭ'**
  String get itemStatusRetired;

  /// No description provided for @issueBorrowing.
  ///
  /// In am, this message translates to:
  /// **'እቃ አዋስ'**
  String get issueBorrowing;

  /// No description provided for @bulkBorrowing.
  ///
  /// In am, this message translates to:
  /// **'በጅምላ አዋስ'**
  String get bulkBorrowing;

  /// No description provided for @selectUser.
  ///
  /// In am, this message translates to:
  /// **'ተጠቃሚ ምረጥ'**
  String get selectUser;

  /// No description provided for @selectUsers.
  ///
  /// In am, this message translates to:
  /// **'ተጠቃሚዎችን ምረጥ'**
  String get selectUsers;

  /// No description provided for @selectItem.
  ///
  /// In am, this message translates to:
  /// **'እቃ ምረጥ'**
  String get selectItem;

  /// No description provided for @addItem.
  ///
  /// In am, this message translates to:
  /// **'እቃ ጨምር'**
  String get addItem;

  /// No description provided for @loanDays.
  ///
  /// In am, this message translates to:
  /// **'የውሰት ቀናት'**
  String get loanDays;

  /// No description provided for @signHere.
  ///
  /// In am, this message translates to:
  /// **'ተዋሹ እዚህ ይፈርሙ'**
  String get signHere;

  /// No description provided for @clearSignature.
  ///
  /// In am, this message translates to:
  /// **'ፊርማ አጽዳ'**
  String get clearSignature;

  /// No description provided for @signFor.
  ///
  /// In am, this message translates to:
  /// **'{name} — እባክዎ ይፈርሙ'**
  String signFor(String name);

  /// No description provided for @skipSignature.
  ///
  /// In am, this message translates to:
  /// **'ያለ ፊርማ ቀጥል'**
  String get skipSignature;

  /// No description provided for @signatureRequiredHint.
  ///
  /// In am, this message translates to:
  /// **'ፊርማው ተዋሹ እቃውን መቀበሉን ያረጋግጣል።'**
  String get signatureRequiredHint;

  /// No description provided for @borrowingCreated.
  ///
  /// In am, this message translates to:
  /// **'ውሰቱ ተመዝግቧል'**
  String get borrowingCreated;

  /// No description provided for @bulkCreated.
  ///
  /// In am, this message translates to:
  /// **'{count} የውሰት መዝገቦች ተፈጥረዋል'**
  String bulkCreated(int count);

  /// No description provided for @processReturn.
  ///
  /// In am, this message translates to:
  /// **'መመለሱን መዝግብ'**
  String get processReturn;

  /// No description provided for @returnedQuantity.
  ///
  /// In am, this message translates to:
  /// **'የተመለሰ ብዛት'**
  String get returnedQuantity;

  /// No description provided for @returnedOn.
  ///
  /// In am, this message translates to:
  /// **'የተመለሰበት ቀን'**
  String get returnedOn;

  /// No description provided for @returnNotes.
  ///
  /// In am, this message translates to:
  /// **'የሁኔታ ማስታወሻ'**
  String get returnNotes;

  /// No description provided for @fineOverride.
  ///
  /// In am, this message translates to:
  /// **'ቅጣት ቀይር'**
  String get fineOverride;

  /// No description provided for @overrideReason.
  ///
  /// In am, this message translates to:
  /// **'ምክንያት'**
  String get overrideReason;

  /// No description provided for @clearOverride.
  ///
  /// In am, this message translates to:
  /// **'ወደ ራስ-ሰር ስሌት መልስ'**
  String get clearOverride;

  /// No description provided for @markPaid.
  ///
  /// In am, this message translates to:
  /// **'እንደተከፈለ ምልክት አድርግ'**
  String get markPaid;

  /// No description provided for @waiveFine.
  ///
  /// In am, this message translates to:
  /// **'ቅጣቱን ሰርዝ'**
  String get waiveFine;

  /// No description provided for @issuedBy.
  ///
  /// In am, this message translates to:
  /// **'ያዋሰው'**
  String get issuedBy;

  /// No description provided for @returnedTo.
  ///
  /// In am, this message translates to:
  /// **'የተቀበለው'**
  String get returnedTo;

  /// No description provided for @openBorrowings.
  ///
  /// In am, this message translates to:
  /// **'ያልተመለሱ'**
  String get openBorrowings;

  /// No description provided for @overdueFilter.
  ///
  /// In am, this message translates to:
  /// **'ጊዜ ያለፈባቸው'**
  String get overdueFilter;

  /// No description provided for @returnConditions.
  ///
  /// In am, this message translates to:
  /// **'የመመለሻ ሁኔታዎች'**
  String get returnConditions;

  /// No description provided for @marksLost.
  ///
  /// In am, this message translates to:
  /// **'እንደጠፋ ይቆጠራል'**
  String get marksLost;

  /// No description provided for @restock.
  ///
  /// In am, this message translates to:
  /// **'ወደ ክምችት ይመለሳል'**
  String get restock;

  /// No description provided for @finePolicy.
  ///
  /// In am, this message translates to:
  /// **'የቅጣት ደንብ'**
  String get finePolicy;

  /// No description provided for @fineEnabled.
  ///
  /// In am, this message translates to:
  /// **'ቅጣት ንቁ ነው'**
  String get fineEnabled;

  /// No description provided for @fineAmount.
  ///
  /// In am, this message translates to:
  /// **'የቅጣት መጠን (ብር)'**
  String get fineAmount;

  /// No description provided for @finePeriod.
  ///
  /// In am, this message translates to:
  /// **'የቅጣት ስሌት'**
  String get finePeriod;

  /// No description provided for @perDay.
  ///
  /// In am, this message translates to:
  /// **'በቀን'**
  String get perDay;

  /// No description provided for @perWeek.
  ///
  /// In am, this message translates to:
  /// **'በሳምንት'**
  String get perWeek;

  /// No description provided for @graceDays.
  ///
  /// In am, this message translates to:
  /// **'የእፎይታ ቀናት'**
  String get graceDays;

  /// No description provided for @maxFine.
  ///
  /// In am, this message translates to:
  /// **'ከፍተኛ ቅጣት (አማራጭ)'**
  String get maxFine;

  /// No description provided for @fineOverridden.
  ///
  /// In am, this message translates to:
  /// **'በእጅ የተቀየረ'**
  String get fineOverridden;

  /// No description provided for @borrower.
  ///
  /// In am, this message translates to:
  /// **'ተዋሽ'**
  String get borrower;

  /// No description provided for @borrowingsDue.
  ///
  /// In am, this message translates to:
  /// **'የሚመለሱበት ቀን'**
  String get borrowingsDue;

  /// No description provided for @signNow.
  ///
  /// In am, this message translates to:
  /// **'አሁን አስፈርም'**
  String get signNow;

  /// No description provided for @reportUsers.
  ///
  /// In am, this message translates to:
  /// **'የተጠቃሚ ሪፖርት'**
  String get reportUsers;

  /// No description provided for @reportMezmurs.
  ///
  /// In am, this message translates to:
  /// **'የመዝሙር አጠቃቀም'**
  String get reportMezmurs;

  /// No description provided for @reportAttendance.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት ሪፖርት'**
  String get reportAttendance;

  /// No description provided for @reportBorrowings.
  ///
  /// In am, this message translates to:
  /// **'የውሰት ሪፖርት'**
  String get reportBorrowings;

  /// No description provided for @reportNotifications.
  ///
  /// In am, this message translates to:
  /// **'የማሳወቂያ ሪፖርት'**
  String get reportNotifications;

  /// No description provided for @reportAdminActivity.
  ///
  /// In am, this message translates to:
  /// **'የአስተዳዳሪ እንቅስቃሴ'**
  String get reportAdminActivity;

  /// No description provided for @topViewed.
  ///
  /// In am, this message translates to:
  /// **'በብዛት የታዩ'**
  String get topViewed;

  /// No description provided for @topPlayed.
  ///
  /// In am, this message translates to:
  /// **'በብዛት የተደመጡ'**
  String get topPlayed;

  /// No description provided for @topFavorited.
  ///
  /// In am, this message translates to:
  /// **'በብዛት የተወደዱ'**
  String get topFavorited;

  /// No description provided for @topDownloaded.
  ///
  /// In am, this message translates to:
  /// **'በብዛት የወረዱ'**
  String get topDownloaded;

  /// No description provided for @topSearches.
  ///
  /// In am, this message translates to:
  /// **'በብዛት የተፈለጉ'**
  String get topSearches;

  /// No description provided for @registrationsPerDay.
  ///
  /// In am, this message translates to:
  /// **'በቀን ምዝገባ'**
  String get registrationsPerDay;

  /// No description provided for @distinctLogins.
  ///
  /// In am, this message translates to:
  /// **'የገቡ ተጠቃሚዎች'**
  String get distinctLogins;

  /// No description provided for @byStatus.
  ///
  /// In am, this message translates to:
  /// **'በሁኔታ'**
  String get byStatus;

  /// No description provided for @byItem.
  ///
  /// In am, this message translates to:
  /// **'በእቃ'**
  String get byItem;

  /// No description provided for @attendedOf.
  ///
  /// In am, this message translates to:
  /// **'{attended}/{participants} ተገኝተዋል'**
  String attendedOf(int attended, int participants);

  /// No description provided for @sender.
  ///
  /// In am, this message translates to:
  /// **'ላኪ'**
  String get sender;

  /// No description provided for @countLabel.
  ///
  /// In am, this message translates to:
  /// **'ብዛት'**
  String get countLabel;

  /// No description provided for @last30Days.
  ///
  /// In am, this message translates to:
  /// **'ያለፉት 30 ቀናት'**
  String get last30Days;

  /// No description provided for @last7Days.
  ///
  /// In am, this message translates to:
  /// **'ያለፉት 7 ቀናት'**
  String get last7Days;

  /// No description provided for @last90Days.
  ///
  /// In am, this message translates to:
  /// **'ያለፉት 90 ቀናት'**
  String get last90Days;

  /// No description provided for @action.
  ///
  /// In am, this message translates to:
  /// **'ተግባር'**
  String get action;

  /// No description provided for @actor.
  ///
  /// In am, this message translates to:
  /// **'አድራጊ'**
  String get actor;

  /// No description provided for @target.
  ///
  /// In am, this message translates to:
  /// **'ዒላማ'**
  String get target;

  /// No description provided for @user.
  ///
  /// In am, this message translates to:
  /// **'ተጠቃሚ'**
  String get user;

  /// No description provided for @newAdmin.
  ///
  /// In am, this message translates to:
  /// **'አስተዳዳሪ መድብ'**
  String get newAdmin;

  /// No description provided for @role.
  ///
  /// In am, this message translates to:
  /// **'ሚና'**
  String get role;

  /// No description provided for @level.
  ///
  /// In am, this message translates to:
  /// **'ደረጃ'**
  String get level;

  /// No description provided for @rolePermissions.
  ///
  /// In am, this message translates to:
  /// **'የሚናው ፈቃዶች'**
  String get rolePermissions;

  /// No description provided for @extraPermissions.
  ///
  /// In am, this message translates to:
  /// **'ተጨማሪ ፈቃዶች'**
  String get extraPermissions;

  /// No description provided for @newRole.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ሚና'**
  String get newRole;

  /// No description provided for @roleSlug.
  ///
  /// In am, this message translates to:
  /// **'መለያ ስም (a-z, _)'**
  String get roleSlug;

  /// No description provided for @roleName.
  ///
  /// In am, this message translates to:
  /// **'የሚና ስም'**
  String get roleName;

  /// No description provided for @notManageable.
  ///
  /// In am, this message translates to:
  /// **'ይህን አስተዳዳሪ ማስተዳደር አይችሉም'**
  String get notManageable;

  /// No description provided for @adminCreated.
  ///
  /// In am, this message translates to:
  /// **'አስተዳዳሪው ተመድቧል'**
  String get adminCreated;

  /// No description provided for @perm_users_view.
  ///
  /// In am, this message translates to:
  /// **'ተጠቃሚዎችን ማየት'**
  String get perm_users_view;

  /// No description provided for @perm_users_create.
  ///
  /// In am, this message translates to:
  /// **'ተጠቃሚ መፍጠር'**
  String get perm_users_create;

  /// No description provided for @perm_users_update.
  ///
  /// In am, this message translates to:
  /// **'ተጠቃሚ ማስተካከል'**
  String get perm_users_update;

  /// No description provided for @perm_users_disable.
  ///
  /// In am, this message translates to:
  /// **'ተጠቃሚ ማገድ/ማንቃት'**
  String get perm_users_disable;

  /// No description provided for @perm_users_reset_device.
  ///
  /// In am, this message translates to:
  /// **'መሣሪያ ዳግም ማስጀመር'**
  String get perm_users_reset_device;

  /// No description provided for @perm_mezmurs_view.
  ///
  /// In am, this message translates to:
  /// **'መዝሙሮችን ማየት (ረቂቅን ጨምሮ)'**
  String get perm_mezmurs_view;

  /// No description provided for @perm_mezmurs_create.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር መፍጠር'**
  String get perm_mezmurs_create;

  /// No description provided for @perm_mezmurs_update.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር ማስተካከል'**
  String get perm_mezmurs_update;

  /// No description provided for @perm_mezmurs_delete.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር መሰረዝ'**
  String get perm_mezmurs_delete;

  /// No description provided for @perm_categories_manage.
  ///
  /// In am, this message translates to:
  /// **'ምድቦችን ማስተዳደር'**
  String get perm_categories_manage;

  /// No description provided for @perm_ads_manage.
  ///
  /// In am, this message translates to:
  /// **'ማስታወቂያዎችን ማስተዳደር'**
  String get perm_ads_manage;

  /// No description provided for @perm_pages_manage.
  ///
  /// In am, this message translates to:
  /// **'ውስጣዊ ገጾችን ማስተዳደር'**
  String get perm_pages_manage;

  /// No description provided for @perm_programs_manage.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራሞችን ማስተዳደር'**
  String get perm_programs_manage;

  /// No description provided for @perm_attendance_manage.
  ///
  /// In am, this message translates to:
  /// **'መገኘትን መመዝገብ'**
  String get perm_attendance_manage;

  /// No description provided for @perm_notifications_send.
  ///
  /// In am, this message translates to:
  /// **'ማሳወቂያ መላክ'**
  String get perm_notifications_send;

  /// No description provided for @perm_notifications_send_all.
  ///
  /// In am, this message translates to:
  /// **'ለሁሉም ማሳወቂያ መላክ'**
  String get perm_notifications_send_all;

  /// No description provided for @perm_borrowing_manage.
  ///
  /// In am, this message translates to:
  /// **'ውሰትና መመለስ'**
  String get perm_borrowing_manage;

  /// No description provided for @perm_items_manage.
  ///
  /// In am, this message translates to:
  /// **'እቃዎችን ማስተዳደር'**
  String get perm_items_manage;

  /// No description provided for @perm_fines_manage.
  ///
  /// In am, this message translates to:
  /// **'ቅጣቶችን ማስተዳደር'**
  String get perm_fines_manage;

  /// No description provided for @perm_reports_view.
  ///
  /// In am, this message translates to:
  /// **'ሪፖርቶችን ማየት'**
  String get perm_reports_view;

  /// No description provided for @perm_audit_logs_view.
  ///
  /// In am, this message translates to:
  /// **'የአስተዳደር መዝገብ ማየት'**
  String get perm_audit_logs_view;

  /// No description provided for @perm_activity_logs_view.
  ///
  /// In am, this message translates to:
  /// **'የተጠቃሚ እንቅስቃሴ ማየት'**
  String get perm_activity_logs_view;

  /// No description provided for @perm_admins_view.
  ///
  /// In am, this message translates to:
  /// **'አስተዳዳሪዎችን ማየት'**
  String get perm_admins_view;

  /// No description provided for @perm_admins_manage.
  ///
  /// In am, this message translates to:
  /// **'አስተዳዳሪዎችን ማስተዳደር'**
  String get perm_admins_manage;

  /// No description provided for @perm_settings_manage.
  ///
  /// In am, this message translates to:
  /// **'የሲስተም ማስተካከያ'**
  String get perm_settings_manage;

  /// No description provided for @reminderSettings.
  ///
  /// In am, this message translates to:
  /// **'የማስታወሻ ማስተካከያ'**
  String get reminderSettings;

  /// No description provided for @borrowingDaysBefore.
  ///
  /// In am, this message translates to:
  /// **'ከመመለሻ ቀን ስንት ቀን በፊት ማሳወቅ'**
  String get borrowingDaysBefore;

  /// No description provided for @overdueRepeatDays.
  ///
  /// In am, this message translates to:
  /// **'የዘገየ ማሳወቂያ በየስንት ቀኑ'**
  String get overdueRepeatDays;

  /// No description provided for @defaultLoanDays.
  ///
  /// In am, this message translates to:
  /// **'መደበኛ የውሰት ቀናት'**
  String get defaultLoanDays;

  /// No description provided for @programReminderDefault.
  ///
  /// In am, this message translates to:
  /// **'የፕሮግራም ማስታወሻ (መደበኛ)'**
  String get programReminderDefault;

  /// No description provided for @notificationRetention.
  ///
  /// In am, this message translates to:
  /// **'የተነበቡ ማሳወቂያዎች የሚቆዩበት (ቀን)'**
  String get notificationRetention;

  /// No description provided for @systemLogin.
  ///
  /// In am, this message translates to:
  /// **'የሲስተም መግቢያ'**
  String get systemLogin;

  /// No description provided for @totpCode.
  ///
  /// In am, this message translates to:
  /// **'የማረጋገጫ ኮድ (6 አሃዝ)'**
  String get totpCode;

  /// No description provided for @systemConsole.
  ///
  /// In am, this message translates to:
  /// **'የሲስተም ቁጥጥር'**
  String get systemConsole;

  /// No description provided for @hiddenEntries.
  ///
  /// In am, this message translates to:
  /// **'የተደበቁ መዝገቦች'**
  String get hiddenEntries;

  /// No description provided for @visibleEntries.
  ///
  /// In am, this message translates to:
  /// **'የሚታዩ መዝገቦች'**
  String get visibleEntries;

  /// No description provided for @deniedAttempts.
  ///
  /// In am, this message translates to:
  /// **'ውድቅ የተደረጉ ሙከራዎች (7 ቀን)'**
  String get deniedAttempts;

  /// No description provided for @adminsByRole.
  ///
  /// In am, this message translates to:
  /// **'አስተዳዳሪዎች በሚና'**
  String get adminsByRole;

  /// No description provided for @allAdmins.
  ///
  /// In am, this message translates to:
  /// **'ሁሉም አስተዳዳሪዎች'**
  String get allAdmins;

  /// No description provided for @act_register.
  ///
  /// In am, this message translates to:
  /// **'ተመዘገበ'**
  String get act_register;

  /// No description provided for @act_login.
  ///
  /// In am, this message translates to:
  /// **'ገባ'**
  String get act_login;

  /// No description provided for @act_login_failed.
  ///
  /// In am, this message translates to:
  /// **'መግባት አልተሳካም'**
  String get act_login_failed;

  /// No description provided for @act_logout.
  ///
  /// In am, this message translates to:
  /// **'ወጣ'**
  String get act_logout;

  /// No description provided for @act_password_change.
  ///
  /// In am, this message translates to:
  /// **'ፒን ቀየረ'**
  String get act_password_change;

  /// No description provided for @act_password_reset.
  ///
  /// In am, this message translates to:
  /// **'ፒን መለሰ'**
  String get act_password_reset;

  /// No description provided for @act_profile_update.
  ///
  /// In am, this message translates to:
  /// **'መገለጫ አስተካከለ'**
  String get act_profile_update;

  /// No description provided for @act_device_change.
  ///
  /// In am, this message translates to:
  /// **'መሣሪያ ተቀየረ'**
  String get act_device_change;

  /// No description provided for @act_mezmur_view.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር አየ'**
  String get act_mezmur_view;

  /// No description provided for @act_mezmur_search.
  ///
  /// In am, this message translates to:
  /// **'ፈለገ'**
  String get act_mezmur_search;

  /// No description provided for @act_audio_play.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር አጫወተ'**
  String get act_audio_play;

  /// No description provided for @act_audio_complete.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር አዳምጦ ጨረሰ'**
  String get act_audio_complete;

  /// No description provided for @act_favorite_add.
  ///
  /// In am, this message translates to:
  /// **'ተወዳጅ አደረገ'**
  String get act_favorite_add;

  /// No description provided for @act_favorite_remove.
  ///
  /// In am, this message translates to:
  /// **'ከተወዳጅ አስወገደ'**
  String get act_favorite_remove;

  /// No description provided for @act_download.
  ///
  /// In am, this message translates to:
  /// **'አወረደ'**
  String get act_download;

  /// No description provided for @act_download_remove.
  ///
  /// In am, this message translates to:
  /// **'ውርድ አስወገደ'**
  String get act_download_remove;

  /// No description provided for @act_offline_access.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ ተጠቀመ'**
  String get act_offline_access;

  /// No description provided for @act_program_view.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራም አየ'**
  String get act_program_view;

  /// No description provided for @act_program_register.
  ///
  /// In am, this message translates to:
  /// **'ለፕሮግራም ተመዘገበ'**
  String get act_program_register;

  /// No description provided for @act_program_unregister.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባ ሰረዘ'**
  String get act_program_unregister;

  /// No description provided for @act_reminder_create.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻ ፈጠረ'**
  String get act_reminder_create;

  /// No description provided for @act_reminder_update.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻ አስተካከለ'**
  String get act_reminder_update;

  /// No description provided for @act_reminder_delete.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻ ሰረዘ'**
  String get act_reminder_delete;

  /// No description provided for @act_notification_open.
  ///
  /// In am, this message translates to:
  /// **'ማሳወቂያ ከፈተ'**
  String get act_notification_open;

  /// No description provided for @act_attendance.
  ///
  /// In am, this message translates to:
  /// **'ተገኘ'**
  String get act_attendance;

  /// No description provided for @act_borrow.
  ///
  /// In am, this message translates to:
  /// **'እቃ ተዋሰ'**
  String get act_borrow;

  /// No description provided for @act_return.
  ///
  /// In am, this message translates to:
  /// **'እቃ መለሰ'**
  String get act_return;

  /// No description provided for @act_page_view.
  ///
  /// In am, this message translates to:
  /// **'ገጽ አየ'**
  String get act_page_view;

  /// No description provided for @telegram.
  ///
  /// In am, this message translates to:
  /// **'ቴሌግራም'**
  String get telegram;

  /// No description provided for @telegramConnect.
  ///
  /// In am, this message translates to:
  /// **'ቴሌግራም አገናኝ'**
  String get telegramConnect;

  /// No description provided for @telegramLinked.
  ///
  /// In am, this message translates to:
  /// **'ተገናኝቷል'**
  String get telegramLinked;

  /// No description provided for @telegramHint.
  ///
  /// In am, this message translates to:
  /// **'ቴሌግራምዎን ካገናኙ የፒን መቀየሪያ ኮድና ጊዜያዊ ፒን በቴሌግራም ይላክልዎታል።'**
  String get telegramHint;

  /// No description provided for @telegramOpenBot.
  ///
  /// In am, this message translates to:
  /// **'ቴሌግራም ይከፈታል። «Start» የሚለውን ይጫኑ፣ ከዚያ ወደ መተግበሪያው ይመለሱ።'**
  String get telegramOpenBot;

  /// No description provided for @telegramDisconnect.
  ///
  /// In am, this message translates to:
  /// **'ግንኙነቱን አቋርጥ'**
  String get telegramDisconnect;

  /// No description provided for @telegramDisconnectConfirm.
  ///
  /// In am, this message translates to:
  /// **'የቴሌግራም ግንኙነቱን ማቋረጥ ይፈልጋሉ?'**
  String get telegramDisconnectConfirm;

  /// No description provided for @errTelegramNotConfigured.
  ///
  /// In am, this message translates to:
  /// **'የቴሌግራም ቦት ገና አልተዋቀረም። አስተዳዳሪውን ያነጋግሩ።'**
  String get errTelegramNotConfigured;

  /// No description provided for @forgotHintTelegram.
  ///
  /// In am, this message translates to:
  /// **'ቴሌግራም ካገናኙ ኮዱ በቴሌግራም ይላክልዎታል።'**
  String get forgotHintTelegram;

  /// No description provided for @copy.
  ///
  /// In am, this message translates to:
  /// **'ቅዳ'**
  String get copy;

  /// No description provided for @tempPasswordSentTelegram.
  ///
  /// In am, this message translates to:
  /// **'ይህ ፒን ለተጠቃሚው በቴሌግራምም ተልኳል።'**
  String get tempPasswordSentTelegram;

  /// No description provided for @profileChangePending.
  ///
  /// In am, this message translates to:
  /// **'የስም/ስልክ ለውጥዎ በአስተዳዳሪ እስኪጸድቅ በመጠባበቅ ላይ ነው፦ {change}'**
  String profileChangePending(String change);

  /// No description provided for @profileChangeSubmitted.
  ///
  /// In am, this message translates to:
  /// **'ለውጡ ለአስተዳዳሪ ተልኳል። ሲጸድቅ ይተገበራል።'**
  String get profileChangeSubmitted;

  /// No description provided for @profileApprovalNote.
  ///
  /// In am, this message translates to:
  /// **'የስም እና የስልክ ቁጥር ለውጥ በአስተዳዳሪ መጽደቅ አለበት።'**
  String get profileApprovalNote;

  /// No description provided for @cancelRequest.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄውን ሰርዝ'**
  String get cancelRequest;

  /// No description provided for @changeRequests.
  ///
  /// In am, this message translates to:
  /// **'የመገለጫ ለውጥ ጥያቄዎች'**
  String get changeRequests;

  /// No description provided for @approve.
  ///
  /// In am, this message translates to:
  /// **'አጽድቅ'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In am, this message translates to:
  /// **'ውድቅ አድርግ'**
  String get reject;

  /// No description provided for @approved.
  ///
  /// In am, this message translates to:
  /// **'ጸድቋል'**
  String get approved;

  /// No description provided for @rejected.
  ///
  /// In am, this message translates to:
  /// **'ውድቅ ሆኗል'**
  String get rejected;

  /// No description provided for @pendingStatus.
  ///
  /// In am, this message translates to:
  /// **'በመጠባበቅ ላይ'**
  String get pendingStatus;

  /// No description provided for @noChangeRequests.
  ///
  /// In am, this message translates to:
  /// **'በመጠባበቅ ላይ ያለ ጥያቄ የለም'**
  String get noChangeRequests;

  /// No description provided for @currentValue.
  ///
  /// In am, this message translates to:
  /// **'የአሁኑ'**
  String get currentValue;

  /// No description provided for @requestedValue.
  ///
  /// In am, this message translates to:
  /// **'የተጠየቀው'**
  String get requestedValue;

  /// No description provided for @youtubeLink.
  ///
  /// In am, this message translates to:
  /// **'የYouTube ማገናኛ (አማራጭ)'**
  String get youtubeLink;

  /// No description provided for @watchOnYoutube.
  ///
  /// In am, this message translates to:
  /// **'በYouTube ይመልከቱ'**
  String get watchOnYoutube;

  /// No description provided for @vInvalidYoutube.
  ///
  /// In am, this message translates to:
  /// **'ትክክለኛ የYouTube ማገናኛ ያስገቡ (youtube.com ወይም youtu.be)'**
  String get vInvalidYoutube;

  /// No description provided for @reminderReturnItem.
  ///
  /// In am, this message translates to:
  /// **'«{item}» መመለስ'**
  String reminderReturnItem(String item);

  /// No description provided for @attendanceToday.
  ///
  /// In am, this message translates to:
  /// **'የዛሬና መጪ ፕሮግራሞች'**
  String get attendanceToday;

  /// No description provided for @attendanceRecent.
  ///
  /// In am, this message translates to:
  /// **'ያለፉ ፕሮግራሞች'**
  String get attendanceRecent;

  /// No description provided for @attendanceOnlyAdmins.
  ///
  /// In am, this message translates to:
  /// **'የፕሮግራሙን መገኘት የሚመዘግበው የሰው ሀብት ክፍል የመደበው መዝጋቢ ብቻ ነው፤ አባላት ሲመዘገቡ ይፈርማሉ።'**
  String get attendanceOnlyAdmins;

  /// No description provided for @releases.
  ///
  /// In am, this message translates to:
  /// **'የመተግበሪያ ስሪቶች'**
  String get releases;

  /// No description provided for @newRelease.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ስሪት ጫን'**
  String get newRelease;

  /// No description provided for @versionName.
  ///
  /// In am, this message translates to:
  /// **'የስሪት ስም (ለምሳሌ 1.1.0)'**
  String get versionName;

  /// No description provided for @versionCode.
  ///
  /// In am, this message translates to:
  /// **'የስሪት ቁጥር (build number)'**
  String get versionCode;

  /// No description provided for @releaseNotes.
  ///
  /// In am, this message translates to:
  /// **'የለውጥ ማስታወሻ'**
  String get releaseNotes;

  /// No description provided for @mandatoryUpdate.
  ///
  /// In am, this message translates to:
  /// **'አስገዳጅ ዝማኔ (የቆዩ እትሞች መዘመን አለባቸው)'**
  String get mandatoryUpdate;

  /// No description provided for @minSupportedCode.
  ///
  /// In am, this message translates to:
  /// **'ዝቅተኛ የሚፈቀድ የስሪት ቁጥር (አማራጭ)'**
  String get minSupportedCode;

  /// No description provided for @publish.
  ///
  /// In am, this message translates to:
  /// **'አትም'**
  String get publish;

  /// No description provided for @chooseApk.
  ///
  /// In am, this message translates to:
  /// **'APK ፋይል ምረጥ'**
  String get chooseApk;

  /// No description provided for @downloadsCount.
  ///
  /// In am, this message translates to:
  /// **'{count} ጊዜ ወርዷል'**
  String downloadsCount(int count);

  /// No description provided for @openDownloadPage.
  ///
  /// In am, this message translates to:
  /// **'የማውረጃ ገጹን ክፈት'**
  String get openDownloadPage;

  /// No description provided for @errVersionExists.
  ///
  /// In am, this message translates to:
  /// **'ይህ የስሪት ቁጥር አስቀድሞ አለ።'**
  String get errVersionExists;

  /// No description provided for @vInvalidVersion.
  ///
  /// In am, this message translates to:
  /// **'ትክክለኛ የስሪት ስም ያስገቡ (ለምሳሌ 1.1.0)'**
  String get vInvalidVersion;

  /// No description provided for @unpublish.
  ///
  /// In am, this message translates to:
  /// **'ከገጹ አስወግድ'**
  String get unpublish;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In am, this message translates to:
  /// **'ዝማኔ ያስፈልጋል'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In am, this message translates to:
  /// **'ለመቀጠል እባክዎ አዲሱን የመተግበሪያ እትም ({version}) ያውርዱና ይጫኑ።'**
  String updateRequiredBody(String version);

  /// No description provided for @updateAvailableTitle.
  ///
  /// In am, this message translates to:
  /// **'አዲስ እትም አለ'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In am, this message translates to:
  /// **'አዲስ የመተግበሪያ እትም ({version}) ተለቋል።'**
  String updateAvailableBody(String version);

  /// No description provided for @updateNow.
  ///
  /// In am, this message translates to:
  /// **'አሁን አዘምን'**
  String get updateNow;

  /// No description provided for @later.
  ///
  /// In am, this message translates to:
  /// **'በኋላ'**
  String get later;

  /// No description provided for @checkAgain.
  ///
  /// In am, this message translates to:
  /// **'እንደገና አረጋግጥ'**
  String get checkAgain;

  /// No description provided for @perm_releases_manage.
  ///
  /// In am, this message translates to:
  /// **'የመተግበሪያ ስሪቶችን ማስተዳደር'**
  String get perm_releases_manage;

  /// No description provided for @permissionTitle.
  ///
  /// In am, this message translates to:
  /// **'የመቅረት ፈቃድ'**
  String get permissionTitle;

  /// No description provided for @requestPermission.
  ///
  /// In am, this message translates to:
  /// **'ፈቃድ ጠይቅ'**
  String get requestPermission;

  /// No description provided for @permissionReason.
  ///
  /// In am, this message translates to:
  /// **'ምክንያት (አማራጭ)'**
  String get permissionReason;

  /// No description provided for @permissionRequested.
  ///
  /// In am, this message translates to:
  /// **'ፈቃድ ተጠይቋል'**
  String get permissionRequested;

  /// No description provided for @permissionPending.
  ///
  /// In am, this message translates to:
  /// **'ተጠይቋል — ማረጋገጫ በመጠበቅ ላይ'**
  String get permissionPending;

  /// No description provided for @permissionApproved.
  ///
  /// In am, this message translates to:
  /// **'ፈቃድ ተሰጥቷል — ከመገኘት ነፃ ነዎት'**
  String get permissionApproved;

  /// No description provided for @permissionRejected.
  ///
  /// In am, this message translates to:
  /// **'ፈቃድ አልተሰጠም'**
  String get permissionRejected;

  /// No description provided for @cancelPermission.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄውን ሰርዝ'**
  String get cancelPermission;

  /// No description provided for @permissionDeadline.
  ///
  /// In am, this message translates to:
  /// **'ከ{date} በፊት ይጠይቁ'**
  String permissionDeadline(String date);

  /// No description provided for @permissionQuotaMonth.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ወር፦ {used} ከ{limit}'**
  String permissionQuotaMonth(int used, int limit);

  /// No description provided for @permissionQuotaQuarter.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ሩብ ዓመት፦ {used} ከ{limit}'**
  String permissionQuotaQuarter(int used, int limit);

  /// No description provided for @errPermissionDeadline.
  ///
  /// In am, this message translates to:
  /// **'ፈቃድ የመጠየቂያ ጊዜ አልፏል'**
  String get errPermissionDeadline;

  /// No description provided for @errPermissionMonthly.
  ///
  /// In am, this message translates to:
  /// **'የዚህን ወር ፈቃዶች በሙሉ ተጠቅመዋል'**
  String get errPermissionMonthly;

  /// No description provided for @errPermissionQuarterly.
  ///
  /// In am, this message translates to:
  /// **'የዚህን ሩብ ዓመት ፈቃዶች በሙሉ ተጠቅመዋል'**
  String get errPermissionQuarterly;

  /// No description provided for @errPermissionExists.
  ///
  /// In am, this message translates to:
  /// **'ለዚህ ፕሮግራም አስቀድመው ፈቃድ ጠይቀዋል'**
  String get errPermissionExists;

  /// No description provided for @errPermissionRejected.
  ///
  /// In am, this message translates to:
  /// **'ለዚህ ፕሮግራም ያቀረቡት ጥያቄ አልተፈቀደም'**
  String get errPermissionRejected;

  /// No description provided for @errPermissionNotApplicable.
  ///
  /// In am, this message translates to:
  /// **'ለዚህ ፕሮግራም ፈቃድ መጠየቅ አይቻልም'**
  String get errPermissionNotApplicable;

  /// No description provided for @errPermissionDisabled.
  ///
  /// In am, this message translates to:
  /// **'የፈቃድ ጥያቄ ለጊዜው ዝግ ነው'**
  String get errPermissionDisabled;

  /// No description provided for @permissionRequests.
  ///
  /// In am, this message translates to:
  /// **'የፈቃድ ጥያቄዎች'**
  String get permissionRequests;

  /// No description provided for @noPermissionRequests.
  ///
  /// In am, this message translates to:
  /// **'ምንም የፈቃድ ጥያቄ የለም'**
  String get noPermissionRequests;

  /// No description provided for @permissionPolicy.
  ///
  /// In am, this message translates to:
  /// **'የፈቃድ ደንቦች'**
  String get permissionPolicy;

  /// No description provided for @permissionsEnabled.
  ///
  /// In am, this message translates to:
  /// **'የፈቃድ ጥያቄ ፍቀድ'**
  String get permissionsEnabled;

  /// No description provided for @permissionDeadlineHours.
  ///
  /// In am, this message translates to:
  /// **'የመጠየቂያ ገደብ (ፕሮግራሙ ከመጀመሩ በፊት በሰዓት)'**
  String get permissionDeadlineHours;

  /// No description provided for @permissionMonthlyLimit.
  ///
  /// In am, this message translates to:
  /// **'በወር ከፍተኛ (ባዶ = ገደብ የለም)'**
  String get permissionMonthlyLimit;

  /// No description provided for @permissionQuarterlyLimit.
  ///
  /// In am, this message translates to:
  /// **'በሩብ ዓመት ከፍተኛ (ባዶ = ገደብ የለም)'**
  String get permissionQuarterlyLimit;

  /// No description provided for @permissionWeight.
  ///
  /// In am, this message translates to:
  /// **'የተፈቀደ መቅረት የመገኘት ክብደት (0 – 1)'**
  String get permissionWeight;

  /// No description provided for @permissionWeightHint.
  ///
  /// In am, this message translates to:
  /// **'0 እንደ መቅረት፣ 1 እንደ መገኘት፣ 0.5 እንደ ግማሽ ይቆጠራል'**
  String get permissionWeightHint;

  /// No description provided for @permissionUsage.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ወር {month} · በዚህ ሩብ ዓመት {quarter}'**
  String permissionUsage(int month, int quarter);

  /// No description provided for @attendanceRate.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት መጠን፦ {rate}%'**
  String attendanceRate(String rate);

  /// No description provided for @tapForLyrics.
  ///
  /// In am, this message translates to:
  /// **'ግጥሙን ለማየት ምስሉን ይንኩ'**
  String get tapForLyrics;

  /// No description provided for @noLyricsYet.
  ///
  /// In am, this message translates to:
  /// **'ለዚህ መዝሙር ግጥም የለም'**
  String get noLyricsYet;

  /// No description provided for @statusPending.
  ///
  /// In am, this message translates to:
  /// **'ማረጋገጫ በመጠበቅ ላይ'**
  String get statusPending;

  /// No description provided for @errAccountPending.
  ///
  /// In am, this message translates to:
  /// **'መለያዎ በአስተዳዳሪ እስኪጸድቅ በመጠበቅ ላይ ነው።'**
  String get errAccountPending;

  /// No description provided for @registerPendingTitle.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባዎ ደርሷል'**
  String get registerPendingTitle;

  /// No description provided for @registerPendingBody.
  ///
  /// In am, this message translates to:
  /// **'አስተዳዳሪ መለያዎን ከመረመሩ በኋላ ያጸድቁታል። ከጸደቀ በኋላ መግባት ይችላሉ።'**
  String get registerPendingBody;

  /// No description provided for @profileLockedNote.
  ///
  /// In am, this message translates to:
  /// **'የመገለጫ መረጃ መቀየር የሚችሉት አስተዳዳሪዎች ብቻ ናቸው። እባክዎ አስተዳዳሪን ያነጋግሩ።'**
  String get profileLockedNote;

  /// No description provided for @errProfileLocked.
  ///
  /// In am, this message translates to:
  /// **'የመገለጫ ለውጥ የሚደረገው በአስተዳዳሪዎች ነው።'**
  String get errProfileLocked;

  /// No description provided for @myProfile.
  ///
  /// In am, this message translates to:
  /// **'መገለጫዬ'**
  String get myProfile;

  /// No description provided for @todayStudy.
  ///
  /// In am, this message translates to:
  /// **'ዛሬ የሚጠኑ'**
  String get todayStudy;

  /// No description provided for @markToday.
  ///
  /// In am, this message translates to:
  /// **'ዛሬ በ«ዛሬ የሚጠኑ» አሳይ'**
  String get markToday;

  /// No description provided for @programKind.
  ///
  /// In am, this message translates to:
  /// **'የፕሮግራም ዓይነት'**
  String get programKind;

  /// No description provided for @programGeneral.
  ///
  /// In am, this message translates to:
  /// **'አጠቃላይ — ሁሉም ይገኛሉ'**
  String get programGeneral;

  /// No description provided for @programSpecial.
  ///
  /// In am, this message translates to:
  /// **'ልዩ ዝግጅት — የተጋበዙ ብቻ'**
  String get programSpecial;

  /// No description provided for @eventType.
  ///
  /// In am, this message translates to:
  /// **'የዝግጅቱ ዓይነት'**
  String get eventType;

  /// No description provided for @eventWedding.
  ///
  /// In am, this message translates to:
  /// **'ሠርግ'**
  String get eventWedding;

  /// No description provided for @eventHoliday.
  ///
  /// In am, this message translates to:
  /// **'በዓል'**
  String get eventHoliday;

  /// No description provided for @eventMemorial.
  ///
  /// In am, this message translates to:
  /// **'መታሰቢያ'**
  String get eventMemorial;

  /// No description provided for @eventCelebration.
  ///
  /// In am, this message translates to:
  /// **'ክብረ በዓል'**
  String get eventCelebration;

  /// No description provided for @eventOther.
  ///
  /// In am, this message translates to:
  /// **'ሌላ'**
  String get eventOther;

  /// No description provided for @specialInviteHint.
  ///
  /// In am, this message translates to:
  /// **'ካስቀመጡ በኋላ ከ«ተሳታፊዎች» ሰዎችን ይጋብዙ — ዝግጅቱን የሚያዩት እነሱ ብቻ ናቸው።'**
  String get specialInviteHint;

  /// No description provided for @checkFields.
  ///
  /// In am, this message translates to:
  /// **'እባክዎ የተመለከቱትን መስኮች ያስተካክሉ'**
  String get checkFields;

  /// No description provided for @audioOnPhone.
  ///
  /// In am, this message translates to:
  /// **'በስልኩ ላይ ያሉ ድምጾች'**
  String get audioOnPhone;

  /// No description provided for @browseFiles.
  ///
  /// In am, this message translates to:
  /// **'ፋይሎችን አስስ'**
  String get browseFiles;

  /// No description provided for @audioPermissionNeeded.
  ///
  /// In am, this message translates to:
  /// **'ቅጂ ለመምረጥ የድምጽ ፋይሎችን እንዲደርስ ይፍቀዱ።'**
  String get audioPermissionNeeded;

  /// No description provided for @allowAccess.
  ///
  /// In am, this message translates to:
  /// **'ፍቀድ'**
  String get allowAccess;

  /// No description provided for @openSettings.
  ///
  /// In am, this message translates to:
  /// **'ቅንብሮችን ክፈት'**
  String get openSettings;

  /// No description provided for @noAudioFiles.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ስልክ ላይ ምንም የድምጽ ፋይል አልተገኘም'**
  String get noAudioFiles;

  /// No description provided for @searchAudio.
  ///
  /// In am, this message translates to:
  /// **'ቅጂዎችን ፈልግ'**
  String get searchAudio;

  /// No description provided for @currentRecording.
  ///
  /// In am, this message translates to:
  /// **'አሁን ያለው ቅጂ'**
  String get currentRecording;

  /// No description provided for @noRecordingYet.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን ቅጂ አልተያያዘም'**
  String get noRecordingYet;

  /// No description provided for @savedForUpload.
  ///
  /// In am, this message translates to:
  /// **'ቅጂውን ለማያያዝ መዝሙሩ ተቀምጧል'**
  String get savedForUpload;

  /// No description provided for @lyricsSavedOffline.
  ///
  /// In am, this message translates to:
  /// **'ግጥሞች ያለ ኢንተርኔት እንዲሰሩ በራስ-ሰር ይቀመጣሉ'**
  String get lyricsSavedOffline;

  /// No description provided for @programAlarm30.
  ///
  /// In am, this message translates to:
  /// **'ከመጀመሩ 30 ደቂቃ በፊት ማንቂያ ይደርስዎታል'**
  String get programAlarm30;

  /// No description provided for @programSoonTitle.
  ///
  /// In am, this message translates to:
  /// **'በ30 ደቂቃ ይጀምራል'**
  String get programSoonTitle;

  /// No description provided for @entityMezmur.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር'**
  String get entityMezmur;

  /// No description provided for @entityProgram.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራም'**
  String get entityProgram;

  /// No description provided for @entityCategory.
  ///
  /// In am, this message translates to:
  /// **'ምድብ'**
  String get entityCategory;

  /// No description provided for @searchedFor.
  ///
  /// In am, this message translates to:
  /// **'«{q}» ተፈልጓል · {n} ውጤት'**
  String searchedFor(String q, int n);

  /// No description provided for @activityDetails.
  ///
  /// In am, this message translates to:
  /// **'ዝርዝር'**
  String get activityDetails;

  /// No description provided for @closePlayer.
  ///
  /// In am, this message translates to:
  /// **'ማጫወቻውን ዝጋ'**
  String get closePlayer;

  /// No description provided for @relatedMezmurs.
  ///
  /// In am, this message translates to:
  /// **'ተዛማጅ መዝሙሮች'**
  String get relatedMezmurs;

  /// No description provided for @adminAlerts.
  ///
  /// In am, this message translates to:
  /// **'ትኩረት የሚሹ'**
  String get adminAlerts;

  /// No description provided for @permissionAsked.
  ///
  /// In am, this message translates to:
  /// **'{name} ከ«{title}» ለመቅረት ፈቃድ ጠይቀዋል'**
  String permissionAsked(String name, String title);

  /// No description provided for @pendingCount.
  ///
  /// In am, this message translates to:
  /// **'{n} በመጠበቅ ላይ'**
  String pendingCount(int n);

  /// No description provided for @noAdminAlerts.
  ///
  /// In am, this message translates to:
  /// **'የሚጠብቅዎት ነገር የለም'**
  String get noAdminAlerts;

  /// No description provided for @editMode.
  ///
  /// In am, this message translates to:
  /// **'የማስተካከያ ሁነታ'**
  String get editMode;

  /// No description provided for @editModeOn.
  ///
  /// In am, this message translates to:
  /// **'የማስተካከያ ሁነታ፦ ለማስተካከል ✎ ፣ ለመጨመር + ይንኩ'**
  String get editModeOn;

  /// No description provided for @addNew.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ጨምር'**
  String get addNew;

  /// No description provided for @bulkImport.
  ///
  /// In am, this message translates to:
  /// **'በጅምላ ማስገቢያ'**
  String get bulkImport;

  /// No description provided for @importMezmurs.
  ///
  /// In am, this message translates to:
  /// **'መዝሙሮች (ግጥም)'**
  String get importMezmurs;

  /// No description provided for @importFormat.
  ///
  /// In am, this message translates to:
  /// **'የፋይል ቅርጸት'**
  String get importFormat;

  /// No description provided for @importMezmursHelp.
  ///
  /// In am, this message translates to:
  /// **'UTF-8 .txt ፋይል። እያንዳንዱ መዝሙር በራሱ ክፍል፤ ክፍሎችን === ባለው መስመር ይለዩ።\nእያንዳንዱ ክፍል በርዕስ መስመሮች ይጀምራል፣ ከዚያ ባዶ መስመር፣ ከዚያ ግጥሙ፦\n  Title: … (ግዴታ)\n  Category: ወላጅ > ንዑስ (አማራጭ፣ ያለ ምድብ መሆን አለበት)\n  Tags: ሀ, ለ (አማራጭ)\n  Status: published ወይም draft (ካልተጻፈ draft)\n  YouTube: https://youtu.be/… (አማራጭ)'**
  String get importMezmursHelp;

  /// No description provided for @importCategoriesHelp.
  ///
  /// In am, this message translates to:
  /// **'UTF-8 .csv ፋይል ከዚህ ርዕስ ጋር፦ name,parent,description,order,active\nparent ያለ ምድብ ወይም ከላይ ያለ ረድፍ ስም (ወይም «ወላጅ > ንዑስ») ነው፤ ለዋና ምድብ ባዶ ይተዉት።'**
  String get importCategoriesHelp;

  /// No description provided for @importUsersHelp.
  ///
  /// In am, this message translates to:
  /// **'UTF-8 .csv ፋይል ከዚህ ርዕስ ጋር፦ full_name,phone,email,pin\nemail እና pin ባዶ ሊሆኑ ይችላሉ፤ pin ከ4 እስከ 6 ቁጥሮች ነው። ከሌለ ጊዜያዊ ፒን ተፈጥሮ ከማስገባቱ በኋላ ይታያል፤ ተጠቃሚው በመጀመሪያ ሲገባ የራሱን ማዘጋጀት አለበት።'**
  String get importUsersHelp;

  /// No description provided for @shareTemplate.
  ///
  /// In am, this message translates to:
  /// **'ናሙናውን አጋራ'**
  String get shareTemplate;

  /// No description provided for @chooseFile.
  ///
  /// In am, this message translates to:
  /// **'ፋይል ምረጥ'**
  String get chooseFile;

  /// No description provided for @checkFile.
  ///
  /// In am, this message translates to:
  /// **'ፋይሉን አረጋግጥ'**
  String get checkFile;

  /// No description provided for @importNow.
  ///
  /// In am, this message translates to:
  /// **'{n} አስገባ'**
  String importNow(int n);

  /// No description provided for @importResult.
  ///
  /// In am, this message translates to:
  /// **'{ok} ዝግጁ · {skipped} ቀድሞ ያሉ · {failed} ስህተት ያለባቸው'**
  String importResult(int ok, int skipped, int failed);

  /// No description provided for @importDone.
  ///
  /// In am, this message translates to:
  /// **'{n} ገብተዋል'**
  String importDone(int n);

  /// No description provided for @lineN.
  ///
  /// In am, this message translates to:
  /// **'መስመር {n}'**
  String lineN(int n);

  /// No description provided for @tempPasswordsNote.
  ///
  /// In am, this message translates to:
  /// **'ለእያንዳንዱ ተጠቃሚ ጊዜያዊ ፒኑን ይስጡ — በመጀመሪያ ሲገቡ የራሳቸውን ማዘጋጀት አለባቸው።'**
  String get tempPasswordsNote;

  /// No description provided for @attachments.
  ///
  /// In am, this message translates to:
  /// **'ፋይሎችና አገናኞች'**
  String get attachments;

  /// No description provided for @addFile.
  ///
  /// In am, this message translates to:
  /// **'ፋይል ጨምር (PDF / ምስል)'**
  String get addFile;

  /// No description provided for @addLink.
  ///
  /// In am, this message translates to:
  /// **'አገናኝ ጨምር'**
  String get addLink;

  /// No description provided for @linkUrl.
  ///
  /// In am, this message translates to:
  /// **'አገናኝ (https://…)'**
  String get linkUrl;

  /// No description provided for @vInvalidUrl.
  ///
  /// In am, this message translates to:
  /// **'በ https:// የሚጀምር አገናኝ ያስገቡ'**
  String get vInvalidUrl;

  /// No description provided for @draftRestored.
  ///
  /// In am, this message translates to:
  /// **'ያልተቀመጡ ለውጦችዎ ተመልሰዋል'**
  String get draftRestored;

  /// No description provided for @discardDraft.
  ///
  /// In am, this message translates to:
  /// **'ተው'**
  String get discardDraft;

  /// No description provided for @savedAsDraft.
  ///
  /// In am, this message translates to:
  /// **'እንደ ረቂቅ ተቀምጧል'**
  String get savedAsDraft;

  /// No description provided for @draftAutosave.
  ///
  /// In am, this message translates to:
  /// **'Save እስኪጫኑ ድረስ ለውጦች እንደ ረቂቅ ይቀመጣሉ'**
  String get draftAutosave;

  /// No description provided for @shareLinkNote.
  ///
  /// In am, this message translates to:
  /// **'ይህንን ገጽ በመተግበሪያው ይከፍታል'**
  String get shareLinkNote;

  /// No description provided for @todayDate.
  ///
  /// In am, this message translates to:
  /// **'ዛሬ'**
  String get todayDate;

  /// No description provided for @hubEducation.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት'**
  String get hubEducation;

  /// No description provided for @hubMezmur.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር'**
  String get hubMezmur;

  /// No description provided for @hubAboutMe.
  ///
  /// In am, this message translates to:
  /// **'ስለ እኔ'**
  String get hubAboutMe;

  /// No description provided for @hubEducationSub.
  ///
  /// In am, this message translates to:
  /// **'ክፍሎች፣ የጊዜ ሰሌዳ፣ መገኘት፣ የቤት ሥራና ውጤት'**
  String get hubEducationSub;

  /// No description provided for @hubMezmurSub.
  ///
  /// In am, this message translates to:
  /// **'መዝሙራት፣ ፕሮግራሞች፣ ቤተ መጻሕፍትና ማሳወቂያዎች'**
  String get hubMezmurSub;

  /// No description provided for @hubAboutMeSub.
  ///
  /// In am, this message translates to:
  /// **'መታወቂያዬ፣ የሥራ ክፍሎቼና ወርሃዊ ክፍያዬ'**
  String get hubAboutMeSub;

  /// No description provided for @hubHome.
  ///
  /// In am, this message translates to:
  /// **'መነሻ'**
  String get hubHome;

  /// No description provided for @hubGreeting.
  ///
  /// In am, this message translates to:
  /// **'ሰላም፣ {name}'**
  String hubGreeting(String name);

  /// No description provided for @myClasses.
  ///
  /// In am, this message translates to:
  /// **'ክፍሎቼ'**
  String get myClasses;

  /// No description provided for @myDepartments.
  ///
  /// In am, this message translates to:
  /// **'የሥራ ክፍሎቼ'**
  String get myDepartments;

  /// No description provided for @noDepartments.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን በየትኛውም የሥራ ክፍል አልተመደቡም'**
  String get noDepartments;

  /// No description provided for @departmentLead.
  ///
  /// In am, this message translates to:
  /// **'የክፍሉ መሪ'**
  String get departmentLead;

  /// No description provided for @memberQrHint.
  ///
  /// In am, this message translates to:
  /// **'ይህንን ኮድ ለመገኘት፣ ለመታወቂያና ለውሰት ያሳዩ'**
  String get memberQrHint;

  /// No description provided for @programRegular.
  ///
  /// In am, this message translates to:
  /// **'መደበኛ'**
  String get programRegular;

  /// No description provided for @programDistance.
  ///
  /// In am, this message translates to:
  /// **'ርቀት'**
  String get programDistance;

  /// No description provided for @scanQr.
  ///
  /// In am, this message translates to:
  /// **'QR ኮድ ይቃኙ'**
  String get scanQr;

  /// No description provided for @scanQrHint.
  ///
  /// In am, this message translates to:
  /// **'ካሜራውን ወደ አባሉ QR ኮድ ያመልክቱ'**
  String get scanQrHint;

  /// No description provided for @flashlight.
  ///
  /// In am, this message translates to:
  /// **'ባትሪ'**
  String get flashlight;

  /// No description provided for @cameraUnavailable.
  ///
  /// In am, this message translates to:
  /// **'ካሜራው አልተገኘም። በስልኩ ቅንብሮች ለመተግበሪያው ካሜራ ይፍቀዱ።'**
  String get cameraUnavailable;

  /// No description provided for @scanMember.
  ///
  /// In am, this message translates to:
  /// **'አባል ይቃኙ'**
  String get scanMember;

  /// No description provided for @monthlyPayments.
  ///
  /// In am, this message translates to:
  /// **'ወርሃዊ መዋጮ'**
  String get monthlyPayments;

  /// No description provided for @paymentsAllPaid.
  ///
  /// In am, this message translates to:
  /// **'ሁሉም ወራት ተከፍለዋል'**
  String get paymentsAllPaid;

  /// No description provided for @paymentsUnpaid.
  ///
  /// In am, this message translates to:
  /// **'{n} ያልተከፈለ ወር'**
  String paymentsUnpaid(int n);

  /// No description provided for @paidMonths.
  ///
  /// In am, this message translates to:
  /// **'{n} ተከፍሏል'**
  String paidMonths(int n);

  /// No description provided for @monthlyAmount.
  ///
  /// In am, this message translates to:
  /// **'ወርሃዊ መጠን፦ {amount}'**
  String monthlyAmount(String amount);

  /// No description provided for @totalPaid.
  ///
  /// In am, this message translates to:
  /// **'በአጠቃላይ የተከፈለ'**
  String get totalPaid;

  /// No description provided for @noPayments.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን ክፍያ የለም'**
  String get noPayments;

  /// No description provided for @paid.
  ///
  /// In am, this message translates to:
  /// **'ተከፍሏል'**
  String get paid;

  /// No description provided for @notPaid.
  ///
  /// In am, this message translates to:
  /// **'አልተከፈለም'**
  String get notPaid;

  /// No description provided for @methodCash.
  ///
  /// In am, this message translates to:
  /// **'በጥሬ ገንዘብ'**
  String get methodCash;

  /// No description provided for @methodBank.
  ///
  /// In am, this message translates to:
  /// **'በባንክ'**
  String get methodBank;

  /// No description provided for @methodTelebirr.
  ///
  /// In am, this message translates to:
  /// **'ቴሌብር'**
  String get methodTelebirr;

  /// No description provided for @methodOther.
  ///
  /// In am, this message translates to:
  /// **'ሌላ'**
  String get methodOther;

  /// No description provided for @amount.
  ///
  /// In am, this message translates to:
  /// **'መጠን'**
  String get amount;

  /// No description provided for @paymentMethod.
  ///
  /// In am, this message translates to:
  /// **'የክፍያ ዘዴ'**
  String get paymentMethod;

  /// No description provided for @paymentReference.
  ///
  /// In am, this message translates to:
  /// **'ማጣቀሻ / የግብይት ቁጥር'**
  String get paymentReference;

  /// No description provided for @recordPayment.
  ///
  /// In am, this message translates to:
  /// **'መዝግብ'**
  String get recordPayment;

  /// No description provided for @attachReceipt.
  ///
  /// In am, this message translates to:
  /// **'የደረሰኝ ፎቶ አያይዝ'**
  String get attachReceipt;

  /// No description provided for @attachReceiptQ.
  ///
  /// In am, this message translates to:
  /// **'የደረሰኝ ፎቶ ይያያዝ?'**
  String get attachReceiptQ;

  /// No description provided for @viewReceipt.
  ///
  /// In am, this message translates to:
  /// **'ደረሰኙን ይመልከቱ'**
  String get viewReceipt;

  /// No description provided for @deletePayment.
  ///
  /// In am, this message translates to:
  /// **'ክፍያውን ሰርዝ'**
  String get deletePayment;

  /// No description provided for @paymentPolicy.
  ///
  /// In am, this message translates to:
  /// **'የክፍያ ቅንብሮች'**
  String get paymentPolicy;

  /// No description provided for @monthlyAmountLabel.
  ///
  /// In am, this message translates to:
  /// **'ወርሃዊ መጠን'**
  String get monthlyAmountLabel;

  /// No description provided for @currency.
  ///
  /// In am, this message translates to:
  /// **'ገንዘብ'**
  String get currency;

  /// No description provided for @paymentsStartFrom.
  ///
  /// In am, this message translates to:
  /// **'ክፍያ የሚጀምረው ከ'**
  String get paymentsStartFrom;

  /// No description provided for @fromSignUp.
  ///
  /// In am, this message translates to:
  /// **'ከተመዘገቡበት ወር'**
  String get fromSignUp;

  /// No description provided for @useSelectedMonth.
  ///
  /// In am, this message translates to:
  /// **'የሚታየውን ወር'**
  String get useSelectedMonth;

  /// No description provided for @paymentsSummary.
  ///
  /// In am, this message translates to:
  /// **'{n} ከፍለዋል · {total}'**
  String paymentsSummary(int n, String total);

  /// No description provided for @departments.
  ///
  /// In am, this message translates to:
  /// **'የሥራ ክፍሎች'**
  String get departments;

  /// No description provided for @newDepartment.
  ///
  /// In am, this message translates to:
  /// **'አዲስ የሥራ ክፍል'**
  String get newDepartment;

  /// No description provided for @departmentKind.
  ///
  /// In am, this message translates to:
  /// **'ዘርፍ'**
  String get departmentKind;

  /// No description provided for @departmentLeadHint.
  ///
  /// In am, this message translates to:
  /// **'መሪ (አስተዳዳሪ)'**
  String get departmentLeadHint;

  /// No description provided for @deptHr.
  ///
  /// In am, this message translates to:
  /// **'የሰው ሀብት'**
  String get deptHr;

  /// No description provided for @deptPayments.
  ///
  /// In am, this message translates to:
  /// **'ክፍያ'**
  String get deptPayments;

  /// No description provided for @memberCount.
  ///
  /// In am, this message translates to:
  /// **'{n} አባላት'**
  String memberCount(int n);

  /// No description provided for @assignMember.
  ///
  /// In am, this message translates to:
  /// **'አባል መድብ'**
  String get assignMember;

  /// No description provided for @roleLabel.
  ///
  /// In am, this message translates to:
  /// **'የሥራ ድርሻ'**
  String get roleLabel;

  /// No description provided for @noRoleLabel.
  ///
  /// In am, this message translates to:
  /// **'ድርሻ አልተሰጠም'**
  String get noRoleLabel;

  /// No description provided for @noMembers.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን አባል የለም'**
  String get noMembers;

  /// No description provided for @removeMemberConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህ አባል ከሥራ ክፍሉ ይወገድ?'**
  String get removeMemberConfirm;

  /// No description provided for @eduManage.
  ///
  /// In am, this message translates to:
  /// **'ክፍሎችን ያስተዳድሩ'**
  String get eduManage;

  /// No description provided for @eduRegister.
  ///
  /// In am, this message translates to:
  /// **'የክፍል ምዝገባ'**
  String get eduRegister;

  /// No description provided for @eduOpenCount.
  ///
  /// In am, this message translates to:
  /// **'{n} ክፍል(ሎች) ለምዝገባ ክፍት ናቸው'**
  String eduOpenCount(int n);

  /// No description provided for @eduNoOpen.
  ///
  /// In am, this message translates to:
  /// **'አሁን ለምዝገባ ክፍት የሆነ ክፍል የለም'**
  String get eduNoOpen;

  /// No description provided for @eduUpcoming.
  ///
  /// In am, this message translates to:
  /// **'የሚቀጥሉ ክፍለ ጊዜያት'**
  String get eduUpcoming;

  /// No description provided for @eduNotEnrolled.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን በየትኛውም ክፍል አልተመዘገቡም'**
  String get eduNotEnrolled;

  /// No description provided for @eduTeaching.
  ///
  /// In am, this message translates to:
  /// **'የማስተምራቸው'**
  String get eduTeaching;

  /// No description provided for @eduStudentCount.
  ///
  /// In am, this message translates to:
  /// **'{n} ተማሪዎች'**
  String eduStudentCount(int n);

  /// No description provided for @eduTakeAttendance.
  ///
  /// In am, this message translates to:
  /// **'መገኘት መዝግብ'**
  String get eduTakeAttendance;

  /// No description provided for @eduBorrowings.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ቤተ መጻሕፍት'**
  String get eduBorrowings;

  /// No description provided for @eduBorrowingsSub.
  ///
  /// In am, this message translates to:
  /// **'ለትምህርት የተዋሷቸው መጻሕፍትና ቁሳቁሶች'**
  String get eduBorrowingsSub;

  /// No description provided for @eduChooseProgram.
  ///
  /// In am, this message translates to:
  /// **'መርሐ ግብርዎን ይምረጡ'**
  String get eduChooseProgram;

  /// No description provided for @eduEnrolled.
  ///
  /// In am, this message translates to:
  /// **'ተመዝግበዋል'**
  String get eduEnrolled;

  /// No description provided for @eduEnroll.
  ///
  /// In am, this message translates to:
  /// **'ተመዝገብ'**
  String get eduEnroll;

  /// No description provided for @eduSeats.
  ///
  /// In am, this message translates to:
  /// **'{taken} / {total} ቦታዎች'**
  String eduSeats(int taken, int total);

  /// No description provided for @eduOpensOn.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባ የሚከፈተው {date}'**
  String eduOpensOn(String date);

  /// No description provided for @eduClosesOn.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባ የሚዘጋው {date}'**
  String eduClosesOn(String date);

  /// No description provided for @eduOpenNow.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባ ክፍት ነው'**
  String get eduOpenNow;

  /// No description provided for @eduYouAreEnrolled.
  ///
  /// In am, this message translates to:
  /// **'ተመዝግበዋል · {program}'**
  String eduYouAreEnrolled(String program);

  /// No description provided for @eduWithdraw.
  ///
  /// In am, this message translates to:
  /// **'ከክፍሉ ውጣ'**
  String get eduWithdraw;

  /// No description provided for @eduWithdrawConfirm.
  ///
  /// In am, this message translates to:
  /// **'ከዚህ ክፍል ይውጡ?'**
  String get eduWithdrawConfirm;

  /// No description provided for @eduDetails.
  ///
  /// In am, this message translates to:
  /// **'ዝርዝር'**
  String get eduDetails;

  /// No description provided for @eduAssignments.
  ///
  /// In am, this message translates to:
  /// **'የቤት ሥራ'**
  String get eduAssignments;

  /// No description provided for @eduResults.
  ///
  /// In am, this message translates to:
  /// **'ውጤት'**
  String get eduResults;

  /// No description provided for @eduSchedule.
  ///
  /// In am, this message translates to:
  /// **'ሳምንታዊ የጊዜ ሰሌዳ'**
  String get eduSchedule;

  /// No description provided for @eduNoSchedule.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን የጊዜ ሰሌዳ የለም'**
  String get eduNoSchedule;

  /// No description provided for @eduCourses.
  ///
  /// In am, this message translates to:
  /// **'ኮርሶች'**
  String get eduCourses;

  /// No description provided for @eduNoTeacher.
  ///
  /// In am, this message translates to:
  /// **'መምህር አልተመደበም'**
  String get eduNoTeacher;

  /// No description provided for @eduNoAttendanceYet.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን መገኘት አልተመዘገበም'**
  String get eduNoAttendanceYet;

  /// No description provided for @eduNoAssignments.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን የቤት ሥራ የለም'**
  String get eduNoAssignments;

  /// No description provided for @eduGroupWork.
  ///
  /// In am, this message translates to:
  /// **'የቡድን ሥራ'**
  String get eduGroupWork;

  /// No description provided for @eduDue.
  ///
  /// In am, this message translates to:
  /// **'የማስረከቢያ ቀን {date}'**
  String eduDue(String date);

  /// No description provided for @eduOpenAttachment.
  ///
  /// In am, this message translates to:
  /// **'አባሪውን ክፈት'**
  String get eduOpenAttachment;

  /// No description provided for @eduScore.
  ///
  /// In am, this message translates to:
  /// **'{score} / {max}'**
  String eduScore(String score, String max);

  /// No description provided for @eduSubmitted.
  ///
  /// In am, this message translates to:
  /// **'ተልኳል'**
  String get eduSubmitted;

  /// No description provided for @eduResubmit.
  ///
  /// In am, this message translates to:
  /// **'እንደገና ላክ'**
  String get eduResubmit;

  /// No description provided for @eduSubmit.
  ///
  /// In am, this message translates to:
  /// **'አስረክብ'**
  String get eduSubmit;

  /// No description provided for @eduAnswer.
  ///
  /// In am, this message translates to:
  /// **'መልስዎ'**
  String get eduAnswer;

  /// No description provided for @eduAttachFile.
  ///
  /// In am, this message translates to:
  /// **'ፋይል አያይዝ (PDF፣ ፎቶ፣ Word…)'**
  String get eduAttachFile;

  /// No description provided for @eduNoResults.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን ውጤት የለም'**
  String get eduNoResults;

  /// No description provided for @notMarked.
  ///
  /// In am, this message translates to:
  /// **'አልተመዘገበም'**
  String get notMarked;

  /// No description provided for @eduMarkedPresent.
  ///
  /// In am, this message translates to:
  /// **'{name} — ተገኝቷል ✓'**
  String eduMarkedPresent(String name);

  /// No description provided for @eduNoStudents.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን ተማሪ የለም'**
  String get eduNoStudents;

  /// No description provided for @eduMarkedCount.
  ///
  /// In am, this message translates to:
  /// **'ከ{total} {marked} ተመዝግበዋል'**
  String eduMarkedCount(int marked, int total);

  /// No description provided for @eduStudents.
  ///
  /// In am, this message translates to:
  /// **'ተማሪዎች'**
  String get eduStudents;

  /// No description provided for @eduAssessments.
  ///
  /// In am, this message translates to:
  /// **'የውጤት መግቢያ'**
  String get eduAssessments;

  /// No description provided for @eduGroupMembers.
  ///
  /// In am, this message translates to:
  /// **'የቡድኑ አባላት'**
  String get eduGroupMembers;

  /// No description provided for @eduGroups.
  ///
  /// In am, this message translates to:
  /// **'ቡድኖች'**
  String get eduGroups;

  /// No description provided for @eduNewGroup.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ቡድን'**
  String get eduNewGroup;

  /// No description provided for @eduNoGroups.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን ቡድን የለም'**
  String get eduNoGroups;

  /// No description provided for @eduNewAssignment.
  ///
  /// In am, this message translates to:
  /// **'አዲስ የቤት ሥራ'**
  String get eduNewAssignment;

  /// No description provided for @eduSubmissionCount.
  ///
  /// In am, this message translates to:
  /// **'{n} አስረክበዋል'**
  String eduSubmissionCount(int n);

  /// No description provided for @eduInstructions.
  ///
  /// In am, this message translates to:
  /// **'መመሪያ'**
  String get eduInstructions;

  /// No description provided for @eduDueDate.
  ///
  /// In am, this message translates to:
  /// **'የማስረከቢያ ቀን'**
  String get eduDueDate;

  /// No description provided for @eduMaxScore.
  ///
  /// In am, this message translates to:
  /// **'ከ'**
  String get eduMaxScore;

  /// No description provided for @eduScoreLabel.
  ///
  /// In am, this message translates to:
  /// **'ውጤት'**
  String get eduScoreLabel;

  /// No description provided for @eduFeedback.
  ///
  /// In am, this message translates to:
  /// **'አስተያየት'**
  String get eduFeedback;

  /// No description provided for @eduSubmissions.
  ///
  /// In am, this message translates to:
  /// **'የተላኩ ሥራዎች'**
  String get eduSubmissions;

  /// No description provided for @eduNoSubmissions.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን የተላከ ሥራ የለም'**
  String get eduNoSubmissions;

  /// No description provided for @eduGrade.
  ///
  /// In am, this message translates to:
  /// **'አርም'**
  String get eduGrade;

  /// No description provided for @eduNewAssessment.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ምዘና'**
  String get eduNewAssessment;

  /// No description provided for @eduAssessmentHint.
  ///
  /// In am, this message translates to:
  /// **'ለምሳሌ የአጋማሽ ፈተና፣ ፈተና 1'**
  String get eduAssessmentHint;

  /// No description provided for @eduWeight.
  ///
  /// In am, this message translates to:
  /// **'ክብደት %'**
  String get eduWeight;

  /// No description provided for @eduNoAssessments.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን ምዘና የለም'**
  String get eduNoAssessments;

  /// No description provided for @eduNewClass.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ክፍል'**
  String get eduNewClass;

  /// No description provided for @eduNoClasses.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን ክፍል የለም'**
  String get eduNoClasses;

  /// No description provided for @eduRegOpen.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባ ክፍት'**
  String get eduRegOpen;

  /// No description provided for @eduRegClosed.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባ ተዘግቷል'**
  String get eduRegClosed;

  /// No description provided for @eduNewCourse.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ኮርስ'**
  String get eduNewCourse;

  /// No description provided for @eduTeacher.
  ///
  /// In am, this message translates to:
  /// **'መምህር'**
  String get eduTeacher;

  /// No description provided for @eduAddSession.
  ///
  /// In am, this message translates to:
  /// **'ክፍለ ጊዜ ጨምር'**
  String get eduAddSession;

  /// No description provided for @eduWeekday.
  ///
  /// In am, this message translates to:
  /// **'ቀን'**
  String get eduWeekday;

  /// No description provided for @eduTerm.
  ///
  /// In am, this message translates to:
  /// **'ክፍለ ጊዜ'**
  String get eduTerm;

  /// No description provided for @eduRegOpens.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባ የሚከፈትበት'**
  String get eduRegOpens;

  /// No description provided for @eduRegCloses.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባ የሚዘጋበት'**
  String get eduRegCloses;

  /// No description provided for @eduSaveFirst.
  ///
  /// In am, this message translates to:
  /// **'ኮርሶችን፣ የጊዜ ሰሌዳንና መገኘት መዝጋቢዎችን ለመጨመር ክፍሉን መጀመሪያ ያስቀምጡ'**
  String get eduSaveFirst;

  /// No description provided for @eduNoCourses.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን ኮርስ የለም'**
  String get eduNoCourses;

  /// No description provided for @eduAttendanceTakers.
  ///
  /// In am, this message translates to:
  /// **'መገኘት መዝጋቢዎች'**
  String get eduAttendanceTakers;

  /// No description provided for @eduNoTakers.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን የተመደበ የለም'**
  String get eduNoTakers;

  /// No description provided for @eduViewStudents.
  ///
  /// In am, this message translates to:
  /// **'ተማሪዎችን ይመልከቱ'**
  String get eduViewStudents;

  /// No description provided for @eduRemoveStudent.
  ///
  /// In am, this message translates to:
  /// **'ከክፍሉ አስወጣ'**
  String get eduRemoveStudent;

  /// No description provided for @eduRemoveStudentConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህ ተማሪ ከክፍሉ ይውጣ?'**
  String get eduRemoveStudentConfirm;

  /// No description provided for @perm_departments_manage.
  ///
  /// In am, this message translates to:
  /// **'የሥራ ክፍሎችንና መሪዎቻቸውን ማስተዳደር'**
  String get perm_departments_manage;

  /// No description provided for @perm_hr_manage.
  ///
  /// In am, this message translates to:
  /// **'አባላትን ለሥራ ክፍሎች መመደብ (የሰው ሀብት)'**
  String get perm_hr_manage;

  /// No description provided for @perm_payments_manage.
  ///
  /// In am, this message translates to:
  /// **'ወርሃዊ ክፍያ መመዝገብ'**
  String get perm_payments_manage;

  /// No description provided for @perm_education_manage.
  ///
  /// In am, this message translates to:
  /// **'ክፍሎችን፣ ኮርሶችንና መምህራንን ማስተዳደር (ሞደሬተር)'**
  String get perm_education_manage;

  /// No description provided for @navMyLibrary.
  ///
  /// In am, this message translates to:
  /// **'የእኔ ስብስብ'**
  String get navMyLibrary;

  /// No description provided for @themeToggle.
  ///
  /// In am, this message translates to:
  /// **'ገጽታ ቀይር (ብርሃን / ጨለማ)'**
  String get themeToggle;

  /// No description provided for @userData.
  ///
  /// In am, this message translates to:
  /// **'የእኔ መረጃ'**
  String get userData;

  /// No description provided for @adminSection.
  ///
  /// In am, this message translates to:
  /// **'አስተዳደር'**
  String get adminSection;

  /// No description provided for @downloadSettings.
  ///
  /// In am, this message translates to:
  /// **'የማውረድ ቅንብሮች'**
  String get downloadSettings;

  /// No description provided for @downloadAudioHint.
  ///
  /// In am, this message translates to:
  /// **'የመዝሙር ድምፅ በራሱ ይወርዳል (በነባሪ በርቷል)። «በWi-Fi ብቻ» ከበራ በሞባይል ዳታ አይወርድም። ያልተሳኩ ማውረዶች በኋላ እንደገና ይሞከራሉ።'**
  String get downloadAudioHint;

  /// No description provided for @calendarUpcoming.
  ///
  /// In am, this message translates to:
  /// **'የሚመጣ'**
  String get calendarUpcoming;

  /// No description provided for @calendarNoProgram.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራም የለም'**
  String get calendarNoProgram;

  /// No description provided for @allCategories.
  ///
  /// In am, this message translates to:
  /// **'ሁሉም'**
  String get allCategories;

  /// No description provided for @previousMonth.
  ///
  /// In am, this message translates to:
  /// **'ያለፈው ወር'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In am, this message translates to:
  /// **'የሚቀጥለው ወር'**
  String get nextMonth;

  /// No description provided for @attendanceStats.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት ስታቲስቲክስ'**
  String get attendanceStats;

  /// No description provided for @totalPrograms.
  ///
  /// In am, this message translates to:
  /// **'ጠቅላላ'**
  String get totalPrograms;

  /// No description provided for @memberIdLabel.
  ///
  /// In am, this message translates to:
  /// **'መ/ሕ/ተማሪ {id}'**
  String memberIdLabel(String id);

  /// No description provided for @tapToShowId.
  ///
  /// In am, this message translates to:
  /// **'መለያ ቁጥሩን ለማየት ይንኩ'**
  String get tapToShowId;

  /// No description provided for @pickFromGallery.
  ///
  /// In am, this message translates to:
  /// **'ከፎቶዎች ምረጥ'**
  String get pickFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In am, this message translates to:
  /// **'ፎቶ አንሳ'**
  String get takePhoto;

  /// No description provided for @photoUpdated.
  ///
  /// In am, this message translates to:
  /// **'ፎቶዎ ተቀይሯል'**
  String get photoUpdated;

  /// No description provided for @choirTitle.
  ///
  /// In am, this message translates to:
  /// **'መዘምራን'**
  String get choirTitle;

  /// No description provided for @choirWerebMezmur.
  ///
  /// In am, this message translates to:
  /// **'ወረብ እና መዝሙር'**
  String get choirWerebMezmur;

  /// No description provided for @choirMezmurOnly.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር ብቻ'**
  String get choirMezmurOnly;

  /// No description provided for @choirEligible.
  ///
  /// In am, this message translates to:
  /// **'ብቁ'**
  String get choirEligible;

  /// No description provided for @choirNotEligible.
  ///
  /// In am, this message translates to:
  /// **'ገና ብቁ አይደሉም'**
  String get choirNotEligible;

  /// No description provided for @choirPassing.
  ///
  /// In am, this message translates to:
  /// **'ማለፊያ ነጥብ፦ {score}'**
  String choirPassing(String score);

  /// No description provided for @choirEducation.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት (መገኘት)'**
  String get choirEducation;

  /// No description provided for @choirMezmurAttendance.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር (መገኘት)'**
  String get choirMezmurAttendance;

  /// No description provided for @choirParticipation.
  ///
  /// In am, this message translates to:
  /// **'ሌሎች ተሳትፎዎች'**
  String get choirParticipation;

  /// No description provided for @choirPayment.
  ///
  /// In am, this message translates to:
  /// **'ወርሃዊ ክፍያ'**
  String get choirPayment;

  /// No description provided for @choirSelectedOn.
  ///
  /// In am, this message translates to:
  /// **'የተመረጡበት ቀን፦ {date}'**
  String choirSelectedOn(String date);

  /// No description provided for @notifGateTitle.
  ///
  /// In am, this message translates to:
  /// **'ማሳወቂያዎችን ይፍቀዱ'**
  String get notifGateTitle;

  /// No description provided for @notifGateBody.
  ///
  /// In am, this message translates to:
  /// **'የፕሮግራም ማስታወሻዎች፣ የመገኘት መረጃ፣ የፈቃድ ምላሾች እና ማስታወቂያዎች የሚደርሱዎት በማሳወቂያ ነው። መተግበሪያውን ለመጠቀም ማሳወቂያዎችን መፍቀድ ግዴታ ነው።'**
  String get notifGateBody;

  /// No description provided for @notifGateAllow.
  ///
  /// In am, this message translates to:
  /// **'ማሳወቂያዎችን ፍቀድ'**
  String get notifGateAllow;

  /// No description provided for @notifGateOpenSettings.
  ///
  /// In am, this message translates to:
  /// **'የስልኩን ቅንብሮች ክፈት'**
  String get notifGateOpenSettings;

  /// No description provided for @programCategory.
  ///
  /// In am, this message translates to:
  /// **'የፕሮግራም ምድብ'**
  String get programCategory;

  /// No description provided for @programCategoryDefault.
  ///
  /// In am, this message translates to:
  /// **'ካልተመረጠ፦ አጠቃላይ'**
  String get programCategoryDefault;

  /// No description provided for @programCategories.
  ///
  /// In am, this message translates to:
  /// **'የፕሮግራም ምድቦች'**
  String get programCategories;

  /// No description provided for @newProgramCategory.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ምድብ'**
  String get newProgramCategory;

  /// No description provided for @editProgramCategory.
  ///
  /// In am, this message translates to:
  /// **'ምድብ አስተካክል'**
  String get editProgramCategory;

  /// No description provided for @categoryNameAm.
  ///
  /// In am, this message translates to:
  /// **'ስም (አማርኛ)'**
  String get categoryNameAm;

  /// No description provided for @categoryNameEn.
  ///
  /// In am, this message translates to:
  /// **'ስም (እንግሊዝኛ)'**
  String get categoryNameEn;

  /// No description provided for @categoryColor.
  ///
  /// In am, this message translates to:
  /// **'ቀለም'**
  String get categoryColor;

  /// No description provided for @deleteCategoryConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህ ምድብ ይሰረዝ? በፕሮግራሞች ላይ ጥቅም ላይ ከዋለ አይሰረዝም፤ ይቦዝናል።'**
  String get deleteCategoryConfirm;

  /// No description provided for @recurrence.
  ///
  /// In am, this message translates to:
  /// **'ድግግሞሽ'**
  String get recurrence;

  /// No description provided for @recurrenceOnce.
  ///
  /// In am, this message translates to:
  /// **'አንድ ቀን'**
  String get recurrenceOnce;

  /// No description provided for @recurrenceWeekly.
  ///
  /// In am, this message translates to:
  /// **'በየሳምንቱ'**
  String get recurrenceWeekly;

  /// No description provided for @recurrenceMonthly.
  ///
  /// In am, this message translates to:
  /// **'በየወሩ'**
  String get recurrenceMonthly;

  /// No description provided for @monthlyRule.
  ///
  /// In am, this message translates to:
  /// **'ወርሃዊ ደንብ'**
  String get monthlyRule;

  /// No description provided for @monthlyRuleDay.
  ///
  /// In am, this message translates to:
  /// **'በየወሩ ተመሳሳይ ቀን (ቀኑ ከሌለ የወሩ መጨረሻ)'**
  String get monthlyRuleDay;

  /// No description provided for @monthlyRuleWeekday.
  ///
  /// In am, this message translates to:
  /// **'በየወሩ ተመሳሳይ ሳምንትና ዕለት (ለምሳሌ 2ኛው እሑድ)'**
  String get monthlyRuleWeekday;

  /// No description provided for @recurrenceUntil.
  ///
  /// In am, this message translates to:
  /// **'እስከ (ካልተሞላ ማብቂያ የለውም)'**
  String get recurrenceUntil;

  /// No description provided for @everyWeekday.
  ///
  /// In am, this message translates to:
  /// **'በየሳምንቱ {weekday}'**
  String everyWeekday(String weekday);

  /// No description provided for @everyNthWeekday.
  ///
  /// In am, this message translates to:
  /// **'በየወሩ {n}ኛው {weekday}'**
  String everyNthWeekday(String n, String weekday);

  /// No description provided for @everyMonthDay.
  ///
  /// In am, this message translates to:
  /// **'በየወሩ በ{day}ኛው ቀን'**
  String everyMonthDay(String day);

  /// No description provided for @untilDate.
  ///
  /// In am, this message translates to:
  /// **'እስከ {date}'**
  String untilDate(String date);

  /// No description provided for @nextOccurrenceLabel.
  ///
  /// In am, this message translates to:
  /// **'ቀጣዩ ቀን'**
  String get nextOccurrenceLabel;

  /// No description provided for @occurrenceDate.
  ///
  /// In am, this message translates to:
  /// **'የፕሮግራሙ ቀን'**
  String get occurrenceDate;

  /// No description provided for @today.
  ///
  /// In am, this message translates to:
  /// **'ዛሬ'**
  String get today;

  /// No description provided for @attendanceCleared.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባው ተሰርዟል'**
  String get attendanceCleared;

  /// No description provided for @attendanceNotOpen.
  ///
  /// In am, this message translates to:
  /// **'መገኘት መመዝገብ የሚቻለው በፕሮግራሙ ቀን ነው።'**
  String get attendanceNotOpen;

  /// No description provided for @attendanceNeedsConnection.
  ///
  /// In am, this message translates to:
  /// **'መገኘት ለመመዝገብ የኢንተርኔት ግንኙነት ያስፈልጋል።'**
  String get attendanceNeedsConnection;

  /// No description provided for @expectedMembers.
  ///
  /// In am, this message translates to:
  /// **'የሚጠበቁ'**
  String get expectedMembers;

  /// No description provided for @choirSelected.
  ///
  /// In am, this message translates to:
  /// **'የተመረጡ'**
  String get choirSelected;

  /// No description provided for @choirRefresh.
  ///
  /// In am, this message translates to:
  /// **'ነጥብ እንደገና አስላ'**
  String get choirRefresh;

  /// No description provided for @choirRefreshed.
  ///
  /// In am, this message translates to:
  /// **'{count} አባላት ተሰልተዋል፤ {newly} አዲስ ብቁ'**
  String choirRefreshed(String count, String newly);

  /// No description provided for @choirPolicy.
  ///
  /// In am, this message translates to:
  /// **'የመዘምራን መስፈርት'**
  String get choirPolicy;

  /// No description provided for @choirWeights.
  ///
  /// In am, this message translates to:
  /// **'የነጥብ ክብደት (ድምሩ 100)'**
  String get choirWeights;

  /// No description provided for @choirWeightsTotal.
  ///
  /// In am, this message translates to:
  /// **'ድምር፦ {total} / 100'**
  String choirWeightsTotal(String total);

  /// No description provided for @choirWeightsMust100.
  ///
  /// In am, this message translates to:
  /// **'የክብደቶቹ ድምር 100 መሆን አለበት'**
  String get choirWeightsMust100;

  /// No description provided for @choirPassingScore.
  ///
  /// In am, this message translates to:
  /// **'ማለፊያ ነጥብ (0–100)'**
  String get choirPassingScore;

  /// No description provided for @choirWindow.
  ///
  /// In am, this message translates to:
  /// **'የግምገማ ጊዜ (ወራት)'**
  String get choirWindow;

  /// No description provided for @choirEducationCats.
  ///
  /// In am, this message translates to:
  /// **'ለትምህርት የሚቆጠሩ ምድቦች'**
  String get choirEducationCats;

  /// No description provided for @choirMezmurCats.
  ///
  /// In am, this message translates to:
  /// **'ለመዝሙር የሚቆጠሩ ምድቦች'**
  String get choirMezmurCats;

  /// No description provided for @choirNoData.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ጊዜ የሚለካ ነገር የለም'**
  String get choirNoData;

  /// No description provided for @choirSelectAs.
  ///
  /// In am, this message translates to:
  /// **'እንደ «{type}» ምረጥ'**
  String choirSelectAs(String type);

  /// No description provided for @choirRemove.
  ///
  /// In am, this message translates to:
  /// **'ከመዘምራን አስወግድ'**
  String get choirRemove;

  /// No description provided for @choirRemoveConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህ አባል ከመዘምራን ይወገድ?'**
  String get choirRemoveConfirm;

  /// No description provided for @choirNotEligibleHint.
  ///
  /// In am, this message translates to:
  /// **'ማለፊያ ነጥቡ ላይ ያልደረሱ አባላት መመረጥ አይችሉም።'**
  String get choirNotEligibleHint;

  /// No description provided for @choirSeason.
  ///
  /// In am, this message translates to:
  /// **'ወቅት'**
  String get choirSeason;

  /// No description provided for @choirSeasonHint.
  ///
  /// In am, this message translates to:
  /// **'ለምሳሌ፦ ጥምቀት 2019 (አማራጭ)'**
  String get choirSeasonHint;

  /// No description provided for @choirNotComputed.
  ///
  /// In am, this message translates to:
  /// **'ገና አልተሰላም'**
  String get choirNotComputed;

  /// No description provided for @participationAdd.
  ///
  /// In am, this message translates to:
  /// **'ተሳትፎ መዝግብ'**
  String get participationAdd;

  /// No description provided for @participationActivity.
  ///
  /// In am, this message translates to:
  /// **'ተግባር'**
  String get participationActivity;

  /// No description provided for @participationPoints.
  ///
  /// In am, this message translates to:
  /// **'ነጥብ (0–100)'**
  String get participationPoints;

  /// No description provided for @pointsCount.
  ///
  /// In am, this message translates to:
  /// **'{points} ነጥብ'**
  String pointsCount(String points);

  /// No description provided for @paymentMonths.
  ///
  /// In am, this message translates to:
  /// **'የሚሸፍነው የወራት ብዛት'**
  String get paymentMonths;

  /// No description provided for @monthsCount.
  ///
  /// In am, this message translates to:
  /// **'{n} ወር'**
  String monthsCount(String n);

  /// No description provided for @memberTypeLabel.
  ///
  /// In am, this message translates to:
  /// **'የአባል ዓይነት'**
  String get memberTypeLabel;

  /// No description provided for @memberStudent.
  ///
  /// In am, this message translates to:
  /// **'ተማሪ'**
  String get memberStudent;

  /// No description provided for @memberWorker.
  ///
  /// In am, this message translates to:
  /// **'ሠራተኛ'**
  String get memberWorker;

  /// No description provided for @amountAuto.
  ///
  /// In am, this message translates to:
  /// **'ባዶ ከተተወ፦ {amount} (መጠን × ወራት)'**
  String amountAuto(String amount);

  /// No description provided for @coverage.
  ///
  /// In am, this message translates to:
  /// **'{from} – {to}'**
  String coverage(String from, String to);

  /// No description provided for @verifyPayment.
  ///
  /// In am, this message translates to:
  /// **'ክፍያውን አረጋግጥ'**
  String get verifyPayment;

  /// No description provided for @paymentVerified.
  ///
  /// In am, this message translates to:
  /// **'ተረጋግጧል'**
  String get paymentVerified;

  /// No description provided for @paymentRates.
  ///
  /// In am, this message translates to:
  /// **'የክፍያ መጠኖች'**
  String get paymentRates;

  /// No description provided for @addRate.
  ///
  /// In am, this message translates to:
  /// **'አዲስ መጠን'**
  String get addRate;

  /// No description provided for @effectiveFrom.
  ///
  /// In am, this message translates to:
  /// **'ከዚህ ቀን ጀምሮ'**
  String get effectiveFrom;

  /// No description provided for @effectiveFromDate.
  ///
  /// In am, this message translates to:
  /// **'ከ{date} ጀምሮ'**
  String effectiveFromDate(String date);

  /// No description provided for @noRates.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን መጠን አልተወሰነም'**
  String get noRates;

  /// No description provided for @paidUntil.
  ///
  /// In am, this message translates to:
  /// **'እስከ {month} ተከፍሏል'**
  String paidUntil(String month);

  /// No description provided for @savedOffline.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ ተቀምጧል — ኢንተርኔት ሲገኝ ይላካል'**
  String get savedOffline;

  /// No description provided for @attendanceOfflineNote.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ ነዎት፦ ጅማሬ፣ ምዝገባዎችና ፊርማዎች በስልኩ (ተመስጥረው) ተቀምጠው ኢንተርኔት ሲገኝ በራሳቸው ይላካሉ።'**
  String get attendanceOfflineNote;

  /// No description provided for @pendingSync.
  ///
  /// In am, this message translates to:
  /// **'ለመላክ በመጠባበቅ ላይ'**
  String get pendingSync;

  /// No description provided for @borrowingSavedOffline.
  ///
  /// In am, this message translates to:
  /// **'ውሰቱ ከመስመር ውጭ ተመዝግቧል — ኢንተርኔት ሲገኝ ይላካል'**
  String get borrowingSavedOffline;

  /// No description provided for @offlineChangeRejected.
  ///
  /// In am, this message translates to:
  /// **'{what} አልተቀመጠም፦ {error}'**
  String offlineChangeRejected(String what, String error);

  /// No description provided for @syncWhatAttendance.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ የተመዘገበው መገኘት'**
  String get syncWhatAttendance;

  /// No description provided for @syncWhatClassAttendance.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ የተመዘገበው የክፍል መገኘት'**
  String get syncWhatClassAttendance;

  /// No description provided for @syncWhatBorrowing.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ የተመዘገበው ውሰት'**
  String get syncWhatBorrowing;

  /// No description provided for @syncWhatReturn.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ የተመዘገበው መመለስ'**
  String get syncWhatReturn;

  /// No description provided for @syncWhatReminder.
  ///
  /// In am, this message translates to:
  /// **'የማስታወሻ ለውጥ'**
  String get syncWhatReminder;

  /// No description provided for @deptParticipation.
  ///
  /// In am, this message translates to:
  /// **'ተሳትፎ (የክፍሉ ኃላፊ የመዘምራን ተሳትፎ ነጥብ ይመዘግባል)'**
  String get deptParticipation;

  /// No description provided for @formTitle.
  ///
  /// In am, this message translates to:
  /// **'የአባልነት ቅጽ'**
  String get formTitle;

  /// No description provided for @memberAccount.
  ///
  /// In am, this message translates to:
  /// **'መለያ እና ምድብ'**
  String get memberAccount;

  /// No description provided for @mfFullName.
  ///
  /// In am, this message translates to:
  /// **'ሙሉ ስም ከነአያት'**
  String get mfFullName;

  /// No description provided for @phoneMobile.
  ///
  /// In am, this message translates to:
  /// **'ስልክ (ተንቀሳቃሽ)'**
  String get phoneMobile;

  /// No description provided for @phoneHome.
  ///
  /// In am, this message translates to:
  /// **'ስልክ (የቤት)'**
  String get phoneHome;

  /// No description provided for @memberGroup.
  ///
  /// In am, this message translates to:
  /// **'የአባል ምድብ'**
  String get memberGroup;

  /// No description provided for @groupChildren.
  ///
  /// In am, this message translates to:
  /// **'ሕጻናት'**
  String get groupChildren;

  /// No description provided for @groupYouth.
  ///
  /// In am, this message translates to:
  /// **'ወጣቶች እና አዋቂዎች'**
  String get groupYouth;

  /// No description provided for @groupMarried.
  ///
  /// In am, this message translates to:
  /// **'ባለትዳሮች'**
  String get groupMarried;

  /// No description provided for @canLogin.
  ///
  /// In am, this message translates to:
  /// **'ወደ መተግበሪያው መግባት ይችላል'**
  String get canLogin;

  /// No description provided for @canLoginHint.
  ///
  /// In am, this message translates to:
  /// **'ሕጻናት ሲያድጉ አስተዳዳሪ ይፈቅዳል'**
  String get canLoginHint;

  /// No description provided for @cannotLogin.
  ///
  /// In am, this message translates to:
  /// **'መግባት አይችልም'**
  String get cannotLogin;

  /// No description provided for @membershipStatus.
  ///
  /// In am, this message translates to:
  /// **'የአባልነት ሁኔታ'**
  String get membershipStatus;

  /// No description provided for @stActive.
  ///
  /// In am, this message translates to:
  /// **'ንቁ'**
  String get stActive;

  /// No description provided for @stDeceased.
  ///
  /// In am, this message translates to:
  /// **'አርፈዋል'**
  String get stDeceased;

  /// No description provided for @stInactive.
  ///
  /// In am, this message translates to:
  /// **'ለጊዜው ንቁ ያልሆነ'**
  String get stInactive;

  /// No description provided for @stUniversity.
  ///
  /// In am, this message translates to:
  /// **'ዩኒቨርሲቲ ላይ'**
  String get stUniversity;

  /// No description provided for @stAbroad.
  ///
  /// In am, this message translates to:
  /// **'ውጭ ሀገር'**
  String get stAbroad;

  /// No description provided for @dateOfDeath.
  ///
  /// In am, this message translates to:
  /// **'ያረፉበት ቀን'**
  String get dateOfDeath;

  /// No description provided for @universityName.
  ///
  /// In am, this message translates to:
  /// **'የዩኒቨርሲቲው ስም'**
  String get universityName;

  /// No description provided for @countryName.
  ///
  /// In am, this message translates to:
  /// **'የሚኖሩበት ሀገር'**
  String get countryName;

  /// No description provided for @spiritualLevel.
  ///
  /// In am, this message translates to:
  /// **'የሰ/ት/ቤት (መንፈሳዊ ትምህርት) ደረጃ'**
  String get spiritualLevel;

  /// No description provided for @notSet.
  ///
  /// In am, this message translates to:
  /// **'አልተገለጸም'**
  String get notSet;

  /// No description provided for @levelN.
  ///
  /// In am, this message translates to:
  /// **'{n}ኛ'**
  String levelN(String n);

  /// No description provided for @gender.
  ///
  /// In am, this message translates to:
  /// **'ጾታ'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In am, this message translates to:
  /// **'ወንድ'**
  String get male;

  /// No description provided for @female.
  ///
  /// In am, this message translates to:
  /// **'ሴት'**
  String get female;

  /// No description provided for @motherName.
  ///
  /// In am, this message translates to:
  /// **'የእናት ስም'**
  String get motherName;

  /// No description provided for @birthSection.
  ///
  /// In am, this message translates to:
  /// **'የትውልድ'**
  String get birthSection;

  /// No description provided for @birthDate.
  ///
  /// In am, this message translates to:
  /// **'የትውልድ ቀን'**
  String get birthDate;

  /// No description provided for @birthDiocese.
  ///
  /// In am, this message translates to:
  /// **'ሀገረ ስብከት'**
  String get birthDiocese;

  /// No description provided for @city.
  ///
  /// In am, this message translates to:
  /// **'ከተማ'**
  String get city;

  /// No description provided for @woreda.
  ///
  /// In am, this message translates to:
  /// **'ወረዳ'**
  String get woreda;

  /// No description provided for @kebele.
  ///
  /// In am, this message translates to:
  /// **'ቀበሌ'**
  String get kebele;

  /// No description provided for @birthPlaceName.
  ///
  /// In am, this message translates to:
  /// **'ልዩ መጠሪያ'**
  String get birthPlaceName;

  /// No description provided for @christianName.
  ///
  /// In am, this message translates to:
  /// **'ስመ ክርስትና'**
  String get christianName;

  /// No description provided for @baptismChurch.
  ///
  /// In am, this message translates to:
  /// **'የተቀበሉበት ቤ/ክርስቲያን'**
  String get baptismChurch;

  /// No description provided for @baptismDate.
  ///
  /// In am, this message translates to:
  /// **'የተጠመቁበት ቀን'**
  String get baptismDate;

  /// No description provided for @addressSection.
  ///
  /// In am, this message translates to:
  /// **'የመኖሪያ አድራሻ'**
  String get addressSection;

  /// No description provided for @houseNumber.
  ///
  /// In am, this message translates to:
  /// **'የቤት ቁጥር'**
  String get houseNumber;

  /// No description provided for @emergencySection.
  ///
  /// In am, this message translates to:
  /// **'የቅርብ ተጠሪ'**
  String get emergencySection;

  /// No description provided for @abinetSection.
  ///
  /// In am, this message translates to:
  /// **'የአብነት ት/ት'**
  String get abinetSection;

  /// No description provided for @abinetQes.
  ///
  /// In am, this message translates to:
  /// **'ቅስና'**
  String get abinetQes;

  /// No description provided for @abinetDeacon.
  ///
  /// In am, this message translates to:
  /// **'ዲቁና'**
  String get abinetDeacon;

  /// No description provided for @abinetNone.
  ///
  /// In am, this message translates to:
  /// **'የለኝም'**
  String get abinetNone;

  /// No description provided for @other.
  ///
  /// In am, this message translates to:
  /// **'ሌላ'**
  String get other;

  /// No description provided for @spiritualSection.
  ///
  /// In am, this message translates to:
  /// **'መንፈሳዊ ትምህርት'**
  String get spiritualSection;

  /// No description provided for @theology.
  ///
  /// In am, this message translates to:
  /// **'የቲዎሎጂ ትምህርት'**
  String get theology;

  /// No description provided for @eduMasters.
  ///
  /// In am, this message translates to:
  /// **'ማስተርስ'**
  String get eduMasters;

  /// No description provided for @eduDegree.
  ///
  /// In am, this message translates to:
  /// **'ዲግሪ'**
  String get eduDegree;

  /// No description provided for @eduDiploma.
  ///
  /// In am, this message translates to:
  /// **'ዲፕሎማ'**
  String get eduDiploma;

  /// No description provided for @eduCertificate.
  ///
  /// In am, this message translates to:
  /// **'ሰርተፊኬት'**
  String get eduCertificate;

  /// No description provided for @eduDoctorate.
  ///
  /// In am, this message translates to:
  /// **'ዶክትሬት'**
  String get eduDoctorate;

  /// No description provided for @secularSection.
  ///
  /// In am, this message translates to:
  /// **'አለማዊ ትምህርት'**
  String get secularSection;

  /// No description provided for @institutionName.
  ///
  /// In am, this message translates to:
  /// **'ከፍተኛ የት/ት ተቋም ስም'**
  String get institutionName;

  /// No description provided for @fieldOfStudy.
  ///
  /// In am, this message translates to:
  /// **'የተማሩበት የትምህርት ዘርፍ'**
  String get fieldOfStudy;

  /// No description provided for @livelihoodSection.
  ///
  /// In am, this message translates to:
  /// **'የመተዳደሪያ አይነት'**
  String get livelihoodSection;

  /// No description provided for @employer.
  ///
  /// In am, this message translates to:
  /// **'ተቀጣሪነት'**
  String get employer;

  /// No description provided for @employerPrivate.
  ///
  /// In am, this message translates to:
  /// **'የግል'**
  String get employerPrivate;

  /// No description provided for @employerGovernment.
  ///
  /// In am, this message translates to:
  /// **'የመንግስት'**
  String get employerGovernment;

  /// No description provided for @profession.
  ///
  /// In am, this message translates to:
  /// **'እየሰሩበት ያለው ሙያ'**
  String get profession;

  /// No description provided for @experienceProfession.
  ///
  /// In am, this message translates to:
  /// **'በልምድ የተገኘ ሙያ'**
  String get experienceProfession;

  /// No description provided for @churchService.
  ///
  /// In am, this message translates to:
  /// **'የቤተክርስቲያን አገልግሎት (ካለ)'**
  String get churchService;

  /// No description provided for @studyPlaceName.
  ///
  /// In am, this message translates to:
  /// **'የሚማሩበት ተቋም ስም'**
  String get studyPlaceName;

  /// No description provided for @chooseStudentWorker.
  ///
  /// In am, this message translates to:
  /// **'በመጀመሪያ ተማሪ ወይም ሠራተኛ ይምረጡ'**
  String get chooseStudentWorker;

  /// No description provided for @confessionSection.
  ///
  /// In am, this message translates to:
  /// **'የንስሐ አባት'**
  String get confessionSection;

  /// No description provided for @maritalSection.
  ///
  /// In am, this message translates to:
  /// **'የትዳር ህይወት'**
  String get maritalSection;

  /// No description provided for @married.
  ///
  /// In am, this message translates to:
  /// **'ያገባ'**
  String get married;

  /// No description provided for @single.
  ///
  /// In am, this message translates to:
  /// **'ያላገባ'**
  String get single;

  /// No description provided for @marriageSection.
  ///
  /// In am, this message translates to:
  /// **'የጋብቻ ሁኔታ'**
  String get marriageSection;

  /// No description provided for @teklil.
  ///
  /// In am, this message translates to:
  /// **'ተክሊል'**
  String get teklil;

  /// No description provided for @kurban.
  ///
  /// In am, this message translates to:
  /// **'ቁርባን'**
  String get kurban;

  /// No description provided for @photo.
  ///
  /// In am, this message translates to:
  /// **'ፎቶ'**
  String get photo;

  /// No description provided for @deptLeader.
  ///
  /// In am, this message translates to:
  /// **'መሪ'**
  String get deptLeader;

  /// No description provided for @deptMember.
  ///
  /// In am, this message translates to:
  /// **'አባል'**
  String get deptMember;

  /// No description provided for @editMember.
  ///
  /// In am, this message translates to:
  /// **'የአባል መረጃ አስተካክል'**
  String get editMember;

  /// No description provided for @addMembers.
  ///
  /// In am, this message translates to:
  /// **'አባላት ጨምር'**
  String get addMembers;

  /// No description provided for @chooseLeader.
  ///
  /// In am, this message translates to:
  /// **'የክፍሉን መሪ ምረጥ'**
  String get chooseLeader;

  /// No description provided for @leaderHint.
  ///
  /// In am, this message translates to:
  /// **'እያንዳንዱ ክፍል አንድ መሪ አለው። መሪው የክፍሉን ወርሃዊ ተሳትፎ ይመዘግባል (የአስተዳዳሪ መብት አያገኝም)።'**
  String get leaderHint;

  /// No description provided for @makeLeader.
  ///
  /// In am, this message translates to:
  /// **'መሪ አድርግ'**
  String get makeLeader;

  /// No description provided for @makeMember.
  ///
  /// In am, this message translates to:
  /// **'አባል አድርግ'**
  String get makeMember;

  /// No description provided for @eligTitle.
  ///
  /// In am, this message translates to:
  /// **'የአገልግሎት ብቁነት'**
  String get eligTitle;

  /// No description provided for @eligEducation.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት'**
  String get eligEducation;

  /// No description provided for @eligMezmur.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር'**
  String get eligMezmur;

  /// No description provided for @eligPayment.
  ///
  /// In am, this message translates to:
  /// **'ወርሃዊ ክፍያ'**
  String get eligPayment;

  /// No description provided for @eligParticipation.
  ///
  /// In am, this message translates to:
  /// **'የክፍል ተሳትፎ'**
  String get eligParticipation;

  /// No description provided for @eligTotal.
  ///
  /// In am, this message translates to:
  /// **'ጠቅላላ'**
  String get eligTotal;

  /// No description provided for @eligEligible.
  ///
  /// In am, this message translates to:
  /// **'ብቁ'**
  String get eligEligible;

  /// No description provided for @eligIneligible.
  ///
  /// In am, this message translates to:
  /// **'ብቁ አይደሉም'**
  String get eligIneligible;

  /// No description provided for @eligPass.
  ///
  /// In am, this message translates to:
  /// **'አልፏል'**
  String get eligPass;

  /// No description provided for @eligFail.
  ///
  /// In am, this message translates to:
  /// **'አላለፈም'**
  String get eligFail;

  /// No description provided for @eligStatus.
  ///
  /// In am, this message translates to:
  /// **'የብቁነት ሁኔታ'**
  String get eligStatus;

  /// No description provided for @eligMinimum.
  ///
  /// In am, this message translates to:
  /// **'ዝቅተኛ፦ {value}'**
  String eligMinimum(String value);

  /// No description provided for @eligTotalScore.
  ///
  /// In am, this message translates to:
  /// **'ጠቅላላ ነጥብ {score} (ዝቅተኛ {minimum})'**
  String eligTotalScore(String score, String minimum);

  /// No description provided for @eligWindow.
  ///
  /// In am, this message translates to:
  /// **'የግምገማ ጊዜ፦ {from} – {to}'**
  String eligWindow(String from, String to);

  /// No description provided for @eligFailedRequirements.
  ///
  /// In am, this message translates to:
  /// **'ያልተሟሉ መስፈርቶች'**
  String get eligFailedRequirements;

  /// No description provided for @eligFailure.
  ///
  /// In am, this message translates to:
  /// **'{category}፦ {current} — {required} ያስፈልጋል ({shortfall} ይጎድላል)'**
  String eligFailure(
    String category,
    String current,
    String required,
    String shortfall,
  );

  /// No description provided for @eligAttendance.
  ///
  /// In am, this message translates to:
  /// **'መገኘት'**
  String get eligAttendance;

  /// No description provided for @eligAssessment.
  ///
  /// In am, this message translates to:
  /// **'የኮርስ ምዘና'**
  String get eligAssessment;

  /// No description provided for @eligAttendanceCalendar.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት ቀን መቁጠሪያ'**
  String get eligAttendanceCalendar;

  /// No description provided for @eligActivities.
  ///
  /// In am, this message translates to:
  /// **'ሌሎች የመዝሙር ተሳትፎዎች'**
  String get eligActivities;

  /// No description provided for @paymentExempt.
  ///
  /// In am, this message translates to:
  /// **'አይጠየቅም'**
  String get paymentExempt;

  /// No description provided for @required.
  ///
  /// In am, this message translates to:
  /// **'የሚጠበቅ'**
  String get required;

  /// No description provided for @paidLate.
  ///
  /// In am, this message translates to:
  /// **'ከወሩ በኋላ ተከፍሏል'**
  String get paidLate;

  /// No description provided for @participationHint.
  ///
  /// In am, this message translates to:
  /// **'የእያንዳንዱን አባል የወሩን ተሳትፎ ከ0 እስከ 10 ይምረጡ። ያልተሰጠ ነጥብ ዜሮ አይቆጠርም፤ ለግምገማ ይታያል።'**
  String get participationHint;

  /// No description provided for @participationMissing.
  ///
  /// In am, this message translates to:
  /// **'{count} አባላት ነጥብ አልተሰጣቸውም (ዜሮ አይቆጠርም)። ይቀጥሉ?'**
  String participationMissing(String count);

  /// No description provided for @departmentParticipation.
  ///
  /// In am, this message translates to:
  /// **'የክፍል ተሳትፎ (ወርሃዊ)'**
  String get departmentParticipation;

  /// No description provided for @myMembershipForm.
  ///
  /// In am, this message translates to:
  /// **'የአባልነት ቅጽ'**
  String get myMembershipForm;

  /// No description provided for @month.
  ///
  /// In am, this message translates to:
  /// **'ወር'**
  String get month;

  /// No description provided for @programForGroups.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራሙ ለማን ነው'**
  String get programForGroups;

  /// No description provided for @allGroups.
  ///
  /// In am, this message translates to:
  /// **'ለሁሉም'**
  String get allGroups;

  /// No description provided for @setMemberTypeFirst.
  ///
  /// In am, this message translates to:
  /// **'ክፍያው በተማሪ / ሠራተኛ መጠን ይወሰናል። በመጀመሪያ በአባሉ መረጃ ላይ ተማሪ ወይም ሠራተኛ ይምረጡ።'**
  String get setMemberTypeFirst;

  /// No description provided for @rateNotSet.
  ///
  /// In am, this message translates to:
  /// **'ለዚህ ዓይነት አባል ወርሃዊ መጠን አልተወሰነም'**
  String get rateNotSet;

  /// No description provided for @paymentSettings.
  ///
  /// In am, this message translates to:
  /// **'የክፍያ ቅንብሮች'**
  String get paymentSettings;

  /// No description provided for @graceDaysHint.
  ///
  /// In am, this message translates to:
  /// **'ወሩ ካለቀ በኋላ ክፍያው አሁንም በሰዓቱ እንደተከፈለ የሚቆጠርባቸው ቀናት'**
  String get graceDaysHint;

  /// No description provided for @editRate.
  ///
  /// In am, this message translates to:
  /// **'መጠን አስተካክል'**
  String get editRate;

  /// No description provided for @memberTypeMissing.
  ///
  /// In am, this message translates to:
  /// **'ተማሪ / ሠራተኛ አልተመረጠም'**
  String get memberTypeMissing;

  /// No description provided for @polWeightsMinimums.
  ///
  /// In am, this message translates to:
  /// **'ክብደት እና ዝቅተኛ ነጥብ (ድምር ክብደት 100)'**
  String get polWeightsMinimums;

  /// No description provided for @polWeight.
  ///
  /// In am, this message translates to:
  /// **'ክብደት'**
  String get polWeight;

  /// No description provided for @polMinimum.
  ///
  /// In am, this message translates to:
  /// **'ዝቅተኛ'**
  String get polMinimum;

  /// No description provided for @polMinAboveWeight.
  ///
  /// In am, this message translates to:
  /// **'ዝቅተኛው ነጥብ ከክብደቱ መብለጥ አይችልም'**
  String get polMinAboveWeight;

  /// No description provided for @polTotalMinimum.
  ///
  /// In am, this message translates to:
  /// **'ዝቅተኛ ድምር ነጥብ'**
  String get polTotalMinimum;

  /// No description provided for @polAllMinimumsHint.
  ///
  /// In am, this message translates to:
  /// **'ብቁ ለመሆን እያንዳንዱ ዝቅተኛ ነጥብ እና ድምሩ መሟላት አለባቸው'**
  String get polAllMinimumsHint;

  /// No description provided for @polClasses.
  ///
  /// In am, this message translates to:
  /// **'ክፍሎች'**
  String get polClasses;

  /// No description provided for @polClassesHint.
  ///
  /// In am, this message translates to:
  /// **'ምንም ካልተመረጠ የአባሉ የራሱ ክፍሎች ይቆጠራሉ'**
  String get polClassesHint;

  /// No description provided for @polCourses.
  ///
  /// In am, this message translates to:
  /// **'ትምህርቶች (ለምዘና)'**
  String get polCourses;

  /// No description provided for @polCoursesHint.
  ///
  /// In am, this message translates to:
  /// **'ምንም ካልተመረጠ የክፍሎቹ ሁሉም ትምህርቶች'**
  String get polCoursesHint;

  /// No description provided for @polAttendanceRange.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት ጊዜ (ባዶ = የምዘና ጊዜው)'**
  String get polAttendanceRange;

  /// No description provided for @polEduShare.
  ///
  /// In am, this message translates to:
  /// **'ከትምህርት ነጥብ የመገኘት ድርሻ (ቀሪው ምዘና)'**
  String get polEduShare;

  /// No description provided for @polActivitiesHint.
  ///
  /// In am, this message translates to:
  /// **'እንደ ሠርክ፣ የእሑድ አገልግሎት፣ ጥናት ያሉ ፕሮግራሞች'**
  String get polActivitiesHint;

  /// No description provided for @polMezShare.
  ///
  /// In am, this message translates to:
  /// **'ከመዝሙር ነጥብ የመገኘት ድርሻ (ቀሪው ተሳትፎ)'**
  String get polMezShare;

  /// No description provided for @polLateCredit.
  ///
  /// In am, this message translates to:
  /// **'ዘግይቶ ለተከፈለ ወር የሚሰጥ ነጥብ'**
  String get polLateCredit;

  /// No description provided for @polLateCreditHint.
  ///
  /// In am, this message translates to:
  /// **'በሰዓቱ የተከፈለ ወር 100% ያገኛል'**
  String get polLateCreditHint;

  /// No description provided for @polParticipationHint.
  ///
  /// In am, this message translates to:
  /// **'ከክፍል መሪዎች ወርሃዊ የተሳትፎ መዝገብ በራሱ ይወሰዳል'**
  String get polParticipationHint;

  /// No description provided for @errLoginNotAllowed.
  ///
  /// In am, this message translates to:
  /// **'ይህ መለያ ወደ መተግበሪያው እንዲገባ አልተፈቀደለትም። አስተዳዳሪውን ያነጋግሩ።'**
  String get errLoginNotAllowed;

  /// No description provided for @errPaymentOverlap.
  ///
  /// In am, this message translates to:
  /// **'ከእነዚህ ወሮች አንዱ ቀድሞ ተከፍሏል'**
  String get errPaymentOverlap;

  /// No description provided for @errChildrenExempt.
  ///
  /// In am, this message translates to:
  /// **'ሕጻናት ወርሃዊ ክፍያ አይከፍሉም'**
  String get errChildrenExempt;

  /// No description provided for @errChildrenNoDepartment.
  ///
  /// In am, this message translates to:
  /// **'ሕጻናት በክፍል ውስጥ አይመደቡም'**
  String get errChildrenNoDepartment;

  /// No description provided for @errNotDepartmentLeader.
  ///
  /// In am, this message translates to:
  /// **'ይህን ማድረግ የሚችለው የክፍሉ መሪ ብቻ ነው'**
  String get errNotDepartmentLeader;

  /// No description provided for @errFuturePeriod.
  ///
  /// In am, this message translates to:
  /// **'ገና ያልደረሰ ወር መመዝገብ አይቻልም'**
  String get errFuturePeriod;

  /// No description provided for @errNotAMember.
  ///
  /// In am, this message translates to:
  /// **'ይህ አባል በዚህ ክፍል ውስጥ የለም'**
  String get errNotAMember;

  /// No description provided for @errChoirNotEligible.
  ///
  /// In am, this message translates to:
  /// **'ይህ አባል ለአገልግሎት ብቁ አይደለም'**
  String get errChoirNotEligible;

  /// No description provided for @paymentDue.
  ///
  /// In am, this message translates to:
  /// **'የሚከፈል (ጊዜው አልደረሰም)'**
  String get paymentDue;

  /// No description provided for @additionalSession.
  ///
  /// In am, this message translates to:
  /// **'ተጨማሪ ጥናት'**
  String get additionalSession;

  /// No description provided for @additionalSessionHint.
  ///
  /// In am, this message translates to:
  /// **'ከመደበኛው ጥናት ውጪ የተጨመረ ክፍለ ጊዜ'**
  String get additionalSessionHint;

  /// No description provided for @countsForSelection.
  ///
  /// In am, this message translates to:
  /// **'ለበዓል ምርጫ ይቆጠራል'**
  String get countsForSelection;

  /// No description provided for @countsForSelectionHint.
  ///
  /// In am, this message translates to:
  /// **'እያንዳንዱ ምርጫ ይህን በራሱ ማካተት ወይም ማስቀረት ይችላል'**
  String get countsForSelectionHint;

  /// No description provided for @attAfterLate.
  ///
  /// In am, this message translates to:
  /// **'ከዘገየበት ጊዜ በኋላ ለሚመጡ'**
  String get attAfterLate;

  /// No description provided for @attAfterLateLate.
  ///
  /// In am, this message translates to:
  /// **'እንደ ዘገየ ይመዘገባል'**
  String get attAfterLateLate;

  /// No description provided for @attAfterLateReject.
  ///
  /// In am, this message translates to:
  /// **'አይመዘገብም (አስተያየት ይሰጣል)'**
  String get attAfterLateReject;

  /// No description provided for @attAttended.
  ///
  /// In am, this message translates to:
  /// **'ተገኝቷል'**
  String get attAttended;

  /// No description provided for @attCloseConfirm.
  ///
  /// In am, this message translates to:
  /// **'የዚህን ቀን መገኘት መዝገብ ልዝጋ? ከዚህ በኋላ የቀሩ አባላት እንደ ቀሩ ይቆጠራሉ፤ ለውጥ በማስተካከያ ጥያቄ ብቻ ይሆናል።'**
  String get attCloseConfirm;

  /// No description provided for @attCloseSession.
  ///
  /// In am, this message translates to:
  /// **'መዝገቡን ዝጋ'**
  String get attCloseSession;

  /// No description provided for @attClosed.
  ///
  /// In am, this message translates to:
  /// **'ተዘግቷል'**
  String get attClosed;

  /// No description provided for @attClosedNotice.
  ///
  /// In am, this message translates to:
  /// **'መዝገቡ ተዘግቷል። ለውጥ ካስፈለገ የማስተካከያ ጥያቄ ያቅርቡ።'**
  String get attClosedNotice;

  /// No description provided for @attCorrectionHint.
  ///
  /// In am, this message translates to:
  /// **'አስተያየቱ መገኘቱን በቀጥታ አይቀይርም፤ በገምጋሚ ይታያል።'**
  String get attCorrectionHint;

  /// No description provided for @attCorrectionRequest.
  ///
  /// In am, this message translates to:
  /// **'አስተያየት / ማስተካከያ ጥያቄ'**
  String get attCorrectionRequest;

  /// No description provided for @attCorrectionSent.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄው ተልኳል'**
  String get attCorrectionSent;

  /// No description provided for @attCorrections.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት ማስተካከያ ጥያቄዎች'**
  String get attCorrections;

  /// No description provided for @attLateMinutes.
  ///
  /// In am, this message translates to:
  /// **'የመዘግየት ጊዜ (ደቂቃ)'**
  String get attLateMinutes;

  /// No description provided for @attOnTimeMinutes.
  ///
  /// In am, this message translates to:
  /// **'ከመጀመሪያ በኋላ በሰዓቱ የሚቆጠርበት (ደቂቃ)'**
  String get attOnTimeMinutes;

  /// No description provided for @attOverride.
  ///
  /// In am, this message translates to:
  /// **'ቀጥተኛ ለውጥ (ከተዘጋ በኋላ)'**
  String get attOverride;

  /// No description provided for @attPermissionReason.
  ///
  /// In am, this message translates to:
  /// **'የፍቃድ ምክንያት'**
  String get attPermissionReason;

  /// No description provided for @attRules.
  ///
  /// In am, this message translates to:
  /// **'የሰዓት ሕጎች'**
  String get attRules;

  /// No description provided for @attRulesHint.
  ///
  /// In am, this message translates to:
  /// **'ከፕሮግራሙ መጀመሪያ ጀምሮ፦ በሰዓቱ → ዘግይቷል → ከዚያ በኋላ ያለው ሕግ። ፕሮግራሙ ሲያልቅ ያልተመዘገቡ እንደ ቀሩ ይቆጠራሉ።'**
  String get attRulesHint;

  /// No description provided for @attRulesLine.
  ///
  /// In am, this message translates to:
  /// **'እስከ {onTime} ደቂቃ በሰዓቱ፤ ከዚያ {late} ደቂቃ ዘግይቷል'**
  String attRulesLine(String onTime, String late);

  /// No description provided for @attScan.
  ///
  /// In am, this message translates to:
  /// **'QR ቃኝ'**
  String get attScan;

  /// No description provided for @attUnmarked.
  ///
  /// In am, this message translates to:
  /// **'ያልተመዘገበ'**
  String get attUnmarked;

  /// No description provided for @availableCount.
  ///
  /// In am, this message translates to:
  /// **'ያለ፦ {n}'**
  String availableCount(String n);

  /// No description provided for @bStatusPending.
  ///
  /// In am, this message translates to:
  /// **'ማጽደቅ ይጠብቃል'**
  String get bStatusPending;

  /// No description provided for @borrowApprovalHint.
  ///
  /// In am, this message translates to:
  /// **'ማጽደቅ የማይችል ሠራተኛ ሲያበድር ንብረቱ እስኪጸድቅ ይጠብቃል'**
  String get borrowApprovalHint;

  /// No description provided for @borrowApprovalRequired.
  ///
  /// In am, this message translates to:
  /// **'ማጽደቅ ያስፈልጋል'**
  String get borrowApprovalRequired;

  /// No description provided for @borrowDirectPolicy.
  ///
  /// In am, this message translates to:
  /// **'የቀጥታ ውሰት ሕጎች'**
  String get borrowDirectPolicy;

  /// No description provided for @borrowDirectPolicyHint.
  ///
  /// In am, this message translates to:
  /// **'በክፍል ጥያቄ ሳይሆን ለአባላት በቀጥታ ማዋስ። የትኞቹ ንብረቶች እንደሚዋሱ በእያንዳንዱ ንብረት ላይ ይወሰናል።'**
  String get borrowDirectPolicyHint;

  /// No description provided for @borrowMaxDays.
  ///
  /// In am, this message translates to:
  /// **'ከፍተኛ የውሰት ቀናት'**
  String get borrowMaxDays;

  /// No description provided for @borrowMaxQuantity.
  ///
  /// In am, this message translates to:
  /// **'ከፍተኛ ብዛት'**
  String get borrowMaxQuantity;

  /// No description provided for @borrowPerItemHint.
  ///
  /// In am, this message translates to:
  /// **'ባዶ = ገደብ የለም (ንብረቱ የራሱ ገደብ ካለው እሱ ይቀድማል)'**
  String get borrowPerItemHint;

  /// No description provided for @borrowRenew.
  ///
  /// In am, this message translates to:
  /// **'ጊዜ አራዝም'**
  String get borrowRenew;

  /// No description provided for @comment.
  ///
  /// In am, this message translates to:
  /// **'አስተያየት'**
  String get comment;

  /// No description provided for @department.
  ///
  /// In am, this message translates to:
  /// **'ክፍል'**
  String get department;

  /// No description provided for @deptAddAdmin.
  ///
  /// In am, this message translates to:
  /// **'አስተዳዳሪ ጨምር'**
  String get deptAddAdmin;

  /// No description provided for @deptAdminRolesHint.
  ///
  /// In am, this message translates to:
  /// **'ሚናዎቹ የሚሰጡትን ፈቃዶች ብቻ ያገኛል'**
  String get deptAdminRolesHint;

  /// No description provided for @deptAdmins.
  ///
  /// In am, this message translates to:
  /// **'የክፍል አስተዳዳሪዎች'**
  String get deptAdmins;

  /// No description provided for @deptAdminsHint.
  ///
  /// In am, this message translates to:
  /// **'የክፍል አስተዳዳሪዎች አባላት ናቸው፤ የተሰጧቸውን ሥራዎች ብቻ ማከናወን ይችላሉ። ራሳቸውን መሾም አይችሉም።'**
  String get deptAdminsHint;

  /// No description provided for @deptExtraPermissions.
  ///
  /// In am, this message translates to:
  /// **'ተጨማሪ ፈቃዶች'**
  String get deptExtraPermissions;

  /// No description provided for @deptExtraPermissionsHint.
  ///
  /// In am, this message translates to:
  /// **'ከሚናዎቹ በተጨማሪ ለዚህ አባል ብቻ የሚሰጡ ፈቃዶች'**
  String get deptExtraPermissionsHint;

  /// No description provided for @deptNoAdmins.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን አስተዳዳሪ የለም'**
  String get deptNoAdmins;

  /// No description provided for @ethiopianDaysHint.
  ///
  /// In am, this message translates to:
  /// **'በየኢትዮጵያ ወሩ የሚደገምባቸው ቀናት (ለምሳሌ ሰርክ፦ 1፣ 10፣ 19)'**
  String get ethiopianDaysHint;

  /// No description provided for @everyEthiopianDays.
  ///
  /// In am, this message translates to:
  /// **'በየወሩ በ{days}'**
  String everyEthiopianDays(String days);

  /// No description provided for @itemDepartment.
  ///
  /// In am, this message translates to:
  /// **'ባለቤት / ኃላፊ ክፍል'**
  String get itemDepartment;

  /// No description provided for @itemDirectBorrowable.
  ///
  /// In am, this message translates to:
  /// **'ለአባላት በቀጥታ ይዋሳል'**
  String get itemDirectBorrowable;

  /// No description provided for @itemDirectBorrowableHint.
  ///
  /// In am, this message translates to:
  /// **'ካልሆነ በክፍል የንብረት ጥያቄ ብቻ ይወጣል'**
  String get itemDirectBorrowableHint;

  /// No description provided for @itemRenewable.
  ///
  /// In am, this message translates to:
  /// **'ጊዜ ማራዘም ይቻላል'**
  String get itemRenewable;

  /// No description provided for @manageOccurrences.
  ///
  /// In am, this message translates to:
  /// **'ቀኖች (መሰረዝ / ማዛወር)'**
  String get manageOccurrences;

  /// No description provided for @noDepartment.
  ///
  /// In am, this message translates to:
  /// **'ክፍል የለም'**
  String get noDepartment;

  /// No description provided for @occCancel.
  ///
  /// In am, this message translates to:
  /// **'ይህን ቀን ሰርዝ'**
  String get occCancel;

  /// No description provided for @occCancelled.
  ///
  /// In am, this message translates to:
  /// **'ተሰርዟል'**
  String get occCancelled;

  /// No description provided for @occHint.
  ///
  /// In am, this message translates to:
  /// **'የተሰረዘ ቀን መገኘት አይወሰድበትም፤ ቅርት አይቆጠርም።'**
  String get occHint;

  /// No description provided for @occReschedule.
  ///
  /// In am, this message translates to:
  /// **'ጊዜ ቀይር'**
  String get occReschedule;

  /// No description provided for @occRestore.
  ///
  /// In am, this message translates to:
  /// **'መልስ'**
  String get occRestore;

  /// No description provided for @pending.
  ///
  /// In am, this message translates to:
  /// **'በመጠባበቅ ላይ'**
  String get pending;

  /// No description provided for @perm_attendance_close.
  ///
  /// In am, this message translates to:
  /// **'????? ???? ???? (??? ???)'**
  String get perm_attendance_close;

  /// No description provided for @perm_attendance_configure.
  ///
  /// In am, this message translates to:
  /// **'????? ????? (???) ?????? ? ??? ???'**
  String get perm_attendance_configure;

  /// No description provided for @perm_attendance_correction_approve.
  ///
  /// In am, this message translates to:
  /// **'የማስተካከያ ጥያቄዎችን ማጽደቅ'**
  String get perm_attendance_correction_approve;

  /// No description provided for @perm_attendance_correction_request.
  ///
  /// In am, this message translates to:
  /// **'የማስተካከያ ጥያቄ ማቅረብ'**
  String get perm_attendance_correction_request;

  /// No description provided for @perm_attendance_override.
  ///
  /// In am, this message translates to:
  /// **'ከተዘጋ በኋላ መገኘት መቀየር'**
  String get perm_attendance_override;

  /// No description provided for @perm_attendance_reports.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት ሪፖርቶች'**
  String get perm_attendance_reports;

  /// No description provided for @perm_attendance_view.
  ///
  /// In am, this message translates to:
  /// **'መገኘት ማየት'**
  String get perm_attendance_view;

  /// No description provided for @perm_borrowing_approve.
  ///
  /// In am, this message translates to:
  /// **'ውሰት ማጽደቅ'**
  String get perm_borrowing_approve;

  /// No description provided for @perm_borrowing_configure.
  ///
  /// In am, this message translates to:
  /// **'የቀጥታ ውሰት ሕጎች'**
  String get perm_borrowing_configure;

  /// No description provided for @perm_choir_manage.
  ///
  /// In am, this message translates to:
  /// **'የሠርግ መዝሙር አገልግሎት'**
  String get perm_choir_manage;

  /// No description provided for @perm_payments_configure.
  ///
  /// In am, this message translates to:
  /// **'የክፍያ መጠንና ቅንብር'**
  String get perm_payments_configure;

  /// No description provided for @perm_payments_view.
  ///
  /// In am, this message translates to:
  /// **'ወርሃዊ ክፍያ ማየት (ብቻ)'**
  String get perm_payments_view;

  /// No description provided for @perm_program_categories_manage.
  ///
  /// In am, this message translates to:
  /// **'የፕሮግራም ምድቦች'**
  String get perm_program_categories_manage;

  /// No description provided for @perm_property_request.
  ///
  /// In am, this message translates to:
  /// **'የንብረት ጥያቄ ማቅረብ'**
  String get perm_property_request;

  /// No description provided for @perm_property_review.
  ///
  /// In am, this message translates to:
  /// **'የንብረት ጥያቄ መገምገም እና መስጠት'**
  String get perm_property_review;

  /// No description provided for @perm_selection_configure.
  ///
  /// In am, this message translates to:
  /// **'የበዓል ምርጫ ማዘጋጀት'**
  String get perm_selection_configure;

  /// No description provided for @perm_selection_exams.
  ///
  /// In am, this message translates to:
  /// **'የፈተና አስፈላጊነት መወሰን'**
  String get perm_selection_exams;

  /// No description provided for @perm_selection_finalize.
  ///
  /// In am, this message translates to:
  /// **'ምርጫ ማጠናቀቅ'**
  String get perm_selection_finalize;

  /// No description provided for @perm_selection_review.
  ///
  /// In am, this message translates to:
  /// **'ምርጫ መገምገም'**
  String get perm_selection_review;

  /// No description provided for @perm_selection_view.
  ///
  /// In am, this message translates to:
  /// **'ምርጫ ማየት'**
  String get perm_selection_view;

  /// No description provided for @pgChoir.
  ///
  /// In am, this message translates to:
  /// **'መዘምራን እና ምርጫ'**
  String get pgChoir;

  /// No description provided for @pgContent.
  ///
  /// In am, this message translates to:
  /// **'ይዘት'**
  String get pgContent;

  /// No description provided for @pgHr.
  ///
  /// In am, this message translates to:
  /// **'የሰው ኃብት'**
  String get pgHr;

  /// No description provided for @pgNotifications.
  ///
  /// In am, this message translates to:
  /// **'ማሳወቂያዎች'**
  String get pgNotifications;

  /// No description provided for @pgPrograms.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራሞች እና መገኘት'**
  String get pgPrograms;

  /// No description provided for @pgSystem.
  ///
  /// In am, this message translates to:
  /// **'ሥርዓት'**
  String get pgSystem;

  /// No description provided for @propDraft.
  ///
  /// In am, this message translates to:
  /// **'ረቂቅ'**
  String get propDraft;

  /// No description provided for @propIssue.
  ///
  /// In am, this message translates to:
  /// **'ስጥ'**
  String get propIssue;

  /// No description provided for @propIssued.
  ///
  /// In am, this message translates to:
  /// **'ተሰጥቷል'**
  String get propIssued;

  /// No description provided for @propItemName.
  ///
  /// In am, this message translates to:
  /// **'የንብረቱ / የአገልግሎቱ ስም'**
  String get propItemName;

  /// No description provided for @propNeededOn.
  ///
  /// In am, this message translates to:
  /// **'የሚያስፈልግበት ቀን'**
  String get propNeededOn;

  /// No description provided for @propNew.
  ///
  /// In am, this message translates to:
  /// **'አዲስ የንብረት ጥያቄ'**
  String get propNew;

  /// No description provided for @propNone.
  ///
  /// In am, this message translates to:
  /// **'የንብረት ጥያቄ የለም'**
  String get propNone;

  /// No description provided for @propPartiallyIssued.
  ///
  /// In am, this message translates to:
  /// **'በከፊል ተሰጥቷል'**
  String get propPartiallyIssued;

  /// No description provided for @propPickItem.
  ///
  /// In am, this message translates to:
  /// **'ከንብረት መዝገብ ምረጥ'**
  String get propPickItem;

  /// No description provided for @propPickItemHint.
  ///
  /// In am, this message translates to:
  /// **'ወይም ከታች ስሙን ይጻፉ'**
  String get propPickItemHint;

  /// No description provided for @propPurpose.
  ///
  /// In am, this message translates to:
  /// **'ዓላማ / ምክንያት'**
  String get propPurpose;

  /// No description provided for @propQuantityOptional.
  ///
  /// In am, this message translates to:
  /// **'ብዛት (አማራጭ)'**
  String get propQuantityOptional;

  /// No description provided for @propRequests.
  ///
  /// In am, this message translates to:
  /// **'የንብረት ጥያቄዎች'**
  String get propRequests;

  /// No description provided for @propReturn.
  ///
  /// In am, this message translates to:
  /// **'መልስ ተቀበል'**
  String get propReturn;

  /// No description provided for @propReturnOn.
  ///
  /// In am, this message translates to:
  /// **'የሚመለስበት ቀን'**
  String get propReturnOn;

  /// No description provided for @propReturned.
  ///
  /// In am, this message translates to:
  /// **'ተመልሷል'**
  String get propReturned;

  /// No description provided for @propSaveDraft.
  ///
  /// In am, this message translates to:
  /// **'ረቂቅ አስቀምጥ'**
  String get propSaveDraft;

  /// No description provided for @propSubmitted.
  ///
  /// In am, this message translates to:
  /// **'ቀርቧል'**
  String get propSubmitted;

  /// No description provided for @propUnderReview.
  ///
  /// In am, this message translates to:
  /// **'በግምገማ ላይ'**
  String get propUnderReview;

  /// No description provided for @reason.
  ///
  /// In am, this message translates to:
  /// **'ምክንያት'**
  String get reason;

  /// No description provided for @reasonExamNotRequired.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ምርጫ ፈተና አያስፈልግም'**
  String get reasonExamNotRequired;

  /// No description provided for @reasonMissingMonths.
  ///
  /// In am, this message translates to:
  /// **'ያልተመዘገቡ ወሮች አሉ (ለግምገማ)'**
  String get reasonMissingMonths;

  /// No description provided for @reasonNoExam.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ጊዜ ፈተና አልተሰጠም'**
  String get reasonNoExam;

  /// No description provided for @reasonNoScores.
  ///
  /// In am, this message translates to:
  /// **'ከክፍሉ መሪ ነጥብ አልተመዘገበም'**
  String get reasonNoScores;

  /// No description provided for @reasonNoSessions.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ጊዜ ምንም ክፍለ ጊዜ አልነበረም'**
  String get reasonNoSessions;

  /// No description provided for @reasonNotConfigured.
  ///
  /// In am, this message translates to:
  /// **'የሚቆጠሩ ምድቦች አልተመረጡም'**
  String get reasonNotConfigured;

  /// No description provided for @reasonNotEnrolled.
  ///
  /// In am, this message translates to:
  /// **'በክፍል አልተመዘገበም'**
  String get reasonNotEnrolled;

  /// No description provided for @reasonNotInDepartment.
  ///
  /// In am, this message translates to:
  /// **'በምንም ክፍል ውስጥ የለም'**
  String get reasonNotInDepartment;

  /// No description provided for @reasonNotMemberYet.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ጊዜ ገና አባል አልነበረም'**
  String get reasonNotMemberYet;

  /// No description provided for @reasonNothingDue.
  ///
  /// In am, this message translates to:
  /// **'የሚከፈል ወር የለም'**
  String get reasonNothingDue;

  /// No description provided for @recurrenceEthiopianDays.
  ///
  /// In am, this message translates to:
  /// **'በኢትዮጵያ ወር ቀኖች'**
  String get recurrenceEthiopianDays;

  /// No description provided for @requestedBy.
  ///
  /// In am, this message translates to:
  /// **'ያቀረበው'**
  String get requestedBy;

  /// No description provided for @roleActive.
  ///
  /// In am, this message translates to:
  /// **'ሚናው ንቁ ነው'**
  String get roleActive;

  /// No description provided for @roleActiveHint.
  ///
  /// In am, this message translates to:
  /// **'ያልነቃ ሚና ምንም ፈቃድ አይሰጥም'**
  String get roleActiveHint;

  /// No description provided for @roleDepartment.
  ///
  /// In am, this message translates to:
  /// **'የክፍሉ ነባር ሚና'**
  String get roleDepartment;

  /// No description provided for @roleInUse.
  ///
  /// In am, this message translates to:
  /// **'{n} ሰዎች'**
  String roleInUse(String n);

  /// No description provided for @selAdditionalCounted.
  ///
  /// In am, this message translates to:
  /// **'የተቆጠሩ ተጨማሪ ጥናቶች'**
  String get selAdditionalCounted;

  /// No description provided for @selAdditionalHint.
  ///
  /// In am, this message translates to:
  /// **'እያንዳንዱ ተጨማሪ ጥናት በዚህ ምርጫ ይቆጠር እንደሆነ'**
  String get selAdditionalHint;

  /// No description provided for @selAdditionalSessions.
  ///
  /// In am, this message translates to:
  /// **'ተጨማሪ ጥናቶች'**
  String get selAdditionalSessions;

  /// No description provided for @selAverage.
  ///
  /// In am, this message translates to:
  /// **'አማካይ'**
  String get selAverage;

  /// No description provided for @selBackToOpen.
  ///
  /// In am, this message translates to:
  /// **'ወደ ክፍት መልስ'**
  String get selBackToOpen;

  /// No description provided for @selBonus.
  ///
  /// In am, this message translates to:
  /// **'የአገልግሎት ጉርሻ'**
  String get selBonus;

  /// No description provided for @selBonusHint.
  ///
  /// In am, this message translates to:
  /// **'በሰርክ እና በሌሎች አገልግሎቶች መገኘት ላይ የሚጨመር ጉርሻ (ከፍተኛው 30)'**
  String get selBonusHint;

  /// No description provided for @selBonusMax.
  ///
  /// In am, this message translates to:
  /// **'ከፍተኛ ጉርሻ (≤ 30)'**
  String get selBonusMax;

  /// No description provided for @selBonusSources.
  ///
  /// In am, this message translates to:
  /// **'ለጉርሻ የሚቆጠሩ ምድቦች / ፕሮግራሞች'**
  String get selBonusSources;

  /// No description provided for @selCancel.
  ///
  /// In am, this message translates to:
  /// **'ምርጫውን ሰርዝ'**
  String get selCancel;

  /// No description provided for @selClearException.
  ///
  /// In am, this message translates to:
  /// **'ልዩ ውሳኔውን አንሳ'**
  String get selClearException;

  /// No description provided for @selConfiguration.
  ///
  /// In am, this message translates to:
  /// **'ቅንብር እና ቀመር'**
  String get selConfiguration;

  /// No description provided for @selConfigure.
  ///
  /// In am, this message translates to:
  /// **'አስተካክል'**
  String get selConfigure;

  /// No description provided for @selConfirmStatus.
  ///
  /// In am, this message translates to:
  /// **'ምርጫውን ወደ «{status}» ላሸጋግር?'**
  String selConfirmStatus(String status);

  /// No description provided for @selContribution.
  ///
  /// In am, this message translates to:
  /// **'ወርሃዊ ክፍያ'**
  String get selContribution;

  /// No description provided for @selCounts.
  ///
  /// In am, this message translates to:
  /// **'{q} ከ{t} አሟልተዋል'**
  String selCounts(String q, String t);

  /// No description provided for @selCourseAttendance.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት መገኘት'**
  String get selCourseAttendance;

  /// No description provided for @selDefaultIn.
  ///
  /// In am, this message translates to:
  /// **'ነባሪ (ይቆጠራል)'**
  String get selDefaultIn;

  /// No description provided for @selDefaultOut.
  ///
  /// In am, this message translates to:
  /// **'ነባሪ (አይቆጠርም)'**
  String get selDefaultOut;

  /// No description provided for @selDraftNoResults.
  ///
  /// In am, this message translates to:
  /// **'ምርጫው ሲከፈት ውጤቶች ይሰላሉ'**
  String get selDraftNoResults;

  /// No description provided for @selExam.
  ///
  /// In am, this message translates to:
  /// **'ፈተና / ምዘና'**
  String get selExam;

  /// No description provided for @selExamsNotRequired.
  ///
  /// In am, this message translates to:
  /// **'ፈተና አያስፈልግም'**
  String get selExamsNotRequired;

  /// No description provided for @selExamsOnlyHint.
  ///
  /// In am, this message translates to:
  /// **'የፈተና አስፈላጊነትን ብቻ መቀየር ይችላሉ'**
  String get selExamsOnlyHint;

  /// No description provided for @selExamsRequired.
  ///
  /// In am, this message translates to:
  /// **'ፈተና ያስፈልጋል'**
  String get selExamsRequired;

  /// No description provided for @selExamsRequiredHint.
  ///
  /// In am, this message translates to:
  /// **'ካልሆነ የፈተና ክፍሉ አይቆጠርም፤ ሌሎቹ በ100 ይሰላሉ'**
  String get selExamsRequiredHint;

  /// No description provided for @selExamsRequiredSwitch.
  ///
  /// In am, this message translates to:
  /// **'የፈተና ውጤት ያስፈልጋል'**
  String get selExamsRequiredSwitch;

  /// No description provided for @selException.
  ///
  /// In am, this message translates to:
  /// **'ልዩ ውሳኔ'**
  String get selException;

  /// No description provided for @selExceptionHint.
  ///
  /// In am, this message translates to:
  /// **'ልዩ ውሳኔ ምክንያት ይፈልጋል እና ይመዘገባል'**
  String get selExceptionHint;

  /// No description provided for @selExclude.
  ///
  /// In am, this message translates to:
  /// **'አትቁጠር'**
  String get selExclude;

  /// No description provided for @selExcludedSessions.
  ///
  /// In am, this message translates to:
  /// **'ያልተቆጠሩ ክፍለ ጊዜዎች'**
  String get selExcludedSessions;

  /// No description provided for @selFinalize.
  ///
  /// In am, this message translates to:
  /// **'አጠናቅ'**
  String get selFinalize;

  /// No description provided for @selFormula.
  ///
  /// In am, this message translates to:
  /// **'ቀመር፦ መሠረታዊ = (የመቶኛ × ክብደት ድምር) ÷ (የተቆጠሩ ክብደቶች ድምር) × 100፤ ጠቅላላ = መሠረታዊ + ጉርሻ (≤ 30)። እያንዳንዱ የተቆጠረ ክፍል ዝቅተኛውን ሲያሟላ እና ጠቅላላው ዝቅተኛውን ሲያልፍ ያሟላል። ደረጃ የለም፤ እኩል ነጥብ ያላቸው እኩል ናቸው።'**
  String get selFormula;

  /// No description provided for @selInclude.
  ///
  /// In am, this message translates to:
  /// **'ቁጠር'**
  String get selInclude;

  /// No description provided for @selLateCreditHint.
  ///
  /// In am, this message translates to:
  /// **'100% = ዘግይቶ የተከፈለ ወርም እንደ ተከፈለ ይቆጠራል'**
  String get selLateCreditHint;

  /// No description provided for @selLive.
  ///
  /// In am, this message translates to:
  /// **'እየተሰላ'**
  String get selLive;

  /// No description provided for @selMarkNotQualified.
  ///
  /// In am, this message translates to:
  /// **'እንዳላሟላ ወስን'**
  String get selMarkNotQualified;

  /// No description provided for @selMarkQualified.
  ///
  /// In am, this message translates to:
  /// **'እንዳሟላ ወስን'**
  String get selMarkQualified;

  /// No description provided for @selMezmurAttendance.
  ///
  /// In am, this message translates to:
  /// **'የመዝሙር ጥናት መገኘት'**
  String get selMezmurAttendance;

  /// No description provided for @selMissingTitle.
  ///
  /// In am, this message translates to:
  /// **'ያልተሟላ መረጃ'**
  String get selMissingTitle;

  /// No description provided for @selName.
  ///
  /// In am, this message translates to:
  /// **'የበዓሉ / የአገልግሎቱ ስም'**
  String get selName;

  /// No description provided for @selNameHint.
  ///
  /// In am, this message translates to:
  /// **'ለምሳሌ፦ ጥምቀት 2019'**
  String get selNameHint;

  /// No description provided for @selNew.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ምርጫ'**
  String get selNew;

  /// No description provided for @selNoMinimum.
  ///
  /// In am, this message translates to:
  /// **'ዝቅተኛ የለም'**
  String get selNoMinimum;

  /// No description provided for @selNone.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን ምርጫ የለም'**
  String get selNone;

  /// No description provided for @selNoneOpen.
  ///
  /// In am, this message translates to:
  /// **'አሁን ክፍት የሆነ የበዓል ምርጫ የለም'**
  String get selNoneOpen;

  /// No description provided for @selNotCounted.
  ///
  /// In am, this message translates to:
  /// **'አልተቆጠረም'**
  String get selNotCounted;

  /// No description provided for @selNotQualified.
  ///
  /// In am, this message translates to:
  /// **'አላሟሉም'**
  String get selNotQualified;

  /// No description provided for @selNotScored.
  ///
  /// In am, this message translates to:
  /// **'ነጥብ አልተሰጠም'**
  String get selNotScored;

  /// No description provided for @selOpen.
  ///
  /// In am, this message translates to:
  /// **'ክፈት'**
  String get selOpen;

  /// No description provided for @selPercent.
  ///
  /// In am, this message translates to:
  /// **'መቶኛ'**
  String get selPercent;

  /// No description provided for @selPoints.
  ///
  /// In am, this message translates to:
  /// **'ነጥብ'**
  String get selPoints;

  /// No description provided for @selQualified.
  ///
  /// In am, this message translates to:
  /// **'አሟልተዋል'**
  String get selQualified;

  /// No description provided for @selStatusCancelled.
  ///
  /// In am, this message translates to:
  /// **'ተሰርዟል'**
  String get selStatusCancelled;

  /// No description provided for @selStatusDraft.
  ///
  /// In am, this message translates to:
  /// **'ረቂቅ'**
  String get selStatusDraft;

  /// No description provided for @selStatusFinalized.
  ///
  /// In am, this message translates to:
  /// **'ተጠናቋል'**
  String get selStatusFinalized;

  /// No description provided for @selStatusOpen.
  ///
  /// In am, this message translates to:
  /// **'ክፍት'**
  String get selStatusOpen;

  /// No description provided for @selStatusReview.
  ///
  /// In am, this message translates to:
  /// **'በግምገማ ላይ'**
  String get selStatusReview;

  /// No description provided for @selTitle.
  ///
  /// In am, this message translates to:
  /// **'የበዓል መዝሙር አገልግሎት ምርጫ'**
  String get selTitle;

  /// No description provided for @selToReview.
  ///
  /// In am, this message translates to:
  /// **'ወደ ግምገማ'**
  String get selToReview;

  /// No description provided for @selTotalLine.
  ///
  /// In am, this message translates to:
  /// **'መሠረታዊ {base} + ጉርሻ {bonus} = {total} (ዝቅተኛ {min})'**
  String selTotalLine(String base, String bonus, String total, String min);

  /// No description provided for @selectCount.
  ///
  /// In am, this message translates to:
  /// **'{n} ምረጥ'**
  String selectCount(String n);

  /// No description provided for @wedAbsent.
  ///
  /// In am, this message translates to:
  /// **'አልተገኘም'**
  String get wedAbsent;

  /// No description provided for @wedCompleted.
  ///
  /// In am, this message translates to:
  /// **'ተከናውኗል'**
  String get wedCompleted;

  /// No description provided for @wedMembers.
  ///
  /// In am, this message translates to:
  /// **'የተመረጡ ({n})'**
  String wedMembers(String n);

  /// No description provided for @wedNew.
  ///
  /// In am, this message translates to:
  /// **'አዲስ የሠርግ አገልግሎት'**
  String get wedNew;

  /// No description provided for @wedNone.
  ///
  /// In am, this message translates to:
  /// **'የሠርግ አገልግሎት የለም'**
  String get wedNone;

  /// No description provided for @wedParticipated.
  ///
  /// In am, this message translates to:
  /// **'አገልግሏል'**
  String get wedParticipated;

  /// No description provided for @wedPlanned.
  ///
  /// In am, this message translates to:
  /// **'የታቀደ'**
  String get wedPlanned;

  /// No description provided for @wedSelectMembers.
  ///
  /// In am, this message translates to:
  /// **'መዘምራን ምረጥ'**
  String get wedSelectMembers;

  /// No description provided for @wedSelected.
  ///
  /// In am, this message translates to:
  /// **'ተመርጧል'**
  String get wedSelected;

  /// No description provided for @wedServiceAt.
  ///
  /// In am, this message translates to:
  /// **'የአገልግሎቱ ቀን እና ሰዓት'**
  String get wedServiceAt;

  /// No description provided for @wedTitle.
  ///
  /// In am, this message translates to:
  /// **'ሌሎች የመዝሙር አገልግሎቶች'**
  String get wedTitle;

  /// No description provided for @wedWithdrawn.
  ///
  /// In am, this message translates to:
  /// **'ተወግዷል'**
  String get wedWithdrawn;

  /// No description provided for @minutesUnit.
  ///
  /// In am, this message translates to:
  /// **'ደቂቃ'**
  String get minutesUnit;

  /// No description provided for @chatTitle.
  ///
  /// In am, this message translates to:
  /// **'የክፍል ውይይት'**
  String get chatTitle;

  /// No description provided for @chatNone.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን የተመደቡበት ክፍል የለም።'**
  String get chatNone;

  /// No description provided for @chatPrivate.
  ///
  /// In am, this message translates to:
  /// **'የግል መልዕክቶች'**
  String get chatPrivate;

  /// No description provided for @chatNoMessages.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን መልዕክት የለም — የመጀመሪያውን ይጻፉ።'**
  String get chatNoMessages;

  /// No description provided for @chatTypeHint.
  ///
  /// In am, this message translates to:
  /// **'መልዕክት ይጻፉ…'**
  String get chatTypeHint;

  /// No description provided for @chatSend.
  ///
  /// In am, this message translates to:
  /// **'ላክ'**
  String get chatSend;

  /// No description provided for @chatAttach.
  ///
  /// In am, this message translates to:
  /// **'ፋይል አያይዝ'**
  String get chatAttach;

  /// No description provided for @chatPhoto.
  ///
  /// In am, this message translates to:
  /// **'ፎቶ'**
  String get chatPhoto;

  /// No description provided for @chatCamera.
  ///
  /// In am, this message translates to:
  /// **'ካሜራ'**
  String get chatCamera;

  /// No description provided for @chatFile.
  ///
  /// In am, this message translates to:
  /// **'ድምፅ፣ ቪዲዮ ወይም ሰነድ'**
  String get chatFile;

  /// No description provided for @chatMeeting.
  ///
  /// In am, this message translates to:
  /// **'የድምፅ ስብሰባ ሊንክ'**
  String get chatMeeting;

  /// No description provided for @chatMeetingUrl.
  ///
  /// In am, this message translates to:
  /// **'የስብሰባ ሊንክ (Jitsi, Google Meet, Zoom, Telegram)'**
  String get chatMeetingUrl;

  /// No description provided for @chatMeetingNote.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻ (አማራጭ)'**
  String get chatMeetingNote;

  /// No description provided for @chatMeetingWhen.
  ///
  /// In am, this message translates to:
  /// **'ሰዓት (አማራጭ)'**
  String get chatMeetingWhen;

  /// No description provided for @chatMeetingJoin.
  ///
  /// In am, this message translates to:
  /// **'ተቀላቀል'**
  String get chatMeetingJoin;

  /// No description provided for @chatMeetingTitle.
  ///
  /// In am, this message translates to:
  /// **'የድምፅ ስብሰባ'**
  String get chatMeetingTitle;

  /// No description provided for @chatVoiceInfo.
  ///
  /// In am, this message translates to:
  /// **'የአሁኑ ሰርቨር (cPanel) ቀጥታ የድምፅ ጥሪና የቡድን ድምፅ ውይይትን አይደግፍም። መሪዎች በምትኩ የJitsi፣ Google Meet ወይም Telegram የድምፅ ስብሰባ ሊንክ ይልካሉ።'**
  String get chatVoiceInfo;

  /// No description provided for @chatDeleted.
  ///
  /// In am, this message translates to:
  /// **'ይህ መልዕክት ተሰርዟል'**
  String get chatDeleted;

  /// No description provided for @chatDeleteConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህን መልዕክት ይሰርዙ?'**
  String get chatDeleteConfirm;

  /// No description provided for @chatLeader.
  ///
  /// In am, this message translates to:
  /// **'መሪ'**
  String get chatLeader;

  /// No description provided for @chatNewPrivate.
  ///
  /// In am, this message translates to:
  /// **'አዲስ የግል መልዕክት'**
  String get chatNewPrivate;

  /// No description provided for @chatNoThreads.
  ///
  /// In am, this message translates to:
  /// **'የግል መልዕክት የለም።'**
  String get chatNoThreads;

  /// No description provided for @chatOpenFile.
  ///
  /// In am, this message translates to:
  /// **'ክፈት'**
  String get chatOpenFile;

  /// No description provided for @chatLoadOlder.
  ///
  /// In am, this message translates to:
  /// **'የቆዩ መልዕክቶች'**
  String get chatLoadOlder;

  /// No description provided for @midTitle.
  ///
  /// In am, this message translates to:
  /// **'የአባል መለያ ቁጥር'**
  String get midTitle;

  /// No description provided for @midHint.
  ///
  /// In am, this message translates to:
  /// **'ቁጥሩ ቋሚ ነው፤ የሚቀየረው የምድቡ መነሻ (prefix) እና አጻጻፉ ብቻ ነው። ለውጡ የዚያን ምድብ አባላት ሁሉ መለያ ወዲያው ይቀይራል።'**
  String get midHint;

  /// No description provided for @midSeparator.
  ///
  /// In am, this message translates to:
  /// **'መለያያ ምልክት'**
  String get midSeparator;

  /// No description provided for @midDigits.
  ///
  /// In am, this message translates to:
  /// **'ዝቅተኛ የአሃዝ ብዛት (0 = እንዳለ)'**
  String get midDigits;

  /// No description provided for @midPreview.
  ///
  /// In am, this message translates to:
  /// **'ናሙና'**
  String get midPreview;

  /// No description provided for @midSpace.
  ///
  /// In am, this message translates to:
  /// **'ክፍተት'**
  String get midSpace;

  /// No description provided for @midNone.
  ///
  /// In am, this message translates to:
  /// **'(ምንም)'**
  String get midNone;

  /// No description provided for @errMemberNotExpected.
  ///
  /// In am, this message translates to:
  /// **'ይህ አባል የዚህ መርሐ ግብር ተሳታፊ ምድብ አይደለም።'**
  String get errMemberNotExpected;

  /// No description provided for @errSelfAttendance.
  ///
  /// In am, this message translates to:
  /// **'የራስዎን መገኘት መመዝገብ አይችሉም፤ ሌላ የመገኘት መዝጋቢ ይመዝግብዎ።'**
  String get errSelfAttendance;

  /// No description provided for @errAttendanceNotActive.
  ///
  /// In am, this message translates to:
  /// **'መገኘት የሚመዘገበው በመርሐ ግብሩ ቀን ነው።'**
  String get errAttendanceNotActive;

  /// No description provided for @errChatForbidden.
  ///
  /// In am, this message translates to:
  /// **'የዚህ ክፍል አባል አይደሉም።'**
  String get errChatForbidden;

  /// No description provided for @errChatPrivate.
  ///
  /// In am, this message translates to:
  /// **'የግል መልዕክት የሚቻለው ከክፍልዎ መሪዎች ጋር ብቻ ነው።'**
  String get errChatPrivate;

  /// No description provided for @errChatMedia.
  ///
  /// In am, this message translates to:
  /// **'ፎቶ፣ ሚዲያና የስብሰባ ሊንክ የሚልኩት የክፍሉ መሪዎች ብቻ ናቸው።'**
  String get errChatMedia;

  /// No description provided for @errChatDelete.
  ///
  /// In am, this message translates to:
  /// **'የራስዎን መልዕክት ብቻ መሰረዝ ይችላሉ።'**
  String get errChatDelete;

  /// No description provided for @vMessageEmpty.
  ///
  /// In am, this message translates to:
  /// **'መልዕክቱ ባዶ ነው።'**
  String get vMessageEmpty;

  /// No description provided for @vInvalidMeetingUrl.
  ///
  /// In am, this message translates to:
  /// **'የሚታወቅ የስብሰባ ሊንክ ያስገቡ (Jitsi፣ Google Meet፣ Zoom፣ Telegram)።'**
  String get vInvalidMeetingUrl;

  /// No description provided for @vNoSpaces.
  ///
  /// In am, this message translates to:
  /// **'ክፍተት አይፈቀድም።'**
  String get vNoSpaces;

  /// No description provided for @pin.
  ///
  /// In am, this message translates to:
  /// **'ፒን (PIN)'**
  String get pin;

  /// No description provided for @pinHelp.
  ///
  /// In am, this message translates to:
  /// **'ከ4 እስከ 6 ቁጥሮች'**
  String get pinHelp;

  /// No description provided for @confirmPin.
  ///
  /// In am, this message translates to:
  /// **'ፒኑን ያረጋግጡ'**
  String get confirmPin;

  /// No description provided for @newPin.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ፒን'**
  String get newPin;

  /// No description provided for @currentPinOrPassword.
  ///
  /// In am, this message translates to:
  /// **'የአሁኑ ፒን'**
  String get currentPinOrPassword;

  /// No description provided for @pinOrPassword.
  ///
  /// In am, this message translates to:
  /// **'ፒን (PIN)'**
  String get pinOrPassword;

  /// No description provided for @pinOrPasswordHelp.
  ///
  /// In am, this message translates to:
  /// **'ከ4 እስከ 6 ቁጥሮች'**
  String get pinOrPasswordHelp;

  /// No description provided for @vInvalidPin.
  ///
  /// In am, this message translates to:
  /// **'ፒኑ ከ4 እስከ 6 ቁጥሮች መሆን አለበት'**
  String get vInvalidPin;

  /// No description provided for @vPinMismatch.
  ///
  /// In am, this message translates to:
  /// **'ፒኖቹ አይመሳሰሉም'**
  String get vPinMismatch;

  /// No description provided for @vPinOrPassword.
  ///
  /// In am, this message translates to:
  /// **'ከ4 እስከ 6 ቁጥር ፒን ያስገቡ'**
  String get vPinOrPassword;

  /// No description provided for @changePinTitle.
  ///
  /// In am, this message translates to:
  /// **'ፒን መቀየር'**
  String get changePinTitle;

  /// No description provided for @pinChanged.
  ///
  /// In am, this message translates to:
  /// **'ፒንዎ ተቀይሯል'**
  String get pinChanged;

  /// No description provided for @errorInvalidPin.
  ///
  /// In am, this message translates to:
  /// **'ፒኑ ከ4 እስከ 6 ቁጥሮች መሆን አለበት'**
  String get errorInvalidPin;

  /// No description provided for @errorPinOrPassword.
  ///
  /// In am, this message translates to:
  /// **'ከ4 እስከ 6 ቁጥር ፒን ያስገቡ'**
  String get errorPinOrPassword;

  /// No description provided for @remindBefore2880.
  ///
  /// In am, this message translates to:
  /// **'ከ2 ቀን በፊት'**
  String get remindBefore2880;

  /// No description provided for @remindBefore1440.
  ///
  /// In am, this message translates to:
  /// **'ከ1 ቀን በፊት'**
  String get remindBefore1440;

  /// No description provided for @remindBefore360.
  ///
  /// In am, this message translates to:
  /// **'ከ6 ሰዓት በፊት'**
  String get remindBefore360;

  /// No description provided for @remindBefore60.
  ///
  /// In am, this message translates to:
  /// **'ከ1 ሰዓት በፊት'**
  String get remindBefore60;

  /// No description provided for @startsIn2880.
  ///
  /// In am, this message translates to:
  /// **'በ2 ቀን ውስጥ ይጀምራል'**
  String get startsIn2880;

  /// No description provided for @startsIn1440.
  ///
  /// In am, this message translates to:
  /// **'ነገ ይጀምራል'**
  String get startsIn1440;

  /// No description provided for @startsIn360.
  ///
  /// In am, this message translates to:
  /// **'በ6 ሰዓት ውስጥ ይጀምራል'**
  String get startsIn360;

  /// No description provided for @startsIn60.
  ///
  /// In am, this message translates to:
  /// **'በ1 ሰዓት ውስጥ ይጀምራል'**
  String get startsIn60;

  /// No description provided for @programReminderAlarm.
  ///
  /// In am, this message translates to:
  /// **'የፕሮግራም ማስታወሻ'**
  String get programReminderAlarm;

  /// No description provided for @myProgramReminders.
  ///
  /// In am, this message translates to:
  /// **'የዚህ ፕሮግራም ማስታወሻ (ማንቂያ)'**
  String get myProgramReminders;

  /// No description provided for @myProgramRemindersHint.
  ///
  /// In am, this message translates to:
  /// **'ስልክዎ በመረጡት ጊዜ ያስታውስዎታል፤ ኢንተርኔት ባይኖርም ይሠራል።'**
  String get myProgramRemindersHint;

  /// No description provided for @useProgramReminders.
  ///
  /// In am, this message translates to:
  /// **'የፕሮግራሙን ማስታወሻ ተጠቀም'**
  String get useProgramReminders;

  /// No description provided for @programReminderTimes.
  ///
  /// In am, this message translates to:
  /// **'የማስታወሻ ጊዜዎች'**
  String get programReminderTimes;

  /// No description provided for @programReminderTimesHint.
  ///
  /// In am, this message translates to:
  /// **'አባላት በእነዚህ ጊዜዎች ማሳወቂያ እና ማንቂያ ያገኛሉ (እያንዳንዱ አባል ለራሱ መቀየር ይችላል)።'**
  String get programReminderTimesHint;

  /// No description provided for @noEndTime.
  ///
  /// In am, this message translates to:
  /// **'የማብቂያ ሰዓት የለውም'**
  String get noEndTime;

  /// No description provided for @hasEndTime.
  ///
  /// In am, this message translates to:
  /// **'የማብቂያ ሰዓት አለው'**
  String get hasEndTime;

  /// No description provided for @noEndTimeHint.
  ///
  /// In am, this message translates to:
  /// **'የማብቂያ ሰዓት የሌለው ፕሮግራም እስከ ቀኑ መጨረሻ ይቆያል።'**
  String get noEndTimeHint;

  /// No description provided for @attendanceWindow.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት ሰዓት (ደቂቃ)'**
  String get attendanceWindow;

  /// No description provided for @attendanceWindowHint.
  ///
  /// In am, this message translates to:
  /// **'ለምሳሌ ፕሮግራሙ 5:30 ቢጀምርና በሰዓቱ 30 ደቂቃ ከሆነ እስከ 6:00 የመጡ በሰዓቱ ይቆጠራሉ። ባዶ = አጠቃላይ ደንቡ።'**
  String get attendanceWindowHint;

  /// No description provided for @onTimeMinutes.
  ///
  /// In am, this message translates to:
  /// **'በሰዓቱ (ደቂቃ)'**
  String get onTimeMinutes;

  /// No description provided for @lateMinutes.
  ///
  /// In am, this message translates to:
  /// **'ዘግይቶ (ተጨማሪ ደቂቃ)'**
  String get lateMinutes;

  /// No description provided for @onTimeUntil.
  ///
  /// In am, this message translates to:
  /// **'በሰዓቱ እስከ {time}'**
  String onTimeUntil(String time);

  /// No description provided for @lateUntil.
  ///
  /// In am, this message translates to:
  /// **'ዘግይቶ እስከ {time}'**
  String lateUntil(String time);

  /// No description provided for @fromTime.
  ///
  /// In am, this message translates to:
  /// **'ከ {time} ጀምሮ'**
  String fromTime(String time);

  /// No description provided for @rolePermissionsRevokeHint.
  ///
  /// In am, this message translates to:
  /// **'ምልክቱን ማንሳት ፈቃዱን ለዚህ ሰው ብቻ ይሰርዛል (ሚናው አይቀየርም)፤ እንደገና ማድረግ ይመልሰዋል።'**
  String get rolePermissionsRevokeHint;

  /// No description provided for @permissionRevoked.
  ///
  /// In am, this message translates to:
  /// **'ተሰርዟል'**
  String get permissionRevoked;

  /// No description provided for @seeAllCategories.
  ///
  /// In am, this message translates to:
  /// **'ሁሉንም ምድቦች ይመልከቱ ({count})'**
  String seeAllCategories(String count);

  /// No description provided for @hubQuickLinks.
  ///
  /// In am, this message translates to:
  /// **'ፈጣን መዳረሻ'**
  String get hubQuickLinks;

  /// No description provided for @projectsTitle.
  ///
  /// In am, this message translates to:
  /// **'ፕሮጀክቶች'**
  String get projectsTitle;

  /// No description provided for @projectManagement.
  ///
  /// In am, this message translates to:
  /// **'የፕሮጀክት አስተዳደር'**
  String get projectManagement;

  /// No description provided for @pmOverview.
  ///
  /// In am, this message translates to:
  /// **'አጠቃላይ'**
  String get pmOverview;

  /// No description provided for @pmMyTasks.
  ///
  /// In am, this message translates to:
  /// **'የእኔ ተግባራት'**
  String get pmMyTasks;

  /// No description provided for @pmIssues.
  ///
  /// In am, this message translates to:
  /// **'ችግሮች'**
  String get pmIssues;

  /// No description provided for @pmSuggestions.
  ///
  /// In am, this message translates to:
  /// **'ሐሳቦች'**
  String get pmSuggestions;

  /// No description provided for @pmBudget.
  ///
  /// In am, this message translates to:
  /// **'በጀት'**
  String get pmBudget;

  /// No description provided for @pmExpenses.
  ///
  /// In am, this message translates to:
  /// **'ወጪዎች'**
  String get pmExpenses;

  /// No description provided for @pmReports.
  ///
  /// In am, this message translates to:
  /// **'ሪፖርቶች'**
  String get pmReports;

  /// No description provided for @pmTasks.
  ///
  /// In am, this message translates to:
  /// **'ተግባራት'**
  String get pmTasks;

  /// No description provided for @pmTeam.
  ///
  /// In am, this message translates to:
  /// **'ቡድን'**
  String get pmTeam;

  /// No description provided for @pmFiles.
  ///
  /// In am, this message translates to:
  /// **'ፋይሎች'**
  String get pmFiles;

  /// No description provided for @pmActivity.
  ///
  /// In am, this message translates to:
  /// **'እንቅስቃሴ'**
  String get pmActivity;

  /// No description provided for @pmApprovals.
  ///
  /// In am, this message translates to:
  /// **'የሚጸድቁ'**
  String get pmApprovals;

  /// No description provided for @pmNoDepartments.
  ///
  /// In am, this message translates to:
  /// **'ፕሮጀክቶቻቸውን ማየት የሚችሉበት ክፍል የለም።'**
  String get pmNoDepartments;

  /// No description provided for @pmNoProjects.
  ///
  /// In am, this message translates to:
  /// **'ፕሮጀክት የለም'**
  String get pmNoProjects;

  /// No description provided for @pmNoTasks.
  ///
  /// In am, this message translates to:
  /// **'ተግባር የለም'**
  String get pmNoTasks;

  /// No description provided for @pmNoIssues.
  ///
  /// In am, this message translates to:
  /// **'ችግር የለም'**
  String get pmNoIssues;

  /// No description provided for @pmNoSuggestions.
  ///
  /// In am, this message translates to:
  /// **'ሐሳብ የለም'**
  String get pmNoSuggestions;

  /// No description provided for @pmNoExpenses.
  ///
  /// In am, this message translates to:
  /// **'ወጪ የለም'**
  String get pmNoExpenses;

  /// No description provided for @pmNoFiles.
  ///
  /// In am, this message translates to:
  /// **'ፋይል የለም'**
  String get pmNoFiles;

  /// No description provided for @pmNoActivity.
  ///
  /// In am, this message translates to:
  /// **'እንቅስቃሴ የለም'**
  String get pmNoActivity;

  /// No description provided for @pmActiveCount.
  ///
  /// In am, this message translates to:
  /// **'{count} ንቁ'**
  String pmActiveCount(String count);

  /// No description provided for @pmOverdueCount.
  ///
  /// In am, this message translates to:
  /// **'{count} ጊዜው ያለፈ'**
  String pmOverdueCount(String count);

  /// No description provided for @pmOpenCount.
  ///
  /// In am, this message translates to:
  /// **'{count} ክፍት'**
  String pmOpenCount(String count);

  /// No description provided for @pmProjectsCount.
  ///
  /// In am, this message translates to:
  /// **'{count} ፕሮጀክቶች'**
  String pmProjectsCount(String count);

  /// No description provided for @pmNewProject.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ፕሮጀክት'**
  String get pmNewProject;

  /// No description provided for @pmEditProject.
  ///
  /// In am, this message translates to:
  /// **'ፕሮጀክት ማስተካከል'**
  String get pmEditProject;

  /// No description provided for @pmNewTask.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ተግባር'**
  String get pmNewTask;

  /// No description provided for @pmEditTask.
  ///
  /// In am, this message translates to:
  /// **'ተግባር ማስተካከል'**
  String get pmEditTask;

  /// No description provided for @pmTitle.
  ///
  /// In am, this message translates to:
  /// **'ርዕስ'**
  String get pmTitle;

  /// No description provided for @pmLeader.
  ///
  /// In am, this message translates to:
  /// **'የፕሮጀክት መሪ'**
  String get pmLeader;

  /// No description provided for @pmResponsible.
  ///
  /// In am, this message translates to:
  /// **'ኃላፊዎች'**
  String get pmResponsible;

  /// No description provided for @pmStartDate.
  ///
  /// In am, this message translates to:
  /// **'የሚጀምርበት ቀን'**
  String get pmStartDate;

  /// No description provided for @pmDeadline.
  ///
  /// In am, this message translates to:
  /// **'ማብቂያ ጊዜ'**
  String get pmDeadline;

  /// No description provided for @pmProjectDeadline.
  ///
  /// In am, this message translates to:
  /// **'የፕሮጀክቱ ማብቂያ'**
  String get pmProjectDeadline;

  /// No description provided for @pmTaskDeadline.
  ///
  /// In am, this message translates to:
  /// **'የተግባሩ ማብቂያ'**
  String get pmTaskDeadline;

  /// No description provided for @pmNoDeadline.
  ///
  /// In am, this message translates to:
  /// **'ማብቂያ የለም'**
  String get pmNoDeadline;

  /// No description provided for @pmPriority.
  ///
  /// In am, this message translates to:
  /// **'ቅድሚያ'**
  String get pmPriority;

  /// No description provided for @pmProgress.
  ///
  /// In am, this message translates to:
  /// **'እድገት'**
  String get pmProgress;

  /// No description provided for @pmProgressMode.
  ///
  /// In am, this message translates to:
  /// **'እድገት የሚሰላው'**
  String get pmProgressMode;

  /// No description provided for @pmProgressTasks.
  ///
  /// In am, this message translates to:
  /// **'ከተጠናቀቁ ተግባራት'**
  String get pmProgressTasks;

  /// No description provided for @pmProgressWeighted.
  ///
  /// In am, this message translates to:
  /// **'በተግባር ክብደት'**
  String get pmProgressWeighted;

  /// No description provided for @pmProgressManual.
  ///
  /// In am, this message translates to:
  /// **'በእጅ'**
  String get pmProgressManual;

  /// No description provided for @pmWeight.
  ///
  /// In am, this message translates to:
  /// **'ክብደት'**
  String get pmWeight;

  /// No description provided for @pmNotes.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻ'**
  String get pmNotes;

  /// No description provided for @pmAllowLateTasks.
  ///
  /// In am, this message translates to:
  /// **'ከፕሮጀክቱ ማብቂያ በኋላ የሚያልቁ ተግባራት ይፈቀዱ'**
  String get pmAllowLateTasks;

  /// No description provided for @pmAfterProjectDeadline.
  ///
  /// In am, this message translates to:
  /// **'ከፕሮጀክቱ ማብቂያ በኋላ እንዲያልቅ ፍቀድ (ፈቃድ ያስፈልጋል)'**
  String get pmAfterProjectDeadline;

  /// No description provided for @pmTimeLeft.
  ///
  /// In am, this message translates to:
  /// **'{time} ቀርቷል'**
  String pmTimeLeft(String time);

  /// No description provided for @pmOverdueBy.
  ///
  /// In am, this message translates to:
  /// **'በ{time} ዘግይቷል'**
  String pmOverdueBy(String time);

  /// No description provided for @pmDays.
  ///
  /// In am, this message translates to:
  /// **'{n} ቀን'**
  String pmDays(String n);

  /// No description provided for @pmHours.
  ///
  /// In am, this message translates to:
  /// **'{n} ሰዓት'**
  String pmHours(String n);

  /// No description provided for @pmMinutes.
  ///
  /// In am, this message translates to:
  /// **'{n} ደቂቃ'**
  String pmMinutes(String n);

  /// No description provided for @pmOverdue.
  ///
  /// In am, this message translates to:
  /// **'ጊዜው አልፏል'**
  String get pmOverdue;

  /// No description provided for @pmPrLow.
  ///
  /// In am, this message translates to:
  /// **'ዝቅተኛ'**
  String get pmPrLow;

  /// No description provided for @pmPrMedium.
  ///
  /// In am, this message translates to:
  /// **'መካከለኛ'**
  String get pmPrMedium;

  /// No description provided for @pmPrHigh.
  ///
  /// In am, this message translates to:
  /// **'ከፍተኛ'**
  String get pmPrHigh;

  /// No description provided for @pmPrUrgent.
  ///
  /// In am, this message translates to:
  /// **'አስቸኳይ'**
  String get pmPrUrgent;

  /// No description provided for @pmStPlanning.
  ///
  /// In am, this message translates to:
  /// **'በዕቅድ ላይ'**
  String get pmStPlanning;

  /// No description provided for @pmStNotStarted.
  ///
  /// In am, this message translates to:
  /// **'ያልተጀመረ'**
  String get pmStNotStarted;

  /// No description provided for @pmStInProgress.
  ///
  /// In am, this message translates to:
  /// **'በሂደት ላይ'**
  String get pmStInProgress;

  /// No description provided for @pmStOnHold.
  ///
  /// In am, this message translates to:
  /// **'የቆመ'**
  String get pmStOnHold;

  /// No description provided for @pmStCompleted.
  ///
  /// In am, this message translates to:
  /// **'የተጠናቀቀ'**
  String get pmStCompleted;

  /// No description provided for @pmStCancelled.
  ///
  /// In am, this message translates to:
  /// **'የተሰረዘ'**
  String get pmStCancelled;

  /// No description provided for @pmStPending.
  ///
  /// In am, this message translates to:
  /// **'በመጠባበቅ ላይ'**
  String get pmStPending;

  /// No description provided for @pmStBlocked.
  ///
  /// In am, this message translates to:
  /// **'የታገደ'**
  String get pmStBlocked;

  /// No description provided for @pmReasonApproval.
  ///
  /// In am, this message translates to:
  /// **'ፈቃድ እየጠበቀ'**
  String get pmReasonApproval;

  /// No description provided for @pmReasonMaterials.
  ///
  /// In am, this message translates to:
  /// **'ቁሳቁስ እየጠበቀ'**
  String get pmReasonMaterials;

  /// No description provided for @pmReasonFinance.
  ///
  /// In am, this message translates to:
  /// **'ሒሳብ ክፍልን እየጠበቀ'**
  String get pmReasonFinance;

  /// No description provided for @pmReasonAnotherTask.
  ///
  /// In am, this message translates to:
  /// **'ሌላ ተግባር እየጠበቀ'**
  String get pmReasonAnotherTask;

  /// No description provided for @pmReasonAnotherDepartment.
  ///
  /// In am, this message translates to:
  /// **'ሌላ ክፍል እየጠበቀ'**
  String get pmReasonAnotherDepartment;

  /// No description provided for @pmReasonPaused.
  ///
  /// In am, this message translates to:
  /// **'ለጊዜው የቆመ'**
  String get pmReasonPaused;

  /// No description provided for @pmReasonOther.
  ///
  /// In am, this message translates to:
  /// **'ሌላ'**
  String get pmReasonOther;

  /// No description provided for @pmChangeStatus.
  ///
  /// In am, this message translates to:
  /// **'ሁኔታ ቀይር'**
  String get pmChangeStatus;

  /// No description provided for @pmPendingWhy.
  ///
  /// In am, this message translates to:
  /// **'ምን እየጠበቀ ነው?'**
  String get pmPendingWhy;

  /// No description provided for @pmBlockedWhy.
  ///
  /// In am, this message translates to:
  /// **'ምን እያገደው ነው?'**
  String get pmBlockedWhy;

  /// No description provided for @pmCompletionNote.
  ///
  /// In am, this message translates to:
  /// **'የማጠናቀቂያ ማስታወሻ (አማራጭ)'**
  String get pmCompletionNote;

  /// No description provided for @pmReason.
  ///
  /// In am, this message translates to:
  /// **'ምክንያት'**
  String get pmReason;

  /// No description provided for @pmMarkCompleted.
  ///
  /// In am, this message translates to:
  /// **'ተጠናቋል'**
  String get pmMarkCompleted;

  /// No description provided for @pmAskStatus.
  ///
  /// In am, this message translates to:
  /// **'በቻት ሁኔታውን ጠይቅ'**
  String get pmAskStatus;

  /// No description provided for @pmAskedStatus.
  ///
  /// In am, this message translates to:
  /// **'የሁኔታ ጥያቄ በክፍሉ ቻት ተልኳል'**
  String get pmAskedStatus;

  /// No description provided for @pmAssign.
  ///
  /// In am, this message translates to:
  /// **'ኃላፊ መድብ'**
  String get pmAssign;

  /// No description provided for @pmReassignReason.
  ///
  /// In am, this message translates to:
  /// **'የመቀየሩ ምክንያት (አማራጭ)'**
  String get pmReassignReason;

  /// No description provided for @pmCompletedBy.
  ///
  /// In am, this message translates to:
  /// **'በ{name} ተጠናቋል · {time}'**
  String pmCompletedBy(String name, String time);

  /// No description provided for @pmProgram.
  ///
  /// In am, this message translates to:
  /// **'የተያያዘ ፕሮግራም'**
  String get pmProgram;

  /// No description provided for @pmNoProgram.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራም የለም'**
  String get pmNoProgram;

  /// No description provided for @pmRelatedIssue.
  ///
  /// In am, this message translates to:
  /// **'የተያያዘ ችግር'**
  String get pmRelatedIssue;

  /// No description provided for @pmComments.
  ///
  /// In am, this message translates to:
  /// **'አስተያየቶች'**
  String get pmComments;

  /// No description provided for @pmAddComment.
  ///
  /// In am, this message translates to:
  /// **'አስተያየት ይጻፉ'**
  String get pmAddComment;

  /// No description provided for @pmReportIssue.
  ///
  /// In am, this message translates to:
  /// **'ችግር ሪፖርት አድርግ'**
  String get pmReportIssue;

  /// No description provided for @pmIssueTitle.
  ///
  /// In am, this message translates to:
  /// **'ችግሩ ምንድን ነው?'**
  String get pmIssueTitle;

  /// No description provided for @pmAssignee.
  ///
  /// In am, this message translates to:
  /// **'የሚፈታው'**
  String get pmAssignee;

  /// No description provided for @pmResolution.
  ///
  /// In am, this message translates to:
  /// **'መፍትሔ'**
  String get pmResolution;

  /// No description provided for @pmReporter.
  ///
  /// In am, this message translates to:
  /// **'ሪፖርት ያደረገው'**
  String get pmReporter;

  /// No description provided for @pmIsOpen.
  ///
  /// In am, this message translates to:
  /// **'ክፍት'**
  String get pmIsOpen;

  /// No description provided for @pmIsUnderReview.
  ///
  /// In am, this message translates to:
  /// **'በግምገማ ላይ'**
  String get pmIsUnderReview;

  /// No description provided for @pmIsAssigned.
  ///
  /// In am, this message translates to:
  /// **'ተመድቧል'**
  String get pmIsAssigned;

  /// No description provided for @pmIsResolved.
  ///
  /// In am, this message translates to:
  /// **'ተፈትቷል'**
  String get pmIsResolved;

  /// No description provided for @pmIsClosed.
  ///
  /// In am, this message translates to:
  /// **'ተዘግቷል'**
  String get pmIsClosed;

  /// No description provided for @pmSuggest.
  ///
  /// In am, this message translates to:
  /// **'ሐሳብ አቅርብ'**
  String get pmSuggest;

  /// No description provided for @pmSuggestionTitle.
  ///
  /// In am, this message translates to:
  /// **'ሐሳብዎ'**
  String get pmSuggestionTitle;

  /// No description provided for @pmSgSubmitted.
  ///
  /// In am, this message translates to:
  /// **'ቀርቧል'**
  String get pmSgSubmitted;

  /// No description provided for @pmSgAccepted.
  ///
  /// In am, this message translates to:
  /// **'ተቀባይነት አግኝቷል'**
  String get pmSgAccepted;

  /// No description provided for @pmSgRejected.
  ///
  /// In am, this message translates to:
  /// **'ውድቅ ተደርጓል'**
  String get pmSgRejected;

  /// No description provided for @pmSgConverted.
  ///
  /// In am, this message translates to:
  /// **'ወደ ተግባር ተቀይሯል'**
  String get pmSgConverted;

  /// No description provided for @pmAccept.
  ///
  /// In am, this message translates to:
  /// **'ተቀበል'**
  String get pmAccept;

  /// No description provided for @pmReject.
  ///
  /// In am, this message translates to:
  /// **'ውድቅ አድርግ'**
  String get pmReject;

  /// No description provided for @pmReview.
  ///
  /// In am, this message translates to:
  /// **'ለግምገማ'**
  String get pmReview;

  /// No description provided for @pmConvertToTask.
  ///
  /// In am, this message translates to:
  /// **'ወደ ተግባር ቀይር'**
  String get pmConvertToTask;

  /// No description provided for @pmChooseProject.
  ///
  /// In am, this message translates to:
  /// **'ፕሮጀክት ይምረጡ'**
  String get pmChooseProject;

  /// No description provided for @pmBudgetProposed.
  ///
  /// In am, this message translates to:
  /// **'የታቀደ በጀት'**
  String get pmBudgetProposed;

  /// No description provided for @pmBudgetApproved.
  ///
  /// In am, this message translates to:
  /// **'የጸደቀ በጀት'**
  String get pmBudgetApproved;

  /// No description provided for @pmBudgetSpent.
  ///
  /// In am, this message translates to:
  /// **'የወጣ'**
  String get pmBudgetSpent;

  /// No description provided for @pmBudgetRemaining.
  ///
  /// In am, this message translates to:
  /// **'የቀረ'**
  String get pmBudgetRemaining;

  /// No description provided for @pmBudgetUsed.
  ///
  /// In am, this message translates to:
  /// **'{percent}% ጥቅም ላይ ውሏል'**
  String pmBudgetUsed(String percent);

  /// No description provided for @pmBudgetPending.
  ///
  /// In am, this message translates to:
  /// **'በመጠባበቅ ላይ ያሉ ወጪዎች'**
  String get pmBudgetPending;

  /// No description provided for @pmBudgetNotApproved.
  ///
  /// In am, this message translates to:
  /// **'በጀቱ ገና አልጸደቀም'**
  String get pmBudgetNotApproved;

  /// No description provided for @pmBudgetOver.
  ///
  /// In am, this message translates to:
  /// **'በጀቱ አልፏል'**
  String get pmBudgetOver;

  /// No description provided for @pmBudgetLines.
  ///
  /// In am, this message translates to:
  /// **'የበጀት ምድቦች'**
  String get pmBudgetLines;

  /// No description provided for @pmEditBudget.
  ///
  /// In am, this message translates to:
  /// **'በጀት አዘጋጅ'**
  String get pmEditBudget;

  /// No description provided for @pmApproveBudget.
  ///
  /// In am, this message translates to:
  /// **'በጀቱን አጽድቅ'**
  String get pmApproveBudget;

  /// No description provided for @pmAmount.
  ///
  /// In am, this message translates to:
  /// **'መጠን'**
  String get pmAmount;

  /// No description provided for @pmCategory.
  ///
  /// In am, this message translates to:
  /// **'ምድብ'**
  String get pmCategory;

  /// No description provided for @pmDescription.
  ///
  /// In am, this message translates to:
  /// **'መግለጫ'**
  String get pmDescription;

  /// No description provided for @pmExpenseDate.
  ///
  /// In am, this message translates to:
  /// **'የወጪው ቀን'**
  String get pmExpenseDate;

  /// No description provided for @pmPaidBy.
  ///
  /// In am, this message translates to:
  /// **'የከፈለው'**
  String get pmPaidBy;

  /// No description provided for @pmReceipt.
  ///
  /// In am, this message translates to:
  /// **'ደረሰኝ'**
  String get pmReceipt;

  /// No description provided for @pmAttachReceipt.
  ///
  /// In am, this message translates to:
  /// **'ደረሰኝ አያይዝ'**
  String get pmAttachReceipt;

  /// No description provided for @pmNewExpense.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ወጪ'**
  String get pmNewExpense;

  /// No description provided for @pmExApproved.
  ///
  /// In am, this message translates to:
  /// **'ጸድቋል'**
  String get pmExApproved;

  /// No description provided for @pmExRecorded.
  ///
  /// In am, this message translates to:
  /// **'ተመዝግቧል'**
  String get pmExRecorded;

  /// No description provided for @pmApprove.
  ///
  /// In am, this message translates to:
  /// **'አጽድቅ'**
  String get pmApprove;

  /// No description provided for @pmRecord.
  ///
  /// In am, this message translates to:
  /// **'መዝግብ'**
  String get pmRecord;

  /// No description provided for @pmOverride.
  ///
  /// In am, this message translates to:
  /// **'ከበጀት በላይ ቢሆንም አጽድቅ (ምክንያት ያስፈልጋል)'**
  String get pmOverride;

  /// No description provided for @pmRequestAdjustment.
  ///
  /// In am, this message translates to:
  /// **'የበጀት ጭማሪ ጠይቅ'**
  String get pmRequestAdjustment;

  /// No description provided for @pmAdjustments.
  ///
  /// In am, this message translates to:
  /// **'የበጀት ማሻሻያዎች'**
  String get pmAdjustments;

  /// No description provided for @pmAdditional.
  ///
  /// In am, this message translates to:
  /// **'ተጨማሪ መጠን'**
  String get pmAdditional;

  /// No description provided for @pmUploadFile.
  ///
  /// In am, this message translates to:
  /// **'ፋይል ጫን'**
  String get pmUploadFile;

  /// No description provided for @pmMembers.
  ///
  /// In am, this message translates to:
  /// **'አባላት'**
  String get pmMembers;

  /// No description provided for @pmEditTeam.
  ///
  /// In am, this message translates to:
  /// **'ቡድኑን አስተካክል'**
  String get pmEditTeam;

  /// No description provided for @pmRoleLeader.
  ///
  /// In am, this message translates to:
  /// **'መሪ'**
  String get pmRoleLeader;

  /// No description provided for @pmRoleAdmin.
  ///
  /// In am, this message translates to:
  /// **'አስተዳዳሪ'**
  String get pmRoleAdmin;

  /// No description provided for @pmRoleMember.
  ///
  /// In am, this message translates to:
  /// **'አባል'**
  String get pmRoleMember;

  /// No description provided for @pmDeleteProjectConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህን ፕሮጀክት መሰረዝ ይፈልጋሉ?'**
  String get pmDeleteProjectConfirm;

  /// No description provided for @pmDeleteTaskConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህን ተግባር መሰረዝ ይፈልጋሉ?'**
  String get pmDeleteTaskConfirm;

  /// No description provided for @pmOfflineQueued.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ ተቀምጧል፤ ኢንተርኔት ሲገኝ ይላካል'**
  String get pmOfflineQueued;

  /// No description provided for @pmWaitingSync.
  ///
  /// In am, this message translates to:
  /// **'ለመላክ በመጠባበቅ ላይ'**
  String get pmWaitingSync;

  /// No description provided for @pmSyncConflict.
  ///
  /// In am, this message translates to:
  /// **'ተግባሩ በሌላ ሰው ተቀይሯል፤ ከመስመር ውጭ ያደረጉት ለውጥ አልተተገበረም። እባክዎ እንደገና ይመልከቱ።'**
  String get pmSyncConflict;

  /// No description provided for @syncWhatTask.
  ///
  /// In am, this message translates to:
  /// **'የተግባር ለውጥ'**
  String get syncWhatTask;

  /// No description provided for @pmFilters.
  ///
  /// In am, this message translates to:
  /// **'ማጣሪያዎች'**
  String get pmFilters;

  /// No description provided for @pmFilterUser.
  ///
  /// In am, this message translates to:
  /// **'ሰው'**
  String get pmFilterUser;

  /// No description provided for @pmFilterProject.
  ///
  /// In am, this message translates to:
  /// **'ፕሮጀክት'**
  String get pmFilterProject;

  /// No description provided for @pmFilterTask.
  ///
  /// In am, this message translates to:
  /// **'ተግባር'**
  String get pmFilterTask;

  /// No description provided for @pmFilterDate.
  ///
  /// In am, this message translates to:
  /// **'ቀን'**
  String get pmFilterDate;

  /// No description provided for @pmFilterBudget.
  ///
  /// In am, this message translates to:
  /// **'በጀት'**
  String get pmFilterBudget;

  /// No description provided for @pmFilterCompletion.
  ///
  /// In am, this message translates to:
  /// **'የማጠናቀቂያ መጠን'**
  String get pmFilterCompletion;

  /// No description provided for @pmApply.
  ///
  /// In am, this message translates to:
  /// **'ተግብር'**
  String get pmApply;

  /// No description provided for @pmClearFilters.
  ///
  /// In am, this message translates to:
  /// **'ማጣሪያዎችን አጽዳ'**
  String get pmClearFilters;

  /// No description provided for @pmAll.
  ///
  /// In am, this message translates to:
  /// **'ሁሉም'**
  String get pmAll;

  /// No description provided for @pmActive.
  ///
  /// In am, this message translates to:
  /// **'ንቁ'**
  String get pmActive;

  /// No description provided for @pmToday.
  ///
  /// In am, this message translates to:
  /// **'ዛሬ'**
  String get pmToday;

  /// No description provided for @pmThisWeek.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ሳምንት'**
  String get pmThisWeek;

  /// No description provided for @pmThisMonth.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ወር'**
  String get pmThisMonth;

  /// No description provided for @pmCustomRange.
  ///
  /// In am, this message translates to:
  /// **'የተወሰነ ጊዜ'**
  String get pmCustomRange;

  /// No description provided for @pmDateField.
  ///
  /// In am, this message translates to:
  /// **'የሚመለከተው ቀን'**
  String get pmDateField;

  /// No description provided for @pmByDeadline.
  ///
  /// In am, this message translates to:
  /// **'ማብቂያ'**
  String get pmByDeadline;

  /// No description provided for @pmByCreated.
  ///
  /// In am, this message translates to:
  /// **'የተፈጠረበት'**
  String get pmByCreated;

  /// No description provided for @pmByStart.
  ///
  /// In am, this message translates to:
  /// **'የሚጀምርበት'**
  String get pmByStart;

  /// No description provided for @pmByCompleted.
  ///
  /// In am, this message translates to:
  /// **'የተጠናቀቀበት'**
  String get pmByCompleted;

  /// No description provided for @pmWithinBudget.
  ///
  /// In am, this message translates to:
  /// **'በበጀት ውስጥ'**
  String get pmWithinBudget;

  /// No description provided for @pmNoBudget.
  ///
  /// In am, this message translates to:
  /// **'በጀት የሌለው'**
  String get pmNoBudget;

  /// No description provided for @pmMinProgress.
  ///
  /// In am, this message translates to:
  /// **'ቢያንስ {n}%'**
  String pmMinProgress(String n);

  /// No description provided for @pmSummary.
  ///
  /// In am, this message translates to:
  /// **'ማጠቃለያ'**
  String get pmSummary;

  /// No description provided for @pmByUser.
  ///
  /// In am, this message translates to:
  /// **'በሰው'**
  String get pmByUser;

  /// No description provided for @pmProjectsInvolved.
  ///
  /// In am, this message translates to:
  /// **'ፕሮጀክቶች'**
  String get pmProjectsInvolved;

  /// No description provided for @pmAssigned.
  ///
  /// In am, this message translates to:
  /// **'የተሰጡ'**
  String get pmAssigned;

  /// No description provided for @pmTotal.
  ///
  /// In am, this message translates to:
  /// **'ጠቅላላ'**
  String get pmTotal;

  /// No description provided for @pmCreatedBy.
  ///
  /// In am, this message translates to:
  /// **'ያዘጋጀው'**
  String get pmCreatedBy;

  /// No description provided for @pmLiveUpdated.
  ///
  /// In am, this message translates to:
  /// **'ተሻሽሏል'**
  String get pmLiveUpdated;

  /// No description provided for @pmTaskBot.
  ///
  /// In am, this message translates to:
  /// **'🤖 የተግባር ረዳት'**
  String get pmTaskBot;

  /// No description provided for @pmBotNotAllowed.
  ///
  /// In am, this message translates to:
  /// **'🔒 ይህን ተግባር ለማሻሻል ፈቃድ የለዎትም።'**
  String get pmBotNotAllowed;

  /// No description provided for @pmBotUpdated.
  ///
  /// In am, this message translates to:
  /// **'✅ ተግባሩ ተሻሽሏል'**
  String get pmBotUpdated;

  /// No description provided for @pmOpenTask.
  ///
  /// In am, this message translates to:
  /// **'ተግባሩን ክፈት'**
  String get pmOpenTask;

  /// No description provided for @pmPeople.
  ///
  /// In am, this message translates to:
  /// **'ሰዎች'**
  String get pmPeople;

  /// No description provided for @pmSelectPeople.
  ///
  /// In am, this message translates to:
  /// **'ሰዎችን ይምረጡ'**
  String get pmSelectPeople;

  /// No description provided for @pmDepartment.
  ///
  /// In am, this message translates to:
  /// **'ክፍል'**
  String get pmDepartment;

  /// No description provided for @errTaskUpdateForbidden.
  ///
  /// In am, this message translates to:
  /// **'🔒 ይህን ተግባር ለማሻሻል ፈቃድ የለዎትም።'**
  String get errTaskUpdateForbidden;

  /// No description provided for @errProjectForbidden.
  ///
  /// In am, this message translates to:
  /// **'ይህን ለማድረግ ፈቃድ የለዎትም።'**
  String get errProjectForbidden;

  /// No description provided for @errTaskAfterProjectDeadline.
  ///
  /// In am, this message translates to:
  /// **'የተግባሩ ማብቂያ ከፕሮጀክቱ ማብቂያ በኋላ ሊሆን አይችልም።'**
  String get errTaskAfterProjectDeadline;

  /// No description provided for @errPendingReasonRequired.
  ///
  /// In am, this message translates to:
  /// **'የመጠበቂያ ምክንያት ያስፈልጋል።'**
  String get errPendingReasonRequired;

  /// No description provided for @errBlockerRequired.
  ///
  /// In am, this message translates to:
  /// **'ምን እያገደው እንደሆነ ይጻፉ።'**
  String get errBlockerRequired;

  /// No description provided for @errUserNotInDepartment.
  ///
  /// In am, this message translates to:
  /// **'ይህ ሰው የክፍሉ አባል አይደለም።'**
  String get errUserNotInDepartment;

  /// No description provided for @errOverBudget.
  ///
  /// In am, this message translates to:
  /// **'ይህ ወጪ ከጸደቀው በጀት ያልፋል። የበጀት ጭማሪ ያጽድቁ ወይም በምክንያት ይፍቀዱ።'**
  String get errOverBudget;

  /// No description provided for @errTaskChanged.
  ///
  /// In am, this message translates to:
  /// **'ተግባሩ በሌላ ሰው ተቀይሯል። እባክዎ እንደገና ይሞክሩ።'**
  String get errTaskChanged;

  /// No description provided for @errResolutionRequired.
  ///
  /// In am, this message translates to:
  /// **'መፍትሔውን ይጻፉ።'**
  String get errResolutionRequired;

  /// No description provided for @errProjectClosed.
  ///
  /// In am, this message translates to:
  /// **'ፕሮጀክቱ ተዘግቷል።'**
  String get errProjectClosed;

  /// No description provided for @errExpenseApproveForbidden.
  ///
  /// In am, this message translates to:
  /// **'ወጪ ማጽደቅ የሚችለው የሒሳብ ክፍል ብቻ ነው።'**
  String get errExpenseApproveForbidden;

  /// No description provided for @perm_projects_view.
  ///
  /// In am, this message translates to:
  /// **'የክፍል ፕሮጀክቶችን ማየት'**
  String get perm_projects_view;

  /// No description provided for @perm_projects_manage.
  ///
  /// In am, this message translates to:
  /// **'ፕሮጀክቶችን፣ ተግባራትን እና ቡድኖችን ማስተዳደር'**
  String get perm_projects_manage;

  /// No description provided for @perm_projects_expenses_approve.
  ///
  /// In am, this message translates to:
  /// **'የፕሮጀክት በጀትና ወጪ ማጽደቅ (ሒሳብ)'**
  String get perm_projects_expenses_approve;

  /// No description provided for @perm_projects_reports.
  ///
  /// In am, this message translates to:
  /// **'የፕሮጀክት ሪፖርቶችን ማየት'**
  String get perm_projects_reports;

  /// No description provided for @perm_projects_all_departments.
  ///
  /// In am, this message translates to:
  /// **'የሁሉንም ክፍሎች ፕሮጀክቶች ማየት'**
  String get perm_projects_all_departments;

  /// No description provided for @libTitle.
  ///
  /// In am, this message translates to:
  /// **'ቤተ መጻሕፍት'**
  String get libTitle;

  /// No description provided for @libDigital.
  ///
  /// In am, this message translates to:
  /// **'ዲጂታል መጻሕፍት'**
  String get libDigital;

  /// No description provided for @libPhysical.
  ///
  /// In am, this message translates to:
  /// **'መጻሕፍት (ለመዋስ)'**
  String get libPhysical;

  /// No description provided for @libMine.
  ///
  /// In am, this message translates to:
  /// **'የእኔ'**
  String get libMine;

  /// No description provided for @libNoBooks.
  ///
  /// In am, this message translates to:
  /// **'መጽሐፍ የለም'**
  String get libNoBooks;

  /// No description provided for @libDownload.
  ///
  /// In am, this message translates to:
  /// **'አውርድ'**
  String get libDownload;

  /// No description provided for @libOpen.
  ///
  /// In am, this message translates to:
  /// **'ክፈት'**
  String get libOpen;

  /// No description provided for @libDownloaded.
  ///
  /// In am, this message translates to:
  /// **'ወርዷል'**
  String get libDownloaded;

  /// No description provided for @libDeleteDownload.
  ///
  /// In am, this message translates to:
  /// **'የወረደውን አጥፋ'**
  String get libDeleteDownload;

  /// No description provided for @libRequest.
  ///
  /// In am, this message translates to:
  /// **'ጠይቅ'**
  String get libRequest;

  /// No description provided for @libRequestTitle.
  ///
  /// In am, this message translates to:
  /// **'መጽሐፉን መጠየቅ'**
  String get libRequestTitle;

  /// No description provided for @libRequestNote.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻ (አማራጭ)'**
  String get libRequestNote;

  /// No description provided for @libNeededOn.
  ///
  /// In am, this message translates to:
  /// **'የሚፈልጉበት ቀን (አማራጭ)'**
  String get libNeededOn;

  /// No description provided for @libRequested.
  ///
  /// In am, this message translates to:
  /// **'ተጠይቋል'**
  String get libRequested;

  /// No description provided for @libReqApproved.
  ///
  /// In am, this message translates to:
  /// **'ተዘጋጅቷል — መጥተው በፊርማ ይውሰዱ'**
  String get libReqApproved;

  /// No description provided for @libReqRejected.
  ///
  /// In am, this message translates to:
  /// **'አልተቀበለም'**
  String get libReqRejected;

  /// No description provided for @libReqIssued.
  ///
  /// In am, this message translates to:
  /// **'ተሰጥቷል'**
  String get libReqIssued;

  /// No description provided for @libReqCancelled.
  ///
  /// In am, this message translates to:
  /// **'ተሰርዟል'**
  String get libReqCancelled;

  /// No description provided for @libAvailable.
  ///
  /// In am, this message translates to:
  /// **'{count} ይገኛል'**
  String libAvailable(String count);

  /// No description provided for @libNoneAvailable.
  ///
  /// In am, this message translates to:
  /// **'አሁን የለም'**
  String get libNoneAvailable;

  /// No description provided for @libMyRequests.
  ///
  /// In am, this message translates to:
  /// **'የእኔ ጥያቄዎች'**
  String get libMyRequests;

  /// No description provided for @libNoRequests.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄ የለም'**
  String get libNoRequests;

  /// No description provided for @libCancelRequest.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄውን ሰርዝ'**
  String get libCancelRequest;

  /// No description provided for @libRequestSent.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄዎ ተልኳል'**
  String get libRequestSent;

  /// No description provided for @libAuthor.
  ///
  /// In am, this message translates to:
  /// **'ደራሲ'**
  String get libAuthor;

  /// No description provided for @libDownloads.
  ///
  /// In am, this message translates to:
  /// **'{count} ጊዜ ወርዷል'**
  String libDownloads(String count);

  /// No description provided for @libRequests.
  ///
  /// In am, this message translates to:
  /// **'የመጽሐፍ ጥያቄዎች'**
  String get libRequests;

  /// No description provided for @libApprove.
  ///
  /// In am, this message translates to:
  /// **'አጽድቅ'**
  String get libApprove;

  /// No description provided for @libReject.
  ///
  /// In am, this message translates to:
  /// **'አትቀበል'**
  String get libReject;

  /// No description provided for @libHandOver.
  ///
  /// In am, this message translates to:
  /// **'በፊርማ አስረክብ'**
  String get libHandOver;

  /// No description provided for @libLoanDays.
  ///
  /// In am, this message translates to:
  /// **'የብድር ቀናት'**
  String get libLoanDays;

  /// No description provided for @libBookKind.
  ///
  /// In am, this message translates to:
  /// **'የመጽሐፍ ዓይነት'**
  String get libBookKind;

  /// No description provided for @libKindPhysical.
  ///
  /// In am, this message translates to:
  /// **'ታትሞ የተዘጋጀ'**
  String get libKindPhysical;

  /// No description provided for @libKindDigital.
  ///
  /// In am, this message translates to:
  /// **'ዲጂታል (PDF)'**
  String get libKindDigital;

  /// No description provided for @libUploadPdf.
  ///
  /// In am, this message translates to:
  /// **'PDF ጫን'**
  String get libUploadPdf;

  /// No description provided for @libReplacePdf.
  ///
  /// In am, this message translates to:
  /// **'PDF ቀይር'**
  String get libReplacePdf;

  /// No description provided for @libPdfUploaded.
  ///
  /// In am, this message translates to:
  /// **'PDF ተጭኗል'**
  String get libPdfUploaded;

  /// No description provided for @libSaveFirst.
  ///
  /// In am, this message translates to:
  /// **'መጀመሪያ ያስቀምጡ'**
  String get libSaveFirst;

  /// No description provided for @libBooks.
  ///
  /// In am, this message translates to:
  /// **'መጻሕፍት'**
  String get libBooks;

  /// No description provided for @errBookIsDigital.
  ///
  /// In am, this message translates to:
  /// **'ዲጂታል መጻሕፍት ይወርዳሉ እንጂ አይዋሱም።'**
  String get errBookIsDigital;

  /// No description provided for @errRequestExists.
  ///
  /// In am, this message translates to:
  /// **'ይህን መጽሐፍ ቀድመው ጠይቀዋል።'**
  String get errRequestExists;

  /// No description provided for @errRequestClosed.
  ///
  /// In am, this message translates to:
  /// **'ይህ ጥያቄ ተዘግቷል።'**
  String get errRequestClosed;

  /// No description provided for @regTitle.
  ///
  /// In am, this message translates to:
  /// **'የተማሪዎች ምዝገባ'**
  String get regTitle;

  /// No description provided for @regSubtitle.
  ///
  /// In am, this message translates to:
  /// **'አባላትን ከኮርሶቻቸው ጋር ይመዝግቡ'**
  String get regSubtitle;

  /// No description provided for @regChooseClass.
  ///
  /// In am, this message translates to:
  /// **'ክፍል (ኮርሶች) ይምረጡ'**
  String get regChooseClass;

  /// No description provided for @regCourses.
  ///
  /// In am, this message translates to:
  /// **'ኮርሶች'**
  String get regCourses;

  /// No description provided for @regExisting.
  ///
  /// In am, this message translates to:
  /// **'ያሉ አባላትን መዝግብ'**
  String get regExisting;

  /// No description provided for @regNewMember.
  ///
  /// In am, this message translates to:
  /// **'አዲስ አባል መዝግብ'**
  String get regNewMember;

  /// No description provided for @regStudents.
  ///
  /// In am, this message translates to:
  /// **'የተመዘገቡ ተማሪዎች'**
  String get regStudents;

  /// No description provided for @regDone.
  ///
  /// In am, this message translates to:
  /// **'{count} ተመዝግበዋል'**
  String regDone(String count);

  /// No description provided for @regAlready.
  ///
  /// In am, this message translates to:
  /// **'{count} ቀድመው ተመዝግበው ነበር'**
  String regAlready(String count);

  /// No description provided for @regTempPin.
  ///
  /// In am, this message translates to:
  /// **'ጊዜያዊ ፒን'**
  String get regTempPin;

  /// No description provided for @regTempPinHint.
  ///
  /// In am, this message translates to:
  /// **'ለአባሉ ይስጡ። በመጀመሪያ ሲገቡ ፒኑን ይቀይራሉ።'**
  String get regTempPinHint;

  /// No description provided for @regRemoveConfirm.
  ///
  /// In am, this message translates to:
  /// **'ተማሪውን ከዚህ ክፍል ማስወጣት ይፈልጋሉ?'**
  String get regRemoveConfirm;

  /// No description provided for @regNoClasses.
  ///
  /// In am, this message translates to:
  /// **'ንቁ ክፍል የለም'**
  String get regNoClasses;

  /// No description provided for @courseManagement.
  ///
  /// In am, this message translates to:
  /// **'የኮርስ አስተዳደር'**
  String get courseManagement;

  /// No description provided for @eduSection.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት'**
  String get eduSection;

  /// No description provided for @adminGroupPeople.
  ///
  /// In am, this message translates to:
  /// **'ሰዎች እና ፈቃዶች'**
  String get adminGroupPeople;

  /// No description provided for @adminGroupContent.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር እና ይዘት'**
  String get adminGroupContent;

  /// No description provided for @adminGroupPrograms.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራሞች እና መገኘት'**
  String get adminGroupPrograms;

  /// No description provided for @adminGroupEducation.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት'**
  String get adminGroupEducation;

  /// No description provided for @adminGroupLibrary.
  ///
  /// In am, this message translates to:
  /// **'ቤተ መጻሕፍት እና ንብረት'**
  String get adminGroupLibrary;

  /// No description provided for @adminGroupDepartments.
  ///
  /// In am, this message translates to:
  /// **'ክፍሎች፣ ፕሮጀክቶች እና ክፍያ'**
  String get adminGroupDepartments;

  /// No description provided for @adminGroupChoir.
  ///
  /// In am, this message translates to:
  /// **'የመዝሙር አገልግሎት'**
  String get adminGroupChoir;

  /// No description provided for @adminGroupOversight.
  ///
  /// In am, this message translates to:
  /// **'ክትትል'**
  String get adminGroupOversight;

  /// No description provided for @adminGroupSystem.
  ///
  /// In am, this message translates to:
  /// **'ሥርዓት'**
  String get adminGroupSystem;

  /// No description provided for @perm_education_register.
  ///
  /// In am, this message translates to:
  /// **'ተማሪዎችን ከኮርሶቻቸው ጋር መመዝገብ'**
  String get perm_education_register;

  /// No description provided for @libHomeSub.
  ///
  /// In am, this message translates to:
  /// **'ዲጂታል መጻሕፍትን ያውርዱ፣ የሚታተሙ መጻሕፍትን ይጠይቁ፣ የተዋሷቸውን ይመልከቱ'**
  String get libHomeSub;

  /// No description provided for @libRead.
  ///
  /// In am, this message translates to:
  /// **'አንብብ'**
  String get libRead;

  /// No description provided for @libDownloadAgain.
  ///
  /// In am, this message translates to:
  /// **'ይህ መጽሐፍ በዚህ መሣሪያ ላይ የለም። እባክዎ እንደገና ያውርዱት።'**
  String get libDownloadAgain;

  /// No description provided for @paymentsYearFull.
  ///
  /// In am, this message translates to:
  /// **'{year} ዓ.ም.\nየተከፈለ፦ 12 ወራት\nያልተከፈለ፦ 0 ወራት\n✓ ሁሉም ወራት ተከፍለዋል'**
  String paymentsYearFull(String year);

  /// No description provided for @paymentsYearPartial.
  ///
  /// In am, this message translates to:
  /// **'{year} ዓ.ም.\nየተከፈለ፦ {paid} ወራት\nያልተከፈለ፦ {unpaid} ወራት'**
  String paymentsYearPartial(String year, String paid, String unpaid);

  /// No description provided for @paymentsYearPaidList.
  ///
  /// In am, this message translates to:
  /// **'የተከፈሉ ወራት፦ {months}'**
  String paymentsYearPaidList(String months);

  /// No description provided for @paymentsYearNone.
  ///
  /// In am, this message translates to:
  /// **'{year} ዓ.ም.\nየተከፈለ፦ 0 ወራት\nያልተከፈለ፦ 12 ወራት'**
  String paymentsYearNone(String year);

  /// No description provided for @promoteToAdmin.
  ///
  /// In am, this message translates to:
  /// **'አስተዳዳሪ አድርግ'**
  String get promoteToAdmin;

  /// No description provided for @promoteChooseRole.
  ///
  /// In am, this message translates to:
  /// **'ሚና ይምረጡ'**
  String get promoteChooseRole;

  /// No description provided for @promoteHint.
  ///
  /// In am, this message translates to:
  /// **'{name} አስተዳዳሪ ይሆናሉ፤ የአባልነት አገልግሎቶቻቸው በሙሉ ይቀጥላሉ። እንደገና ገብተው ፒናቸውን ያዘጋጃሉ።'**
  String promoteHint(String name);

  /// No description provided for @promoted.
  ///
  /// In am, this message translates to:
  /// **'አስተዳዳሪ ሆነዋል'**
  String get promoted;

  /// No description provided for @demoteToMember.
  ///
  /// In am, this message translates to:
  /// **'ወደ አባልነት መልስ'**
  String get demoteToMember;

  /// No description provided for @demoteConfirm.
  ///
  /// In am, this message translates to:
  /// **'{name} አስተዳዳሪነታቸው ተነስቶ ወደ አባልነት ይመለሱ?'**
  String demoteConfirm(String name);

  /// No description provided for @demoted.
  ///
  /// In am, this message translates to:
  /// **'ወደ አባልነት ተመልሰዋል'**
  String get demoted;

  /// No description provided for @errAlreadyAdmin.
  ///
  /// In am, this message translates to:
  /// **'ይህ ሰው አስቀድሞ አስተዳዳሪ ነው።'**
  String get errAlreadyAdmin;

  /// No description provided for @adminBadge.
  ///
  /// In am, this message translates to:
  /// **'አስተዳዳሪ'**
  String get adminBadge;

  /// No description provided for @requestProfileChange.
  ///
  /// In am, this message translates to:
  /// **'የመረጃ ለውጥ ጠይቅ'**
  String get requestProfileChange;

  /// No description provided for @requestProfileChangeHint.
  ///
  /// In am, this message translates to:
  /// **'መቀየር የሚፈልጉትን ያስተካክሉ። የተቀየሩት ብቻ ለአስተዳዳሪ ለማጽደቅ ይላካሉ፤ የቀድሞ መረጃዎ አይጠፋም።'**
  String get requestProfileChangeHint;

  /// No description provided for @changeNote.
  ///
  /// In am, this message translates to:
  /// **'ለአስተዳዳሪው መልእክት (ካለ)'**
  String get changeNote;

  /// No description provided for @sendForApproval.
  ///
  /// In am, this message translates to:
  /// **'ለማጽደቅ ላክ'**
  String get sendForApproval;

  /// No description provided for @changeRequestSent.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄዎ ተልኳል'**
  String get changeRequestSent;

  /// No description provided for @myChangeRequests.
  ///
  /// In am, this message translates to:
  /// **'የለውጥ ጥያቄዎቼ'**
  String get myChangeRequests;

  /// No description provided for @changeHistory.
  ///
  /// In am, this message translates to:
  /// **'የለውጥ ታሪክ'**
  String get changeHistory;

  /// No description provided for @noChangeHistory.
  ///
  /// In am, this message translates to:
  /// **'ምንም ለውጥ አልተመዘገበም'**
  String get noChangeHistory;

  /// No description provided for @historyByRequest.
  ///
  /// In am, this message translates to:
  /// **'በአባሉ ጥያቄ (ጸድቋል)'**
  String get historyByRequest;

  /// No description provided for @historyByAdmin.
  ///
  /// In am, this message translates to:
  /// **'በአስተዳዳሪ'**
  String get historyByAdmin;

  /// No description provided for @historyBySelf.
  ///
  /// In am, this message translates to:
  /// **'በራሳቸው'**
  String get historyBySelf;

  /// No description provided for @declineReason.
  ///
  /// In am, this message translates to:
  /// **'ያልተቀበሉበት ምክንያት (ለአባሉ ይታያል)'**
  String get declineReason;

  /// No description provided for @approveNote.
  ///
  /// In am, this message translates to:
  /// **'ማስታወሻ (ካለ)'**
  String get approveNote;

  /// No description provided for @errNoChanges.
  ///
  /// In am, this message translates to:
  /// **'ምንም ለውጥ የለም።'**
  String get errNoChanges;

  /// No description provided for @playerOptions.
  ///
  /// In am, this message translates to:
  /// **'አማራጮች'**
  String get playerOptions;

  /// No description provided for @playbackSpeed.
  ///
  /// In am, this message translates to:
  /// **'የመጫወቻ ፍጥነት'**
  String get playbackSpeed;

  /// No description provided for @sleepTimer.
  ///
  /// In am, this message translates to:
  /// **'ሰዓት ቆጣሪ (ማቆሚያ)'**
  String get sleepTimer;

  /// No description provided for @off.
  ///
  /// In am, this message translates to:
  /// **'ጠፍቷል'**
  String get off;

  /// No description provided for @sleepEndOfMezmur.
  ///
  /// In am, this message translates to:
  /// **'መዝሙሩ ሲያልቅ'**
  String get sleepEndOfMezmur;

  /// No description provided for @upNext.
  ///
  /// In am, this message translates to:
  /// **'ቀጣይ መዝሙሮች'**
  String get upNext;

  /// No description provided for @syncedLyrics.
  ///
  /// In am, this message translates to:
  /// **'ከሙዚቃው ጋር የሚሄድ ግጥም (.lrc)'**
  String get syncedLyrics;

  /// No description provided for @syncedLyricsHint.
  ///
  /// In am, this message translates to:
  /// **'ግጥሙ ከድምፁ ጋር እየበራ ይታያል። .lrc ፋይል ይጫኑ፣ ይለጥፉ፣ ወይም በመተግበሪያው ውስጥ ያዘጋጁ (ሌላ መተግበሪያ አያስፈልግም)።'**
  String get syncedLyricsHint;

  /// No description provided for @lrcUpload.
  ///
  /// In am, this message translates to:
  /// **'.lrc ፋይል ጫን'**
  String get lrcUpload;

  /// No description provided for @lrcMake.
  ///
  /// In am, this message translates to:
  /// **'በመተግበሪያው አዘጋጅ'**
  String get lrcMake;

  /// No description provided for @lrcNeedsAudio.
  ///
  /// In am, this message translates to:
  /// **'በመተግበሪያው ለማዘጋጀት መጀመሪያ ድምፅ ይጫኑ።'**
  String get lrcNeedsAudio;

  /// No description provided for @lrcInvalid.
  ///
  /// In am, this message translates to:
  /// **'ትክክለኛ .lrc አይደለም (ለምሳሌ [00:12.50] የሚል የጊዜ ምልክት ያስፈልጋል)'**
  String get lrcInvalid;

  /// No description provided for @lrcLoaded.
  ///
  /// In am, this message translates to:
  /// **'{count} መስመሮች ተጭነዋል — ለማስቀመጥ «አስቀምጥ» ይጫኑ'**
  String lrcLoaded(String count);

  /// No description provided for @lrcLines.
  ///
  /// In am, this message translates to:
  /// **'{count} በጊዜ የተቀመጡ መስመሮች'**
  String lrcLines(String count);

  /// No description provided for @lrcMaker.
  ///
  /// In am, this message translates to:
  /// **'የግጥም ጊዜ ማዘጋጃ'**
  String get lrcMaker;

  /// No description provided for @lrcMakerHint.
  ///
  /// In am, this message translates to:
  /// **'ድምፁ ሲጫወት እያንዳንዱ መስመር ሲጀመር «ቀጣይ መስመር» ይጫኑ። ከተሳሳቱ «መልስ» ይጫኑ።'**
  String get lrcMakerHint;

  /// No description provided for @lrcNoLyrics.
  ///
  /// In am, this message translates to:
  /// **'መጀመሪያ ግጥሙን ይጻፉ።'**
  String get lrcNoLyrics;

  /// No description provided for @lrcNextLine.
  ///
  /// In am, this message translates to:
  /// **'ቀጣይ መስመር'**
  String get lrcNextLine;

  /// No description provided for @lrcAllTimed.
  ///
  /// In am, this message translates to:
  /// **'ሁሉም መስመሮች ተዘጋጅተዋል'**
  String get lrcAllTimed;

  /// No description provided for @lrcUndo.
  ///
  /// In am, this message translates to:
  /// **'መልስ'**
  String get lrcUndo;

  /// No description provided for @lrcRestart.
  ///
  /// In am, this message translates to:
  /// **'እንደገና ጀምር'**
  String get lrcRestart;

  /// No description provided for @lrcRestartConfirm.
  ///
  /// In am, this message translates to:
  /// **'የተዘጋጁት ጊዜዎች ይጥፉ እና እንደገና ይጀመር?'**
  String get lrcRestartConfirm;

  /// No description provided for @lrcBack5.
  ///
  /// In am, this message translates to:
  /// **'5 ሰከንድ ወደ ኋላ'**
  String get lrcBack5;

  /// No description provided for @lrcProgress.
  ///
  /// In am, this message translates to:
  /// **'{done} / {total} መስመሮች'**
  String lrcProgress(String done, String total);

  /// No description provided for @adminGroupUsers.
  ///
  /// In am, this message translates to:
  /// **'የተጠቃሚዎች አስተዳደር'**
  String get adminGroupUsers;

  /// No description provided for @adminGroupMemberServices.
  ///
  /// In am, this message translates to:
  /// **'የአባላትና እንቅስቃሴ አስተዳደር'**
  String get adminGroupMemberServices;

  /// No description provided for @adminGroupDepartmentsMgmt.
  ///
  /// In am, this message translates to:
  /// **'የክፍሎች አስተዳደር'**
  String get adminGroupDepartmentsMgmt;

  /// No description provided for @adminGroupProperties.
  ///
  /// In am, this message translates to:
  /// **'ንብረቶች'**
  String get adminGroupProperties;

  /// No description provided for @adminGroupEducationMgmt.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት አስተዳደር'**
  String get adminGroupEducationMgmt;

  /// No description provided for @adminGroupMezmurMgmt.
  ///
  /// In am, this message translates to:
  /// **'የመዝሙር አስተዳደር'**
  String get adminGroupMezmurMgmt;

  /// No description provided for @adminGroupPromotion.
  ///
  /// In am, this message translates to:
  /// **'የማስተዋወቅ አስተዳደር'**
  String get adminGroupPromotion;

  /// No description provided for @adminGroupAdministration.
  ///
  /// In am, this message translates to:
  /// **'የአስተዳደር አስተዳደር'**
  String get adminGroupAdministration;

  /// No description provided for @eduManageCourses.
  ///
  /// In am, this message translates to:
  /// **'ኮርሶች'**
  String get eduManageCourses;

  /// No description provided for @eduManageClasses.
  ///
  /// In am, this message translates to:
  /// **'ክፍሎች (ክላሶች)'**
  String get eduManageClasses;

  /// No description provided for @eduManageLibrary.
  ///
  /// In am, this message translates to:
  /// **'ቤተ መጻሕፍት'**
  String get eduManageLibrary;

  /// No description provided for @serviceManagement.
  ///
  /// In am, this message translates to:
  /// **'የአገልግሎት አስተዳደር'**
  String get serviceManagement;

  /// No description provided for @eduAllCourses.
  ///
  /// In am, this message translates to:
  /// **'ሁሉም ኮርሶች'**
  String get eduAllCourses;

  /// No description provided for @importMezmursHelp2.
  ///
  /// In am, this message translates to:
  /// **'አንድ መዝሙር በአንድ መስመር፦ ርዕስ፣ ምድብ፣ ግጥም (በአንድ ሕዋስ ውስጥ ብዙ መስመሮች — Alt+Enter)፣ መለያዎች፣ ሁኔታ። የኤክሴል ቅጹ ምሳሌዎችንና ያሉትን ምድቦች ይዟል።'**
  String get importMezmursHelp2;

  /// No description provided for @importUsersHelp2.
  ///
  /// In am, this message translates to:
  /// **'አንድ አባል በአንድ መስመር፦ ሙሉ ስም፣ ስልክ፣ ኢሜይል፣ ፒን (ከ4 እስከ 6 ቁጥሮች፤ ባዶ = ጊዜያዊ)፣ የአባል ምድብ፣ ተማሪ/ሠራተኛ፣ ጾታ። ተቀባይነት ያላቸው እሴቶች በቅጹ ውስጥ አሉ።'**
  String get importUsersHelp2;

  /// No description provided for @importStepTemplate.
  ///
  /// In am, this message translates to:
  /// **'ቅጹን ያውርዱ'**
  String get importStepTemplate;

  /// No description provided for @importStepRows.
  ///
  /// In am, this message translates to:
  /// **'መስመሮችን ያስገቡ'**
  String get importStepRows;

  /// No description provided for @importStepCheck.
  ///
  /// In am, this message translates to:
  /// **'ይመርምሩ — እስካሁን ምንም አልተቀመጠም'**
  String get importStepCheck;

  /// No description provided for @importStepDone.
  ///
  /// In am, this message translates to:
  /// **'ተጭኗል'**
  String get importStepDone;

  /// No description provided for @importExcelTemplate.
  ///
  /// In am, this message translates to:
  /// **'የኤክሴል ቅጽ (.xlsx)'**
  String get importExcelTemplate;

  /// No description provided for @importTextTemplate.
  ///
  /// In am, this message translates to:
  /// **'የጽሑፍ ቅጽ'**
  String get importTextTemplate;

  /// No description provided for @importUploadFile.
  ///
  /// In am, this message translates to:
  /// **'ፋይል ጫን (.xlsx, .csv, .txt)'**
  String get importUploadFile;

  /// No description provided for @importPaste.
  ///
  /// In am, this message translates to:
  /// **'ከኤክሴል / Google Sheets ለጥፍ'**
  String get importPaste;

  /// No description provided for @importPasteHint.
  ///
  /// In am, this message translates to:
  /// **'የርዕስ መስመሩን ጨምሮ መስመሮቹን ኮፒ አድርገው እዚህ ይለጥፉ'**
  String get importPasteHint;

  /// No description provided for @importPasted.
  ///
  /// In am, this message translates to:
  /// **'የተለጠፉ መስመሮች'**
  String get importPasted;

  /// No description provided for @importTypeRows.
  ///
  /// In am, this message translates to:
  /// **'በመተግበሪያው ውስጥ ጻፍ'**
  String get importTypeRows;

  /// No description provided for @importTyped.
  ///
  /// In am, this message translates to:
  /// **'{count} በመተግበሪያው የተጻፉ መዝሙሮች'**
  String importTyped(String count);

  /// No description provided for @importCheckRows.
  ///
  /// In am, this message translates to:
  /// **'መርምር'**
  String get importCheckRows;

  /// No description provided for @importAddRow.
  ///
  /// In am, this message translates to:
  /// **'ሌላ መዝሙር ጨምር'**
  String get importAddRow;

  /// No description provided for @filters.
  ///
  /// In am, this message translates to:
  /// **'ማጣሪያዎች'**
  String get filters;

  /// No description provided for @fClearAll.
  ///
  /// In am, this message translates to:
  /// **'ሁሉንም አጽዳ'**
  String get fClearAll;

  /// No description provided for @fPersonal.
  ///
  /// In am, this message translates to:
  /// **'የግል መረጃ'**
  String get fPersonal;

  /// No description provided for @fMembership.
  ///
  /// In am, this message translates to:
  /// **'አባልነት'**
  String get fMembership;

  /// No description provided for @fAccount.
  ///
  /// In am, this message translates to:
  /// **'መለያ'**
  String get fAccount;

  /// No description provided for @fActivity.
  ///
  /// In am, this message translates to:
  /// **'እንቅስቃሴ እና ክፍሎች'**
  String get fActivity;

  /// No description provided for @fAge.
  ///
  /// In am, this message translates to:
  /// **'ዕድሜ'**
  String get fAge;

  /// No description provided for @fAccountType.
  ///
  /// In am, this message translates to:
  /// **'የመለያ ዓይነት'**
  String get fAccountType;

  /// No description provided for @fMembersOnly.
  ///
  /// In am, this message translates to:
  /// **'አባላት ብቻ'**
  String get fMembersOnly;

  /// No description provided for @fHasDevice.
  ///
  /// In am, this message translates to:
  /// **'መሣሪያ አለው'**
  String get fHasDevice;

  /// No description provided for @fNoDevice.
  ///
  /// In am, this message translates to:
  /// **'መሣሪያ የለውም'**
  String get fNoDevice;

  /// No description provided for @fNoTelegram.
  ///
  /// In am, this message translates to:
  /// **'ቴሌግራም አልተገናኘም'**
  String get fNoTelegram;

  /// No description provided for @fDepartment.
  ///
  /// In am, this message translates to:
  /// **'ክፍል'**
  String get fDepartment;

  /// No description provided for @fLastActive.
  ///
  /// In am, this message translates to:
  /// **'በቅርቡ የገቡ'**
  String get fLastActive;

  /// No description provided for @fActiveWithin.
  ///
  /// In am, this message translates to:
  /// **'ባለፉት {days} ቀናት'**
  String fActiveWithin(String days);

  /// No description provided for @fShowAll.
  ///
  /// In am, this message translates to:
  /// **'ሁሉንም አሳይ'**
  String get fShowAll;

  /// No description provided for @fApply.
  ///
  /// In am, this message translates to:
  /// **'ተግብር ({count})'**
  String fApply(String count);

  /// No description provided for @selAttendancePoints.
  ///
  /// In am, this message translates to:
  /// **'የክትትል ነጥቦች'**
  String get selAttendancePoints;

  /// No description provided for @selAttendancePointsHint.
  ///
  /// In am, this message translates to:
  /// **'እያንዳንዱ የፕሮግራም ክትትል ስንት ነጥብ እንደሚያስገኝ (ከሙሉ ክትትል %)። ለመዝሙር ክትትል እና ለጉርሻ ይውላል።'**
  String get selAttendancePointsHint;

  /// No description provided for @selExcusedPolicyHint.
  ///
  /// In am, this message translates to:
  /// **'ባዶ = የፈቃድ ፖሊሲው ክብደት'**
  String get selExcusedPolicyHint;

  /// No description provided for @selProgramWeights.
  ///
  /// In am, this message translates to:
  /// **'የፕሮግራሞች ክብደት'**
  String get selProgramWeights;

  /// No description provided for @selProgramWeightsHint.
  ///
  /// In am, this message translates to:
  /// **'አንድ ፕሮግራም ከሌሎቹ የበለጠ (×2) ወይም ያነሰ (×0.5) እንዲቆጠር፤ ×0 = አይቆጠርም'**
  String get selProgramWeightsHint;

  /// No description provided for @errLateAbovePresent.
  ///
  /// In am, this message translates to:
  /// **'የዘገየ ነጥብ ከተገኘ ነጥብ መብለጥ የለበትም።'**
  String get errLateAbovePresent;

  /// No description provided for @mgTitle.
  ///
  /// In am, this message translates to:
  /// **'የአባላት ዓይነቶች'**
  String get mgTitle;

  /// No description provided for @mgHint.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራሞች፣ የመገኘት መዝገብ፣ የአባል መታወቂያ እና ማጣሪያዎች እነዚህን ዓይነቶች ይጠቀማሉ። አብሮ የተሠሩት ሊሰረዙ ወይም ሊጠፉ አይችሉም፤ አዲስ ዓይነት ማንም ሳይጠቀመው ሊሰረዝ ይችላል፤ ያለበለዚያ ያጥፉት።'**
  String get mgHint;

  /// No description provided for @mgAdd.
  ///
  /// In am, this message translates to:
  /// **'አዲስ የአባላት ዓይነት'**
  String get mgAdd;

  /// No description provided for @mgEdit.
  ///
  /// In am, this message translates to:
  /// **'የአባላት ዓይነት'**
  String get mgEdit;

  /// No description provided for @mgName.
  ///
  /// In am, this message translates to:
  /// **'ስም (አማርኛ)'**
  String get mgName;

  /// No description provided for @mgNameEn.
  ///
  /// In am, this message translates to:
  /// **'ስም (እንግሊዝኛ)'**
  String get mgNameEn;

  /// No description provided for @mgActive.
  ///
  /// In am, this message translates to:
  /// **'በሥራ ላይ (ለአዲስ ምርጫ ይታያል)'**
  String get mgActive;

  /// No description provided for @mgBuiltIn.
  ///
  /// In am, this message translates to:
  /// **'አብሮ የተሠራ'**
  String get mgBuiltIn;

  /// No description provided for @mgInactive.
  ///
  /// In am, this message translates to:
  /// **'ጠፍቷል'**
  String get mgInactive;

  /// No description provided for @mgMembers.
  ///
  /// In am, this message translates to:
  /// **'{count} አባላት'**
  String mgMembers(String count);

  /// No description provided for @mgDeleteConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህን የአባላት ዓይነት ልሰርዝ?'**
  String get mgDeleteConfirm;

  /// No description provided for @errMemberGroupInUse.
  ///
  /// In am, this message translates to:
  /// **'አባላት ወይም ፕሮግራሞች ይህን ዓይነት ይጠቀማሉ፤ ከመሰረዝ ይልቅ ያጥፉት።'**
  String get errMemberGroupInUse;

  /// No description provided for @errMemberGroupBuiltIn.
  ///
  /// In am, this message translates to:
  /// **'አብሮ የተሠራ የአባላት ዓይነት ሊሰረዝ ወይም ሊጠፋ አይችልም።'**
  String get errMemberGroupBuiltIn;

  /// No description provided for @errInvalidMemberGroup.
  ///
  /// In am, this message translates to:
  /// **'የአባላት ዓይነቱ አይታወቅም።'**
  String get errInvalidMemberGroup;

  /// No description provided for @attVerifyTitle.
  ///
  /// In am, this message translates to:
  /// **'አባሉን ያረጋግጡ'**
  String get attVerifyTitle;

  /// No description provided for @attVerifyHint.
  ///
  /// In am, this message translates to:
  /// **'ፎቶውን ከሰውዬው ጋር ያመሳክሩ፤ ትክክል ከሆነ ይመዝግቡ።'**
  String get attVerifyHint;

  /// No description provided for @attRecord.
  ///
  /// In am, this message translates to:
  /// **'መገኘቱን መዝግብ'**
  String get attRecord;

  /// No description provided for @attScanNext.
  ///
  /// In am, this message translates to:
  /// **'ቀጣዩን ስካን'**
  String get attScanNext;

  /// No description provided for @attEligible.
  ///
  /// In am, this message translates to:
  /// **'ለዚህ ፕሮግራም መመዝገብ ይችላል'**
  String get attEligible;

  /// No description provided for @attWillBe.
  ///
  /// In am, this message translates to:
  /// **'የሚመዘገበው፦ {status}'**
  String attWillBe(String status);

  /// No description provided for @attAlreadyRecorded.
  ///
  /// In am, this message translates to:
  /// **'ለዚህ ፕሮግራም መገኘቱ ቀደም ብሎ ተመዝግቧል።'**
  String get attAlreadyRecorded;

  /// No description provided for @attRecordedBy.
  ///
  /// In am, this message translates to:
  /// **'የመዘገበው፦ {name} · {time}'**
  String attRecordedBy(String name, String time);

  /// No description provided for @attMethodQr.
  ///
  /// In am, this message translates to:
  /// **'በQR'**
  String get attMethodQr;

  /// No description provided for @attMethodManual.
  ///
  /// In am, this message translates to:
  /// **'በእጅ'**
  String get attMethodManual;

  /// No description provided for @attFindMember.
  ///
  /// In am, this message translates to:
  /// **'አባል ፈልግ (ስልክ የሌላቸው)'**
  String get attFindMember;

  /// No description provided for @attTakers.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት መዝጋቢዎች'**
  String get attTakers;

  /// No description provided for @attTakersHint.
  ///
  /// In am, this message translates to:
  /// **'ባዶ ከሆነ ማንኛውም የመገኘት መዝጋቢ ይህን ፕሮግራም መመዝገብ ይችላል።'**
  String get attTakersHint;

  /// No description provided for @attTakersAll.
  ///
  /// In am, this message translates to:
  /// **'ሁሉም የመገኘት መዝጋቢዎች'**
  String get attTakersAll;

  /// No description provided for @errNotProgramTaker.
  ///
  /// In am, this message translates to:
  /// **'የዚህ ፕሮግራም የመገኘት መዝጋቢ አይደሉም።'**
  String get errNotProgramTaker;

  /// No description provided for @errNotAttendanceTaker.
  ///
  /// In am, this message translates to:
  /// **'የተመረጠው ሰው የመገኘት መዝጋቢ ፈቃድ የለውም።'**
  String get errNotAttendanceTaker;

  /// No description provided for @errAttendanceNotRequired.
  ///
  /// In am, this message translates to:
  /// **'ይህ ፕሮግራም መገኘት አይመዘግብም።'**
  String get errAttendanceNotRequired;

  /// No description provided for @errProgramCancelled.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራሙ ተሰርዟል።'**
  String get errProgramCancelled;

  /// No description provided for @errMemberNotInGroup.
  ///
  /// In am, this message translates to:
  /// **'አባሉ ለዚህ ፕሮግራም ከተመረጡት የአባላት ዓይነቶች አይደለም፤ እንደ ቀሪ አይቆጠርም።'**
  String get errMemberNotInGroup;

  /// No description provided for @ctaOpenClass.
  ///
  /// In am, this message translates to:
  /// **'ክፍል ክፈት'**
  String get ctaOpenClass;

  /// No description provided for @ctaOpenCourse.
  ///
  /// In am, this message translates to:
  /// **'ኮርስ ክፈት'**
  String get ctaOpenCourse;

  /// No description provided for @ctaOpenAssignment.
  ///
  /// In am, this message translates to:
  /// **'የቤት ሥራ ክፈት'**
  String get ctaOpenAssignment;

  /// No description provided for @ctaOpenPage.
  ///
  /// In am, this message translates to:
  /// **'ሌላ ገጽ ክፈት'**
  String get ctaOpenPage;

  /// No description provided for @ctaOpenLibrary.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ቤተ መጻሕፍት ክፈት'**
  String get ctaOpenLibrary;

  /// No description provided for @ctaOpenUrl.
  ///
  /// In am, this message translates to:
  /// **'ድረ ገጽ ክፈት'**
  String get ctaOpenUrl;

  /// No description provided for @ctaUrl.
  ///
  /// In am, this message translates to:
  /// **'የድረ ገጽ አድራሻ (https://…)'**
  String get ctaUrl;

  /// No description provided for @ctaNothingChosen.
  ///
  /// In am, this message translates to:
  /// **'ገና አልተመረጠም'**
  String get ctaNothingChosen;

  /// No description provided for @errInvalidUrl.
  ///
  /// In am, this message translates to:
  /// **'አድራሻው በ https:// መጀመር አለበት።'**
  String get errInvalidUrl;

  /// No description provided for @lrcRepeat.
  ///
  /// In am, this message translates to:
  /// **'ድገም'**
  String get lrcRepeat;

  /// No description provided for @lrcRepeatHint.
  ///
  /// In am, this message translates to:
  /// **'ዘማሪዎቹ መስመር ሲደግሙ ያንን መስመር ከላይ ይንኩ (ወይም «ድገም»)፤ ማሳያው ወደዚያው መስመር ይመለሳል እንጂ መስመሩ ደግሞ አይጻፍም። አንድ መስመር እስከ 3 ጊዜ።'**
  String get lrcRepeatHint;

  /// No description provided for @lrcRepeatPick.
  ///
  /// In am, this message translates to:
  /// **'የሚደገመውን መስመር ይምረጡ'**
  String get lrcRepeatPick;

  /// No description provided for @lrcRepeatLimit.
  ///
  /// In am, this message translates to:
  /// **'አንድ መስመር እስከ 3 ጊዜ ብቻ ይደገማል።'**
  String get lrcRepeatLimit;

  /// No description provided for @bioLock.
  ///
  /// In am, this message translates to:
  /// **'በጣት አሻራ ቆልፍ'**
  String get bioLock;

  /// No description provided for @bioLockHint.
  ///
  /// In am, this message translates to:
  /// **'መተግበሪያው ሲከፈት የስልኩ የጣት አሻራ (ወይም የስልኩ መክፈቻ) ይጠየቃል። አሻራው በስልኩ ላይ ብቻ ይቀራል፤ ወደ አገልጋዩ አይላክም።'**
  String get bioLockHint;

  /// No description provided for @bioUnlock.
  ///
  /// In am, this message translates to:
  /// **'ክፈት'**
  String get bioUnlock;

  /// No description provided for @bioReason.
  ///
  /// In am, this message translates to:
  /// **'መተግበሪያውን ለመክፈት የጣት አሻራዎን ያስገቡ'**
  String get bioReason;

  /// No description provided for @bioUnavailable.
  ///
  /// In am, this message translates to:
  /// **'ይህ ስልክ የጣት አሻራ ወይም የማያ መቆለፊያ አልተዘጋጀለትም።'**
  String get bioUnavailable;

  /// No description provided for @bioLocked.
  ///
  /// In am, this message translates to:
  /// **'መተግበሪያው ተቆልፏል'**
  String get bioLocked;

  /// No description provided for @errAttendanceTooLate.
  ///
  /// In am, this message translates to:
  /// **'የመዘግየት ጊዜው አልፏል፤ በምትኩ ለግምገማ የማስተካከያ ጥያቄ ያቅርቡ።'**
  String get errAttendanceTooLate;

  /// No description provided for @adminFromMemberHint.
  ///
  /// In am, this message translates to:
  /// **'አስተዳዳሪ የሚሆነው ቀድሞ የተመዘገበ አባል ነው፤ አዲስ መለያ አይፈጠርም። አባሉ መለያውን፣ መታወቂያውን እና ታሪኩን ይይዛል፤ በሚቀጥለው መግቢያ ፒኑን ያዘጋጃል።'**
  String get adminFromMemberHint;

  /// No description provided for @adminPickMember.
  ///
  /// In am, this message translates to:
  /// **'አባል ይምረጡ'**
  String get adminPickMember;

  /// No description provided for @errAdminFromMemberOnly.
  ///
  /// In am, this message translates to:
  /// **'አስተዳዳሪ ለማድረግ ከአባላት ውስጥ አንዱን ይምረጡ።'**
  String get errAdminFromMemberOnly;

  /// No description provided for @errUserNotActive.
  ///
  /// In am, this message translates to:
  /// **'ንቁ አባል ብቻ አስተዳዳሪ ሊሆን ይችላል።'**
  String get errUserNotActive;

  /// No description provided for @errMemberNotFound.
  ///
  /// In am, this message translates to:
  /// **'አባሉ አልተገኘም። ከመስመር ውጭ ከሆኑ ስልኩ ዝርዝሩን እንዲያድስ አንድ ጊዜ ከኢንተርኔት ጋር ያገናኙት።'**
  String get errMemberNotFound;

  /// No description provided for @attOfflineChecked.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ ተረጋግጧል፤ ሲገናኝ አገልጋዩ ደግሞ ያረጋግጣል (በሰዓቱ / ዘግይቶ እዚያ ይወሰናል)።'**
  String get attOfflineChecked;

  /// No description provided for @attNoMembersFound.
  ///
  /// In am, this message translates to:
  /// **'ምንም አባል አልተገኘም'**
  String get attNoMembersFound;

  /// No description provided for @alarmSnooze.
  ///
  /// In am, this message translates to:
  /// **'በ10 ደቂቃ ድገም'**
  String get alarmSnooze;

  /// No description provided for @alarmDismiss.
  ///
  /// In am, this message translates to:
  /// **'ዝጋ'**
  String get alarmDismiss;

  /// No description provided for @sessTitle.
  ///
  /// In am, this message translates to:
  /// **'የመግቢያ ክፍለ ጊዜዎች'**
  String get sessTitle;

  /// No description provided for @sessHint.
  ///
  /// In am, this message translates to:
  /// **'መለያዎ የገባባቸው ስልኮች። አንዱን ማስወገድ ያንን ክፍለ ጊዜ ብቻ ያስወጣል፤ መለያው አይሰረዝም።'**
  String get sessHint;

  /// No description provided for @sessCurrent.
  ///
  /// In am, this message translates to:
  /// **'ይህ ስልክ'**
  String get sessCurrent;

  /// No description provided for @sessRevoke.
  ///
  /// In am, this message translates to:
  /// **'አስወጣ'**
  String get sessRevoke;

  /// No description provided for @sessRevokeOthers.
  ///
  /// In am, this message translates to:
  /// **'ሌሎቹን ሁሉ አስወጣ'**
  String get sessRevokeOthers;

  /// No description provided for @sessRevokeAll.
  ///
  /// In am, this message translates to:
  /// **'ከሁሉም ቦታ ውጣ (ይህ ስልክም)'**
  String get sessRevokeAll;

  /// No description provided for @sessRevokeAllConfirm.
  ///
  /// In am, this message translates to:
  /// **'ከሁሉም ክፍለ ጊዜዎች ይውጡ? እንደገና መግባት ያስፈልግዎታል።'**
  String get sessRevokeAllConfirm;

  /// No description provided for @sessSignedIn.
  ///
  /// In am, this message translates to:
  /// **'የገባበት፦ {when}'**
  String sessSignedIn(String when);

  /// No description provided for @sessLastActive.
  ///
  /// In am, this message translates to:
  /// **'መጨረሻ የታየው፦ {when}'**
  String sessLastActive(String when);

  /// No description provided for @sessRevokedCount.
  ///
  /// In am, this message translates to:
  /// **'{n} ክፍለ ጊዜዎች ወጥተዋል'**
  String sessRevokedCount(String n);

  /// No description provided for @errMezmurTitleTaken.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ርዕስ ሌላ መዝሙር አለ፤ የተለየ ርዕስ ይስጡ።'**
  String get errMezmurTitleTaken;

  /// No description provided for @errSessionNotFound.
  ///
  /// In am, this message translates to:
  /// **'ክፍለ ጊዜው አልተገኘም።'**
  String get errSessionNotFound;

  /// No description provided for @adminGroupProjects.
  ///
  /// In am, this message translates to:
  /// **'የፕሮጀክትና ተግባር አስተዳደር'**
  String get adminGroupProjects;

  /// No description provided for @adminGroupReports.
  ///
  /// In am, this message translates to:
  /// **'ሪፖርትና ኦዲት'**
  String get adminGroupReports;

  /// No description provided for @eduCourseProgress.
  ///
  /// In am, this message translates to:
  /// **'የኮርስ ሂደት፦ {p} %'**
  String eduCourseProgress(String p);

  /// No description provided for @eduCourseCompletedHint.
  ///
  /// In am, this message translates to:
  /// **'100 % ሲደርስ ኮርሱ ይጠናቀቃል፤ ከዚያ በኋላ የመገኘት ግዴታ አይቆጠርም።'**
  String get eduCourseCompletedHint;

  /// No description provided for @eduFrequency.
  ///
  /// In am, this message translates to:
  /// **'ድግግሞሽ'**
  String get eduFrequency;

  /// No description provided for @eduWeekly.
  ///
  /// In am, this message translates to:
  /// **'በየሳምንቱ'**
  String get eduWeekly;

  /// No description provided for @eduMonthly.
  ///
  /// In am, this message translates to:
  /// **'በወር አንድ ጊዜ'**
  String get eduMonthly;

  /// No description provided for @eduWeekOfMonth.
  ///
  /// In am, this message translates to:
  /// **'የወሩ ሳምንት'**
  String get eduWeekOfMonth;

  /// No description provided for @eduWeek1.
  ///
  /// In am, this message translates to:
  /// **'1ኛ'**
  String get eduWeek1;

  /// No description provided for @eduWeek2.
  ///
  /// In am, this message translates to:
  /// **'2ኛ'**
  String get eduWeek2;

  /// No description provided for @eduWeek3.
  ///
  /// In am, this message translates to:
  /// **'3ኛ'**
  String get eduWeek3;

  /// No description provided for @eduWeek4.
  ///
  /// In am, this message translates to:
  /// **'4ኛ'**
  String get eduWeek4;

  /// No description provided for @eduWeekLast.
  ///
  /// In am, this message translates to:
  /// **'የመጨረሻው'**
  String get eduWeekLast;

  /// No description provided for @eduMonthlyDay.
  ///
  /// In am, this message translates to:
  /// **'የወሩ {week} {day}'**
  String eduMonthlyDay(String week, String day);

  /// No description provided for @eduSessionFor.
  ///
  /// In am, this message translates to:
  /// **'ለማን'**
  String get eduSessionFor;

  /// No description provided for @eduMode.
  ///
  /// In am, this message translates to:
  /// **'አቀራረብ'**
  String get eduMode;

  /// No description provided for @eduInPerson.
  ///
  /// In am, this message translates to:
  /// **'በአካል'**
  String get eduInPerson;

  /// No description provided for @eduOnline.
  ///
  /// In am, this message translates to:
  /// **'በመስመር ላይ'**
  String get eduOnline;

  /// No description provided for @export.
  ///
  /// In am, this message translates to:
  /// **'ወደ ውጭ ላክ'**
  String get export;

  /// No description provided for @exportPdf.
  ///
  /// In am, this message translates to:
  /// **'PDF (ለህትመት)'**
  String get exportPdf;

  /// No description provided for @exportExcel.
  ///
  /// In am, this message translates to:
  /// **'Excel (XLSX)'**
  String get exportExcel;

  /// No description provided for @exportCsv.
  ///
  /// In am, this message translates to:
  /// **'CSV (ዳታ)'**
  String get exportCsv;

  /// No description provided for @exportReady.
  ///
  /// In am, this message translates to:
  /// **'ፋይሉ ተዘጋጅቷል'**
  String get exportReady;

  /// No description provided for @itemHistory.
  ///
  /// In am, this message translates to:
  /// **'የንብረት ታሪክ'**
  String get itemHistory;

  /// No description provided for @issueCondition.
  ///
  /// In am, this message translates to:
  /// **'ሲሰጥ የነበረበት ሁኔታ'**
  String get issueCondition;

  /// No description provided for @openWith.
  ///
  /// In am, this message translates to:
  /// **'በሌላ መተግበሪያ ክፈት / አጋራ'**
  String get openWith;

  /// No description provided for @previewUnavailable.
  ///
  /// In am, this message translates to:
  /// **'ይህ ፋይል በመተግበሪያው ውስጥ ሊታይ አይችልም።'**
  String get previewUnavailable;

  /// No description provided for @fileTypeUnknown.
  ///
  /// In am, this message translates to:
  /// **'ያልታወቀ ዓይነት'**
  String get fileTypeUnknown;

  /// No description provided for @recentActivityAndNotifications.
  ///
  /// In am, this message translates to:
  /// **'የቅርብ ጊዜ እንቅስቃሴዎችና ማሳወቂያዎች'**
  String get recentActivityAndNotifications;

  /// No description provided for @resendNotification.
  ///
  /// In am, this message translates to:
  /// **'እንደገና ላክ'**
  String get resendNotification;

  /// No description provided for @alsoByEmail.
  ///
  /// In am, this message translates to:
  /// **'በኢሜልም ላክ'**
  String get alsoByEmail;

  /// No description provided for @alsoByEmailHint.
  ///
  /// In am, this message translates to:
  /// **'ኢሜል ላስመዘገቡና ኢሜል ለፈቀዱ አባላት'**
  String get alsoByEmailHint;

  /// No description provided for @resendNote.
  ///
  /// In am, this message translates to:
  /// **'እንደገና መላክ አዲስ ማሳወቂያ ይፈጥራል፤ የቀድሞው እና ታሪኩ አይቀየርም።'**
  String get resendNote;

  /// No description provided for @notificationDetails.
  ///
  /// In am, this message translates to:
  /// **'የማሳወቂያ ዝርዝር'**
  String get notificationDetails;

  /// No description provided for @channelPush.
  ///
  /// In am, this message translates to:
  /// **'የስልክ ማሳወቂያ'**
  String get channelPush;

  /// No description provided for @channelEmail.
  ///
  /// In am, this message translates to:
  /// **'ኢሜል'**
  String get channelEmail;

  /// No description provided for @resentFrom.
  ///
  /// In am, this message translates to:
  /// **'ከ#{id} እንደገና የተላከ'**
  String resentFrom(String id);

  /// No description provided for @sentAt.
  ///
  /// In am, this message translates to:
  /// **'የተላከበት'**
  String get sentAt;

  /// No description provided for @readCount.
  ///
  /// In am, this message translates to:
  /// **'ያነበቡ'**
  String get readCount;

  /// No description provided for @resends.
  ///
  /// In am, this message translates to:
  /// **'እንደገና የተላኩ'**
  String get resends;

  /// No description provided for @readAt.
  ///
  /// In am, this message translates to:
  /// **'ያነበቡት {time}'**
  String readAt(String time);

  /// No description provided for @deliverySent.
  ///
  /// In am, this message translates to:
  /// **'ደርሷል'**
  String get deliverySent;

  /// No description provided for @deliveryFailed.
  ///
  /// In am, this message translates to:
  /// **'አልደረሰም'**
  String get deliveryFailed;

  /// No description provided for @deliverySkipped.
  ///
  /// In am, this message translates to:
  /// **'አልተላከም'**
  String get deliverySkipped;

  /// No description provided for @deliveryPending.
  ///
  /// In am, this message translates to:
  /// **'በመላክ ላይ'**
  String get deliveryPending;

  /// No description provided for @deliveryNone.
  ///
  /// In am, this message translates to:
  /// **'—'**
  String get deliveryNone;

  /// No description provided for @notificationHealth.
  ///
  /// In am, this message translates to:
  /// **'የማሳወቂያ ሁኔታ'**
  String get notificationHealth;

  /// No description provided for @providers.
  ///
  /// In am, this message translates to:
  /// **'አገልግሎቶች'**
  String get providers;

  /// No description provided for @fcmReady.
  ///
  /// In am, this message translates to:
  /// **'የስልክ ማሳወቂያ (Firebase)'**
  String get fcmReady;

  /// No description provided for @emailConfigured.
  ///
  /// In am, this message translates to:
  /// **'ኢሜል (SMTP)'**
  String get emailConfigured;

  /// No description provided for @backgroundJobs.
  ///
  /// In am, this message translates to:
  /// **'የጀርባ ሥራዎች'**
  String get backgroundJobs;

  /// No description provided for @registeredDevices.
  ///
  /// In am, this message translates to:
  /// **'የተመዘገቡ ስልኮች'**
  String get registeredDevices;

  /// No description provided for @oldestPending.
  ///
  /// In am, this message translates to:
  /// **'ረጅም ጊዜ የቆየ ያልተላከ'**
  String get oldestPending;

  /// No description provided for @scheduledReminders.
  ///
  /// In am, this message translates to:
  /// **'የታቀዱ ማስታወሻዎች'**
  String get scheduledReminders;

  /// No description provided for @notificationSettings.
  ///
  /// In am, this message translates to:
  /// **'ማሳወቂያዎች'**
  String get notificationSettings;

  /// No description provided for @notificationSettingsHint.
  ///
  /// In am, this message translates to:
  /// **'የሚደርስዎትን ማሳወቂያ በርዕስ ይምረጡ። ሁሉም ማሳወቂያዎች በመተግበሪያው ማሳወቂያ ዝርዝር ውስጥ ይቀመጣሉ፤ የአስተዳደር መልዕክቶች ሁልጊዜ ይደርሳሉ።'**
  String get notificationSettingsHint;

  /// No description provided for @notificationsAll.
  ///
  /// In am, this message translates to:
  /// **'ማሳወቂያዎችን ፍቀድ'**
  String get notificationsAll;

  /// No description provided for @noEmailForNotifications.
  ///
  /// In am, this message translates to:
  /// **'ኢሜል አልተመዘገበም፤ በኢሜል ለመቀበል በመገለጫዎ ኢሜል ያክሉ።'**
  String get noEmailForNotifications;

  /// No description provided for @alwaysOn.
  ///
  /// In am, this message translates to:
  /// **'ሁልጊዜ'**
  String get alwaysOn;

  /// No description provided for @topicProgram.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራሞች'**
  String get topicProgram;

  /// No description provided for @topicAttendance.
  ///
  /// In am, this message translates to:
  /// **'ክትትል'**
  String get topicAttendance;

  /// No description provided for @topicProject.
  ///
  /// In am, this message translates to:
  /// **'ፕሮጀክቶች'**
  String get topicProject;

  /// No description provided for @topicDepartment.
  ///
  /// In am, this message translates to:
  /// **'ክፍል (ቻት)'**
  String get topicDepartment;

  /// No description provided for @topicEducation.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት'**
  String get topicEducation;

  /// No description provided for @topicProperty.
  ///
  /// In am, this message translates to:
  /// **'ንብረት'**
  String get topicProperty;

  /// No description provided for @topicMezmur.
  ///
  /// In am, this message translates to:
  /// **'መዝሙር'**
  String get topicMezmur;

  /// No description provided for @topicSystem.
  ///
  /// In am, this message translates to:
  /// **'አስተዳደር'**
  String get topicSystem;

  /// No description provided for @pmActivityDetail.
  ///
  /// In am, this message translates to:
  /// **'የእንቅስቃሴ ዝርዝር'**
  String get pmActivityDetail;

  /// No description provided for @pmViaBot.
  ///
  /// In am, this message translates to:
  /// **'በተግባር ቦት'**
  String get pmViaBot;

  /// No description provided for @pmActor.
  ///
  /// In am, this message translates to:
  /// **'ያደረጉት'**
  String get pmActor;

  /// No description provided for @pmActName.
  ///
  /// In am, this message translates to:
  /// **'ስም'**
  String get pmActName;

  /// No description provided for @pmActLeaderRole.
  ///
  /// In am, this message translates to:
  /// **'መሪ'**
  String get pmActLeaderRole;

  /// No description provided for @pmActMemberRole.
  ///
  /// In am, this message translates to:
  /// **'አባል'**
  String get pmActMemberRole;

  /// No description provided for @pmActDeptAdmin.
  ///
  /// In am, this message translates to:
  /// **'የክፍል አስተዳዳሪ'**
  String get pmActDeptAdmin;

  /// No description provided for @pmActProgram.
  ///
  /// In am, this message translates to:
  /// **'ፕሮግራም'**
  String get pmActProgram;

  /// No description provided for @pmProject.
  ///
  /// In am, this message translates to:
  /// **'ፕሮጀክት'**
  String get pmProject;

  /// No description provided for @pmTask.
  ///
  /// In am, this message translates to:
  /// **'ተግባር'**
  String get pmTask;

  /// No description provided for @pmAssignees.
  ///
  /// In am, this message translates to:
  /// **'ኃላፊዎች'**
  String get pmAssignees;

  /// No description provided for @pmProblem.
  ///
  /// In am, this message translates to:
  /// **'ችግር'**
  String get pmProblem;

  /// No description provided for @pmSolution.
  ///
  /// In am, this message translates to:
  /// **'መፍትሄ'**
  String get pmSolution;

  /// No description provided for @pmChanges.
  ///
  /// In am, this message translates to:
  /// **'ለውጦች'**
  String get pmChanges;

  /// No description provided for @pmAdded.
  ///
  /// In am, this message translates to:
  /// **'የተጨመሩ'**
  String get pmAdded;

  /// No description provided for @pmRemoved.
  ///
  /// In am, this message translates to:
  /// **'የተነሱ'**
  String get pmRemoved;

  /// No description provided for @pmRelatedPeople.
  ///
  /// In am, this message translates to:
  /// **'የሚመለከታቸው ሰዎች'**
  String get pmRelatedPeople;

  /// No description provided for @pmNotificationsSent.
  ///
  /// In am, this message translates to:
  /// **'የተላኩ ማሳወቂያዎች'**
  String get pmNotificationsSent;

  /// No description provided for @pmBotMessages.
  ///
  /// In am, this message translates to:
  /// **'የቦት መልዕክቶች'**
  String get pmBotMessages;

  /// No description provided for @pickGallery.
  ///
  /// In am, this message translates to:
  /// **'ፎቶ (ጋለሪ)'**
  String get pickGallery;

  /// No description provided for @pickCamera.
  ///
  /// In am, this message translates to:
  /// **'ካሜራ'**
  String get pickCamera;

  /// No description provided for @pickVideo.
  ///
  /// In am, this message translates to:
  /// **'ቪዲዮ'**
  String get pickVideo;

  /// No description provided for @pickRecordVideo.
  ///
  /// In am, this message translates to:
  /// **'ቪዲዮ ቅረጽ'**
  String get pickRecordVideo;

  /// No description provided for @pickAudio.
  ///
  /// In am, this message translates to:
  /// **'ድምፅ'**
  String get pickAudio;

  /// No description provided for @pickDocument.
  ///
  /// In am, this message translates to:
  /// **'ሰነድ (PDF, Word, Excel…)'**
  String get pickDocument;

  /// No description provided for @pickAnyFile.
  ///
  /// In am, this message translates to:
  /// **'ሌላ ፋይል'**
  String get pickAnyFile;

  /// No description provided for @itemCodeAuto.
  ///
  /// In am, this message translates to:
  /// **'ባዶ ከተተወ ከክፍሉና ከምድቡ በራስ-ሰር ይሰጣል'**
  String get itemCodeAuto;

  /// No description provided for @permissionCancelExcuse.
  ///
  /// In am, this message translates to:
  /// **'ፈቃዱን ሰርዝ'**
  String get permissionCancelExcuse;

  /// No description provided for @permissionCancelExcuseHint.
  ///
  /// In am, this message translates to:
  /// **'በስህተት የተሰጠ ፈቃድን ይሰርዛል። በፈቃዱ የተመዘገበው «ፈቃድ ያለው» አቴንዳንስ ይወገዳል፣ አባሉም ይነገራቸዋል።'**
  String get permissionCancelExcuseHint;

  /// No description provided for @permissionCancelled.
  ///
  /// In am, this message translates to:
  /// **'ተሰርዟል'**
  String get permissionCancelled;

  /// No description provided for @permissionCancelledBy.
  ///
  /// In am, this message translates to:
  /// **'በ{name} ተሰርዟል፦ {reason}'**
  String permissionCancelledBy(String name, String reason);

  /// No description provided for @wedManualSelectionHint.
  ///
  /// In am, this message translates to:
  /// **'ተሳታፊዎች በእጅ ይመረጣሉ፤ የአቴንዳንስ ወይም የፈተና መስፈርት የለም።'**
  String get wedManualSelectionHint;

  /// No description provided for @wedReviewTitle.
  ///
  /// In am, this message translates to:
  /// **'{n} አባላትን ለመምረጥ ያረጋግጡ'**
  String wedReviewTitle(String n);

  /// No description provided for @wedHideChosen.
  ///
  /// In am, this message translates to:
  /// **'ያልተመረጡ ብቻ'**
  String get wedHideChosen;

  /// No description provided for @remindEvery15Days.
  ///
  /// In am, this message translates to:
  /// **'በየ15 ቀኑ አስታውስ'**
  String get remindEvery15Days;

  /// No description provided for @remindEvery15DaysHint.
  ///
  /// In am, this message translates to:
  /// **'መርሐ ግብሩ እስከሚያልቅ ድረስ ለተሳታፊዎቹ በየ15 ቀኑ ማስታወሻ ይላካል፤ ሲሰረዝ ወይም ሲጠናቀቅ ይቆማል።'**
  String get remindEvery15DaysHint;

  /// No description provided for @remindEvery15DaysFrom.
  ///
  /// In am, this message translates to:
  /// **'ከዚህ ቀን ጀምሮ (ባዶ ከሆነ ከመርሐ ግብሩ መጀመሪያ ወይም ከዛሬ)'**
  String get remindEvery15DaysFrom;

  /// No description provided for @programTypeReminders.
  ///
  /// In am, this message translates to:
  /// **'የዚህ ዓይነት መርሐ ግብሮች ነባሪ ማስታወሻዎች'**
  String get programTypeReminders;

  /// No description provided for @itemCategoriesConfig.
  ///
  /// In am, this message translates to:
  /// **'የእቃዎች ምድብ ቅንብር'**
  String get itemCategoriesConfig;

  /// No description provided for @itemCategoryNew.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ምድብ'**
  String get itemCategoryNew;

  /// No description provided for @itemCategoryEdit.
  ///
  /// In am, this message translates to:
  /// **'ምድብ አርትዕ'**
  String get itemCategoryEdit;

  /// No description provided for @itemCategoryNameAm.
  ///
  /// In am, this message translates to:
  /// **'የምድብ ስም (አማርኛ)'**
  String get itemCategoryNameAm;

  /// No description provided for @itemCategoryNameEn.
  ///
  /// In am, this message translates to:
  /// **'የምድብ ስም (እንግሊዝኛ)'**
  String get itemCategoryNameEn;

  /// No description provided for @itemCategoryCode.
  ///
  /// In am, this message translates to:
  /// **'የኮድ ቅድመ-ቅጥያ (ለምሳሌ EQ)'**
  String get itemCategoryCode;

  /// No description provided for @itemCategoryKey.
  ///
  /// In am, this message translates to:
  /// **'መለያ ቁልፍ'**
  String get itemCategoryKey;

  /// No description provided for @itemCategoryKeyHint.
  ///
  /// In am, this message translates to:
  /// **'በላቲን ፊደል፣ ለምሳሌ equipment — ከተቀመጠ በኋላ አይቀየርም'**
  String get itemCategoryKeyHint;

  /// No description provided for @itemCategoryDeleteConfirm.
  ///
  /// In am, this message translates to:
  /// **'ምድቡ ይሰረዝ?'**
  String get itemCategoryDeleteConfirm;

  /// No description provided for @itemRetired.
  ///
  /// In am, this message translates to:
  /// **'ከአገልግሎት ውጭ'**
  String get itemRetired;

  /// No description provided for @eaAcademicYear.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ዘመን'**
  String get eaAcademicYear;

  /// No description provided for @eaAddInfoHint.
  ///
  /// In am, this message translates to:
  /// **'ተጨማሪ መረጃ ይጻፉ…'**
  String get eaAddInfoHint;

  /// No description provided for @eaAdminComment.
  ///
  /// In am, this message translates to:
  /// **'የአስተዳዳሪ አስተያየት'**
  String get eaAdminComment;

  /// No description provided for @eaAmend.
  ///
  /// In am, this message translates to:
  /// **'ውጤት ማስተካከያ'**
  String get eaAmend;

  /// No description provided for @eaAmendReason.
  ///
  /// In am, this message translates to:
  /// **'የማስተካከያው ምክንያት (ግዴታ)'**
  String get eaAmendReason;

  /// No description provided for @eaApproveAndPublish.
  ///
  /// In am, this message translates to:
  /// **'አጽድቅ እና አትም'**
  String get eaApproveAndPublish;

  /// No description provided for @eaApproveConfirm.
  ///
  /// In am, this message translates to:
  /// **'የቀረቡት ውጤቶች ይጽደቁ?'**
  String get eaApproveConfirm;

  /// No description provided for @eaApprovePublishConfirm.
  ///
  /// In am, this message translates to:
  /// **'የቀረቡት ውጤቶች ጸድቀው ለተማሪዎች ይታተሙ?'**
  String get eaApprovePublishConfirm;

  /// No description provided for @eaApproveRequestHint.
  ///
  /// In am, this message translates to:
  /// **'ሲፈቀድ ለውጡ በምዝገባው ላይ ወዲያውኑ ይተገበራል።'**
  String get eaApproveRequestHint;

  /// No description provided for @eaArchived.
  ///
  /// In am, this message translates to:
  /// **'በማህደር የተቀመጠ'**
  String get eaArchived;

  /// No description provided for @eaAssignedBy.
  ///
  /// In am, this message translates to:
  /// **'የመደበው፦'**
  String get eaAssignedBy;

  /// No description provided for @eaAssignTeacher.
  ///
  /// In am, this message translates to:
  /// **'መምህር መድብ'**
  String get eaAssignTeacher;

  /// No description provided for @eaAssignToMe.
  ///
  /// In am, this message translates to:
  /// **'ለእኔ መድብ'**
  String get eaAssignToMe;

  /// No description provided for @eaAttachEvidence.
  ///
  /// In am, this message translates to:
  /// **'ማስረጃ አያይዝ (አማራጭ)'**
  String get eaAttachEvidence;

  /// No description provided for @eaBy.
  ///
  /// In am, this message translates to:
  /// **'በ'**
  String get eaBy;

  /// No description provided for @eaCancelRequestConfirm.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄው ይሰረዝ?'**
  String get eaCancelRequestConfirm;

  /// No description provided for @eaCatCourseAdmin.
  ///
  /// In am, this message translates to:
  /// **'የኮርስ አስተዳደር'**
  String get eaCatCourseAdmin;

  /// No description provided for @eaCategory.
  ///
  /// In am, this message translates to:
  /// **'ዓይነት'**
  String get eaCategory;

  /// No description provided for @eaCatEnrollment.
  ///
  /// In am, this message translates to:
  /// **'ምዝገባ'**
  String get eaCatEnrollment;

  /// No description provided for @eaCatMarks.
  ///
  /// In am, this message translates to:
  /// **'ውጤት'**
  String get eaCatMarks;

  /// No description provided for @eaCatOther.
  ///
  /// In am, this message translates to:
  /// **'ሌላ'**
  String get eaCatOther;

  /// No description provided for @eaCatPlacement.
  ///
  /// In am, this message translates to:
  /// **'የክፍል / ዘርፍ ምደባ'**
  String get eaCatPlacement;

  /// No description provided for @eaCatStudyMode.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ዓይነት (መደበኛ / ርቀት)'**
  String get eaCatStudyMode;

  /// No description provided for @eaCatTeacher.
  ///
  /// In am, this message translates to:
  /// **'መምህርን የሚመለከት'**
  String get eaCatTeacher;

  /// No description provided for @eaChangeTeacherStatus.
  ///
  /// In am, this message translates to:
  /// **'የመምህሩን ሁኔታ ቀይር'**
  String get eaChangeTeacherStatus;

  /// No description provided for @eaClassAll.
  ///
  /// In am, this message translates to:
  /// **'ክፍል (ኮርስ)'**
  String get eaClassAll;

  /// No description provided for @eaComplaint.
  ///
  /// In am, this message translates to:
  /// **'ቅሬታ'**
  String get eaComplaint;

  /// No description provided for @eaComplaintConfidential.
  ///
  /// In am, this message translates to:
  /// **'ቅሬታዎ ሚስጥራዊ ነው፤ የሚያዩት እርስዎ እና የትምህርት ክፍሉ ኃላፊዎች ብቻ ናቸው።'**
  String get eaComplaintConfidential;

  /// No description provided for @eaComplaintDescription.
  ///
  /// In am, this message translates to:
  /// **'ዝርዝር መግለጫ'**
  String get eaComplaintDescription;

  /// No description provided for @eaComplaintSubject.
  ///
  /// In am, this message translates to:
  /// **'ርዕስ'**
  String get eaComplaintSubject;

  /// No description provided for @eaComplaints.
  ///
  /// In am, this message translates to:
  /// **'ቅሬታዎች'**
  String get eaComplaints;

  /// No description provided for @eaComplaintSent.
  ///
  /// In am, this message translates to:
  /// **'ቅሬታዎ ቀርቧል'**
  String get eaComplaintSent;

  /// No description provided for @eaComplaintTooShort.
  ///
  /// In am, this message translates to:
  /// **'እባክዎ ርዕስ እና ቢያንስ 10 ፊደላት ያለው መግለጫ ይጻፉ።'**
  String get eaComplaintTooShort;

  /// No description provided for @eaCsAwaitingInfo.
  ///
  /// In am, this message translates to:
  /// **'ተጨማሪ መረጃ ይጠበቃል'**
  String get eaCsAwaitingInfo;

  /// No description provided for @eaCsEscalated.
  ///
  /// In am, this message translates to:
  /// **'ለበላይ ተላልፏል'**
  String get eaCsEscalated;

  /// No description provided for @eaCsResolved.
  ///
  /// In am, this message translates to:
  /// **'ተፈትቷል'**
  String get eaCsResolved;

  /// No description provided for @eaCsSubmitted.
  ///
  /// In am, this message translates to:
  /// **'ቀርቧል'**
  String get eaCsSubmitted;

  /// No description provided for @eaCsUnderReview.
  ///
  /// In am, this message translates to:
  /// **'በመታየት ላይ'**
  String get eaCsUnderReview;

  /// No description provided for @eaEnrollmentStatus.
  ///
  /// In am, this message translates to:
  /// **'የምዝገባ ሁኔታ'**
  String get eaEnrollmentStatus;

  /// No description provided for @eaEnteredBy.
  ///
  /// In am, this message translates to:
  /// **'ያስገባው፦'**
  String get eaEnteredBy;

  /// No description provided for @eaHistory.
  ///
  /// In am, this message translates to:
  /// **'ታሪክ'**
  String get eaHistory;

  /// No description provided for @eaImplemented.
  ///
  /// In am, this message translates to:
  /// **'ተፈጽሟል'**
  String get eaImplemented;

  /// No description provided for @eaInternalNote.
  ///
  /// In am, this message translates to:
  /// **'የውስጥ ማስታወሻ'**
  String get eaInternalNote;

  /// No description provided for @eaJClassChanged.
  ///
  /// In am, this message translates to:
  /// **'ክፍል ተቀይሯል'**
  String get eaJClassChanged;

  /// No description provided for @eaJEnrolled.
  ///
  /// In am, this message translates to:
  /// **'ተመዝግቧል'**
  String get eaJEnrolled;

  /// No description provided for @eaJMarkAmended.
  ///
  /// In am, this message translates to:
  /// **'ውጤት ተስተካክሏል'**
  String get eaJMarkAmended;

  /// No description provided for @eaJMarkApproved.
  ///
  /// In am, this message translates to:
  /// **'ውጤት ጸድቋል'**
  String get eaJMarkApproved;

  /// No description provided for @eaJMarkPublished.
  ///
  /// In am, this message translates to:
  /// **'ውጤት ታትሟል'**
  String get eaJMarkPublished;

  /// No description provided for @eaJMarkRejected.
  ///
  /// In am, this message translates to:
  /// **'ውጤት ለማስተካከያ ተመልሷል'**
  String get eaJMarkRejected;

  /// No description provided for @eaJMarkSubmitted.
  ///
  /// In am, this message translates to:
  /// **'ውጤት ለማጽደቅ ቀርቧል'**
  String get eaJMarkSubmitted;

  /// No description provided for @eaJourney.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ጉዞ'**
  String get eaJourney;

  /// No description provided for @eaJRequestDecided.
  ///
  /// In am, this message translates to:
  /// **'በጥያቄ ላይ ውሳኔ ተሰጥቷል'**
  String get eaJRequestDecided;

  /// No description provided for @eaJStreamChanged.
  ///
  /// In am, this message translates to:
  /// **'ዘርፍ ተቀይሯል'**
  String get eaJStreamChanged;

  /// No description provided for @eaJStudyModeChanged.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ዓይነት ተቀይሯል'**
  String get eaJStudyModeChanged;

  /// No description provided for @eaJSubjectAdded.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት ተጨምሯል'**
  String get eaJSubjectAdded;

  /// No description provided for @eaJSubjectDropped.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት ተትቷል'**
  String get eaJSubjectDropped;

  /// No description provided for @eaJTeacherAssigned.
  ///
  /// In am, this message translates to:
  /// **'መምህር ሆነው ተመድበዋል'**
  String get eaJTeacherAssigned;

  /// No description provided for @eaJTeacherReactivated.
  ///
  /// In am, this message translates to:
  /// **'የመምህርነት ምደባ እንደገና ጸንቷል'**
  String get eaJTeacherReactivated;

  /// No description provided for @eaJTeacherRemoved.
  ///
  /// In am, this message translates to:
  /// **'ከመምህርነት ምደባ ተነስተዋል'**
  String get eaJTeacherRemoved;

  /// No description provided for @eaJTeacherSuspended.
  ///
  /// In am, this message translates to:
  /// **'የመምህርነት ምደባ ታግዷል'**
  String get eaJTeacherSuspended;

  /// No description provided for @eaJWithdrawn.
  ///
  /// In am, this message translates to:
  /// **'አቋርጧል'**
  String get eaJWithdrawn;

  /// No description provided for @eaLayoutLong.
  ///
  /// In am, this message translates to:
  /// **'በረድፍ (ተማሪ × ትምህርት)'**
  String get eaLayoutLong;

  /// No description provided for @eaLayoutWide.
  ///
  /// In am, this message translates to:
  /// **'በአምድ (ትምህርቶች በአምድ)'**
  String get eaLayoutWide;

  /// No description provided for @eaMarkDraft.
  ///
  /// In am, this message translates to:
  /// **'ረቂቅ'**
  String get eaMarkDraft;

  /// No description provided for @eaMarkEmpty.
  ///
  /// In am, this message translates to:
  /// **'አልገባም'**
  String get eaMarkEmpty;

  /// No description provided for @eaMarkPublished.
  ///
  /// In am, this message translates to:
  /// **'ታትሟል'**
  String get eaMarkPublished;

  /// No description provided for @eaMarkRejected.
  ///
  /// In am, this message translates to:
  /// **'ለማስተካከያ ተመልሷል'**
  String get eaMarkRejected;

  /// No description provided for @eaMarks.
  ///
  /// In am, this message translates to:
  /// **'ውጤቶች'**
  String get eaMarks;

  /// No description provided for @eaMarksExport.
  ///
  /// In am, this message translates to:
  /// **'የውጤት ሪፖርት'**
  String get eaMarksExport;

  /// No description provided for @eaMarkStatus.
  ///
  /// In am, this message translates to:
  /// **'የውጤት ሁኔታ'**
  String get eaMarkStatus;

  /// No description provided for @eaMarkSubmitted.
  ///
  /// In am, this message translates to:
  /// **'ለማጽደቅ ቀርቧል'**
  String get eaMarkSubmitted;

  /// No description provided for @eaMarksWorkflowHint.
  ///
  /// In am, this message translates to:
  /// **'ውጤቶች፦ ረቂቅ → ለማጽደቅ ማቅረብ → ማጽደቅ → ማተም። ተማሪዎች የሚያዩት የታተመውን ብቻ ነው።'**
  String get eaMarksWorkflowHint;

  /// No description provided for @eaMissingIsDash.
  ///
  /// In am, this message translates to:
  /// **'ያልገባ ውጤት «—» ሆኖ ይታያል (0 አይደለም)።'**
  String get eaMissingIsDash;

  /// No description provided for @eaMyClass.
  ///
  /// In am, this message translates to:
  /// **'ክፍሌ'**
  String get eaMyClass;

  /// No description provided for @eaNewComplaint.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ቅሬታ'**
  String get eaNewComplaint;

  /// No description provided for @eaNewRequest.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ጥያቄ'**
  String get eaNewRequest;

  /// No description provided for @eaNoComplaints.
  ///
  /// In am, this message translates to:
  /// **'ቅሬታ የለም'**
  String get eaNoComplaints;

  /// No description provided for @eaNoJourney.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን የተመዘገበ ነገር የለም'**
  String get eaNoJourney;

  /// No description provided for @eaNoRequests.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄ የለም'**
  String get eaNoRequests;

  /// No description provided for @eaNoStreams.
  ///
  /// In am, this message translates to:
  /// **'ይህ ክፍል ዘርፎች አልተዘጋጁለትም።'**
  String get eaNoStreams;

  /// No description provided for @eaNothingToReview.
  ///
  /// In am, this message translates to:
  /// **'የሚታይ ነገር የለም'**
  String get eaNothingToReview;

  /// No description provided for @eaNotSpecific.
  ///
  /// In am, this message translates to:
  /// **'አልተገለጸም'**
  String get eaNotSpecific;

  /// No description provided for @eaPublishConfirm.
  ///
  /// In am, this message translates to:
  /// **'የጸደቁት ውጤቶች ለተማሪዎች ይታተሙ?'**
  String get eaPublishConfirm;

  /// No description provided for @eaReactivate.
  ///
  /// In am, this message translates to:
  /// **'እንደገና አጽና'**
  String get eaReactivate;

  /// No description provided for @eaRejectReason.
  ///
  /// In am, this message translates to:
  /// **'ያልጸደቀበት ምክንያት'**
  String get eaRejectReason;

  /// No description provided for @eaRemove.
  ///
  /// In am, this message translates to:
  /// **'አንሳ'**
  String get eaRemove;

  /// No description provided for @eaReplyHint.
  ///
  /// In am, this message translates to:
  /// **'ምላሽ ወይም ማስታወሻ…'**
  String get eaReplyHint;

  /// No description provided for @eaReqAddClass.
  ///
  /// In am, this message translates to:
  /// **'ኮርስ መመዝገብ'**
  String get eaReqAddClass;

  /// No description provided for @eaReqAddSubject.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት መጨመር'**
  String get eaReqAddSubject;

  /// No description provided for @eaReqClassChange.
  ///
  /// In am, this message translates to:
  /// **'የክፍል ለውጥ'**
  String get eaReqClassChange;

  /// No description provided for @eaReqDropClass.
  ///
  /// In am, this message translates to:
  /// **'ኮርስ ማቋረጥ'**
  String get eaReqDropClass;

  /// No description provided for @eaReqDropSubject.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት መተው'**
  String get eaReqDropSubject;

  /// No description provided for @eaReqOther.
  ///
  /// In am, this message translates to:
  /// **'ሌላ ለውጥ'**
  String get eaReqOther;

  /// No description provided for @eaReqStreamChange.
  ///
  /// In am, this message translates to:
  /// **'የዘርፍ ለውጥ'**
  String get eaReqStreamChange;

  /// No description provided for @eaReqStudyMode.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ዓይነት ለውጥ (መደበኛ / ርቀት)'**
  String get eaReqStudyMode;

  /// No description provided for @eaRequestedChange.
  ///
  /// In am, this message translates to:
  /// **'የሚፈልጉት ለውጥ'**
  String get eaRequestedChange;

  /// No description provided for @eaRequests.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄዎች'**
  String get eaRequests;

  /// No description provided for @eaRequestSent.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄዎ ቀርቧል'**
  String get eaRequestSent;

  /// No description provided for @eaRequestType.
  ///
  /// In am, this message translates to:
  /// **'የጥያቄ ዓይነት'**
  String get eaRequestType;

  /// No description provided for @eaResultPending.
  ///
  /// In am, this message translates to:
  /// **'በሂደት ላይ'**
  String get eaResultPending;

  /// No description provided for @eaReviewCenter.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ግምገማ ማዕከል'**
  String get eaReviewCenter;

  /// No description provided for @eaReviewCenterSub.
  ///
  /// In am, this message translates to:
  /// **'ውጤቶችን ማጽደቅ፣ ጥያቄዎች፣ ቅሬታዎች እና ሪፖርቶች'**
  String get eaReviewCenterSub;

  /// No description provided for @eaSelfService.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄዎች፣ ቅሬታዎች እና የትምህርት ጉዞ'**
  String get eaSelfService;

  /// No description provided for @eaSelfServiceSub.
  ///
  /// In am, this message translates to:
  /// **'የክፍል/ዘርፍ ለውጥ፣ ትምህርት መጨመር/መተው፣ ቅሬታ ማቅረብ'**
  String get eaSelfServiceSub;

  /// No description provided for @eaSemester.
  ///
  /// In am, this message translates to:
  /// **'ሴሚስተር'**
  String get eaSemester;

  /// No description provided for @eaSend.
  ///
  /// In am, this message translates to:
  /// **'አስገባ'**
  String get eaSend;

  /// No description provided for @eaStream.
  ///
  /// In am, this message translates to:
  /// **'ዘርፍ'**
  String get eaStream;

  /// No description provided for @eaStreams.
  ///
  /// In am, this message translates to:
  /// **'ዘርፎች'**
  String get eaStreams;

  /// No description provided for @eaStreamsHint.
  ///
  /// In am, this message translates to:
  /// **'በኮማ ይለዩ (ለምሳሌ፦ ሀ, ለ)'**
  String get eaStreamsHint;

  /// No description provided for @eaStudentIdOrName.
  ///
  /// In am, this message translates to:
  /// **'የተማሪ መለያ ወይም ስም'**
  String get eaStudentIdOrName;

  /// No description provided for @eaStudyMode.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ዓይነት'**
  String get eaStudyMode;

  /// No description provided for @eaSubject.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት'**
  String get eaSubject;

  /// No description provided for @eaSubjectCode.
  ///
  /// In am, this message translates to:
  /// **'የትምህርቱ ኮድ'**
  String get eaSubjectCode;

  /// No description provided for @eaSubjects.
  ///
  /// In am, this message translates to:
  /// **'ትምህርቶች'**
  String get eaSubjects;

  /// No description provided for @eaSubmitMarks.
  ///
  /// In am, this message translates to:
  /// **'ለማጽደቅ አቅርብ'**
  String get eaSubmitMarks;

  /// No description provided for @eaSubmitMarksConfirm.
  ///
  /// In am, this message translates to:
  /// **'የገቡት ውጤቶች ለትምህርት ክፍሉ ለማጽደቅ ይቅረቡ? ከቀረቡ በኋላ መቀየር አይቻልም።'**
  String get eaSubmitMarksConfirm;

  /// No description provided for @eaSuspend.
  ///
  /// In am, this message translates to:
  /// **'አግድ'**
  String get eaSuspend;

  /// No description provided for @eaTargetClass.
  ///
  /// In am, this message translates to:
  /// **'ወደ የሚፈልጉት ክፍል'**
  String get eaTargetClass;

  /// No description provided for @eaTeacherRemoved.
  ///
  /// In am, this message translates to:
  /// **'ተነስቷል'**
  String get eaTeacherRemoved;

  /// No description provided for @eaTeachers.
  ///
  /// In am, this message translates to:
  /// **'መምህራን'**
  String get eaTeachers;

  /// No description provided for @eaTeacherSuspended.
  ///
  /// In am, this message translates to:
  /// **'ታግዷል'**
  String get eaTeacherSuspended;

  /// No description provided for @eaComplaintRef.
  ///
  /// In am, this message translates to:
  /// **'የቅሬታዎ መለያ ቁጥር፦ {ref}'**
  String eaComplaintRef(String ref);

  /// No description provided for @eaMarksCount.
  ///
  /// In am, this message translates to:
  /// **'{n} ውጤቶች'**
  String eaMarksCount(int n);

  /// No description provided for @eaMarksSubmitted.
  ///
  /// In am, this message translates to:
  /// **'{n} ውጤቶች ለማጽደቅ ቀርበዋል፤ {empty} ባዶ ናቸው።'**
  String eaMarksSubmitted(int n, int empty);

  /// No description provided for @eaPublishApproved.
  ///
  /// In am, this message translates to:
  /// **'የጸደቁትን አትም ({n})'**
  String eaPublishApproved(int n);

  /// No description provided for @eaResolvedIn.
  ///
  /// In am, this message translates to:
  /// **'በ{hours} ሰዓት ውስጥ ተፈትቷል'**
  String eaResolvedIn(String hours);

  /// No description provided for @eaTeachersOf.
  ///
  /// In am, this message translates to:
  /// **'የ{course} መምህራን'**
  String eaTeachersOf(String course);

  /// No description provided for @scMezmurExport.
  ///
  /// In am, this message translates to:
  /// **'የመዝሙር ምርጫ ሪፖርት'**
  String get scMezmurExport;

  /// No description provided for @recurrenceTwiceMonthly.
  ///
  /// In am, this message translates to:
  /// **'በወር 2 ጊዜ (በየ2 ሳምንቱ)'**
  String get recurrenceTwiceMonthly;

  /// No description provided for @twiceMonthlyRuleDay.
  ///
  /// In am, this message translates to:
  /// **'በተወሰኑ ሁለት ቀኖች (ለምሳሌ 1 እና 15)'**
  String get twiceMonthlyRuleDay;

  /// No description provided for @twiceMonthlyRuleWeekday.
  ///
  /// In am, this message translates to:
  /// **'በሳምንቱ ቀን (1ኛ እና 3ኛ ወይም 2ኛ እና 4ኛ)'**
  String get twiceMonthlyRuleWeekday;

  /// No description provided for @twiceMonthlyDays.
  ///
  /// In am, this message translates to:
  /// **'በየወሩ በ{first}ኛው እና በ{second}ኛው ቀን'**
  String twiceMonthlyDays(String first, String second);

  /// No description provided for @twiceMonthlyNth13.
  ///
  /// In am, this message translates to:
  /// **'በየወሩ 1ኛው እና 3ኛው {weekday}'**
  String twiceMonthlyNth13(String weekday);

  /// No description provided for @twiceMonthlyNth24.
  ///
  /// In am, this message translates to:
  /// **'በየወሩ 2ኛው እና 4ኛው {weekday}'**
  String twiceMonthlyNth24(String weekday);

  /// No description provided for @vWeightsTotal.
  ///
  /// In am, this message translates to:
  /// **'የመመዘኛዎቹ ድምር ከክፍሉ ድርሻ ጋር እኩል መሆን አለበት።'**
  String get vWeightsTotal;

  /// No description provided for @vMinimumAboveWeight.
  ///
  /// In am, this message translates to:
  /// **'ዝቅተኛው ነጥብ ከመመዘኛው ክብደት መብለጥ አይችልም።'**
  String get vMinimumAboveWeight;

  /// No description provided for @elTabLearn.
  ///
  /// In am, this message translates to:
  /// **'ተማር'**
  String get elTabLearn;

  /// No description provided for @elTabClasses.
  ///
  /// In am, this message translates to:
  /// **'ክፍሎች'**
  String get elTabClasses;

  /// No description provided for @elTabProgress.
  ///
  /// In am, this message translates to:
  /// **'እድገት'**
  String get elTabProgress;

  /// No description provided for @elTabMore.
  ///
  /// In am, this message translates to:
  /// **'ተጨማሪ'**
  String get elTabMore;

  /// No description provided for @elHomeSubtitle.
  ///
  /// In am, this message translates to:
  /// **'የነፍስ ምግብና የዕውቀት መቅሰሚያ'**
  String get elHomeSubtitle;

  /// No description provided for @elFeaturedLabel.
  ///
  /// In am, this message translates to:
  /// **'የዕለቱ ትምህርት'**
  String get elFeaturedLabel;

  /// No description provided for @elFeatured.
  ///
  /// In am, this message translates to:
  /// **'የዕለቱ ትምህርት (ባነር)'**
  String get elFeatured;

  /// No description provided for @elStart.
  ///
  /// In am, this message translates to:
  /// **'ጀምር'**
  String get elStart;

  /// No description provided for @elContinue.
  ///
  /// In am, this message translates to:
  /// **'ቀጥል'**
  String get elContinue;

  /// No description provided for @elContinueLearning.
  ///
  /// In am, this message translates to:
  /// **'ካቆሙበት ይቀጥሉ'**
  String get elContinueLearning;

  /// No description provided for @elPositionOf.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት {pos} ከ {total}'**
  String elPositionOf(String pos, String total);

  /// No description provided for @elDoneOf.
  ///
  /// In am, this message translates to:
  /// **'{done} ከ {total} ተጠናቋል'**
  String elDoneOf(String done, String total);

  /// No description provided for @elPercentDone.
  ///
  /// In am, this message translates to:
  /// **'{p}% ተጠናቋል'**
  String elPercentDone(int p);

  /// No description provided for @elSubjects.
  ///
  /// In am, this message translates to:
  /// **'ትምህርቶች'**
  String get elSubjects;

  /// No description provided for @elSeeAll.
  ///
  /// In am, this message translates to:
  /// **'ሁሉንም እይ'**
  String get elSeeAll;

  /// No description provided for @elNoCategories.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን የትምህርት ምድቦች አልተዘጋጁም።'**
  String get elNoCategories;

  /// No description provided for @elThisWeek.
  ///
  /// In am, this message translates to:
  /// **'የዚህ ሳምንት'**
  String get elThisWeek;

  /// No description provided for @elWeeklyQuizzes.
  ///
  /// In am, this message translates to:
  /// **'የሳምንቱ የፈተና ጥያቄዎች'**
  String get elWeeklyQuizzes;

  /// No description provided for @elQuizzesWaiting.
  ///
  /// In am, this message translates to:
  /// **'{n} ፈተና(ዎች) ይጠብቁዎታል — እውቀትዎን ይፈትሹ!'**
  String elQuizzesWaiting(int n);

  /// No description provided for @elTakePart.
  ///
  /// In am, this message translates to:
  /// **'ተሳተፍ'**
  String get elTakePart;

  /// No description provided for @elNothingThisWeek.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ሳምንት የሚጠበቅብዎት ፈተና ወይም የቤት ሥራ የለም።'**
  String get elNothingThisWeek;

  /// No description provided for @elDue.
  ///
  /// In am, this message translates to:
  /// **'እስከ {date}'**
  String elDue(String date);

  /// No description provided for @elOverdue.
  ///
  /// In am, this message translates to:
  /// **'የዘገየ'**
  String get elOverdue;

  /// No description provided for @elMyStudies.
  ///
  /// In am, this message translates to:
  /// **'የእኔ ትምህርት'**
  String get elMyStudies;

  /// No description provided for @elNotEnrolledOpen.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን በክፍል አልተመዘገቡም። {n} ክፍል(ሎች) ለምዝገባ ክፍት ናቸው።'**
  String elNotEnrolledOpen(int n);

  /// No description provided for @elNotEnrolledNoOpen.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን በክፍል አልተመዘገቡም። ምዝገባ ሲከፈት እዚህ ይታያል፤ እስከዚያው ለሁሉም ክፍት የሆኑ ትምህርቶችን በ«ተማር» ማየት ይችላሉ።'**
  String get elNotEnrolledNoOpen;

  /// No description provided for @elNoUpcomingClasses.
  ///
  /// In am, this message translates to:
  /// **'በሚቀጥሉት 7 ቀናት ክፍለ ጊዜ የለም።'**
  String get elNoUpcomingClasses;

  /// No description provided for @elAttendance.
  ///
  /// In am, this message translates to:
  /// **'የክፍል መገኘት'**
  String get elAttendance;

  /// No description provided for @elNoSessionsYet.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን ክትትል አልተወሰደም'**
  String get elNoSessionsYet;

  /// No description provided for @elLatestResults.
  ///
  /// In am, this message translates to:
  /// **'የቅርብ ጊዜ ውጤቶች'**
  String get elLatestResults;

  /// No description provided for @elNoPublishedResults.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን የታተመ ውጤት የለም።'**
  String get elNoPublishedResults;

  /// No description provided for @elToGrade.
  ///
  /// In am, this message translates to:
  /// **'የሚታረሙ የቤት ሥራዎች'**
  String get elToGrade;

  /// No description provided for @elMarksRejected.
  ///
  /// In am, this message translates to:
  /// **'ለማስተካከያ የተመለሱ ውጤቶች'**
  String get elMarksRejected;

  /// No description provided for @elMarksDraft.
  ///
  /// In am, this message translates to:
  /// **'ያልቀረቡ ረቂቅ ውጤቶች'**
  String get elMarksDraft;

  /// No description provided for @elQuizAnswersToGrade.
  ///
  /// In am, this message translates to:
  /// **'የሚታረሙ የፈተና መልሶች'**
  String get elQuizAnswersToGrade;

  /// No description provided for @elAdminTools.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት አስተዳደር'**
  String get elAdminTools;

  /// No description provided for @elMarksToReview.
  ///
  /// In am, this message translates to:
  /// **'ለማጽደቅ የቀረቡ ውጤቶች'**
  String get elMarksToReview;

  /// No description provided for @elMarksToPublish.
  ///
  /// In am, this message translates to:
  /// **'የጸደቁ ያልታተሙ ውጤቶች'**
  String get elMarksToPublish;

  /// No description provided for @elRequestsPending.
  ///
  /// In am, this message translates to:
  /// **'በመጠባበቅ ላይ ያሉ ጥያቄዎች'**
  String get elRequestsPending;

  /// No description provided for @elComplaintsOpen.
  ///
  /// In am, this message translates to:
  /// **'ክፍት ቅሬታዎች'**
  String get elComplaintsOpen;

  /// No description provided for @elSubjectsUnlinked.
  ///
  /// In am, this message translates to:
  /// **'ከትምህርት ዓይነት ጋር ያልተያያዙ ኮርሶች'**
  String get elSubjectsUnlinked;

  /// No description provided for @elOtherSections.
  ///
  /// In am, this message translates to:
  /// **'ሌሎች ክፍሎች'**
  String get elOtherSections;

  /// No description provided for @elGuidanceCenter.
  ///
  /// In am, this message translates to:
  /// **'የመመሪያ ማዕከል'**
  String get elGuidanceCenter;

  /// No description provided for @elSearchHint.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት፣ ምድብ ወይም ጥቅስ ይፈልጉ'**
  String get elSearchHint;

  /// No description provided for @elSearchStart.
  ///
  /// In am, this message translates to:
  /// **'ቢያንስ 2 ፊደላት ይጻፉ'**
  String get elSearchStart;

  /// No description provided for @elSearchNone.
  ///
  /// In am, this message translates to:
  /// **'ምንም አልተገኘም'**
  String get elSearchNone;

  /// No description provided for @elMySubjects.
  ///
  /// In am, this message translates to:
  /// **'የእኔ ትምህርቶች'**
  String get elMySubjects;

  /// No description provided for @elCategories.
  ///
  /// In am, this message translates to:
  /// **'ምድቦች'**
  String get elCategories;

  /// No description provided for @elCategory.
  ///
  /// In am, this message translates to:
  /// **'ምድብ'**
  String get elCategory;

  /// No description provided for @elNoCategory.
  ///
  /// In am, this message translates to:
  /// **'ምድብ የሌላቸው'**
  String get elNoCategory;

  /// No description provided for @elOtherSubjects.
  ///
  /// In am, this message translates to:
  /// **'ሌሎች ትምህርቶች'**
  String get elOtherSubjects;

  /// No description provided for @elSubject.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ዓይነት'**
  String get elSubject;

  /// No description provided for @elLesson.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት'**
  String get elLesson;

  /// No description provided for @elLessons.
  ///
  /// In am, this message translates to:
  /// **'ትምህርቶች'**
  String get elLessons;

  /// No description provided for @elMoreLessons.
  ///
  /// In am, this message translates to:
  /// **'ሌሎች ትምህርቶች'**
  String get elMoreLessons;

  /// No description provided for @elClass.
  ///
  /// In am, this message translates to:
  /// **'ክፍል'**
  String get elClass;

  /// No description provided for @elLessonCount.
  ///
  /// In am, this message translates to:
  /// **'{n} ትምህርቶች'**
  String elLessonCount(int n);

  /// No description provided for @elSubjectCount.
  ///
  /// In am, this message translates to:
  /// **'{n} የትምህርት ዓይነቶች'**
  String elSubjectCount(int n);

  /// No description provided for @elNoLessonsYet.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት ገና አልተዘጋጀም'**
  String get elNoLessonsYet;

  /// No description provided for @elNoSubjectsInCategory.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ምድብ ገና የታተመ የትምህርት ዓይነት የለም።'**
  String get elNoSubjectsInCategory;

  /// No description provided for @elForStudents.
  ///
  /// In am, this message translates to:
  /// **'ለተመዘገቡ ተማሪዎች'**
  String get elForStudents;

  /// No description provided for @elSubjectForStudents.
  ///
  /// In am, this message translates to:
  /// **'የዚህ ትምህርት ይዘት ለተመዘገቡ ተማሪዎች ብቻ ነው። ርዕሶቹን ማየት ይችላሉ።'**
  String get elSubjectForStudents;

  /// No description provided for @elObjectives.
  ///
  /// In am, this message translates to:
  /// **'የትምህርቱ ዓላማዎች'**
  String get elObjectives;

  /// No description provided for @elCompleted.
  ///
  /// In am, this message translates to:
  /// **'ተጠናቋል'**
  String get elCompleted;

  /// No description provided for @elInProgress.
  ///
  /// In am, this message translates to:
  /// **'በመማር ላይ'**
  String get elInProgress;

  /// No description provided for @elLocked.
  ///
  /// In am, this message translates to:
  /// **'የተቆለፈ'**
  String get elLocked;

  /// No description provided for @elMinutes.
  ///
  /// In am, this message translates to:
  /// **'{n} ደቂቃ'**
  String elMinutes(int n);

  /// No description provided for @elLessonN.
  ///
  /// In am, this message translates to:
  /// **'ትምህርት {n}'**
  String elLessonN(String n);

  /// No description provided for @elTextSize.
  ///
  /// In am, this message translates to:
  /// **'የፊደል መጠን'**
  String get elTextSize;

  /// No description provided for @elBookmark.
  ///
  /// In am, this message translates to:
  /// **'ምልክት አድርግ'**
  String get elBookmark;

  /// No description provided for @elBookmarks.
  ///
  /// In am, this message translates to:
  /// **'ምልክት የተደረገባቸው'**
  String get elBookmarks;

  /// No description provided for @elShare.
  ///
  /// In am, this message translates to:
  /// **'አጋራ'**
  String get elShare;

  /// No description provided for @elPrevious.
  ///
  /// In am, this message translates to:
  /// **'ቀዳሚ'**
  String get elPrevious;

  /// No description provided for @elNext.
  ///
  /// In am, this message translates to:
  /// **'ቀጣይ'**
  String get elNext;

  /// No description provided for @elListen.
  ///
  /// In am, this message translates to:
  /// **'ያዳምጡ'**
  String get elListen;

  /// No description provided for @elMarkDone.
  ///
  /// In am, this message translates to:
  /// **'እንዳጠናቀቅሁ ምልክት አድርግ'**
  String get elMarkDone;

  /// No description provided for @elMarkNotDone.
  ///
  /// In am, this message translates to:
  /// **'እንዳላጠናቀቅሁ መልስ'**
  String get elMarkNotDone;

  /// No description provided for @elImages.
  ///
  /// In am, this message translates to:
  /// **'ምስሎች'**
  String get elImages;

  /// No description provided for @elMaterials.
  ///
  /// In am, this message translates to:
  /// **'አጋዥ መረጃዎች'**
  String get elMaterials;

  /// No description provided for @elTeacherNotes.
  ///
  /// In am, this message translates to:
  /// **'የመምህር ማስታወሻ'**
  String get elTeacherNotes;

  /// No description provided for @elVideoLink.
  ///
  /// In am, this message translates to:
  /// **'የቪዲዮ ሊንክ'**
  String get elVideoLink;

  /// No description provided for @elWebLink.
  ///
  /// In am, this message translates to:
  /// **'የድረ-ገጽ ሊንክ'**
  String get elWebLink;

  /// No description provided for @elBadLink.
  ///
  /// In am, this message translates to:
  /// **'ሊንኩ ትክክል አይደለም (https:// ያስፈልጋል)።'**
  String get elBadLink;

  /// No description provided for @elLessonProgress.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት እድገት'**
  String get elLessonProgress;

  /// No description provided for @elPublishedResults.
  ///
  /// In am, this message translates to:
  /// **'የታተሙ ውጤቶች'**
  String get elPublishedResults;

  /// No description provided for @elPending.
  ///
  /// In am, this message translates to:
  /// **'በመጠባበቅ ላይ'**
  String get elPending;

  /// No description provided for @elNoProgressYet.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን የተመዘገበ እድገት የለም። ትምህርት ሲጀምሩ እዚህ ይታያል።'**
  String get elNoProgressYet;

  /// No description provided for @elAttendanceSummary.
  ///
  /// In am, this message translates to:
  /// **'{rate} · ተገኝቷል {present} · ቀርቷል {absent} · በፈቃድ {excused}'**
  String elAttendanceSummary(String rate, int present, int absent, int excused);

  /// No description provided for @elQuiz.
  ///
  /// In am, this message translates to:
  /// **'ፈተና'**
  String get elQuiz;

  /// No description provided for @elQuizzes.
  ///
  /// In am, this message translates to:
  /// **'ፈተናዎች'**
  String get elQuizzes;

  /// No description provided for @elQuizOpen.
  ///
  /// In am, this message translates to:
  /// **'ክፍት'**
  String get elQuizOpen;

  /// No description provided for @elQuizUpcoming.
  ///
  /// In am, this message translates to:
  /// **'ገና አልተከፈተም'**
  String get elQuizUpcoming;

  /// No description provided for @elQuizClosed.
  ///
  /// In am, this message translates to:
  /// **'ተዘግቷል'**
  String get elQuizClosed;

  /// No description provided for @elQuizInProgress.
  ///
  /// In am, this message translates to:
  /// **'በመሥራት ላይ'**
  String get elQuizInProgress;

  /// No description provided for @elQuizDone.
  ///
  /// In am, this message translates to:
  /// **'ተሠርቷል'**
  String get elQuizDone;

  /// No description provided for @elQuizScore.
  ///
  /// In am, this message translates to:
  /// **'ውጤት፦ {score}'**
  String elQuizScore(String score);

  /// No description provided for @elScorePending.
  ///
  /// In am, this message translates to:
  /// **'ውጤቱ ሲታተም ይታያል'**
  String get elScorePending;

  /// No description provided for @elAwaitingTeacher.
  ///
  /// In am, this message translates to:
  /// **'መምህሩ የጽሑፍ መልሶችን እስኪያርሙ ይጠብቁ'**
  String get elAwaitingTeacher;

  /// No description provided for @elOfficialQuiz.
  ///
  /// In am, this message translates to:
  /// **'ይፋዊ ውጤት'**
  String get elOfficialQuiz;

  /// No description provided for @elOfficialQuizNote.
  ///
  /// In am, this message translates to:
  /// **'የዚህ ፈተና ውጤት በመምህሩና በትምህርት ክፍሉ ከጸደቀ በኋላ ይፋዊ ውጤት ሆኖ ይታተማል።'**
  String get elOfficialQuizNote;

  /// No description provided for @elPracticeScoreNote.
  ///
  /// In am, this message translates to:
  /// **'ይህ ውጤት ለልምምድ ነው እንጂ ይፋዊ ውጤት አይደለም።'**
  String get elPracticeScoreNote;

  /// No description provided for @elPolicyAfterClose.
  ///
  /// In am, this message translates to:
  /// **'ትክክለኛ መልሶች ፈተናው ሲዘጋ ይታያሉ።'**
  String get elPolicyAfterClose;

  /// No description provided for @elPolicyAfterSubmit.
  ///
  /// In am, this message translates to:
  /// **'ትክክለኛ መልሶች ካስረከቡ በኋላ ይታያሉ።'**
  String get elPolicyAfterSubmit;

  /// No description provided for @elPolicyPractice.
  ///
  /// In am, this message translates to:
  /// **'ልምምድ፦ እያንዳንዱን መልስ ወዲያውኑ መፈተሽ ይችላሉ።'**
  String get elPolicyPractice;

  /// No description provided for @elPolicyNever.
  ///
  /// In am, this message translates to:
  /// **'ትክክለኛ መልሶች አይታዩም።'**
  String get elPolicyNever;

  /// No description provided for @elQuizNotAvailable.
  ///
  /// In am, this message translates to:
  /// **'ይህ ፈተና ለእርስዎ አልተከፈተም (ለኮርሱ ተማሪዎች ብቻ ነው)።'**
  String get elQuizNotAvailable;

  /// No description provided for @elQuestionCount.
  ///
  /// In am, this message translates to:
  /// **'{n} ጥያቄዎች'**
  String elQuestionCount(int n);

  /// No description provided for @elAttemptsLeft.
  ///
  /// In am, this message translates to:
  /// **'{left} ከ {max} ሙከራ ቀርቷል'**
  String elAttemptsLeft(int left, int max);

  /// No description provided for @elOpens.
  ///
  /// In am, this message translates to:
  /// **'የሚከፈተው {date}'**
  String elOpens(String date);

  /// No description provided for @elInstructions.
  ///
  /// In am, this message translates to:
  /// **'መመሪያ'**
  String get elInstructions;

  /// No description provided for @elStartQuiz.
  ///
  /// In am, this message translates to:
  /// **'ፈተናውን ጀምር'**
  String get elStartQuiz;

  /// No description provided for @elTryAgain.
  ///
  /// In am, this message translates to:
  /// **'እንደገና ሞክር'**
  String get elTryAgain;

  /// No description provided for @elResume.
  ///
  /// In am, this message translates to:
  /// **'ቀጥል'**
  String get elResume;

  /// No description provided for @elViewAttempt.
  ///
  /// In am, this message translates to:
  /// **'የመጨረሻ ሙከራዬን እይ'**
  String get elViewAttempt;

  /// No description provided for @elQuestionOf.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄ {n} ከ {total}'**
  String elQuestionOf(String n, String total);

  /// No description provided for @elCheckAnswer.
  ///
  /// In am, this message translates to:
  /// **'መልስዎን ይፈትሹ'**
  String get elCheckAnswer;

  /// No description provided for @elSubmit.
  ///
  /// In am, this message translates to:
  /// **'አስረክብ'**
  String get elSubmit;

  /// No description provided for @elSubmitConfirm.
  ///
  /// In am, this message translates to:
  /// **'መልሶችዎን አሁን ያስረክቡ? ካስረከቡ በኋላ መቀየር አይቻልም።'**
  String get elSubmitConfirm;

  /// No description provided for @elSubmitUnanswered.
  ///
  /// In am, this message translates to:
  /// **'{n} ጥያቄ(ዎች) አልተመለሱም። አሁን ያስረክቡ?'**
  String elSubmitUnanswered(int n);

  /// No description provided for @elSubmitted.
  ///
  /// In am, this message translates to:
  /// **'ተረክቧል'**
  String get elSubmitted;

  /// No description provided for @elNoQuestions.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄዎች ገና አልተዘጋጁም'**
  String get elNoQuestions;

  /// No description provided for @elChooseAll.
  ///
  /// In am, this message translates to:
  /// **'ትክክል የሆኑትን ሁሉ ይምረጡ'**
  String get elChooseAll;

  /// No description provided for @elYourAnswer.
  ///
  /// In am, this message translates to:
  /// **'መልስዎን ይጻፉ'**
  String get elYourAnswer;

  /// No description provided for @elTrue.
  ///
  /// In am, this message translates to:
  /// **'እውነት'**
  String get elTrue;

  /// No description provided for @elFalse.
  ///
  /// In am, this message translates to:
  /// **'ሐሰት'**
  String get elFalse;

  /// No description provided for @elModelAnswer.
  ///
  /// In am, this message translates to:
  /// **'ናሙና መልስ'**
  String get elModelAnswer;

  /// No description provided for @elNewQuiz.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ፈተና'**
  String get elNewQuiz;

  /// No description provided for @elNoQuizzes.
  ///
  /// In am, this message translates to:
  /// **'ለዚህ ኮርስ ፈተና ገና አልተዘጋጀም።'**
  String get elNoQuizzes;

  /// No description provided for @elStatusDraft.
  ///
  /// In am, this message translates to:
  /// **'ረቂቅ'**
  String get elStatusDraft;

  /// No description provided for @elStatusPublished.
  ///
  /// In am, this message translates to:
  /// **'የታተመ'**
  String get elStatusPublished;

  /// No description provided for @elStatusArchived.
  ///
  /// In am, this message translates to:
  /// **'በማህደር'**
  String get elStatusArchived;

  /// No description provided for @elStatusActive.
  ///
  /// In am, this message translates to:
  /// **'ንቁ'**
  String get elStatusActive;

  /// No description provided for @elAttemptsCount.
  ///
  /// In am, this message translates to:
  /// **'{n} ሙከራዎች'**
  String elAttemptsCount(int n);

  /// No description provided for @elToGradeCount.
  ///
  /// In am, this message translates to:
  /// **'{n} የሚታረሙ'**
  String elToGradeCount(int n);

  /// No description provided for @elResults.
  ///
  /// In am, this message translates to:
  /// **'ውጤቶች'**
  String get elResults;

  /// No description provided for @elQuizLockedNote.
  ///
  /// In am, this message translates to:
  /// **'ተማሪዎች ፈተናውን ስለጀመሩ ጥያቄዎችና የውጤት ደንቦች መቀየር አይችሉም። የመዝጊያ ቀን፣ መመሪያና ሁኔታ ግን ይቀየራሉ።'**
  String get elQuizLockedNote;

  /// No description provided for @elPublish.
  ///
  /// In am, this message translates to:
  /// **'አትም'**
  String get elPublish;

  /// No description provided for @elCloseQuiz.
  ///
  /// In am, this message translates to:
  /// **'ዝጋ'**
  String get elCloseQuiz;

  /// No description provided for @elReopenQuiz.
  ///
  /// In am, this message translates to:
  /// **'እንደገና ክፈት'**
  String get elReopenQuiz;

  /// No description provided for @elQuizSettings.
  ///
  /// In am, this message translates to:
  /// **'የፈተናው ቅንብር'**
  String get elQuizSettings;

  /// No description provided for @elTitle.
  ///
  /// In am, this message translates to:
  /// **'ርዕስ'**
  String get elTitle;

  /// No description provided for @elOpensAt.
  ///
  /// In am, this message translates to:
  /// **'የሚከፈትበት'**
  String get elOpensAt;

  /// No description provided for @elClosesAt.
  ///
  /// In am, this message translates to:
  /// **'የሚዘጋበት (የመጨረሻ ቀን)'**
  String get elClosesAt;

  /// No description provided for @elTimeLimit.
  ///
  /// In am, this message translates to:
  /// **'የጊዜ ገደብ (ደቂቃ)'**
  String get elTimeLimit;

  /// No description provided for @elTimeLimitHint.
  ///
  /// In am, this message translates to:
  /// **'ባዶ = ገደብ የለም'**
  String get elTimeLimitHint;

  /// No description provided for @elMaxAttempts.
  ///
  /// In am, this message translates to:
  /// **'የሙከራ ብዛት'**
  String get elMaxAttempts;

  /// No description provided for @elScoring.
  ///
  /// In am, this message translates to:
  /// **'የሚቆጠረው'**
  String get elScoring;

  /// No description provided for @elScoringBest.
  ///
  /// In am, this message translates to:
  /// **'ከፍተኛው ሙከራ'**
  String get elScoringBest;

  /// No description provided for @elScoringLast.
  ///
  /// In am, this message translates to:
  /// **'የመጨረሻው ሙከራ'**
  String get elScoringLast;

  /// No description provided for @elReviewPolicy.
  ///
  /// In am, this message translates to:
  /// **'ትክክለኛ መልሶች መቼ ይታዩ'**
  String get elReviewPolicy;

  /// No description provided for @elLinkAssessment.
  ///
  /// In am, this message translates to:
  /// **'ከውጤት መመዝገቢያ ጋር ማያያዝ'**
  String get elLinkAssessment;

  /// No description provided for @elLinkAssessmentHint.
  ///
  /// In am, this message translates to:
  /// **'ከተያያዘ ውጤቶቹ ወደዚያ የውጤት መመዝገቢያ በረቂቅነት ይላካሉ፤ ከዚያም እንደተለመደው ቀርበው፣ ጸድቀው ይታተማሉ።'**
  String get elLinkAssessmentHint;

  /// No description provided for @elNotOfficial.
  ///
  /// In am, this message translates to:
  /// **'አይያያዝም (ልምምድ)'**
  String get elNotOfficial;

  /// No description provided for @elNotOfficialNote.
  ///
  /// In am, this message translates to:
  /// **'ይህ ፈተና ከውጤት መመዝገቢያ ጋር አልተያያዘም፤ ውጤቱ ለልምምድ ብቻ ነው።'**
  String get elNotOfficialNote;

  /// No description provided for @elLinkLesson.
  ///
  /// In am, this message translates to:
  /// **'ከትምህርት ጋር ማያያዝ'**
  String get elLinkLesson;

  /// No description provided for @elShuffle.
  ///
  /// In am, this message translates to:
  /// **'የጥያቄዎችን ቅደም ተከተል ቀላቅል'**
  String get elShuffle;

  /// No description provided for @elQuestions.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄዎች'**
  String get elQuestions;

  /// No description provided for @elAddQuestion.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄ ጨምር'**
  String get elAddQuestion;

  /// No description provided for @elSaveQuestions.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄዎቹን አስቀምጥ'**
  String get elSaveQuestions;

  /// No description provided for @elDeleteQuizConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህን ፈተና ይሰርዙ?'**
  String get elDeleteQuizConfirm;

  /// No description provided for @elQuestionN.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄ {n}'**
  String elQuestionN(int n);

  /// No description provided for @elTypeSingle.
  ///
  /// In am, this message translates to:
  /// **'አንድ ምርጫ'**
  String get elTypeSingle;

  /// No description provided for @elTypeMultiple.
  ///
  /// In am, this message translates to:
  /// **'ብዙ ምርጫ'**
  String get elTypeMultiple;

  /// No description provided for @elTypeTrueFalse.
  ///
  /// In am, this message translates to:
  /// **'እውነት/ሐሰት'**
  String get elTypeTrueFalse;

  /// No description provided for @elTypeShortText.
  ///
  /// In am, this message translates to:
  /// **'አጭር ጽሑፍ'**
  String get elTypeShortText;

  /// No description provided for @elPrompt.
  ///
  /// In am, this message translates to:
  /// **'ጥያቄው'**
  String get elPrompt;

  /// No description provided for @elOptionN.
  ///
  /// In am, this message translates to:
  /// **'ምርጫ {n}'**
  String elOptionN(int n);

  /// No description provided for @elAddOption.
  ///
  /// In am, this message translates to:
  /// **'ምርጫ ጨምር'**
  String get elAddOption;

  /// No description provided for @elMarkCorrect.
  ///
  /// In am, this message translates to:
  /// **'ትክክለኛውን መልስ ይምረጡ'**
  String get elMarkCorrect;

  /// No description provided for @elShortTextHint.
  ///
  /// In am, this message translates to:
  /// **'በመምህሩ ይታረማል፤ ናሙና መልሱ ለተማሪዎች መልሶቹ ሲታዩ ይታያል።'**
  String get elShortTextHint;

  /// No description provided for @elPoints.
  ///
  /// In am, this message translates to:
  /// **'ነጥብ'**
  String get elPoints;

  /// No description provided for @elExplanation.
  ///
  /// In am, this message translates to:
  /// **'ማብራሪያ (አማራጭ)'**
  String get elExplanation;

  /// No description provided for @elQuestionNeedsPrompt.
  ///
  /// In am, this message translates to:
  /// **'እያንዳንዱ ጥያቄ ጽሑፍ ያስፈልገዋል።'**
  String get elQuestionNeedsPrompt;

  /// No description provided for @elQuestionNeedsOptions.
  ///
  /// In am, this message translates to:
  /// **'ምርጫ ጥያቄ ቢያንስ 2 ምርጫዎች ያስፈልገዋል።'**
  String get elQuestionNeedsOptions;

  /// No description provided for @elQuestionNeedsAnswer.
  ///
  /// In am, this message translates to:
  /// **'የእያንዳንዱን ጥያቄ ትክክለኛ መልስ ይምረጡ።'**
  String get elQuestionNeedsAnswer;

  /// No description provided for @elTransfer.
  ///
  /// In am, this message translates to:
  /// **'ወደ ውጤት መመዝገቢያ ላክ'**
  String get elTransfer;

  /// No description provided for @elTransferConfirm.
  ///
  /// In am, this message translates to:
  /// **'የፈተናውን ውጤቶች ወደተያያዘው የውጤት መመዝገቢያ በረቂቅነት ይላኩ? ቀድሞ የቀረቡ ወይም የጸደቁ ውጤቶች አይቀየሩም።'**
  String get elTransferConfirm;

  /// No description provided for @elTransferResult.
  ///
  /// In am, this message translates to:
  /// **'{sent} ውጤቶች በረቂቅነት ተልከዋል። {pending} የመምህር እርማት ይጠብቃሉ፤ {locked} ቀድሞ የቀረቡ/የጸደቁ ስለሆኑ አልተቀየሩም። ከውጤት መመዝገቢያው ያቅርቧቸው።'**
  String elTransferResult(int sent, int pending, int locked);

  /// No description provided for @elTransferred.
  ///
  /// In am, this message translates to:
  /// **'ተልኳል'**
  String get elTransferred;

  /// No description provided for @elNeedsGrading.
  ///
  /// In am, this message translates to:
  /// **'እርማት ይጠብቃል'**
  String get elNeedsGrading;

  /// No description provided for @elNotTaken.
  ///
  /// In am, this message translates to:
  /// **'አልተሠራም'**
  String get elNotTaken;

  /// No description provided for @elNoStudents.
  ///
  /// In am, this message translates to:
  /// **'ተማሪዎች የሉም'**
  String get elNoStudents;

  /// No description provided for @elAttempt.
  ///
  /// In am, this message translates to:
  /// **'ሙከራ'**
  String get elAttempt;

  /// No description provided for @elGradeAnswer.
  ///
  /// In am, this message translates to:
  /// **'መልሱን አርም'**
  String get elGradeAnswer;

  /// No description provided for @elPointsOutOf.
  ///
  /// In am, this message translates to:
  /// **'ነጥብ (ከ {max})'**
  String elPointsOutOf(String max);

  /// No description provided for @elContentTitle.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ይዘት'**
  String get elContentTitle;

  /// No description provided for @elNoAuthoring.
  ///
  /// In am, this message translates to:
  /// **'የሚያስተምሩት ኮርስ ገና ከትምህርት ዓይነት ጋር አልተያያዘም።'**
  String get elNoAuthoring;

  /// No description provided for @elNewCategory.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ምድብ'**
  String get elNewCategory;

  /// No description provided for @elEditCategory.
  ///
  /// In am, this message translates to:
  /// **'ምድቡን አስተካክል'**
  String get elEditCategory;

  /// No description provided for @elDragToReorder.
  ///
  /// In am, this message translates to:
  /// **'ቅደም ተከተል ለመቀየር ይጎትቱ'**
  String get elDragToReorder;

  /// No description provided for @elNameAmharic.
  ///
  /// In am, this message translates to:
  /// **'ስም (አማርኛ)'**
  String get elNameAmharic;

  /// No description provided for @elNameEnglish.
  ///
  /// In am, this message translates to:
  /// **'ስም (እንግሊዝኛ)'**
  String get elNameEnglish;

  /// No description provided for @elNameRequired.
  ///
  /// In am, this message translates to:
  /// **'ስም / ርዕስ ያስፈልጋል።'**
  String get elNameRequired;

  /// No description provided for @elDescription.
  ///
  /// In am, this message translates to:
  /// **'መግለጫ'**
  String get elDescription;

  /// No description provided for @elIcon.
  ///
  /// In am, this message translates to:
  /// **'አዶ (ምስል እስኪጫን)'**
  String get elIcon;

  /// No description provided for @elAddImage.
  ///
  /// In am, this message translates to:
  /// **'ምስል ጨምር'**
  String get elAddImage;

  /// No description provided for @elChangeImage.
  ///
  /// In am, this message translates to:
  /// **'ምስል ቀይር'**
  String get elChangeImage;

  /// No description provided for @elRemoveImage.
  ///
  /// In am, this message translates to:
  /// **'ምስል አስወግድ'**
  String get elRemoveImage;

  /// No description provided for @elImage.
  ///
  /// In am, this message translates to:
  /// **'ምስል'**
  String get elImage;

  /// No description provided for @elImageAfterSave.
  ///
  /// In am, this message translates to:
  /// **'ምስል ከተቀመጠ በኋላ መጨመር ይቻላል።'**
  String get elImageAfterSave;

  /// No description provided for @elArchiveHint.
  ///
  /// In am, this message translates to:
  /// **'ሲጠፋ በማህደር ይቀመጣል፤ ለአባላት አይታይም።'**
  String get elArchiveHint;

  /// No description provided for @elDeleteCategoryConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህን ምድብ ይሰርዙ? የትምህርት ዓይነቶች ያሉት ምድብ ሊሰረዝ አይችልም — በማህደር ያስቀምጡት።'**
  String get elDeleteCategoryConfirm;

  /// No description provided for @elNewSubject.
  ///
  /// In am, this message translates to:
  /// **'አዲስ የትምህርት ዓይነት'**
  String get elNewSubject;

  /// No description provided for @elEditSubject.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ዓይነቱን አስተካክል'**
  String get elEditSubject;

  /// No description provided for @elNoSubjects.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ዓይነቶች ገና አልተዘጋጁም።'**
  String get elNoSubjects;

  /// No description provided for @elCode.
  ///
  /// In am, this message translates to:
  /// **'ኮድ'**
  String get elCode;

  /// No description provided for @elWhoCanRead.
  ///
  /// In am, this message translates to:
  /// **'ይዘቱን ማን ያያል'**
  String get elWhoCanRead;

  /// No description provided for @elVisibilityEnrolled.
  ///
  /// In am, this message translates to:
  /// **'የተመዘገቡ ተማሪዎች ብቻ'**
  String get elVisibilityEnrolled;

  /// No description provided for @elVisibilityMembers.
  ///
  /// In am, this message translates to:
  /// **'ሁሉም አባላት'**
  String get elVisibilityMembers;

  /// No description provided for @elStatus.
  ///
  /// In am, this message translates to:
  /// **'ሁኔታ'**
  String get elStatus;

  /// No description provided for @elSequential.
  ///
  /// In am, this message translates to:
  /// **'በቅደም ተከተል መማር'**
  String get elSequential;

  /// No description provided for @elSequentialHint.
  ///
  /// In am, this message translates to:
  /// **'ተማሪዎች ቀዳሚውን ትምህርት ሳያጠናቅቁ ቀጣዩን መክፈት አይችሉም።'**
  String get elSequentialHint;

  /// No description provided for @elEditCurriculum.
  ///
  /// In am, this message translates to:
  /// **'ትምህርቶችን አስተካክል'**
  String get elEditCurriculum;

  /// No description provided for @elPreview.
  ///
  /// In am, this message translates to:
  /// **'ቅድመ እይታ'**
  String get elPreview;

  /// No description provided for @elNewLesson.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ትምህርት'**
  String get elNewLesson;

  /// No description provided for @elEditLesson.
  ///
  /// In am, this message translates to:
  /// **'ትምህርቱን አስተካክል'**
  String get elEditLesson;

  /// No description provided for @elMaterialCount.
  ///
  /// In am, this message translates to:
  /// **'{n} አጋዥ መረጃዎች'**
  String elMaterialCount(int n);

  /// No description provided for @elNotLinkedYet.
  ///
  /// In am, this message translates to:
  /// **'ይህ የትምህርት ዓይነት ከማንኛውም ክፍል ኮርስ ጋር ገና አልተያያዘም (በኮርስ አስተዳደር ውስጥ ያያይዙት)።'**
  String get elNotLinkedYet;

  /// No description provided for @elTaughtIn.
  ///
  /// In am, this message translates to:
  /// **'የሚሰጠው በ፦ {list}'**
  String elTaughtIn(String list);

  /// No description provided for @elUnits.
  ///
  /// In am, this message translates to:
  /// **'ምዕራፎች'**
  String get elUnits;

  /// No description provided for @elUnit.
  ///
  /// In am, this message translates to:
  /// **'ምዕራፍ'**
  String get elUnit;

  /// No description provided for @elNewUnit.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ምዕራፍ'**
  String get elNewUnit;

  /// No description provided for @elRenameUnit.
  ///
  /// In am, this message translates to:
  /// **'ምዕራፉን ቀይር'**
  String get elRenameUnit;

  /// No description provided for @elNoUnits.
  ///
  /// In am, this message translates to:
  /// **'ምዕራፎች የሉም — ትምህርቶች በቀጥታ ይዘረዘራሉ።'**
  String get elNoUnits;

  /// No description provided for @elDeleteUnitConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህን ምዕራፍ ይሰርዙ? ትምህርቶቹ አይሰረዙም።'**
  String get elDeleteUnitConfirm;

  /// No description provided for @elSummary.
  ///
  /// In am, this message translates to:
  /// **'አጭር መግለጫ'**
  String get elSummary;

  /// No description provided for @elScriptureRefs.
  ///
  /// In am, this message translates to:
  /// **'የመጽሐፍ ቅዱስ ጥቅሶች'**
  String get elScriptureRefs;

  /// No description provided for @elScriptureRefsHint.
  ///
  /// In am, this message translates to:
  /// **'ለምሳሌ፦ የሐዋ. 2፥1-4'**
  String get elScriptureRefsHint;

  /// No description provided for @elEstMinutes.
  ///
  /// In am, this message translates to:
  /// **'የሚወስደው ጊዜ (ደቂቃ)'**
  String get elEstMinutes;

  /// No description provided for @elLessonText.
  ///
  /// In am, this message translates to:
  /// **'የትምህርቱ ጽሑፍ'**
  String get elLessonText;

  /// No description provided for @elFormattingHelp.
  ///
  /// In am, this message translates to:
  /// **'«# » ርዕስ፣ «## » ንዑስ ርዕስ፣ «> » ጥቅስ፣ «- » ዝርዝር፤ ባዶ መስመር አዲስ አንቀጽ ይጀምራል።'**
  String get elFormattingHelp;

  /// No description provided for @elTeacherNotesHint.
  ///
  /// In am, this message translates to:
  /// **'ለመምህራንና አዘጋጆች ብቻ ይታያል።'**
  String get elTeacherNotesHint;

  /// No description provided for @elMaterialsHint.
  ///
  /// In am, this message translates to:
  /// **'PDF፣ ምስል፣ የድምጽ ፋይል ወይም ሰነድ ይጫኑ፤ ቪዲዮ በሊንክ ይጨመራል። ፋይሎቹ ለትምህርቱ ተማሪዎች ብቻ ይወርዳሉ።'**
  String get elMaterialsHint;

  /// No description provided for @elMaterialTitle.
  ///
  /// In am, this message translates to:
  /// **'የርዕስ ስም'**
  String get elMaterialTitle;

  /// No description provided for @elUploadFile.
  ///
  /// In am, this message translates to:
  /// **'ፋይል ጫን'**
  String get elUploadFile;

  /// No description provided for @elAddLink.
  ///
  /// In am, this message translates to:
  /// **'ሊንክ ጨምር'**
  String get elAddLink;

  /// No description provided for @elDeleteMaterialConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህን አጋዥ መረጃ ይሰርዙ?'**
  String get elDeleteMaterialConfirm;

  /// No description provided for @elDeleteLessonConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህን ትምህርት ይሰርዙ? ተማሪዎች የከፈቱት ትምህርት ሊሰረዝ አይችልም — በማህደር ያስቀምጡት።'**
  String get elDeleteLessonConfirm;

  /// No description provided for @elAddFeatured.
  ///
  /// In am, this message translates to:
  /// **'ባነር ጨምር'**
  String get elAddFeatured;

  /// No description provided for @elEditFeatured.
  ///
  /// In am, this message translates to:
  /// **'ባነሩን አስተካክል'**
  String get elEditFeatured;

  /// No description provided for @elNoFeatured.
  ///
  /// In am, this message translates to:
  /// **'በባነሩ ላይ ምንም የለም። ትምህርት ወይም የትምህርት ዓይነት ይጨምሩ።'**
  String get elNoFeatured;

  /// No description provided for @elTargetUnavailable.
  ///
  /// In am, this message translates to:
  /// **'ይዘቱ አልታተመም/ተወግዷል'**
  String get elTargetUnavailable;

  /// No description provided for @elInactive.
  ///
  /// In am, this message translates to:
  /// **'ጠፍቷል'**
  String get elInactive;

  /// No description provided for @elDeleteFeaturedConfirm.
  ///
  /// In am, this message translates to:
  /// **'ከባነሩ ይውጣ?'**
  String get elDeleteFeaturedConfirm;

  /// No description provided for @elChooseTarget.
  ///
  /// In am, this message translates to:
  /// **'የሚታየውን ይዘት ይምረጡ።'**
  String get elChooseTarget;

  /// No description provided for @elTitleOverride.
  ///
  /// In am, this message translates to:
  /// **'ርዕስ (አማራጭ)'**
  String get elTitleOverride;

  /// No description provided for @elTitleOverrideHint.
  ///
  /// In am, this message translates to:
  /// **'ባዶ ከሆነ የይዘቱ ርዕስ ይታያል'**
  String get elTitleOverrideHint;

  /// No description provided for @elSubtitle.
  ///
  /// In am, this message translates to:
  /// **'ንዑስ ርዕስ'**
  String get elSubtitle;

  /// No description provided for @elShowFrom.
  ///
  /// In am, this message translates to:
  /// **'ከ… ጀምሮ ይታይ'**
  String get elShowFrom;

  /// No description provided for @elShowUntil.
  ///
  /// In am, this message translates to:
  /// **'እስከ… ይታይ'**
  String get elShowUntil;

  /// No description provided for @elCatalogSubject.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ዓይነት (ሥርዓተ ትምህርት)'**
  String get elCatalogSubject;

  /// No description provided for @elCatalogSubjectHint.
  ///
  /// In am, this message translates to:
  /// **'የዚህ ኮርስ ተማሪዎች የዚህን የትምህርት ዓይነት ትምህርቶች ያያሉ፤ መምህሩም ትምህርቶችን ያዘጋጃል።'**
  String get elCatalogSubjectHint;

  /// No description provided for @errModuleDisabled.
  ///
  /// In am, this message translates to:
  /// **'ይህ ክፍል ለመለያዎ ተዘግቷል።'**
  String get errModuleDisabled;

  /// No description provided for @errHasRecords.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት መዝገቦች ስላሉት ሊሰረዝ አይችልም — በማህደር ያስቀምጡት።'**
  String get errHasRecords;

  /// No description provided for @errLessonLocked.
  ///
  /// In am, this message translates to:
  /// **'መጀመሪያ ቀዳሚውን ትምህርት ያጠናቅቁ።'**
  String get errLessonLocked;

  /// No description provided for @errNotEnrolledSubject.
  ///
  /// In am, this message translates to:
  /// **'ይህ ለዚህ ትምህርት የተመዘገቡ ተማሪዎች ብቻ ነው።'**
  String get errNotEnrolledSubject;

  /// No description provided for @errNotSubjectEditor.
  ///
  /// In am, this message translates to:
  /// **'ይህን ትምህርት ለማዘጋጀት ፈቃድ የለዎትም።'**
  String get errNotSubjectEditor;

  /// No description provided for @errQuizNotOpen.
  ///
  /// In am, this message translates to:
  /// **'ፈተናው ገና አልተከፈተም።'**
  String get errQuizNotOpen;

  /// No description provided for @errQuizClosed.
  ///
  /// In am, this message translates to:
  /// **'ፈተናው ተዘግቷል።'**
  String get errQuizClosed;

  /// No description provided for @errNoAttemptsLeft.
  ///
  /// In am, this message translates to:
  /// **'የተፈቀደልዎትን ሙከራ ሁሉ ተጠቅመዋል።'**
  String get errNoAttemptsLeft;

  /// No description provided for @errAttemptExpired.
  ///
  /// In am, this message translates to:
  /// **'የዚህ ሙከራ ጊዜ አልቋል፤ የመለሱት ተረክቧል።'**
  String get errAttemptExpired;

  /// No description provided for @errAttemptSubmitted.
  ///
  /// In am, this message translates to:
  /// **'ይህ ሙከራ ቀድሞ ተረክቧል።'**
  String get errAttemptSubmitted;

  /// No description provided for @errQuizHasAttempts.
  ///
  /// In am, this message translates to:
  /// **'ተማሪዎች ስለሠሩት ይህ መቀየር አይችልም።'**
  String get errQuizHasAttempts;

  /// No description provided for @errQuizEmpty.
  ///
  /// In am, this message translates to:
  /// **'ከማተምዎ በፊት ጥያቄዎችን ይጨምሩ።'**
  String get errQuizEmpty;

  /// No description provided for @errQuizNotLinked.
  ///
  /// In am, this message translates to:
  /// **'መጀመሪያ ፈተናውን ከውጤት መመዝገቢያ ጋር ያያይዙ።'**
  String get errQuizNotLinked;

  /// No description provided for @errAlreadyTransferred.
  ///
  /// In am, this message translates to:
  /// **'ውጤቱ ቀድሞ ተልኳል፤ በውጤት መመዝገቢያው ያስተካክሉ።'**
  String get errAlreadyTransferred;

  /// No description provided for @perm_education_content.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ይዘት (ምድቦች፣ ትምህርቶች፣ ባነር) ማስተዳደር'**
  String get perm_education_content;

  /// No description provided for @errSessionNotStarted.
  ///
  /// In am, this message translates to:
  /// **'መዝጋቢው ይህን የመገኘት መዝገብ ገና አልጀመረም።'**
  String get errSessionNotStarted;

  /// No description provided for @errSessionNotAvailable.
  ///
  /// In am, this message translates to:
  /// **'መገኘት መመዝገብ የሚከፈተው ፕሮግራሙ ከመጀመሩ 15 ደቂቃ በፊት ነው።'**
  String get errSessionNotAvailable;

  /// No description provided for @errBeforeSessionStart.
  ///
  /// In am, this message translates to:
  /// **'ይህ የተመዘገበው መዝገቡ ከመጀመሩ በፊት ነው።'**
  String get errBeforeSessionStart;

  /// No description provided for @errNotSessionTaker.
  ///
  /// In am, this message translates to:
  /// **'ይህን ማድረግ የሚችለው ለዚህ መዝገብ የተመደበው የመገኘት መዝጋቢ ብቻ ነው።'**
  String get errNotSessionTaker;

  /// No description provided for @errNoTakerAssigned.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን የመገኘት መዝጋቢ አልተመደበም — የሰው ሀብት ክፍል ይመድባል።'**
  String get errNoTakerAssigned;

  /// No description provided for @errSignatureRequired.
  ///
  /// In am, this message translates to:
  /// **'መገኘት ከመመዝገቡ በፊት አባሉ መፈረም አለበት።'**
  String get errSignatureRequired;

  /// No description provided for @errLateRemoved.
  ///
  /// In am, this message translates to:
  /// **'\"ዘግይቷል\" የሚባል ሁኔታ የለም፤ ተገኝቷል ወይም በፈቃድ ይመዝግቡ።'**
  String get errLateRemoved;

  /// No description provided for @errOneTakerOnly.
  ///
  /// In am, this message translates to:
  /// **'አንድ ፕሮግራም አንድ የመገኘት መዝጋቢ ብቻ አለው።'**
  String get errOneTakerOnly;

  /// No description provided for @errCaptureTooOld.
  ///
  /// In am, this message translates to:
  /// **'ይህ ከመስመር ውጭ የተያዘ መዝገብ ከ3 ቀን በላይ ስለቆየ ለሰው ሀብት ክፍል ተልኳል።'**
  String get errCaptureTooOld;

  /// No description provided for @errOutsideOccurrence.
  ///
  /// In am, this message translates to:
  /// **'የደረሱበት ሰዓት በፕሮግራሙ ሰዓት ውስጥ መሆን አለበት።'**
  String get errOutsideOccurrence;

  /// No description provided for @errConflictResolved.
  ///
  /// In am, this message translates to:
  /// **'ይህ ጉዳይ ቀድሞ ውሳኔ አግኝቷል።'**
  String get errConflictResolved;

  /// No description provided for @errSelfApproval.
  ///
  /// In am, this message translates to:
  /// **'ያቀረቡትን ራስዎ መወሰን አይችሉም።'**
  String get errSelfApproval;

  /// No description provided for @errLocalDataUnreadable.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ስልክ ከመስመር ውጭ የተቀመጠው መረጃ ሊነበብ አልቻለም።'**
  String get errLocalDataUnreadable;

  /// No description provided for @attSentToHr.
  ///
  /// In am, this message translates to:
  /// **'እንደተያዘ ሊመዘገብ ስላልቻለ ለሰው ሀብት ክፍል ግምገማ ተቀምጧል።'**
  String get attSentToHr;

  /// No description provided for @attSessionStartedSnack.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት መዝገቡ ተጀመረ'**
  String get attSessionStartedSnack;

  /// No description provided for @attSessionEndedSnack.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት መዝገቡ ተጠናቀቀ'**
  String get attSessionEndedSnack;

  /// No description provided for @attEndConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህን የመገኘት መዝገብ ልጨርስ? ከዚያ በኋላ መቀየር የሚቻለው በማስተካከያ ጥያቄ ብቻ ነው።'**
  String get attEndConfirm;

  /// No description provided for @attChangeTaker.
  ///
  /// In am, this message translates to:
  /// **'መዝጋቢ ቀይር'**
  String get attChangeTaker;

  /// No description provided for @attSubstituteReason.
  ///
  /// In am, this message translates to:
  /// **'ተተኪ መዝጋቢ ለምን ይረከባል?'**
  String get attSubstituteReason;

  /// No description provided for @attRemoveReason.
  ///
  /// In am, this message translates to:
  /// **'ይህ ምዝገባ ለምን ይሰረዛል?'**
  String get attRemoveReason;

  /// No description provided for @attMinutesAfterStart.
  ///
  /// In am, this message translates to:
  /// **'ከጅማሬ {minutes} ደቂቃ በኋላ'**
  String attMinutesAfterStart(int minutes);

  /// No description provided for @attSigned.
  ///
  /// In am, this message translates to:
  /// **'ፈርሟል'**
  String get attSigned;

  /// No description provided for @attLegacyMark.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት መዝገቦች ከመጀመራቸው በፊት የተመዘገበ'**
  String get attLegacyMark;

  /// No description provided for @attSessionEndedAuto.
  ///
  /// In am, this message translates to:
  /// **'በተያዘለት የማብቂያ ሰዓት ተጠናቋል ({time})'**
  String attSessionEndedAuto(String time);

  /// No description provided for @attSessionEndedAt.
  ///
  /// In am, this message translates to:
  /// **'መዝጋቢው በ{time} ጨርሷል'**
  String attSessionEndedAt(String time);

  /// No description provided for @attSessionRunning.
  ///
  /// In am, this message translates to:
  /// **'የተጀመረው {start} · {elapsed}'**
  String attSessionRunning(String start, String elapsed);

  /// No description provided for @attSessionOpensAt.
  ///
  /// In am, this message translates to:
  /// **'በ{time} ይከፈታል (ከጅማሬ 15 ደቂቃ በፊት)'**
  String attSessionOpensAt(String time);

  /// No description provided for @attSessionReady.
  ///
  /// In am, this message translates to:
  /// **'ዝግጁ ነው — ፕሮግራሙ ሲጀመር \"ጀምር\" ይጫኑ'**
  String get attSessionReady;

  /// No description provided for @attSessionWaiting.
  ///
  /// In am, this message translates to:
  /// **'መዝጋቢው እስኪጀምር በመጠበቅ ላይ'**
  String get attSessionWaiting;

  /// No description provided for @attYou.
  ///
  /// In am, this message translates to:
  /// **'እርስዎ'**
  String get attYou;

  /// No description provided for @attSessionScheduled.
  ///
  /// In am, this message translates to:
  /// **'የተያዘለት ሰዓት {start} – {end}'**
  String attSessionScheduled(String start, String end);

  /// No description provided for @attNoTakerAssigned.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት መዝጋቢ አልተመደበም'**
  String get attNoTakerAssigned;

  /// No description provided for @attSessionTaker.
  ///
  /// In am, this message translates to:
  /// **'መዝጋቢ፦ {name}'**
  String attSessionTaker(String name);

  /// No description provided for @attStartedOffline.
  ///
  /// In am, this message translates to:
  /// **'በዚህ ስልክ ከመስመር ውጭ ተጀምሯል — ሲላክ አገልጋዩ ያረጋግጣል'**
  String get attStartedOffline;

  /// No description provided for @attOnlyTakerRecords.
  ///
  /// In am, this message translates to:
  /// **'ይህን መዝገብ የሚመዘግበው የተመደበው መዝጋቢ ብቻ ነው።'**
  String get attOnlyTakerRecords;

  /// No description provided for @attStart.
  ///
  /// In am, this message translates to:
  /// **'ጀምር'**
  String get attStart;

  /// No description provided for @attEnd.
  ///
  /// In am, this message translates to:
  /// **'ጨርስ'**
  String get attEnd;

  /// No description provided for @attTaker.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት መዝጋቢ'**
  String get attTaker;

  /// No description provided for @attTakerHint.
  ///
  /// In am, this message translates to:
  /// **'ለአንድ ፕሮግራም አንድ መዝጋቢ፤ ለአንድ ቀን ሌላ መዝጋቢ ከዚያ ቀን ዝርዝር መመደብ ይቻላል።'**
  String get attTakerHint;

  /// No description provided for @attTakerHrOnly.
  ///
  /// In am, this message translates to:
  /// **'የሚመደበው በሰው ሀብት ክፍል ነው።'**
  String get attTakerHrOnly;

  /// No description provided for @attSignaturePolicy.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት ፊርማዎች'**
  String get attSignaturePolicy;

  /// No description provided for @attSignaturePolicyHint.
  ///
  /// In am, this message translates to:
  /// **'አባላት ተገኝተዋል ተብለው ከመመዝገባቸው በፊት በመዝጋቢው ስልክ ላይ ይፈርማሉ። የማይፈርሙትን የአባል ዓይነቶች ይምረጡ።'**
  String get attSignaturePolicyHint;

  /// No description provided for @attSignatureExempt.
  ///
  /// In am, this message translates to:
  /// **'አይፈርምም'**
  String get attSignatureExempt;

  /// No description provided for @attSignatureRequiredShort.
  ///
  /// In am, this message translates to:
  /// **'ሲመዘገብ ይፈርማል'**
  String get attSignatureRequiredShort;

  /// No description provided for @attConflicts.
  ///
  /// In am, this message translates to:
  /// **'የሚገመገሙ ከመስመር ውጭ መዝገቦች'**
  String get attConflicts;

  /// No description provided for @attConflictsHint.
  ///
  /// In am, this message translates to:
  /// **'አገልጋዩ እንደተያዘ ሊመዘግበው ያልቻለ ከመስመር ውጭ ሥራ። ምንም አይጠፋም፤ እያንዳንዱን በማስታወሻ ይቀበሉ ወይም ይከልክሉ።'**
  String get attConflictsHint;

  /// No description provided for @attConflictsEmpty.
  ///
  /// In am, this message translates to:
  /// **'የሚገመገም የለም'**
  String get attConflictsEmpty;

  /// No description provided for @attConflictAccept.
  ///
  /// In am, this message translates to:
  /// **'ተቀበል'**
  String get attConflictAccept;

  /// No description provided for @attConflictReject.
  ///
  /// In am, this message translates to:
  /// **'አትቀበል'**
  String get attConflictReject;

  /// No description provided for @attDecisionNote.
  ///
  /// In am, this message translates to:
  /// **'የውሳኔ ማስታወሻ'**
  String get attDecisionNote;

  /// No description provided for @attConflictRecord.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት ምዝገባ'**
  String get attConflictRecord;

  /// No description provided for @attCapturedAt.
  ///
  /// In am, this message translates to:
  /// **'የተያዘው {time}'**
  String attCapturedAt(String time);

  /// No description provided for @attSubmittedBy.
  ///
  /// In am, this message translates to:
  /// **'ያቀረበው'**
  String get attSubmittedBy;

  /// No description provided for @attArrivedAt.
  ///
  /// In am, this message translates to:
  /// **'የደረሰበት ሰዓት'**
  String get attArrivedAt;

  /// No description provided for @attSessionRuleHint.
  ///
  /// In am, this message translates to:
  /// **'መገኘት፦ የሰው ሀብት ክፍል አንድ መዝጋቢ ይመድባል፤ ከጅማሬ 15 ደቂቃ በፊት ይከፈታል፣ የሚቆጠረውም መዝጋቢው \"ጀምር\" ከጫነበት ጀምሮ ነው። አባላት ሲመዘገቡ ይፈርማሉ።'**
  String get attSessionRuleHint;

  /// No description provided for @syncHeldForReview.
  ///
  /// In am, this message translates to:
  /// **'{what} እንደተያዘ ሊመዘገብ ስላልቻለ ለሰው ሀብት ክፍል ግምገማ ተልኳል።'**
  String syncHeldForReview(String what);

  /// No description provided for @perm_attendance_assign.
  ///
  /// In am, this message translates to:
  /// **'የመገኘት መዝጋቢ መድብ (የሰው ሀብት)'**
  String get perm_attendance_assign;

  /// No description provided for @attTakeAttendance.
  ///
  /// In am, this message translates to:
  /// **'መገኘት መዝግብ'**
  String get attTakeAttendance;

  /// No description provided for @attTakeAttendanceSub.
  ///
  /// In am, this message translates to:
  /// **'የሰው ሀብት ክፍል እንዲመዘግቡ የመደበልዎት ፕሮግራሞች'**
  String get attTakeAttendanceSub;

  /// No description provided for @eduAcademicCalendar.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ዘመን የቀን መቁጠሪያ'**
  String get eduAcademicCalendar;

  /// No description provided for @eduAcademicYears.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ዘመናት'**
  String get eduAcademicYears;

  /// No description provided for @eduAcademicYear.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ዘመን'**
  String get eduAcademicYear;

  /// No description provided for @eduEthYear.
  ///
  /// In am, this message translates to:
  /// **'የኢትዮጵያ ዓመተ ምሕረት'**
  String get eduEthYear;

  /// No description provided for @eduCurrentYear.
  ///
  /// In am, this message translates to:
  /// **'የአሁኑ ዘመን'**
  String get eduCurrentYear;

  /// No description provided for @eduSetCurrent.
  ///
  /// In am, this message translates to:
  /// **'የአሁኑ ዘመን አድርግ'**
  String get eduSetCurrent;

  /// No description provided for @eduCloseYear.
  ///
  /// In am, this message translates to:
  /// **'ዘመኑን ዝጋ'**
  String get eduCloseYear;

  /// No description provided for @eduCloseYearConfirm.
  ///
  /// In am, this message translates to:
  /// **'ይህን የትምህርት ዘመን መዝጋት ይፈልጋሉ? ሁሉም የምዘና ውጤቶች የታተሙ መሆን አለባቸው።'**
  String get eduCloseYearConfirm;

  /// No description provided for @eduTerms.
  ///
  /// In am, this message translates to:
  /// **'የክፍለ ጊዜያት'**
  String get eduTerms;

  /// No description provided for @eduNewTerm.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ክፍለ ጊዜ'**
  String get eduNewTerm;

  /// No description provided for @eduLevels.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ደረጃዎች'**
  String get eduLevels;

  /// No description provided for @eduLevel.
  ///
  /// In am, this message translates to:
  /// **'ደረጃ'**
  String get eduLevel;

  /// No description provided for @eduNewLevel.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ደረጃ'**
  String get eduNewLevel;

  /// No description provided for @eduBuiltIn.
  ///
  /// In am, this message translates to:
  /// **'መሰረታዊ'**
  String get eduBuiltIn;

  /// No description provided for @eduAllowMultiple.
  ///
  /// In am, this message translates to:
  /// **'ተመሳሳይ የትምህርት ዘመን ላይ ሌላ ክፍል መመዝገብ ይፈቀድ'**
  String get eduAllowMultiple;

  /// No description provided for @eduAllowMultipleHint.
  ///
  /// In am, this message translates to:
  /// **'ይህ ሲበራ ተማሪዎች በዚሁ የትምህርት ዘመን ሌላም ክፍል ውስጥ በአንድ ጊዜ መመዝገብ ይችላሉ።'**
  String get eduAllowMultipleHint;

  /// No description provided for @eduAssignStudents.
  ///
  /// In am, this message translates to:
  /// **'ተማሪዎችን መድብ'**
  String get eduAssignStudents;

  /// No description provided for @eduAssignableStudents.
  ///
  /// In am, this message translates to:
  /// **'ሊመደቡ የሚችሉ ተማሪዎች'**
  String get eduAssignableStudents;

  /// No description provided for @eduAlreadyInClass.
  ///
  /// In am, this message translates to:
  /// **'ቀድሞውኑ በዚህ ክፍል ውስጥ ተመድቧል'**
  String get eduAlreadyInClass;

  /// No description provided for @eduInOtherClass.
  ///
  /// In am, this message translates to:
  /// **'በሌላ ክፍል ውስጥ ተመድቧል፦ {className}'**
  String eduInOtherClass(Object className);

  /// No description provided for @eduAssignedSuccess.
  ///
  /// In am, this message translates to:
  /// **'{count} ተማሪዎች በተሳካ ሁኔታ ተመድበዋል'**
  String eduAssignedSuccess(Object count);

  /// No description provided for @eduTransferStudent.
  ///
  /// In am, this message translates to:
  /// **'ተማሪ አስተላልፍ'**
  String get eduTransferStudent;

  /// No description provided for @eduTransferTargetClass.
  ///
  /// In am, this message translates to:
  /// **'የሚዛወርበት ክፍል'**
  String get eduTransferTargetClass;

  /// No description provided for @eduTransferReason.
  ///
  /// In am, this message translates to:
  /// **'የዝውውር ምክንያት'**
  String get eduTransferReason;

  /// No description provided for @eduTransferSuccess.
  ///
  /// In am, this message translates to:
  /// **'ተማሪው በተሳካ ሁኔታ ተዛውሯል'**
  String get eduTransferSuccess;

  /// No description provided for @eduCourseMode.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት አሰጣጥ አይነት'**
  String get eduCourseMode;

  /// No description provided for @eduModePhysical.
  ///
  /// In am, this message translates to:
  /// **'በአካል'**
  String get eduModePhysical;

  /// No description provided for @eduModeOnline.
  ///
  /// In am, this message translates to:
  /// **'በበይነመረብ (Online)'**
  String get eduModeOnline;

  /// No description provided for @eduModeHybrid.
  ///
  /// In am, this message translates to:
  /// **'ቅይጥ (Hybrid)'**
  String get eduModeHybrid;

  /// No description provided for @eduPassMark.
  ///
  /// In am, this message translates to:
  /// **'የማለፊያ ነጥብ'**
  String get eduPassMark;

  /// No description provided for @eduEligibleGroups.
  ///
  /// In am, this message translates to:
  /// **'የተፈቀደላቸው የአባላት ክፍሎች'**
  String get eduEligibleGroups;

  /// No description provided for @eduAllGroups.
  ///
  /// In am, this message translates to:
  /// **'በክፍሉ ያሉ ሁሉም የአባላት ክፍሎች'**
  String get eduAllGroups;

  /// No description provided for @eduLinkedPrograms.
  ///
  /// In am, this message translates to:
  /// **'የተገናኙ ፕሮግራሞች'**
  String get eduLinkedPrograms;

  /// No description provided for @eduLinkedProgramsHint.
  ///
  /// In am, this message translates to:
  /// **'ይህ ትምህርት የሚሰጥባቸው የሰንበት ትምህርት ቤት መርሃ ግብሮች'**
  String get eduLinkedProgramsHint;

  /// No description provided for @eduLate.
  ///
  /// In am, this message translates to:
  /// **'ዘግይቷል'**
  String get eduLate;

  /// No description provided for @eduVersions.
  ///
  /// In am, this message translates to:
  /// **'የማስረከቢያ ታሪክ'**
  String get eduVersions;

  /// No description provided for @eduVersion.
  ///
  /// In am, this message translates to:
  /// **'ስሪት'**
  String get eduVersion;

  /// No description provided for @eduPublishAt.
  ///
  /// In am, this message translates to:
  /// **'የሚታተምበት ቀን/ሰዓት'**
  String get eduPublishAt;

  /// No description provided for @eduLatePolicy.
  ///
  /// In am, this message translates to:
  /// **'ዘግይተው የሚቀርቡ'**
  String get eduLatePolicy;

  /// No description provided for @eduLatePolicyRefuse.
  ///
  /// In am, this message translates to:
  /// **'ዘግይቶ ማስረከብን አትቀበል'**
  String get eduLatePolicyRefuse;

  /// No description provided for @eduLatePolicyAccept.
  ///
  /// In am, this message translates to:
  /// **'እንደ ዘገየ ተመዝግቦ ተቀበል'**
  String get eduLatePolicyAccept;

  /// No description provided for @eduLateUntil.
  ///
  /// In am, this message translates to:
  /// **'የመዘግየት መቀበያ እስከ'**
  String get eduLateUntil;

  /// No description provided for @eduAllowResubmit.
  ///
  /// In am, this message translates to:
  /// **'እንደገና ማስረከብ ፍቀድ'**
  String get eduAllowResubmit;

  /// No description provided for @eduOutcomes.
  ///
  /// In am, this message translates to:
  /// **'የኮርስ ውጤቶች'**
  String get eduOutcomes;

  /// No description provided for @eduComputeOutcomes.
  ///
  /// In am, this message translates to:
  /// **'ውጤቶችን አስላ'**
  String get eduComputeOutcomes;

  /// No description provided for @eduFinalizeOutcomes.
  ///
  /// In am, this message translates to:
  /// **'ውጤቶችን አጽድቅ'**
  String get eduFinalizeOutcomes;

  /// No description provided for @eduFinalizeConfirm.
  ///
  /// In am, this message translates to:
  /// **'የኮርሱን ውጤቶች ማጽደቅ ይፈልጋሉ? ይህ ውጤቶቹን ያጸናል።'**
  String get eduFinalizeConfirm;

  /// No description provided for @eduPassed.
  ///
  /// In am, this message translates to:
  /// **'አልፏል'**
  String get eduPassed;

  /// No description provided for @eduFailed.
  ///
  /// In am, this message translates to:
  /// **'አላለፈም'**
  String get eduFailed;

  /// No description provided for @eduIncomplete.
  ///
  /// In am, this message translates to:
  /// **'ያልተጠናቀቀ'**
  String get eduIncomplete;

  /// No description provided for @eduRetake.
  ///
  /// In am, this message translates to:
  /// **'ድጋሚ ፈተና/ኮርስ'**
  String get eduRetake;

  /// No description provided for @eduRequestRetake.
  ///
  /// In am, this message translates to:
  /// **'የኦንላይን ድጋሚ ኮርስ ጠይቅ'**
  String get eduRequestRetake;

  /// No description provided for @eduRetakeRequested.
  ///
  /// In am, this message translates to:
  /// **'ድጋሚ ተጠይቋል'**
  String get eduRetakeRequested;

  /// No description provided for @eduRetakeRequestedSuccess.
  ///
  /// In am, this message translates to:
  /// **'የኦንላይን ድጋሚ ጥያቄ በተሳካ ሁኔታ ተልኳል'**
  String get eduRetakeRequestedSuccess;

  /// No description provided for @eduCountsForProgression.
  ///
  /// In am, this message translates to:
  /// **'ለመሻገሪያ የሚቆጠር'**
  String get eduCountsForProgression;

  /// No description provided for @eduCertificates.
  ///
  /// In am, this message translates to:
  /// **'የምስክር ወረቀቶች'**
  String get eduCertificates;

  /// No description provided for @eduMyCertificates.
  ///
  /// In am, this message translates to:
  /// **'የእኔ የምስክር ወረቀቶች'**
  String get eduMyCertificates;

  /// No description provided for @eduNoCertificates.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን የተሰጠ የምስክር ወረቀት የለም።'**
  String get eduNoCertificates;

  /// No description provided for @eduCertificateNumber.
  ///
  /// In am, this message translates to:
  /// **'የምስክር ወረቀት ቁጥር'**
  String get eduCertificateNumber;

  /// No description provided for @eduVerificationCode.
  ///
  /// In am, this message translates to:
  /// **'የማረጋገጫ ኮድ'**
  String get eduVerificationCode;

  /// No description provided for @eduIssueCertificates.
  ///
  /// In am, this message translates to:
  /// **'የምስክር ወረቀት ስጥ'**
  String get eduIssueCertificates;

  /// No description provided for @eduIssueCertificatesConfirm.
  ///
  /// In am, this message translates to:
  /// **'ለተመረጡት {count} ተማሪዎች የምስክር ወረቀት መስጠት ይፈልጋሉ?'**
  String eduIssueCertificatesConfirm(Object count);

  /// No description provided for @eduIssuedSuccess.
  ///
  /// In am, this message translates to:
  /// **'{count} የምስክር ወረቀት(ቶች) በተሳካ ሁኔታ ተሰጥተዋል'**
  String eduIssuedSuccess(Object count);

  /// No description provided for @eduNoEligibleStudents.
  ///
  /// In am, this message translates to:
  /// **'የምስክር ወረቀት መስፈርት ያሟላ ተማሪ አልተገኘም።'**
  String get eduNoEligibleStudents;

  /// No description provided for @eduCertificateStatus.
  ///
  /// In am, this message translates to:
  /// **'ሁኔታ'**
  String get eduCertificateStatus;

  /// No description provided for @eduCertificateValid.
  ///
  /// In am, this message translates to:
  /// **'ሕጋዊ'**
  String get eduCertificateValid;

  /// No description provided for @eduCertificateRevoked.
  ///
  /// In am, this message translates to:
  /// **'ተሰርዟል'**
  String get eduCertificateRevoked;

  /// No description provided for @eduCertificateReplaced.
  ///
  /// In am, this message translates to:
  /// **'ተተክቷል'**
  String get eduCertificateReplaced;

  /// No description provided for @eduRevokeCertificate.
  ///
  /// In am, this message translates to:
  /// **'የምስክር ወረቀት ሰርዝ'**
  String get eduRevokeCertificate;

  /// No description provided for @eduRevokeReason.
  ///
  /// In am, this message translates to:
  /// **'የስረዛ ምክንያት'**
  String get eduRevokeReason;

  /// No description provided for @eduRevokedSuccess.
  ///
  /// In am, this message translates to:
  /// **'የምስክር ወረቀቱ በተሳካ ሁኔታ ተሰርዟል'**
  String get eduRevokedSuccess;

  /// No description provided for @eduAcademicPeriod.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ዘመን እና ክፍለ ጊዜ'**
  String get eduAcademicPeriod;

  /// No description provided for @eduAcademicScore.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት ውጤት (Academic)'**
  String get eduAcademicScore;

  /// No description provided for @eduEngagementScore.
  ///
  /// In am, this message translates to:
  /// **'የተሳትፎ ውጤት (Engagement)'**
  String get eduEngagementScore;

  /// No description provided for @eduActivityReport.
  ///
  /// In am, this message translates to:
  /// **'የእንቅስቃሴ ሪፖርት'**
  String get eduActivityReport;

  /// No description provided for @eduScoresAndActivity.
  ///
  /// In am, this message translates to:
  /// **'ውጤቶች እና ተሳትፎ'**
  String get eduScoresAndActivity;

  /// No description provided for @libFavorites.
  ///
  /// In am, this message translates to:
  /// **'ተወዳጆች'**
  String get libFavorites;

  /// No description provided for @libFavorite.
  ///
  /// In am, this message translates to:
  /// **'ተወዳጅ'**
  String get libFavorite;

  /// No description provided for @libAddToFavorites.
  ///
  /// In am, this message translates to:
  /// **'ወደ ተወዳጆች አክል'**
  String get libAddToFavorites;

  /// No description provided for @libRemoveFromFavorites.
  ///
  /// In am, this message translates to:
  /// **'ከተወዳጆች አስወጣ'**
  String get libRemoveFromFavorites;

  /// No description provided for @libProgress.
  ///
  /// In am, this message translates to:
  /// **'ገጽ {page} ከ {total}'**
  String libProgress(int page, int total);

  /// No description provided for @libPageCount.
  ///
  /// In am, this message translates to:
  /// **'{count} ገጾች'**
  String libPageCount(int count);

  /// No description provided for @libResume.
  ///
  /// In am, this message translates to:
  /// **'ማንበብ ይቀጥሉ'**
  String get libResume;

  /// No description provided for @libNarration.
  ///
  /// In am, this message translates to:
  /// **'ትረካ'**
  String get libNarration;

  /// No description provided for @libListenNarration.
  ///
  /// In am, this message translates to:
  /// **'ትረካ አዳምጥ'**
  String get libListenNarration;

  /// No description provided for @libPauseNarration.
  ///
  /// In am, this message translates to:
  /// **'ትረካ አቁም'**
  String get libPauseNarration;

  /// No description provided for @libNarrationPlaying.
  ///
  /// In am, this message translates to:
  /// **'ትረካ በመጫወት ላይ'**
  String get libNarrationPlaying;

  /// No description provided for @libSearchInBook.
  ///
  /// In am, this message translates to:
  /// **'መጽሐፍ ውስጥ ፈልግ'**
  String get libSearchInBook;

  /// No description provided for @libJumpToPage.
  ///
  /// In am, this message translates to:
  /// **'ወደ ገጽ ሂድ'**
  String get libJumpToPage;

  /// No description provided for @libPageNumber.
  ///
  /// In am, this message translates to:
  /// **'የገጽ ቁጥር'**
  String get libPageNumber;

  /// No description provided for @libZoomIn.
  ///
  /// In am, this message translates to:
  /// **'አጉላ'**
  String get libZoomIn;

  /// No description provided for @libZoomOut.
  ///
  /// In am, this message translates to:
  /// **'አሳንስ'**
  String get libZoomOut;

  /// No description provided for @libNextMatch.
  ///
  /// In am, this message translates to:
  /// **'ቀጣይ ውጤት'**
  String get libNextMatch;

  /// No description provided for @libPrevMatch.
  ///
  /// In am, this message translates to:
  /// **'ቀዳሚ ውጤት'**
  String get libPrevMatch;

  /// No description provided for @libNoMatches.
  ///
  /// In am, this message translates to:
  /// **'ምንም ውጤት አልተገኘም'**
  String get libNoMatches;

  /// No description provided for @libCopies.
  ///
  /// In am, this message translates to:
  /// **'ቅጂዎች'**
  String get libCopies;

  /// No description provided for @libCopiesAvailable.
  ///
  /// In am, this message translates to:
  /// **'ከ {total} ቅጂዎች {avail} ይገኛሉ'**
  String libCopiesAvailable(int avail, int total);

  /// No description provided for @libCirculation.
  ///
  /// In am, this message translates to:
  /// **'የመጻሕፍት ስርጭት'**
  String get libCirculation;

  /// No description provided for @libCheckout.
  ///
  /// In am, this message translates to:
  /// **'መጽሐፍ አበድር'**
  String get libCheckout;

  /// No description provided for @libReturn.
  ///
  /// In am, this message translates to:
  /// **'መጽሐፍ ተቀበል'**
  String get libReturn;

  /// No description provided for @libBorrower.
  ///
  /// In am, this message translates to:
  /// **'ተበዳሪ'**
  String get libBorrower;

  /// No description provided for @libSelectBorrower.
  ///
  /// In am, this message translates to:
  /// **'ተበዳሪ ምረጥ'**
  String get libSelectBorrower;

  /// No description provided for @libCopyCode.
  ///
  /// In am, this message translates to:
  /// **'የቅጂ ኮድ'**
  String get libCopyCode;

  /// No description provided for @libCondition.
  ///
  /// In am, this message translates to:
  /// **'ሁኔታ'**
  String get libCondition;

  /// No description provided for @libConditionOut.
  ///
  /// In am, this message translates to:
  /// **'ሲሰጥ የነበረበት ሁኔታ'**
  String get libConditionOut;

  /// No description provided for @libConditionIn.
  ///
  /// In am, this message translates to:
  /// **'ሲመለስ ያለበት ሁኔታ'**
  String get libConditionIn;

  /// No description provided for @libGood.
  ///
  /// In am, this message translates to:
  /// **'ጥሩ'**
  String get libGood;

  /// No description provided for @libFair.
  ///
  /// In am, this message translates to:
  /// **'መካከለኛ'**
  String get libFair;

  /// No description provided for @libPoor.
  ///
  /// In am, this message translates to:
  /// **'ያረጀ'**
  String get libPoor;

  /// No description provided for @libDamaged.
  ///
  /// In am, this message translates to:
  /// **'የተጎዳ'**
  String get libDamaged;

  /// No description provided for @libStatusAvailable.
  ///
  /// In am, this message translates to:
  /// **'ይገኛል'**
  String get libStatusAvailable;

  /// No description provided for @libStatusOnLoan.
  ///
  /// In am, this message translates to:
  /// **'ተበድሯል'**
  String get libStatusOnLoan;

  /// No description provided for @libStatusLost.
  ///
  /// In am, this message translates to:
  /// **'ጠፍቷል'**
  String get libStatusLost;

  /// No description provided for @libStatusWithdrawn.
  ///
  /// In am, this message translates to:
  /// **'ተሰርዟል'**
  String get libStatusWithdrawn;

  /// No description provided for @libOverdue.
  ///
  /// In am, this message translates to:
  /// **'ያለፈባቸው'**
  String get libOverdue;

  /// No description provided for @libOverdueLoans.
  ///
  /// In am, this message translates to:
  /// **'ያለፉባቸው ብድሮች'**
  String get libOverdueLoans;

  /// No description provided for @libActiveLoans.
  ///
  /// In am, this message translates to:
  /// **'የተበደሩ መጻሕፍት'**
  String get libActiveLoans;

  /// No description provided for @libDueOn.
  ///
  /// In am, this message translates to:
  /// **'የመመለሻ ቀን'**
  String get libDueOn;

  /// No description provided for @libSignToBorrow.
  ///
  /// In am, this message translates to:
  /// **'የተበዳሪ ፊርማ'**
  String get libSignToBorrow;

  /// No description provided for @libSignatureRequired.
  ///
  /// In am, this message translates to:
  /// **'መጽሐፍ ለማበደር የተበዳሪ ፊርማ ያስፈልጋል'**
  String get libSignatureRequired;

  /// No description provided for @libCheckoutSuccess.
  ///
  /// In am, this message translates to:
  /// **'መጽሐፉ በተሳካ ሁኔታ ተበድሯል'**
  String get libCheckoutSuccess;

  /// No description provided for @libReturnSuccess.
  ///
  /// In am, this message translates to:
  /// **'መጽሐፉ በተሳካ ሁኔታ ተመልሷል'**
  String get libReturnSuccess;

  /// No description provided for @libConflictOnLoan.
  ///
  /// In am, this message translates to:
  /// **'ይህ የመጽሐፍ ቅጂ አስቀድሞ ለሌላ አባል ተበድሯል'**
  String get libConflictOnLoan;

  /// No description provided for @libScanQr.
  ///
  /// In am, this message translates to:
  /// **'የቅጂ ኮድ ወይም የአባል QR ስካን ያድርጉ'**
  String get libScanQr;

  /// No description provided for @libEnterCopyCode.
  ///
  /// In am, this message translates to:
  /// **'የቅጂ ኮድ ያስገቡ'**
  String get libEnterCopyCode;

  /// No description provided for @libCopyNotFound.
  ///
  /// In am, this message translates to:
  /// **'ይህ የመጽሐፍ ቅጂ አልተገኘም'**
  String get libCopyNotFound;

  /// No description provided for @libDownloadToReadOffline.
  ///
  /// In am, this message translates to:
  /// **'ከመስመር ውጭ ለማንበብ ያውርዱ'**
  String get libDownloadToReadOffline;

  /// No description provided for @elAttemptsExhausted.
  ///
  /// In am, this message translates to:
  /// **'የፈተና ሙከራ ገደብ ተጠናቋል'**
  String get elAttemptsExhausted;

  /// No description provided for @elAttemptsExhaustedDesc.
  ///
  /// In am, this message translates to:
  /// **'ይህን ፈተና ለመውሰድ የተፈቀደልዎ የሙከራ ብዛት አልቋል። ተጨማሪ ሙከራ ማድረግ አይቻልም።'**
  String get elAttemptsExhaustedDesc;

  /// No description provided for @elNoAttemptsLeftAlert.
  ///
  /// In am, this message translates to:
  /// **'ምንም የቀረ ሙከራ የለም (0)'**
  String get elNoAttemptsLeftAlert;

  /// No description provided for @elAttemptsRemaining.
  ///
  /// In am, this message translates to:
  /// **'የቀሩ ሙከራዎች፦ {count}'**
  String elAttemptsRemaining(int count);

  /// No description provided for @elDirectMaterials.
  ///
  /// In am, this message translates to:
  /// **'የትምህርት መርጃዎች'**
  String get elDirectMaterials;

  /// No description provided for @elAddDirectMaterial.
  ///
  /// In am, this message translates to:
  /// **'መርጃ ጨምር'**
  String get elAddDirectMaterial;

  /// No description provided for @elUploadMaterial.
  ///
  /// In am, this message translates to:
  /// **'ፋይል ወይም ሰነድ ጫን'**
  String get elUploadMaterial;

  /// No description provided for @elDirectMaterialSubtitle.
  ///
  /// In am, this message translates to:
  /// **'የ{grade}ኛ ክፍል ቀጥታ መርጃ'**
  String elDirectMaterialSubtitle(int grade);

  /// No description provided for @elNoAssignedGradeTitle.
  ///
  /// In am, this message translates to:
  /// **'የተመደበ ክፍል አልተገኘም'**
  String get elNoAssignedGradeTitle;

  /// No description provided for @elNoAssignedGradeDesc.
  ///
  /// In am, this message translates to:
  /// **'በአሁኑ ሰዓት የተመደቡበት ክፍል የለም። ትምህርቶችን ለመከታተል እባክዎ የሰንበት ት/ቤት አስተዳዳሪውን ያነጋግሩ።'**
  String get elNoAssignedGradeDesc;

  /// No description provided for @elAdminPanelHint.
  ///
  /// In am, this message translates to:
  /// **'ሁሉንም ክፍሎች ለማስተዳደር እባክዎ ወደ ትምህርት አስተዳደር ክፍል ይሂዱ።'**
  String get elAdminPanelHint;

  /// No description provided for @elGradeRestrictedNotice.
  ///
  /// In am, this message translates to:
  /// **'እርስዎ የተመደቡት በ{grade}ኛ ክፍል ብቻ ነው'**
  String elGradeRestrictedNotice(int grade);

  /// No description provided for @elAssignments.
  ///
  /// In am, this message translates to:
  /// **'የቤት ሥራዎች'**
  String get elAssignments;

  /// No description provided for @elAssignmentDetail.
  ///
  /// In am, this message translates to:
  /// **'የሥራ ዝርዝር'**
  String get elAssignmentDetail;

  /// No description provided for @elSubmitAssignment.
  ///
  /// In am, this message translates to:
  /// **'ሥራ አስረክብ'**
  String get elSubmitAssignment;

  /// No description provided for @elTurnedIn.
  ///
  /// In am, this message translates to:
  /// **'ተረክቧል'**
  String get elTurnedIn;

  /// No description provided for @elAssigned.
  ///
  /// In am, this message translates to:
  /// **'ተሰጥቷል'**
  String get elAssigned;

  /// No description provided for @elDueSoon.
  ///
  /// In am, this message translates to:
  /// **'ሊደርስ የቀረበ'**
  String get elDueSoon;

  /// No description provided for @elUpcoming.
  ///
  /// In am, this message translates to:
  /// **'የሚመጣ'**
  String get elUpcoming;

  /// No description provided for @elGraded.
  ///
  /// In am, this message translates to:
  /// **'የታረመ'**
  String get elGraded;

  /// No description provided for @elMySubmission.
  ///
  /// In am, this message translates to:
  /// **'የእርስዎ ሥራ'**
  String get elMySubmission;

  /// No description provided for @elGradeScore.
  ///
  /// In am, this message translates to:
  /// **'ውጤት፦ {score} / {max}'**
  String elGradeScore(String score, String max);

  /// No description provided for @elTeacherFeedback.
  ///
  /// In am, this message translates to:
  /// **'የመምህሩ አስተያየት'**
  String get elTeacherFeedback;

  /// No description provided for @elResubmit.
  ///
  /// In am, this message translates to:
  /// **'እንደገና አስረክብ'**
  String get elResubmit;

  /// No description provided for @elDueDate.
  ///
  /// In am, this message translates to:
  /// **'የማስረከቢያ ቀን፦ {date}'**
  String elDueDate(String date);

  /// No description provided for @elYourResponse.
  ///
  /// In am, this message translates to:
  /// **'የእርስዎ መልስ እዚህ ይጻፉ...'**
  String get elYourResponse;

  /// No description provided for @elAttachFile.
  ///
  /// In am, this message translates to:
  /// **'ፋይል አያይዝ'**
  String get elAttachFile;

  /// No description provided for @elMaxScore.
  ///
  /// In am, this message translates to:
  /// **'ከፍተኛ ውጤት'**
  String get elMaxScore;

  /// No description provided for @elGradeSubmission.
  ///
  /// In am, this message translates to:
  /// **'ሥራ አርም'**
  String get elGradeSubmission;

  /// No description provided for @elReleaseGrade.
  ///
  /// In am, this message translates to:
  /// **'ውጤቱን ለተማሪው ልቀቅ'**
  String get elReleaseGrade;

  /// No description provided for @elSubmissions.
  ///
  /// In am, this message translates to:
  /// **'የቀረቡ ሥራዎች'**
  String get elSubmissions;

  /// No description provided for @elNoAssignments.
  ///
  /// In am, this message translates to:
  /// **'ምንም የተሰጠ የቤት ሥራ የለም'**
  String get elNoAssignments;

  /// No description provided for @elCreateAssignment.
  ///
  /// In am, this message translates to:
  /// **'አዲስ የቤት ሥራ ፍጠር'**
  String get elCreateAssignment;

  /// No description provided for @elAnnouncements.
  ///
  /// In am, this message translates to:
  /// **'የክፍል ማስታወቂያዎች'**
  String get elAnnouncements;

  /// No description provided for @elClassFeed.
  ///
  /// In am, this message translates to:
  /// **'የክፍል ዜና ዥረት'**
  String get elClassFeed;

  /// No description provided for @elNewAnnouncement.
  ///
  /// In am, this message translates to:
  /// **'አዲስ ማስታወቂያ'**
  String get elNewAnnouncement;

  /// No description provided for @elPostAnnouncement.
  ///
  /// In am, this message translates to:
  /// **'ማስታወቂያ ለጥፍ'**
  String get elPostAnnouncement;

  /// No description provided for @elTeacherPosted.
  ///
  /// In am, this message translates to:
  /// **'በመምህር {name} የተለጠፈ'**
  String elTeacherPosted(String name);

  /// No description provided for @elAnnouncementBody.
  ///
  /// In am, this message translates to:
  /// **'የማስታወቂያው መልእክት'**
  String get elAnnouncementBody;

  /// No description provided for @elNoAnnouncements.
  ///
  /// In am, this message translates to:
  /// **'እስካሁን የተለጠፈ ማስታወቂያ የለም'**
  String get elNoAnnouncements;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['am', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
