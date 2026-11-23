import '../../../core/l10n/l10n.dart';
import '../../../models/json.dart';

/// Clean, human-readable class title.
/// Never returns empty string or raw object representation.
String eduClassName(dynamic c) {
  if (c == null) return '';
  if (c is String) {
    final s = c.trim();
    if (s.startsWith('{') && s.endsWith('}')) return '';
    return s;
  }
  if (c is Map) {
    final name = asStr(c['name'])?.trim();
    if (name != null && name.isNotEmpty && !name.startsWith('{')) {
      return name;
    }
    final grade = asStr(c['grade'])?.trim();
    if (grade != null && grade.isNotEmpty) return grade;

    final lvl = c['level'];
    if (lvl is Map) {
      final lvlName = asStr(lvl['name'])?.trim();
      if (lvlName != null && lvlName.isNotEmpty) return lvlName;
    }
    final levelId = asInt(c['level_id']);
    if (levelId != null && levelId > 0 && levelId <= 12) {
      return '$levelIdኛ ክፍል';
    }
    final id = asInt(c['id']);
    return id != null ? 'ክፍል $id' : '';
  }
  return '';
}

/// Clean, human-readable academic year text.
/// Extracts year from String or Map without ever returning `{id:...}` or `0 ዓ.ም`.
String? eduAcademicYear(dynamic y) {
  if (y == null) return null;
  if (y is String) {
    final s = y.trim();
    if (s.isEmpty || (s.startsWith('{') && s.endsWith('}'))) return null;
    return s;
  }
  if (y is Map) {
    final name = asStr(y['name'])?.trim();
    if (name != null && name.isNotEmpty && !name.startsWith('{')) {
      return name;
    }
    final ethYear = asInt(y['eth_year']);
    if (ethYear != null && ethYear > 1900 && ethYear < 2200) {
      return '$ethYear ዓ.ም';
    }
  }
  return null;
}

/// Clean class subtitle combining Term, Academic Year, Grade, and Program.
/// Guarantees that raw serialized objects or empty zero values are never rendered.
String eduClassSubtitle(dynamic c, AppLocalizations l) {
  if (c == null || c is! Map) return '';

  final parts = <String>[];

  // 1. Term
  final termStr = asStr(c['term'])?.trim();
  if (termStr != null && termStr.isNotEmpty && !termStr.startsWith('{')) {
    parts.add(termStr);
  }

  // 2. Academic Year
  final yearStr = eduAcademicYear(c['academic_year']) ?? eduAcademicYear(c['academic_year_obj']);
  if (yearStr != null && yearStr.isNotEmpty && !parts.contains(yearStr)) {
    parts.add(yearStr);
  }

  // 3. Grade (if not already part of the class name)
  final name = eduClassName(c);
  final grade = asStr(c['grade'])?.trim() ??
      (c['level'] is Map ? asStr(asJson(c['level'])['name'])?.trim() : null) ??
      (asInt(c['level_id']) != null && asInt(c['level_id'])! > 0 ? '${c['level_id']}ኛ ክፍል' : null);

  if (grade != null && grade.isNotEmpty && !name.contains(grade)) {
    parts.add(grade);
  }

  // 4. Program / Enrollment Mode
  if (c['added_subjects_only'] == true) {
    parts.add(l.eaJSubjectAdded);
  } else {
    final prog = asStr(c['my_program']);
    if (prog != null && prog.isNotEmpty) {
      parts.add(prog == 'regular' ? l.programRegular : (prog == 'distance' ? l.programDistance : prog));
    }
  }

  return parts.join(' · ');
}
