import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/states.dart';
import '../admin/report_export.dart';
import '../guidance/contextual_help_sheet.dart';

class EduScoresScreen extends ConsumerStatefulWidget {
  const EduScoresScreen({super.key, this.studentId});
  final int? studentId;

  @override
  ConsumerState<EduScoresScreen> createState() => _EduScoresScreenState();
}

class _EduScoresScreenState extends ConsumerState<EduScoresScreen> with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);
  int? _yearId;
  int? _termId;
  int? _classId;
  int? _courseId;
  String? _group;

  late Future<Json> _scoresFuture;
  late Future<Json> _activityFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _scoresFuture = ref.read(eduRepositoryProvider).adminScores(
            yearId: _yearId,
            termId: _termId,
            classId: _classId,
            courseId: _courseId,
            group: _group,
          );
      _activityFuture = ref.read(eduRepositoryProvider).adminActivity(
            yearId: _yearId,
            termId: _termId,
            classId: _classId,
          );
    });
  }

  Json _filterMap() => {
        if (_yearId != null) 'year_id': _yearId,
        if (_termId != null) 'term_id': _termId,
        if (_classId != null) 'class_id': _classId,
        if (_courseId != null) 'course_id': _courseId,
        if (_group != null) 'group': _group,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (widget.studentId != null) {
      return EduStudentScoresView(studentId: widget.studentId);
    }

    return PatternScaffold(
      appBar: AppBar(
        title: Text(l.eduScoresAndActivity),
        actions: [
          const ContextualHelpButton(screenRoute: '/edu/review'),
          ReportExportButton(
            kind: 'education-scores',
            label: l.eduAcademicScore,
            filters: _filterMap,
            extra: [
              ExtraReport(
                kind: 'education-activity',
                label: l.eduActivityReport,
                filters: _filterMap,
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l.eduScoresAndActivity),
            Tab(text: l.eduActivityReport),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ScoresTab(
            future: _scoresFuture,
            onReload: _reload,
          ),
          _ActivityTab(
            future: _activityFuture,
            onReload: _reload,
          ),
        ],
      ),
    );
  }
}

class _ScoresTab extends StatelessWidget {
  const _ScoresTab({required this.future, required this.onReload});
  final Future<Json> future;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;

    return FutureBuilder<Json>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return snap.hasError
              ? ErrorView(error: snap.error!, onRetry: onReload, module: 'education', screen: 'EduScoresScreen')
              : const LoadingView();
        }
        final data = snap.data!;
        final scores = asJsonList(data['scores'] ?? data['data']);
        if (scores.isEmpty) {
          return EmptyView(message: l.eaNothingToReview, icon: Icons.query_stats_rounded);
        }

        return RefreshIndicator(
          onRefresh: () async => onReload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: scores.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final row = scores[i];
              final acad = row['academic_score'];
              final eng = row['engagement_score'];
              final name = asStr(row['full_name']) ?? 'Student #${row['user_id']}';
              final memberId = asStr(row['member_id']);
              final className = asStr(row['class_name']) ?? '—';

              return AppCard(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EduStudentScoresView(studentId: asIntOr(row['user_id'])))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: context.sans(14, weight: FontWeight.w700)),
                              if (memberId != null)
                                Text(memberId, style: context.sans(12, color: p.muted)),
                            ],
                          ),
                        ),
                        Pill(className),
                        IconButton(
                          icon: const Icon(Icons.info_outline_rounded, size: 20),
                          tooltip: l.eduDetails,
                          onPressed: () => _showExplanationDialog(context, row),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.eduAcademicScore, style: context.sans(11.5, color: p.muted)),
                              const SizedBox(height: 2),
                              Text(
                                acad != null ? '$acad%' : '—',
                                style: context.sans(16, weight: FontWeight.w800, color: p.primary),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.eduEngagementScore, style: context.sans(11.5, color: p.muted)),
                              const SizedBox(height: 2),
                              Text(
                                eng != null ? '$eng%' : '—',
                                style: context.sans(16, weight: FontWeight.w800, color: AppColors.goldDark),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.faint),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showExplanationDialog(BuildContext context, Json row) {
    final l = context.l10n;
    final breakdown = asJson(row['breakdown']);
    final lessons = asJson(breakdown['lessons']);
    final assignments = asJson(breakdown['assignments']);
    final quizzes = asJson(breakdown['quizzes']);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${row['full_name']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${l.eduAcademicScore}: ${row['academic_score'] ?? '—'}%', style: ctx.sans(14, weight: FontWeight.w700)),
              Text('Based on ${row['outcomes_count']} finalized outcome(s).', style: ctx.sans(12, color: ctx.palette.muted)),
              const SizedBox(height: 14),
              Text('${l.eduEngagementScore}: ${row['engagement_score'] ?? '—'}%', style: ctx.sans(14, weight: FontWeight.w700)),
              Text('Formula: (Lessons × 50%) + (Assignments × 30%) + (Quizzes × 20%)', style: ctx.sans(11.5, color: ctx.palette.muted)),
              const Divider(height: 16),
              _item(ctx, 'Lessons (50%)', '${lessons['completed']} / ${lessons['accessible']} (${lessons['rate']}%)'),
              _item(ctx, 'Assignments (30%)', '${assignments['submitted']} / ${assignments['accessible']} (${assignments['rate']}%)'),
              _item(ctx, 'Quizzes (20%)', '${quizzes['passed']} / ${quizzes['accessible']} (${quizzes['rate']}%)'),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
        ],
      ),
    );
  }

  Widget _item(BuildContext ctx, String label, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: ctx.sans(12.5))),
            Text(val, style: ctx.sans(12.5, weight: FontWeight.w700)),
          ],
        ),
      );
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.future, required this.onReload});
  final Future<Json> future;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return FutureBuilder<Json>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return snap.hasError
              ? ErrorView(error: snap.error!, onRetry: onReload, module: 'education', screen: 'EduScoresScreen')
              : const LoadingView();
        }
        final data = snap.data!;
        final activity = asJsonList(data['activity'] ?? data['data']);
        if (activity.isEmpty) {
          return EmptyView(message: l.eaNothingToReview, icon: Icons.assessment_outlined);
        }

        return RefreshIndicator(
          onRefresh: () async => onReload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: activity.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final a = activity[i];
              return AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asStr(a['class_name']) ?? 'Class', style: context.sans(14, weight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _metric(context, 'Opens', '${a['lesson_opens']}'),
                        _metric(context, 'Completions', '${a['lesson_completions']}'),
                        _metric(context, 'Submissions', '${a['assignment_submissions']}'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _metric(context, 'Quizzes', '${a['quiz_attempts']}'),
                        _metric(context, 'Certificates', '${a['certificates_issued']}'),
                        const Spacer(),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _metric(BuildContext context, String label, String val) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.sans(11.5, color: context.palette.muted)),
            const SizedBox(height: 2),
            Text(val, style: context.sans(15, weight: FontWeight.w700)),
          ],
        ),
      );
}

