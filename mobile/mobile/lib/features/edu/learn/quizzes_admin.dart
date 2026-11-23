import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/admin.dart' show Perm;
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/dialogs.dart';
import '../../../widgets/states.dart';
import '../../admin/edit_mode.dart' show contentRevisionProvider;
import '../../auth/session.dart' show currentUserProvider;
import 'edu_widgets.dart';

/// Dedicated Quizzes & Assessments management hub for Education Admin Panel.
/// Provides comprehensive control over quizzes, exams, question banks, grading, and review policies.
class EduQuizzesAdminScreen extends ConsumerStatefulWidget {
  const EduQuizzesAdminScreen({super.key, this.initialSubjectId});
  final int? initialSubjectId;

  @override
  ConsumerState<EduQuizzesAdminScreen> createState() => _EduQuizzesAdminScreenState();
}

class _EduQuizzesAdminScreenState extends ConsumerState<EduQuizzesAdminScreen> {
  int? _selectedSubjectId;
  String _selectedStatus = 'all'; // 'all', 'published', 'draft', 'closed'
  String _searchQuery = '';
  bool _loading = false;
  List<Json> _quizzes = [];
  List<Json> _subjects = [];
  List<Json> _courses = [];

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.initialSubjectId;
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final repo = ref.read(eduRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.subjects(all: true),
        repo.teaching().catchError((_) => <Json>[]),
        repo.allAdminQuizzes(),
      ]);
      _subjects = results[0];
      _courses = results[1];
      final allQuizzes = results[2];

      if (mounted) {
        setState(() {
          _quizzes = allQuizzes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteQuiz(int quizId, String title) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final confirmed = await showConfirm(
      context,
      isEn
          ? 'Are you sure you want to delete quiz "$title"? All questions and student attempts will be permanently erased.'
          : 'ፈተና "$title" ይሰረዝ? ሁሉም ጥያቄዎችና የተማሪዎች ውጤቶች ሙሉ በሙሉ ይወገዳሉ።',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await runWithProgress(
      context,
      () => ref.read(eduRepositoryProvider).deleteQuiz(quizId),
      success: isEn ? 'Quiz deleted' : 'ፈተናው ተሰርዟል',
    );
    if (mounted) {
      ref.read(contentRevisionProvider.notifier).bump();
      _loadAll();
    }
  }

  Future<void> _createNewQuiz() async {
    final l = context.l10n;
    final isEn = l.isEn;

    if (_subjects.isEmpty && _courses.isEmpty) {
      showSnack(
        context,
        isEn
            ? 'No curriculum subjects or active courses available to attach a quiz.'
            : 'ፈተና የሚመደብበት የትምህርት ዓይነት ወይም ክፍል አልተገኘም።',
      );
      return;
    }

    final result = await showModalBottomSheet<_NewQuizData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewQuizModal(subjects: _subjects, courses: _courses),
    );

    if (result == null || !mounted) return;

    final repo = ref.read(eduRepositoryProvider);
    Json? created;

    if (result.isExam) {
      created = await runWithProgress(
        context,
        () async {
          final assess = await repo.ensureFinalAssessment(result.targetId);
          final assessId = asInt(assess['id']) ?? asInt(assess['assessment_id']);
          return repo.createQuiz(result.targetId, {
            'title': result.title,
            'kind': 'exam',
            'assessment_id': assessId,
          });
        },
        success: isEn ? 'Closing exam created' : 'የማጠቃለያ ፈተና ተፈጥሯል',
      );
    } else if (result.isSubject) {
      created = await runWithProgress(
        context,
        () => repo.createSubjectQuiz(result.targetId, {'title': result.title, 'kind': 'quiz'}),
        success: isEn ? 'Quiz created' : 'ፈተናው ተፈጥሯል',
      );
    } else {
      created = await runWithProgress(
        context,
        () => repo.createQuiz(result.targetId, {'title': result.title, 'kind': 'quiz'}),
        success: isEn ? 'Quiz created' : 'ፈተናው ተፈጥሯል',
      );
    }

    if (created != null && mounted) {
      final qId = asInt(created['id']);
      _loadAll();
      if (qId != null) {
        await context.push('/edu/quiz-edit/$qId');
        _loadAll();
      }
    }
  }

  void _openQuestionBanks() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuestionBanksSheet(subjects: _subjects),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;
    final user = ref.watch(currentUserProvider);

    final isAuthorized = user != null &&
        (user.isSuperAdmin ||
            user.canAny([
              Perm.educationContent,
              Perm.educationManage,
              Perm.educationReports,
            ]));

    if (!isAuthorized) {
      return PatternScaffold(
        appBar: AppBar(title: Text(isEn ? 'Quizzes & Assessments' : 'ፈተናዎች እና ጥያቄዎች')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyView(
              icon: Icons.lock_outline_rounded,
              message: isEn
                  ? 'Access restricted. Content editing privileges required.'
                  : 'ይህን ገጽ ለመመልከት የአስተዳዳሪ ፈቃድ ያስፈልጋል።',
            ),
          ),
        ),
      );
    }

    // Filter quizzes
    final filtered = _quizzes.where((q) {
      if (_selectedSubjectId != null && asInt(q['subject_id']) != _selectedSubjectId) {
        return false;
      }
      final status = asStr(q['status']) ?? 'draft';
      if (_selectedStatus != 'all' && status != _selectedStatus) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final title = (asStr(q['title']) ?? '').toLowerCase();
        final titleEn = (asStr(q['title_en']) ?? '').toLowerCase();
        final subName = (asStr(q['subject_name']) ?? '').toLowerCase();
        final courseName = (asStr(q['course_name']) ?? '').toLowerCase();
        if (!title.contains(query) &&
            !titleEn.contains(query) &&
            !subName.contains(query) &&
            !courseName.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Stats
    final totalCount = _quizzes.length;
    final publishedCount = _quizzes.where((q) => asStr(q['status']) == 'published').length;
    final draftCount = _quizzes.where((q) => (asStr(q['status']) ?? 'draft') == 'draft').length;
    final needsGradingCount = _quizzes.fold<int>(0, (acc, q) => acc + asIntOr(q['needs_grading']));

    return PatternScaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Quizzes & Assessments' : 'ፈተናዎች እና ጥያቄዎች'),
        actions: [
          IconButton(
            tooltip: isEn ? 'Question Banks (F12)' : 'የጥያቄዎች ባንክ',
            icon: const Icon(Icons.account_balance_rounded),
            onPressed: _openQuestionBanks,
          ),
          IconButton(
            tooltip: isEn ? 'Refresh' : 'አድስ',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewQuiz,
        backgroundColor: AppColors.maroon,
        foregroundColor: AppColors.goldLight,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          isEn ? 'Create Quiz' : 'አዲስ ፈተና',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1F5F8B),
                    AppColors.maroon,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn ? 'Quizzes & Evaluations Hub' : 'የፈተናዎችና ምዘናዎች ማዕከል',
                          style: context.serif(17, color: Colors.white, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEn
                              ? 'Manage tests, grading rules, question pools & student attempts'
                              : 'ፈተናዎችን፣ የውጤት መስፈርቶችን፣ የጥያቄ ባንኮችንና የተማሪ ሙከራዎችን ያስተዳድሩ',
                          style: context.sans(12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Statistics Row
            Row(
              children: [
                _StatTile(
                  count: totalCount,
                  label: isEn ? 'Total' : 'አጠቃላይ',
                  color: AppColors.maroon,
                  icon: Icons.assignment_rounded,
                ),
                const SizedBox(width: 8),
                _StatTile(
                  count: publishedCount,
                  label: isEn ? 'Published' : 'የተለቀቁ',
                  color: const Color(0xFF2E7D32),
                  icon: Icons.check_circle_rounded,
                ),
                const SizedBox(width: 8),
                _StatTile(
                  count: draftCount,
                  label: isEn ? 'Drafts' : 'ረቂቆች',
                  color: const Color(0xFFE65100),
                  icon: Icons.edit_note_rounded,
                ),
                if (needsGradingCount > 0) ...[
                  const SizedBox(width: 8),
                  _StatTile(
                    count: needsGradingCount,
                    label: isEn ? 'To Grade' : 'እርማት የሚሹ',
                    color: AppColors.warning,
                    icon: Icons.rate_review_rounded,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Subject Filter Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.border.withValues(alpha: 0.8)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedSubjectId,
                  isExpanded: true,
                  hint: Text(isEn ? 'Filter by Subject (All)' : 'በትምህርት ዓይነት ይምረጡ (ሁሉም)'),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        isEn ? 'All Curriculum Subjects' : 'ሁሉም የትምህርት ዓይነቶች',
                        style: context.sans(14, weight: FontWeight.w600),
                      ),
                    ),
                    for (final s in _subjects)
                      DropdownMenuItem<int?>(
                        value: asInt(s['id']),
                        child: Text(
                          asStr(s['category_name']) != null
                              ? '${s['category_name']} · ${eduNames(context, s).title}'
                              : eduNames(context, s).title,
                          style: context.sans(14),
                        ),
                      ),
                  ],
                  onChanged: (val) => setState(() => _selectedSubjectId = val),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: isEn ? 'Search quiz title, subject or class...' : 'የፈተና ርዕስ ወይም የትምህርት ዓይነት ይፈልጉ...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: p.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.border),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 12),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusChip(
                    label: isEn ? 'All Quizzes' : 'ሁሉም',
                    selected: _selectedStatus == 'all',
                    onSelected: () => setState(() => _selectedStatus = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: isEn ? 'Published' : 'የተለቀቁ',
                    selected: _selectedStatus == 'published',
                    onSelected: () => setState(() => _selectedStatus = 'published'),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: isEn ? 'Drafts' : 'ረቂቆች',
                    selected: _selectedStatus == 'draft',
                    onSelected: () => setState(() => _selectedStatus = 'draft'),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: isEn ? 'Closed' : 'የተዘጉ',
                    selected: _selectedStatus == 'closed',
                    onSelected: () => setState(() => _selectedStatus = 'closed'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content List
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: LoadingView()))
            else if (filtered.isEmpty)
              EmptyView(
                icon: Icons.quiz_outlined,
                message: isEn ? 'No quizzes match the current criteria.' : 'በዚህ መስፈርት የተዘጋጀ ፈተና አልተገኘም።',
              )
            else
              for (final q in filtered) ...[
                _QuizAdminCard(
                  quiz: q,
                  onEdit: () async {
                    final qId = asInt(q['id']);
                    if (qId != null) {
                      await context.push('/edu/quiz-edit/$qId');
                      _loadAll();
                    }
                  },
                  onPreview: () async {
                    final qId = asInt(q['id']);
                    if (qId != null) {
                      await context.push('/edu/quiz/$qId');
                      _loadAll();
                    }
                  },
                  onResults: () async {
                    final qId = asInt(q['id']);
                    if (qId != null) {
                      await context.push('/edu/quiz-results/$qId');
                      _loadAll();
                    }
                  },
                  onDelete: () {
                    final qId = asInt(q['id']);
                    final title = asStr(q['title']) ?? '';
                    if (qId != null) _deleteQuiz(qId, title);
                  },
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  final int count;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: context.serif(18, weight: FontWeight.w700, color: color),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.sans(10.5, weight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.maroon,
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12.5,
      ),
    );
  }
}

class _QuizAdminCard extends StatelessWidget {
  const _QuizAdminCard({
    required this.quiz,
    required this.onEdit,
    required this.onPreview,
    required this.onResults,
    required this.onDelete,
  });

  final Json quiz;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onResults;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;

    final title = asStr(quiz['title']) ?? '';
    final titleEn = asStr(quiz['title_en']);
    final status = asStr(quiz['status']) ?? 'draft';
    final questionCount = asIntOr(quiz['question_count']);
    final attempts = asIntOr(quiz['attempts']);
    final needsGrading = asIntOr(quiz['needs_grading']);
    final timeLimit = asInt(quiz['time_limit_minutes']);
    final isOfficial = quiz['assessment_id'] != null;

    final subjectName = asStr(quiz['subject_name']);
    final courseName = asStr(quiz['course_name']);
    final className = asStr(quiz['class_name']);

    final statusColor = switch (status) {
      'published' => const Color(0xFF2E7D32),
      'closed' => Colors.blueGrey,
      _ => const Color(0xFFE65100),
    };

    final statusText = switch (status) {
      'published' => isEn ? 'Published' : 'የተለቀቀ',
      'closed' => isEn ? 'Closed' : 'የተዘጋ',
      _ => isEn ? 'Draft' : 'ረቂቅ',
    };

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.maroon.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.quiz_rounded, size: 20, color: AppColors.maroon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.serif(15.5, weight: FontWeight.w700, color: p.text),
                      ),
                      if (titleEn != null && titleEn.isNotEmpty && titleEn != title)
                        Text(
                          titleEn,
                          style: context.sans(12, color: p.muted),
                        ),
                      if (subjectName != null && subjectName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${isEn ? "Subject" : "የትምህርት ዓይነት"}: $subjectName',
                          style: context.sans(12, color: AppColors.maroon, weight: FontWeight.w600),
                        ),
                      ],
                      if (courseName != null && courseName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$courseName${className != null ? " ($className)" : ""}',
                          style: context.sans(12, color: const Color(0xFF1F5F8B), weight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chips / metadata row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Pill(
                  isEn ? '$questionCount Questions' : '$questionCount ጥያቄዎች',
                  icon: Icons.help_outline_rounded,
                ),
                if (attempts > 0)
                  Pill(
                    isEn ? '$attempts Attempts' : '$attempts ሙከራዎች',
                    icon: Icons.people_outline_rounded,
                  ),
                if (timeLimit != null && timeLimit > 0)
                  Pill(
                    isEn ? '$timeLimit min' : '$timeLimit ደቂቃ',
                    icon: Icons.timer_outlined,
                  ),
                if (isOfficial)
                  Pill(
                    isEn ? 'Official' : 'ኦፊሴላዊ',
                    icon: Icons.verified_outlined,
                    color: const Color(0xFF2E7D32),
                  ),
                if (needsGrading > 0)
                  Pill(
                    isEn ? '$needsGrading To Grade' : '$needsGrading ማረም ያለበት',
                    icon: Icons.rate_review_outlined,
                    color: AppColors.warning,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Divider(height: 1, color: p.border.withValues(alpha: 0.5)),

          // Actions row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(isEn ? 'Edit' : 'አርትዕ', style: const TextStyle(fontSize: 12.5)),
                ),
                TextButton.icon(
                  onPressed: onPreview,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(isEn ? 'Preview' : 'ዕይታ', style: const TextStyle(fontSize: 12.5)),
                ),
                TextButton.icon(
                  onPressed: onResults,
                  icon: const Icon(Icons.leaderboard_outlined, size: 16),
                  label: Text(isEn ? 'Results' : 'ውጤቶች', style: const TextStyle(fontSize: 12.5)),
                ),
                const Spacer(),
                IconButton(
                  tooltip: isEn ? 'Delete Quiz' : 'ፈተናውን ሰርዝ',
                  icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.danger),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewQuizData {
  const _NewQuizData({
    required this.title,
    required this.isSubject,
    required this.targetId,
    this.isExam = false,
  });

  final String title;
  final bool isSubject;
  final int targetId;
  final bool isExam;
}

class _NewQuizModal extends StatefulWidget {
  const _NewQuizModal({required this.subjects, required this.courses});
  final List<Json> subjects;
  final List<Json> courses;

  @override
  State<_NewQuizModal> createState() => _NewQuizModalState();
}

class _NewQuizModalState extends State<_NewQuizModal> {
  final _titleController = TextEditingController();
  bool _isExam = false;
  bool _isSubject = true;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    if (widget.subjects.isNotEmpty) {
      _selectedId = asInt(widget.subjects.first['id']);
    } else if (widget.courses.isNotEmpty) {
      _isSubject = false;
      _selectedId = asInt(widget.courses.first['id']);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.add_task_rounded, color: AppColors.maroon, size: 24),
              const SizedBox(width: 10),
              Text(
                isEn ? 'Create New Evaluation' : 'አዲስ ፈተና አዘጋጅ',
                style: context.serif(18, weight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Exam Type: Standard Quiz vs Closing Exam
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  avatar: const Icon(Icons.quiz_outlined, size: 16),
                  label: Text(isEn ? 'Quiz' : 'መደበኛ ፈተና'),
                  selected: !_isExam,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _isExam = false;
                        if (widget.subjects.isNotEmpty) {
                          _isSubject = true;
                          _selectedId = asInt(widget.subjects.first['id']);
                        }
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  avatar: const Icon(Icons.school_rounded, size: 16),
                  label: Text(isEn ? 'Closing Exam' : 'የማጠቃለያ ፈተና'),
                  selected: _isExam,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _isExam = true;
                        _isSubject = false;
                        if (widget.courses.isNotEmpty) {
                          _selectedId = asInt(widget.courses.first['id']);
                        } else {
                          _selectedId = null;
                        }
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scope switch: Subject vs Course (only if not a Closing Exam)
          if (!_isExam && widget.subjects.isNotEmpty && widget.courses.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text(isEn ? 'Subject Quiz' : 'የትምህርት ዓይነት ፈተና'),
                    selected: _isSubject,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _isSubject = true;
                          _selectedId = asInt(widget.subjects.first['id']);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Text(isEn ? 'Class Course Quiz' : 'የክፍል ፈተና'),
                    selected: !_isSubject,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _isSubject = false;
                          _selectedId = asInt(widget.courses.first['id']);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Target Selector
          Text(
            _isExam
                ? (isEn ? 'Assigned Class Course (Required for Closing Exam)' : 'የክፍል ትምህርት (ለማጠቃለያ ፈተና ግዴታ ነው)')
                : (_isSubject
                    ? (isEn ? 'Select Curriculum Subject' : 'የትምህርት ዓይነት ይምረጡ')
                    : (isEn ? 'Select Class Course' : 'የክፍል ትምህርት ይምረጡ')),
            style: context.sans(13, weight: FontWeight.w600, color: p.text),
          ),
          const SizedBox(height: 6),
          if (_isExam && widget.courses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isEn
                    ? 'No active class courses available. Closing exams must belong to a specific enrolled course.'
                    : 'ምንም የክፍል ትምህርት አልተገኘም። የማጠቃለያ ፈተና ለተመዘገበ የክፍል ትምህርት ብቻ ይሰጣል።',
                style: const TextStyle(color: AppColors.maroon, fontSize: 12),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedId,
                  isExpanded: true,
                  items: _isSubject
                      ? [
                          for (final s in widget.subjects)
                            DropdownMenuItem<int>(
                              value: asInt(s['id']),
                              child: Text(
                                asStr(s['category_name']) != null
                                    ? '${s['category_name']} · ${eduNames(context, s).title}'
                                    : eduNames(context, s).title,
                              ),
                            ),
                        ]
                      : [
                          for (final c in widget.courses)
                            DropdownMenuItem<int>(
                              value: asInt(c['id']),
                              child: Text('${asStr(c['name']) ?? ''} (${asStr(c['class_name']) ?? ''})'),
                            ),
                        ],
                  onChanged: (val) => setState(() => _selectedId = val),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Title
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: _isExam ? (isEn ? 'Closing Exam Title' : 'የማጠቃለያ ፈተና ርዕስ') : (isEn ? 'Quiz Title' : 'የፈተናው ርዕስ'),
              hintText: _isExam
                  ? (isEn ? 'e.g. Final Closing Examination 2026' : 'ለምሳሌ፡ የ2018 የማጠቃለያ ፈተና')
                  : (isEn ? 'e.g. Midterm Assessment or Chapter 1 Quiz' : 'ለምሳሌ፡ የመጀመሪያ ወሰነ-ትምህርት ፈተና'),
              filled: true,
              fillColor: p.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.maroon,
              foregroundColor: AppColors.goldLight,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(isEn ? 'Create & Add Questions' : 'ፍጠርና ጥያቄዎችን አክል'),
            onPressed: () {
              final title = _titleController.text.trim();
              if (title.isEmpty || _selectedId == null) return;
              Navigator.of(context).pop(
                _NewQuizData(
                  title: title,
                  isSubject: _isSubject,
                  targetId: _selectedId!,
                  isExam: _isExam,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuestionBanksSheet extends ConsumerStatefulWidget {
  const _QuestionBanksSheet({required this.subjects});
  final List<Json> subjects;

  @override
  ConsumerState<_QuestionBanksSheet> createState() => _QuestionBanksSheetState();
}

class _QuestionBanksSheetState extends ConsumerState<_QuestionBanksSheet> {
  int? _subjectId;
  List<Json> _banks = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.subjects.isNotEmpty) {
      _subjectId = asInt(widget.subjects.first['id']);
      _loadBanks();
    }
  }

  Future<void> _loadBanks() async {
    if (_subjectId == null) return;
    setState(() => _loading = true);
    try {
      final list = await ref.read(eduRepositoryProvider).questionBanks(_subjectId!);
      if (mounted) setState(() => _banks = list);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addBank() async {
    final l = context.l10n;
    final isEn = l.isEn;
    if (_subjectId == null) {
      if (widget.subjects.isEmpty) {
        showSnack(context, isEn ? 'Please create a subject first' : 'እባክዎ መጀመሪያ የትምህርት ዓይነት ይፍጠሩ');
        return;
      }
      _subjectId = asInt(widget.subjects.first['id']);
    }

    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String diff = 'mixed';

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isEn ? 'Create Question Bank' : 'አዲስ የጥያቄ ባንክ ፍጠር'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: isEn ? 'Bank Title / Name *' : 'የባንኩ ስም *',
                    hintText: isEn ? 'e.g. Old Testament Unit 1' : 'ምሳሌ፡ የብሉይ ኪዳን ጥያቄዎች',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: catCtrl,
                  decoration: InputDecoration(
                    labelText: isEn ? 'Category / Tag (optional)' : 'ክፍል / መደብ (አማራጭ)',
                    hintText: isEn ? 'e.g. Genesis' : 'ምሳሌ፡ ኦሪት ዘፍጥረት',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: diff,
                  decoration: InputDecoration(
                    labelText: isEn ? 'Difficulty Level' : 'የክብደት ደረጃ',
                  ),
                  items: [
                    DropdownMenuItem(value: 'mixed', child: Text(isEn ? 'Mixed (All Levels)' : 'የተደባለቀ (ሁሉንም ደረጃ)')),
                    DropdownMenuItem(value: 'easy', child: Text(isEn ? 'Easy' : 'ቀላል')),
                    DropdownMenuItem(value: 'medium', child: Text(isEn ? 'Medium' : 'መካከለኛ')),
                    DropdownMenuItem(value: 'hard', child: Text(isEn ? 'Hard' : 'ከባድ')),
                  ],
                  onChanged: (v) {
                    if (v != null) setS(() => diff = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isEn ? 'Description (optional)' : 'መግለጫ (አማራጭ)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isEn ? 'Cancel' : 'ይቅር'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: Text(isEn ? 'Create' : 'ፍጠር'),
            ),
          ],
        ),
      ),
    );

    if (created != true || !mounted) return;
    final trimmedName = nameCtrl.text.trim();
    if (trimmedName.isEmpty) return;

    final payload = <String, dynamic>{
      'title': trimmedName,
      'name': trimmedName,
      if (catCtrl.text.trim().isNotEmpty) 'category': catCtrl.text.trim(),
      'difficulty': diff,
      if (descCtrl.text.trim().isNotEmpty) 'description': descCtrl.text.trim(),
    };

    await runWithProgress(
      context,
      () => ref.read(eduRepositoryProvider).createQuestionBank(_subjectId!, payload),
      success: isEn ? 'Question bank created' : 'የጥያቄ ባንክ ተፈጥሯል',
    );
    _loadBanks();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_rounded, color: AppColors.maroon),
              const SizedBox(width: 10),
              Text(
                isEn ? 'Question Banks (F12)' : 'የጥያቄዎች ባንክ ማከማቻ',
                style: context.serif(18, weight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Subject dropdown
          if (widget.subjects.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: _subjectId,
              decoration: InputDecoration(
                labelText: isEn ? 'Subject' : 'የትምህርት ዓይነት',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              items: [
                for (final s in widget.subjects)
                  DropdownMenuItem<int>(
                    value: asInt(s['id']),
                    child: Text(
                      asStr(s['category_name']) != null
                          ? '${s['category_name']} · ${eduNames(context, s).title}'
                          : eduNames(context, s).title,
                    ),
                  ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _subjectId = val);
                  _loadBanks();
                }
              },
            ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEn ? 'Question Pools' : 'የጥያቄዎች ክምችት',
                style: context.sans(14, weight: FontWeight.bold, color: p.text),
              ),
              TextButton.icon(
                onPressed: _addBank,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(isEn ? 'Add Bank' : 'ባንክ ጨምር'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _loading
                ? const LoadingView()
                : _banks.isEmpty
                    ? EmptyView(
                        icon: Icons.account_balance_outlined,
                        message: isEn
                            ? 'No question banks created for this subject yet.'
                            : 'ለዚህ የትምህርት ዓይነት የተዘጋጀ የጥያቄ ባንክ የለም።',
                      )
                    : ListView.builder(
                        itemCount: _banks.length,
                        itemBuilder: (ctx, i) {
                          final b = _banks[i];
                          final name = asStr(b['title']) ?? asStr(b['name']) ?? '';
                          final qCount = asIntOr(b['question_count']);
                          final category = asStr(b['category']);
                          final difficulty = asStr(b['difficulty']) ?? 'mixed';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.folder_special_rounded, color: AppColors.maroon),
                              title: Text(name, style: context.sans(14, weight: FontWeight.w600)),
                              subtitle: Row(
                                children: [
                                  Text(
                                    isEn ? '$qCount Questions' : '$qCount ጥያቄዎች',
                                    style: context.sans(12, color: p.muted),
                                  ),
                                  if (category != null && category.isNotEmpty) ...[
                                    Text(' • ', style: TextStyle(color: p.muted)),
                                    Text(category, style: context.sans(12, color: AppColors.maroon, weight: FontWeight.w500)),
                                  ],
                                ],
                              ),
                              trailing: Chip(
                                label: Text(
                                  difficulty == 'easy'
                                      ? (isEn ? 'Easy' : 'ቀላል')
                                      : (difficulty == 'medium'
                                          ? (isEn ? 'Medium' : 'መካከለኛ')
                                          : (difficulty == 'hard'
                                              ? (isEn ? 'Hard' : 'ከባድ')
                                              : (isEn ? 'Mixed' : 'ድብልቅ'))),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
