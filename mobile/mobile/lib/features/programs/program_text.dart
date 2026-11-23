import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';

/// "#RRGGBB" → Color (gold when missing / invalid).
Color hexColor(String? hex) {
  final v = int.tryParse((hex ?? '').replaceFirst('#', ''), radix: 16);
  return v == null ? AppColors.gold : Color(0xFF000000 | v);
}

/// "Every Sunday", "Every month on day 12", "Every 2nd Sunday of the month" (from the first date).
String recurrenceSummary(BuildContext context, String recurrence, String? monthlyRule, DateTime start, {List<int> ethiopianDays = const []}) {
  final l = context.l10n;
  final f = Formatters(l, Localizations.localeOf(context).languageCode);
  final local = start.toLocal();
  final weekday = f.weekday(local);
  return switch (recurrence) {
    'weekly' => l.everyWeekday(weekday),
    'biweekly' || 'every_two_weeks' => Localizations.localeOf(context).languageCode == 'en' ? 'Every 2 weeks on $weekday' : 'በየሁለት ሳምንቱ $weekday',
    // Twice a month: the same two days each month (the day and the day 14 days apart), or the
    // 1st & 3rd / 2nd & 4th weekday — as the server schedules them.
    'twice_monthly' when monthlyRule == 'nth_weekday' => ((local.day - 1) ~/ 7).isEven ? l.twiceMonthlyNth13(weekday) : l.twiceMonthlyNth24(weekday),
    'twice_monthly' => l.twiceMonthlyDays('${local.day <= 15 ? local.day : (local.day - 14).clamp(1, 28)}', '${local.day <= 15 ? (local.day + 14).clamp(1, 28) : local.day}'),
    'monthly' when monthlyRule == 'nth_weekday' => l.everyNthWeekday('${((local.day - 1) ~/ 7) + 1}', weekday),
    'monthly' => l.everyMonthDay('${local.day}'),
    'ethiopian_days' => l.everyEthiopianDays(ethiopianDays.join(', ')),
    _ => l.recurrenceOnce,
  };
}

String programRecurrenceText(BuildContext context, Program p) {
  final base = recurrenceSummary(context, p.recurrence, p.monthlyRule, p.startsAt, ethiopianDays: p.ethiopianDays);
  if (!p.isRecurring || p.recurrenceUntil == null) return base;
  final f = Formatters(context.l10n, Localizations.localeOf(context).languageCode);
  return '$base · ${context.l10n.untilDate(f.date(p.recurrenceUntil))}';
}