class EduStudentScoresView extends ConsumerStatefulWidget {
  const EduStudentScoresView({super.key, this.studentId});
  final int? studentId;

  @override
  ConsumerState<EduStudentScoresView> createState() => _EduStudentScoresViewState();
}

class _EduStudentScoresViewState extends ConsumerState<EduStudentScoresView> with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 3, vsync: this);
  late Future<Json> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = widget.studentId != null
          ? ref.read(eduRepositoryProvider).studentScores(widget.studentId!)
          : ref.read(eduRepositoryProvider).myScores();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);

    return PatternScaffold(
      appBar: AppBar(
        title: Text(widget.studentId != null ? (l.isEn ? 'Student Scores & Activity' : 'የተማሪ ውጤት እና እንቅስቃሴ') : l.eduScoresAndActivity),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l.isEn ? 'Quizzes & Exams' : 'ፈተናዎች'),
            Tab(text: l.isEn ? 'Learning Progress' : 'የትምህርት ሂደት'),
            Tab(text: l.isEn ? 'Activity History' : 'የእንቅስቃሴ ታሪክ'),
          ],
        ),
      ),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return snap.hasError ? ErrorView(error: snap.error!, onRetry: _load) : const LoadingView();
          }
          final data = snap.data!;
          final student = asJson(data['student']);
          final enrollments = asJsonList(data['enrollments']);
          final quizAttempts = asJsonList(data['quiz_attempts']);
          final learningProgress = asJson(data['learning_progress']);
          final recentCompletions = asJsonList(learningProgress['recent_completions']);
          final completedLessonsCount = asIntOr(learningProgress['completed_lessons_count']);
          final activityHistory = asJsonList(data['activity_history']);

          return Column(
            children: [
              // Academic Summary Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.maroon,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: AppColors.maroon.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          foregroundColor: Colors.white,
                          child: const Icon(Icons.school_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(asStr(student['full_name']) ?? 'ተማሪ', style: context.serif(16, color: Colors.white, weight: FontWeight.w700)),
                              if (student['member_id'] != null)
                                Text('${student['member_id']}', style: context.sans(12, color: AppColors.goldLight)),
                            ],
                          ),
                        ),
                        if (enrollments.isNotEmpty)
                          Pill(asStr(enrollments.first['class_name']) ?? 'ክፍል', color: AppColors.gold),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.isEn ? 'Completed Lessons' : 'ያለቋቸው ትምህርቶች', style: context.sans(11, color: Colors.white70)),
                              const SizedBox(height: 2),
                              Text('$completedLessonsCount', style: context.serif(18, color: Colors.white, weight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.isEn ? 'Assessments Taken' : 'የተወሰዱ ፈተናዎች', style: context.sans(11, color: Colors.white70)),
                              const SizedBox(height: 2),
                              Text('${quizAttempts.length}', style: context.serif(18, color: AppColors.goldLight, weight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.isEn ? 'Classes' : 'ክፍሎች', style: context.sans(11, color: Colors.white70)),
                              const SizedBox(height: 2),
                              Text('${enrollments.length}', style: context.serif(18, color: Colors.white, weight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Quiz & Exam Attempts
                    RefreshIndicator(
                      onRefresh: () async => _load(),
                      child: quizAttempts.isEmpty
                          ? EmptyView(message: l.isEn ? 'No quiz attempts recorded yet.' : 'ምንም የፈተና ውጤት አልተመዘገበም።', icon: Icons.quiz_outlined)
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: quizAttempts.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final a = quizAttempts[i];
                                final isPending = a['pending_grading'] == true;
                                final isReleased = a['results_released'] == true;
                                final score = a['score'];
                                final totalQ = a['total_questions'];
                                final maxScore = a['max_score'] ?? (totalQ != null && asIntOr(totalQ) > 0 ? totalQ : 100);
                                final scorePercent = a['score_percent'];
                                final feedbacks = asJsonList(a['feedbacks']).isNotEmpty
                                    ? asJsonList(a['feedbacks'])
                                    : (a['feedbacks'] is List ? (a['feedbacks'] as List).map((x) => '$x').toList() : <String>[]);

                                return AppCard(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(asStr(a['quiz_title']) ?? 'ፈተና', style: context.sans(15, weight: FontWeight.w700)),
                                                if (a['course_title'] != null)
                                                  Text('${a['course_title']}', style: context.sans(12, color: p.muted)),
                                              ],
                                            ),
                                          ),
                                          if (isPending)
                                            Pill(l.isEn ? 'Pending Grading' : 'በእርምት ላይ ያለ', color: AppColors.goldDark, icon: Icons.pending_actions_rounded)
                                          else if (!isReleased)
                                            Pill(l.isEn ? 'Awaiting Release' : 'ውጤት አልተለቀቀም', color: AppColors.goldDark, icon: Icons.schedule_rounded)
                                          else
                                            Pill(
                                              scorePercent != null ? '$scorePercent%' : (l.isEn ? 'Graded' : 'የታረመ'),
                                              color: (scorePercent != null && (asDouble(scorePercent) >= 50)) ? AppColors.success : AppColors.danger,
                                              icon: Icons.check_circle_outline_rounded,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        [
                                          if (a['attempt_no'] != null) '${l.isEn ? 'Attempt' : 'ሙከራ'} #${a['attempt_no']}',
                                          if (a['submitted_at'] != null) f.dateTime(asDate(a['submitted_at'])),
                                        ].join(' · '),
                                        style: context.sans(12, color: p.muted),
                                      ),
                                      const Divider(height: 16),
                                      if (isPending || !isReleased)
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: context.palette.card,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.goldDark),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  isPending
                                                      ? (l.isEn
                                                          ? 'Short-answer questions awaiting grading by teacher. Score and answers are withheld.'
                                                          : 'የጽሑፍ ጥያቄዎች በአስተማሪው እርምት በመጠበቅ ላይ ናቸው። ውጤትና ትክክለኛ መልሶች እርምቱ እስኪያልቅ አይታዩም።')
                                                      : (asStr(a['notice']) ?? (l.isEn ? 'Results are scheduled for future release.' : 'ውጤቱ በይፋ እስኪለቀቅ ተከልክሏል።')),
                                                  style: context.sans(12, color: p.text),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Row(
                                          children: [
                                            Text(
                                              l.isEn ? 'Score: ' : 'የፈተና ነጥብ: ',
                                              style: context.sans(13, color: p.muted),
                                            ),
                                            Text(
                                              '$score / $maxScore',
                                              style: context.sans(16, weight: FontWeight.w800, color: p.primary),
                                            ),
                                            if (scorePercent != null) ...[
                                              const SizedBox(width: 8),
                                              Text('($scorePercent%)', style: context.sans(14, weight: FontWeight.w600, color: p.muted)),
                                            ],
                                          ],
                                        ),
                                      if (feedbacks.isNotEmpty && isReleased) ...[
                                        const SizedBox(height: 8),
                                        Text(l.isEn ? 'Teacher Feedback:' : 'የአስተማሪ አስተያየት:', style: context.sans(12, weight: FontWeight.w700)),
                                        const SizedBox(height: 4),
                                        for (final fb in feedbacks)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4, bottom: 2),
                                            child: Text('• $fb', style: context.sans(12, color: p.muted)),
                                          ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    // Tab 2: Learning Progress (Lessons Completed)
                    RefreshIndicator(
                      onRefresh: () async => _load(),
                      child: recentCompletions.isEmpty
                          ? EmptyView(message: l.isEn ? 'No completed lessons yet.' : 'እስካሁን የተጠናቀቀ ትምህርት የለም።', icon: Icons.menu_book_outlined)
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: recentCompletions.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final rc = recentCompletions[i];
                                return AppCard(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppColors.success.withValues(alpha: 0.12),
                                        foregroundColor: AppColors.success,
                                        child: const Icon(Icons.check_rounded, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(asStr(rc['lesson_title']) ?? 'ትምህርት', style: context.sans(14, weight: FontWeight.w700)),
                                            Text(
                                              [
                                                if (rc['subject_name'] != null) '${rc['subject_name']}',
                                                if (rc['unit_title'] != null) '${rc['unit_title']}',
                                              ].join(' · '),
                                              style: context.sans(12, color: p.muted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (rc['completed_at'] != null)
                                        Text(f.dateTime(asDate(rc['completed_at'])), style: context.sans(11, color: p.muted)),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    // Tab 3: Activity History
                    RefreshIndicator(
                      onRefresh: () async => _load(),
                      child: activityHistory.isEmpty
                          ? EmptyView(message: l.isEn ? 'No activity history recorded.' : 'ምንም የእንቅስቃሴ ታሪክ አልተገኘም።', icon: Icons.history_rounded)
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: activityHistory.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final act = activityHistory[i];
                                final type = asStr(act['type']);
                                final icon = type == 'quiz_submission'
                                    ? Icons.quiz_rounded
                                    : (type == 'lesson_completion' ? Icons.check_circle_rounded : Icons.school_rounded);
                                final color = type == 'quiz_submission'
                                    ? AppColors.gold
                                    : (type == 'lesson_completion' ? AppColors.success : AppColors.maroon);

                                return AppCard(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: color.withValues(alpha: 0.15),
                                        foregroundColor: color,
                                        child: Icon(icon, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(asStr(act['title']) ?? '', style: context.sans(13.5, weight: FontWeight.w700)),
                                            if (act['description'] != null)
                                              Text('${act['description']}', style: context.sans(12, color: p.muted)),
                                          ],
                                        ),
                                      ),
                                      if (act['timestamp'] != null)
                                        Text(f.dateTime(asDate(act['timestamp'])), style: context.sans(11, color: p.muted)),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
