import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/dialogs.dart';
import '../../../widgets/states.dart';
import '../../admin/admin_widgets.dart' show DateTimeField;
import '../../admin/edit_mode.dart' show contentRevisionProvider;
import 'edu_home.dart' show eduDashboardProvider;
import 'edu_widgets.dart';

String _n(Object? v) {
  final d = asDouble(v);
  return d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);
}

String _policyText(AppLocalizations l, String? p) => switch (p) {
      'practice' => l.elPolicyPractice,
      'after_submit' => l.elPolicyAfterSubmit,
      'never' => l.elPolicyNever,
      _ => l.elPolicyAfterClose,
    };

final _quizMaroon = FilledButton.styleFrom(backgroundColor: AppColors.maroon, foregroundColor: AppColors.goldLight, padding: const EdgeInsets.symmetric(vertical: 14));

// =============================================================================
// Student: quiz page (rules, my attempts, start / resume)
// =============================================================================
final _myQuizzesProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(eduRepositoryProvider).myQuizzes());
final eduQuizProvider = FutureProvider.autoDispose.family<Json, int>((ref, id) => ref.watch(eduRepositoryProvider).quiz(id));

class EduQuizScreen extends ConsumerWidget {
  const EduQuizScreen({super.key, required this.quizId});
  final int quizId;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final quiz = ref.read(eduQuizProvider(quizId)).asData?.value;
    final left = asIntOr(quiz?['attempts_left']);
    final resume = asInt(quiz?['in_progress_attempt_id']);
    if (resume == null && left <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.elAttemptsExhaustedDesc),
          backgroundColor: AppColors.maroon,
        ),
      );
      return;
    }
    final a = await runWithProgress(context, () => ref.read(eduRepositoryProvider).startQuiz(quizId));
    if (a == null || !context.mounted) return;
    await context.push('/edu/attempt/${a['id']}');
    ref.invalidate(eduQuizProvider(quizId));
    ref.invalidate(_myQuizzesProvider);
    ref.invalidate(eduDashboardProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final isEn = Localizations.localeOf(context).languageCode != 'am';

    final quizAsync = ref.watch(eduQuizProvider(quizId));
    final qVal = quizAsync.asData?.value;
    final title = qVal != null ? eduNames(context, qVal).title : '';
    final canEdit = asBool(qVal?['can_edit']);

    return PatternScaffold(
      appBar: AppBar(
        title: Text(title.isNotEmpty ? title : l.elQuiz),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: !isEn ? 'ፈተናውን አርትዕ' : 'Edit Quiz',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/edu/quiz-edit/$quizId').then((_) => ref.invalidate(eduQuizProvider(quizId))),
            ),
        ],
      ),
      body: AsyncView(
        value: quizAsync,
        onRetry: () => ref.invalidate(eduQuizProvider(quizId)),
        data: (q) {
          final qTitle = eduNames(context, q).title;
          final instructions = isEn ? (asStr(q['instructions_en']) ?? asStr(q['instructions'])) : (asStr(q['instructions']) ?? asStr(q['instructions_en']));
          final availability = asStr(q['availability']);
          final left = asIntOr(q['attempts_left']);
          final resume = asInt(q['in_progress_attempt_id']);
          final last = asInt(q['last_attempt_id']);
          final closes = asDate(q['closes_at']);
          final opens = asDate(q['opens_at']);
          final limit = asInt(q['time_limit_minutes']);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              MaroonCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(qTitle, style: context.serif(20, color: Colors.white)),
                  if (q['course_name'] != null || q['class_name'] != null)
                    Text('${q['course_name'] ?? ''}${q['class_name'] != null ? ' · ${q['class_name']}' : ''}', style: context.sans(12.5, color: Colors.white70)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _chip(context, Icons.help_outline_rounded, l.elQuestionCount(asIntOr(q['question_count']))),
                    if (limit != null) _chip(context, Icons.timer_outlined, l.elMinutes(limit)),
                    _chip(context, Icons.replay_rounded, l.elAttemptsLeft(left, asIntOr(q['max_attempts']))),
                    if (opens != null && availability == 'upcoming') _chip(context, Icons.lock_clock_rounded, l.elOpens(f.date(opens, withWeekday: true))),
                    if (closes != null) _chip(context, Icons.schedule_rounded, l.elDue(f.date(closes, withWeekday: true))),
                    if (canEdit && q['status'] == 'draft')
                      _chip(context, Icons.edit_note_rounded, !isEn ? 'ረቂቅ (Draft)' : 'Draft'),
                  ]),
                ]),
              ),
              if (instructions != null && instructions.isNotEmpty) ...[
                SectionHeader(title: l.elInstructions),
                AppCard(padding: const EdgeInsets.all(14), child: Text(instructions, style: context.sans(13.5, height: 1.6))),
              ],
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(asBool(q['official']) ? Icons.verified_outlined : Icons.school_outlined, color: AppColors.goldDark, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(asBool(q['official']) ? l.elOfficialQuizNote : l.elPracticeScoreNote, style: context.sans(12.5, color: p.muted, height: 1.5))),
                  ]),
                  const SizedBox(height: 6),
                  Text(_policyText(l, asStr(q['review_policy'])), style: context.sans(12.5, color: p.muted, height: 1.5)),
                ]),
              ),
              if (q['my_score'] != null || asBool(q['score_hidden'])) ...[
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const Icon(Icons.emoji_events_outlined, color: AppColors.gold),
                    const SizedBox(width: 10),
                    Expanded(child: Text(q['my_score'] != null ? l.elQuizScore('${_n(q['my_score'])}/${_n(q['my_max_score'])}') : (asBool(q['needs_grading']) ? l.elAwaitingTeacher : l.elScorePending), style: context.sans(14, weight: FontWeight.w600))),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              if (resume != null)
                FilledButton.icon(
                  onPressed: () => context.push('/edu/attempt/$resume').then((_) => ref.invalidate(eduQuizProvider(quizId))),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l.elResume),
                )
              else if (availability == 'open' && left > 0)
                FilledButton.icon(
                  onPressed: () => _start(context, ref),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(asIntOr(q['attempts_used']) > 0 ? l.elTryAgain : l.elStartQuiz),
                )
              else if (availability == 'open' && left <= 0) ...[
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.block_rounded),
                  label: Text(l.elNoAttemptsLeftAlert),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.maroon),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.elAttemptsExhausted, style: context.sans(13.5, weight: FontWeight.w600, color: AppColors.maroon)),
                          const SizedBox(height: 4),
                          Text(l.elAttemptsExhaustedDesc, style: context.sans(12.5, color: p.muted)),
                        ],
                      ),
                    ),
                  ]),
                ),
              ]
              else if (canEdit && left > 0)
                FilledButton.icon(
                  onPressed: () => _start(context, ref),
                  icon: const Icon(Icons.science_outlined),
                  label: Text(!isEn ? 'ፈተናውን ሞክር / እይ' : 'Preview / Test Quiz'),
                )
              else if (canEdit && left <= 0)
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.block_rounded),
                  label: Text(l.elNoAttemptsLeftAlert),
                ),
              if (last != null && resume == null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push('/edu/attempt/$last'),
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(l.elViewAttempt),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static Widget _chip(BuildContext context, IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(100)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.goldLight),
          const SizedBox(width: 4),
          Flexible(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.sans(11.5, color: Colors.white))),
        ]),
      );
}

// =============================================================================
// Student: taking the quiz (one question per page) and the result
// =============================================================================
class EduAttemptScreen extends ConsumerStatefulWidget {
  const EduAttemptScreen({super.key, required this.attemptId});
  final int attemptId;

  @override
  ConsumerState<EduAttemptScreen> createState() => _EduAttemptScreenState();
}

class _EduAttemptScreenState extends ConsumerState<EduAttemptScreen> {
  Json? _attempt;
  Object? _error;
  final Map<int, Object?> _responses = {};
  final Map<int, Json> _checked = {};
  int _index = 0;
  bool _busy = false;
  Timer? _timer;
  int? _secondsLeft;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final a = await ref.read(eduRepositoryProvider).attempt(widget.attemptId);
      if (!mounted) return;
      setState(() {
        _attempt = a;
        _error = null;
        for (final q in asJsonList(a['questions'])) {
          _responses[asIntOr(q['id'])] = q['response'];
        }
        _secondsLeft = asInt(a['seconds_left']);
      });
      _timer?.cancel();
      if (a['status'] == 'in_progress' && _secondsLeft != null) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() => _secondsLeft = (_secondsLeft ?? 0) - 1);
          // Time is up: hand in what was answered (the server decides anyway).
          if ((_secondsLeft ?? 1) <= 0) {
            _timer?.cancel();
            _submit(confirm: false);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  List<Json> get _questions => asJsonList(_attempt?['questions']);

  Future<void> _saveCurrent() async {
    final qs = _questions;
    if (qs.isEmpty || _attempt?['status'] != 'in_progress') return;
    final id = asIntOr(qs[_index]['id']);
    try {
      await ref.read(eduRepositoryProvider).saveAnswers(widget.attemptId, [{'question_id': id, 'response': _responses[id]}]);
    } catch (_) {
      // Kept on the phone and sent again with the final submit.
    }
  }

  Future<void> _go(int i) async {
    await _saveCurrent();
    if (mounted) setState(() => _index = i);
  }

  Future<void> _check() async {
    final q = _questions[_index];
    final id = asIntOr(q['id']);
    final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).checkAnswer(widget.attemptId, id, _responses[id]));
    if (r != null && mounted) setState(() => _checked[id] = r);
  }

  Future<void> _submit({bool confirm = true}) async {
    final l = context.l10n;
    if (_busy) return;
    if (confirm) {
      final unanswered = _questions.where((q) => _isEmpty(_responses[asIntOr(q['id'])])).length;
      final ok = await showConfirm(context, unanswered > 0 ? l.elSubmitUnanswered(unanswered) : l.elSubmitConfirm, confirmLabel: l.elSubmit);
      if (!ok || !mounted) return;
    }
    _busy = true;
    final answers = [for (final q in _questions) {'question_id': asIntOr(q['id']), 'response': _responses[asIntOr(q['id'])]}];
    final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).submitAttempt(widget.attemptId, answers));
    _busy = false;
    _timer?.cancel();
    if (!mounted) return;
    if (r != null) {
      setState(() {
        _attempt = r;
        _secondsLeft = null;
      });
    } else {
      await _load();
    }
    final quizId = asIntOr(asJson(r?['quiz'] ?? _attempt?['quiz'])['id']);
    if (quizId > 0) ref.invalidate(eduQuizProvider(quizId));
    ref.invalidate(_myQuizzesProvider);
    ref.invalidate(eduDashboardProvider);
  }

  static bool _isEmpty(Object? v) => v == null || v == '' || (v is List && v.isEmpty);

  static final _maroon = FilledButton.styleFrom(backgroundColor: AppColors.maroon, foregroundColor: AppColors.goldLight, padding: const EdgeInsets.symmetric(vertical: 14));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = _attempt;
    final title = asStr(asJson(a?['quiz'])['title']) ?? l.elQuiz;
    final running = a?['status'] == 'in_progress';
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && running) _saveCurrent();
      },
      child: PatternScaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (running && _secondsLeft != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Pill(
                    '${(_secondsLeft! ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft! % 60).clamp(0, 59).toString().padLeft(2, '0')}',
                    icon: Icons.timer_outlined,
                    color: (_secondsLeft ?? 999) < 60 ? AppColors.danger : null,
                  ),
                ),
              ),
          ],
        ),
        body: _error != null
            ? ErrorView(error: _error!, onRetry: _load)
            : a == null
                ? const LoadingView()
                : running
                    ? _runner(context)
                    : _AttemptResult(attempt: a),
      ),
    );
  }

  Widget _runner(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final qs = _questions;
    if (qs.isEmpty) return MessageView(icon: Icons.help_outline_rounded, message: l.elNoQuestions);
    final q = qs[_index];
    final id = asIntOr(q['id']);
    final checked = _checked[id];
    final practice = asJson(_attempt?['quiz'])['review_policy'] == 'practice';
    final last = _index == qs.length - 1;
    final isEn = Localizations.localeOf(context).languageCode != 'am';
    final prompt = isEn ? (asStr(q['prompt_en']) ?? asStr(q['prompt']) ?? '') : (asStr(q['prompt']) ?? asStr(q['prompt_en']) ?? '');
    final explanation = isEn ? (asStr(checked?['explanation_en']) ?? asStr(checked?['explanation'])) : (asStr(checked?['explanation']) ?? asStr(checked?['explanation_en']));
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l.elQuestionOf(eduNumber(context, _index + 1), eduNumber(context, qs.length)), style: context.sans(13, weight: FontWeight.w600, color: p.muted)),
                const SizedBox(height: 6),
                EduProgressBar(value: (_index + 1) / qs.length, height: 6),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
                    child: Text(prompt, style: context.serif(17, color: p.primary, height: 1.45)),
                  ),
                  const SizedBox(height: 14),
                  _QuestionInput(
                    question: q,
                    value: _responses[id],
                    enabled: checked == null,
                    checked: checked,
                    onChanged: (v) => setState(() => _responses[id] = v),
                  ),
                  if (checked != null && explanation != null) ...[
                    const SizedBox(height: 10),
                    AppCard(padding: const EdgeInsets.all(12), child: Text(explanation, style: context.sans(13, height: 1.5))),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Maroon, as in the design's quiz page.
              if (practice && checked == null)
                FilledButton(style: _maroon, onPressed: _isEmpty(_responses[id]) ? null : _check, child: Text(l.elCheckAnswer))
              else if (last)
                FilledButton(style: _maroon, onPressed: () => _submit(), child: Text(l.elSubmit))
              else
                FilledButton(style: _maroon, onPressed: () => _go(_index + 1), child: Text(l.elNext)),
              Row(children: [
                if (_index > 0) TextButton.icon(onPressed: () => _go(_index - 1), icon: const Icon(Icons.chevron_left_rounded), label: Text(l.elPrevious)),
                const Spacer(),
                if (practice && checked != null && !last) TextButton(onPressed: () => _go(_index + 1), child: Text(l.elNext)),
                if (!last && !(practice && checked != null)) TextButton(onPressed: () => _submit(), child: Text(l.elSubmit)),
                if (practice && checked != null && last) TextButton(onPressed: () => _submit(), child: Text(l.elSubmit)),
              ]),
            ]),
          ),
        ),
      ),
    ]);
  }
}

/// The answer area of one question: option cards (single / multiple / true-false) or a text box.
class _QuestionInput extends StatelessWidget {
  const _QuestionInput({required this.question, required this.value, required this.onChanged, this.enabled = true, this.checked, this.correct});
  final Json question;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final bool enabled;
  final Json? checked;
  /// Correct answer to show (result view).
  final Object? correct;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final type = asStr(question['type']);
    final answer = checked?['answer'] ?? correct;
    if (type == 'short_text') {
      return TextFormField(
        initialValue: asStr(value),
        enabled: enabled,
        maxLines: 5,
        minLines: 3,
        onChanged: onChanged,
        decoration: InputDecoration(hintText: l.elYourAnswer),
      );
    }
    final options = type == 'true_false'
        ? [(true, l.elTrue), (false, l.elFalse)]
        : [for (final (i, o) in asJsonList(question['options']).indexed) (asStr(o['id']) as Object, '${_letter(context, i)}) ${o['text']}')];
    final multi = type == 'multiple';
    final selected = multi ? (value is List ? (value as List).map((e) => '$e').toSet() : <String>{}) : null;
    return Column(children: [
      if (multi) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.elChooseAll, style: context.sans(12, color: context.palette.muted))),
      for (final (v, label) in options)
        _OptionCard(
          label: label,
          selected: multi ? selected!.contains('$v') : value == v,
          correct: answer == null ? null : (answer is List ? answer.map((e) => '$e').contains('$v') : answer == v),
          multi: multi,
          onTap: !enabled
              ? null
              : () {
                  if (multi) {
                    final s = {...selected!};
                    s.contains('$v') ? s.remove('$v') : s.add('$v');
                    onChanged(s.toList()..sort());
                  } else {
                    onChanged(v);
                  }
                },
        ),
    ]);
  }

  /// ሀ ለ ሐ መ … in Amharic (as in the design), a b c d in English.
  static String _letter(BuildContext context, int i) {
    const am = ['ሀ', 'ለ', 'ሐ', 'መ', 'ሠ', 'ረ', 'ሰ', 'ሸ', 'ቀ', 'በ'];
    return Localizations.localeOf(context).languageCode == 'am' && i < am.length ? am[i] : String.fromCharCode(97 + i);
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.label, required this.selected, required this.onTap, this.correct, this.multi = false});
  final String label;
  final bool selected;
  final bool? correct;
  final bool multi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isSelected = selected;
    final border = correct == true
        ? AppColors.success
        : (correct == false && selected ? AppColors.danger : (isSelected ? AppColors.eduGold : p.border));
    final bgColor = correct == true
        ? AppColors.success.withValues(alpha: 0.08)
        : (correct == false && selected
            ? AppColors.danger.withValues(alpha: 0.08)
            : (isSelected ? AppColors.eduGold.withValues(alpha: 0.08) : p.card));
    final icon = correct == true
        ? Icons.check_circle_rounded
        : (correct == false && selected
            ? Icons.cancel_rounded
            : (selected
                ? (multi ? Icons.check_box_rounded : Icons.check_circle_rounded)
                : (multi ? Icons.check_box_outline_blank_rounded : Icons.radio_button_unchecked_rounded)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: isSelected || correct == true ? 2.0 : 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Text(
                  label,
                  style: context.serif(15.5, weight: isSelected ? FontWeight.w600 : FontWeight.w500, color: p.text),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                icon,
                color: correct == true
                    ? AppColors.success
                    : (correct == false && selected ? AppColors.danger : (isSelected ? AppColors.goldDark : p.faint)),
                size: 22,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AttemptResult extends StatelessWidget {
  const _AttemptResult({required this.attempt});
  final Json attempt;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final isEn = Localizations.localeOf(context).languageCode != 'am';
    final quiz = asJson(attempt['quiz']);
    final isGradingPending = asBool(attempt['needs_grading']) || attempt['status'] == 'pending_grading';
    final reveal = asBool(attempt['answers_visible']) && !isGradingPending;
    final questions = asJsonList(attempt['questions']);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      if (attempt['score'] != null && !isGradingPending)
        EduResultHeroCard(
          score: asDouble(attempt['score']),
          maxScore: asDouble(attempt['max_score']),
          percentage: (asDouble(attempt['max_score']) > 0)
              ? (asDouble(attempt['score']) * 100 / asDouble(attempt['max_score']))
              : 0.0,
          passed: asBool(attempt['passed']) ||
              ((asDouble(attempt['max_score']) > 0) &&
                  (asDouble(attempt['score']) / asDouble(attempt['max_score']) >= 0.7)),
          quizTitle: asStr(quiz['title']),
        )
      else
        MaroonCard(
          child: Column(children: [
            Icon(isGradingPending ? Icons.hourglass_top_rounded : Icons.task_alt_rounded, color: AppColors.goldLight, size: 40),
            const SizedBox(height: 6),
            Text(isGradingPending ? (!isEn ? 'ፈተናው ተልኳል (እየታረመ ነው)' : 'Submitted (Under Review)') : l.elSubmitted, style: context.serif(18, color: Colors.white)),
            const SizedBox(height: 6),
            Text(isGradingPending ? (!isEn ? 'የፅሁፍ ጥያቄዎች እየታረሙ ስለሆነ ውጤትዎ ገና አልተጠናቀቀም' : 'Short-answer questions are being graded') : l.elScorePending, textAlign: TextAlign.center, style: context.sans(13, color: Colors.white70)),
            const SizedBox(height: 6),
            Text(asBool(quiz['official']) ? l.elOfficialQuizNote : l.elPracticeScoreNote, textAlign: TextAlign.center, style: context.sans(11.5, color: Colors.white70)),
          ]),
        ),
      if (isGradingPending) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.maroon.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.maroon.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.maroon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(!isEn ? 'እየታረመ ነው' : 'Grading in progress', style: context.serif(15, weight: FontWeight.w600, color: AppColors.maroon)),
                const SizedBox(height: 2),
                Text(!isEn ? 'የፅሁፍ መልሶች በአስተማሪው ታርመው ሲያልቁ ሙሉ ውጤትዎ እና የተሰጡ አስተያየቶች ይገለጻሉ።' : 'Full results and teacher feedback will be available once manual grading is complete.', style: context.sans(12.5, color: p.muted)),
              ]),
            ),
          ]),
        ),
      ],
      if (!reveal && !isGradingPending) ...[
        const SizedBox(height: 12),
        EduEmptyCard(icon: Icons.visibility_off_outlined, message: _policyText(l, asStr(quiz['review_policy']))),
      ],
      if (reveal)
        for (final (i, q) in questions.indexed) ...[
          SectionHeader(title: l.elQuestionOf(eduNumber(context, i + 1), eduNumber(context, questions.length))),
          Text(
            isEn ? (asStr(q['prompt_en']) ?? asStr(q['prompt']) ?? '') : (asStr(q['prompt']) ?? asStr(q['prompt_en']) ?? ''),
            style: context.serif(15, color: p.primary),
          ),
          const SizedBox(height: 8),
          _QuestionInput(question: q, value: q['response'], enabled: false, onChanged: (_) {}, correct: q['answer']),
          if (q['type'] == 'short_text' && asStr(q['answer']) != null) Text('${l.elModelAnswer}: ${q['answer']}', style: context.sans(12.5, color: p.muted)),
          if (q['points_awarded'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${!isEn ? "የተሰጠ ውጤት" : "Awarded points"}: ${_n(q['points_awarded'])}/${_n(q['points'])}',
                style: context.sans(13, color: AppColors.gold, weight: FontWeight.w600),
              ),
            ),
          if (asStr(q['feedback']) != null && (asStr(q['feedback']) ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.comment_outlined, size: 16, color: AppColors.goldDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${!isEn ? "የአስተማሪ አስተያየት" : "Teacher feedback"}: ${asStr(q['feedback'])}',
                      style: context.sans(12.5, color: p.primary),
                    ),
                  ),
                ]),
              ),
            ),
          if ((isEn ? (asStr(q['explanation_en']) ?? asStr(q['explanation'])) : (asStr(q['explanation']) ?? asStr(q['explanation_en']))) != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                (isEn ? (asStr(q['explanation_en']) ?? asStr(q['explanation'])) : (asStr(q['explanation']) ?? asStr(q['explanation_en'])))!,
                style: context.sans(12.5, color: p.muted, height: 1.5),
              ),
            ),
        ],
      const SizedBox(height: 24),
      FilledButton.icon(
        style: _quizMaroon,
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.check_circle_outline_rounded),
        label: Text(!isEn ? 'ተጠናቋል / ተመለስ' : 'Done / Return'),
      ),
    ]);
  }
}

// =============================================================================
// Teachers: the quizzes of a class subject (tab of the course page)
// =============================================================================
class CourseQuizzesTab extends ConsumerStatefulWidget {
  const CourseQuizzesTab({super.key, required this.courseId});
  final int courseId;

  @override
  ConsumerState<CourseQuizzesTab> createState() => _CourseQuizzesTabState();
}

class _CourseQuizzesTabState extends ConsumerState<CourseQuizzesTab> {
  late Future<List<Json>> _future = ref.read(eduRepositoryProvider).courseQuizzes(widget.courseId);

  void _reload() => setState(() => _future = ref.read(eduRepositoryProvider).courseQuizzes(widget.courseId));

  bool _isCreating = false;

  Future<void> _create() async {
    if (_isCreating) return;
    _isCreating = true;
    try {
      final l = context.l10n;
      final title = await promptText(context, title: l.elNewQuiz, label: l.elTitle, required: true);
      final trimmed = title?.trim() ?? '';
      if (trimmed.isEmpty || !mounted) return;
      final q = await runWithProgress(context, () => ref.read(eduRepositoryProvider).createQuiz(widget.courseId, {'title': trimmed}));
      if (q == null || !mounted) return;
      await context.push('/edu/quiz-edit/${q['id']}');
      _reload();
    } finally {
      _isCreating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(heroTag: 'new-quiz', onPressed: _create, icon: const Icon(Icons.add_rounded), label: Text(l.elNewQuiz)),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final list = snap.data!;
          if (list.isEmpty) return EmptyView(message: l.elNoQuizzes, icon: Icons.quiz_outlined);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
              for (final q in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    onTap: () async {
                      await context.push('/edu/quiz-edit/${q['id']}');
                      _reload();
                    },
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      const Icon(Icons.quiz_rounded, color: AppColors.maroon),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(asStr(q['title']) ?? '', style: context.serif(14.5)),
                          const SizedBox(height: 4),
                          Wrap(spacing: 6, runSpacing: 4, children: [
                            Pill(switch (asStr(q['status'])) { 'published' => l.elStatusPublished, 'closed' => l.elQuizClosed, _ => l.elStatusDraft }),
                            Pill(l.elQuestionCount(asIntOr(q['question_count']))),
                            if (asIntOr(q['attempts']) > 0) Pill(l.elAttemptsCount(asIntOr(q['attempts']))),
                            if (asIntOr(q['needs_grading']) > 0) Pill(l.elToGradeCount(asIntOr(q['needs_grading'])), color: AppColors.warning),
                            if (q['assessment_id'] != null) Pill(l.elOfficialQuiz, icon: Icons.verified_outlined),
                          ]),
                        ]),
                      ),
                      IconButton(tooltip: l.elResults, icon: Icon(Icons.leaderboard_outlined, color: p.muted), onPressed: () => context.push('/edu/quiz-results/${q['id']}')),
                    ]),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Teachers: quiz editor (settings + questions)
// =============================================================================
class EduQuizEditorScreen extends ConsumerStatefulWidget {
  const EduQuizEditorScreen({super.key, required this.quizId});
  final int quizId;

  @override
  ConsumerState<EduQuizEditorScreen> createState() => _EduQuizEditorScreenState();
}

class _EduQuizEditorScreenState extends ConsumerState<EduQuizEditorScreen> {
  Json? _quiz;
  Object? _error;
  List<Json> _assessments = const [];
  List<Json> _lessons = const [];
  final _title = TextEditingController();
  final _titleEn = TextEditingController();
  final _instructions = TextEditingController();
  final _instructionsEn = TextEditingController();
  final _limit = TextEditingController();
  DateTime? _opens;
  DateTime? _closes;
  int _maxAttempts = 1;
  String _scoring = 'best';
  String _policy = 'after_close';
  bool _shuffle = false;
  int? _assessmentId;
  int? _lessonId;
  List<_QDraft> _questions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _titleEn.dispose();
    _instructions.dispose();
    _instructionsEn.dispose();
    _limit.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(eduRepositoryProvider);
    try {
      final q = await repo.teacherQuiz(widget.quizId);
      final courseId = asIntOr(q['course_id']);
      var assessments = <Json>[];
      var lessons = <Json>[];
      if (courseId > 0) {
        try {
          assessments = await repo.assessments(courseId);
        } catch (_) {}
        try {
          final course = await repo.course(courseId);
          final subjectId = asInt(course['subject_id']);
          if (subjectId != null) {
            final s = await repo.subject(subjectId);
            lessons = [for (final u in asJsonList(s['units'])) ...asJsonList(u['lessons']), ...asJsonList(s['lessons'])];
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _quiz = q;
        _assessments = assessments;
        _lessons = lessons;
        _title.text = asStr(q['title']) ?? '';
        _titleEn.text = asStr(q['title_en']) ?? '';
        _instructions.text = asStr(q['instructions']) ?? '';
        _instructionsEn.text = asStr(q['instructions_en']) ?? '';
        _limit.text = asInt(q['time_limit_minutes'])?.toString() ?? '';
        _opens = asDate(q['opens_at']);
        _closes = asDate(q['closes_at']);
        _maxAttempts = asIntOr(q['max_attempts'], 1).clamp(1, 10);
        _scoring = asStr(q['scoring']) == 'last' ? 'last' : 'best';
        _policy = const ['after_close', 'after_submit', 'practice', 'never'].contains(asStr(q['review_policy']))
            ? asStr(q['review_policy'])!
            : 'after_close';
        _shuffle = asBool(q['shuffle']);
        _assessmentId = asInt(q['assessment_id']);
        _lessonId = asInt(q['lesson_id']);
        for (final d in _questions) {
          d.dispose();
        }
        _questions = [for (final x in asJsonList(q['questions'])) _QDraft.from(x)];
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  bool get _locked => asBool(_quiz?['has_attempts']);

  Future<void> _saveSettings({String? status}) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final effStatus = status ?? asStr(_quiz?['status']) ?? 'draft';
    if (_title.text.trim().isEmpty) return showSnack(context, l.elNameRequired);
    if (effStatus == 'published' && _titleEn.text.trim().isEmpty) {
      return showSnack(context, isEn ? 'English title is required for published quizzes' : 'ለታተሙ ፈተናዎች የእንግሊዝኛ ርዕስ ያስፈልጋል');
    }
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'title_en': _titleEn.text.trim().isEmpty ? null : _titleEn.text.trim(),
      'instructions': _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
      'instructions_en': _instructionsEn.text.trim().isEmpty ? null : _instructionsEn.text.trim(),
      'opens_at': _opens?.toUtc().toIso8601String(),
      'closes_at': _closes?.toUtc().toIso8601String(),
      'shuffle': _shuffle,
      'review_policy': _policy,
      'lesson_id': _lessonId,
      if (!_locked) ...{
        'time_limit_minutes': int.tryParse(_limit.text.trim()),
        'max_attempts': _maxAttempts,
        'scoring': _scoring,
        'assessment_id': _assessmentId,
      },
      'status': ?status,
    };
    final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).updateQuiz(widget.quizId, body), success: context.l10n.saved);
    if (r != null) {
      ref.invalidate(eduQuizProvider(widget.quizId));
      ref.read(contentRevisionProvider.notifier).bump();
      await _load();
    }
  }

  Future<void> _saveQuestions() async {
    final l = context.l10n;
    for (final q in _questions) {
      final err = q.validate(l);
      if (err != null) return showSnack(context, err);
    }
    final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).setQuestions(widget.quizId, [for (final q in _questions) q.toJson()]), success: l.saved);
    if (r != null) {
      ref.invalidate(eduQuizProvider(widget.quizId));
      ref.read(contentRevisionProvider.notifier).bump();
      await _load();
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    if (!await showConfirm(context, l.elDeleteQuizConfirm, destructive: true) || !mounted) return;
    final ok = await runWithProgress(context, () async {
      await ref.read(eduRepositoryProvider).deleteQuiz(widget.quizId);
      return true;
    });
    if (ok == true && mounted) {
      ref.read(contentRevisionProvider.notifier).bump();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = _quiz;
    final status = asStr(q?['status']);
    final isMagazine = asStr(q?['kind']) == 'magazine' || q?['magazine_id'] != null;
    return PatternScaffold(
      appBar: AppBar(
        title: Text(q == null ? l.elQuiz : asStr(q['title']) ?? ''),
        actions: [
          if (q != null)
            IconButton(
              tooltip: l.elPreview,
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () async {
                await _saveSettings();
                if (context.mounted) {
                  ref.invalidate(eduQuizProvider(widget.quizId));
                  context.push('/edu/quiz/${widget.quizId}');
                }
              },
            ),
          if (q != null) IconButton(tooltip: l.elResults, icon: const Icon(Icons.leaderboard_outlined), onPressed: () => context.push('/edu/quiz-results/${widget.quizId}')),
          if (q != null && !_locked) IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
        ],
      ),
      body: _error != null
          ? ErrorView(error: _error!, onRetry: _load)
          : q == null
              ? const LoadingView()
              : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
                  if (_locked) EduEmptyCard(icon: Icons.lock_outline_rounded, message: l.elQuizLockedNote),
                  // ---- status
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Expanded(child: Text(switch (status) { 'published' => l.elStatusPublished, 'closed' => l.elQuizClosed, _ => l.elStatusDraft }, style: context.sans(14, weight: FontWeight.w700))),
                      if (status == 'draft') FilledButton(onPressed: () => _saveSettings(status: 'published'), child: Text(l.elPublish)),
                      if (status == 'published') OutlinedButton(onPressed: () => _saveSettings(status: 'closed'), child: Text(l.elCloseQuiz)),
                      if (status == 'closed') OutlinedButton(onPressed: () => _saveSettings(status: 'published'), child: Text(l.elReopenQuiz)),
                    ]),
                  ),
                  if (isMagazine) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: AppColors.maroon, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              Localizations.localeOf(context).languageCode == 'en'
                                  ? 'Magazine Quiz: locked to 1 attempt with a standard 7-day availability window.'
                                  : 'የሰሌዳ መጽሔት ፈተና፡ 1 ሙከራ ብቻ የተፈቀደ ሲሆን ለ7 ቀናት ክፍት ሆኖ ይቆያል።',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF650D20)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SectionHeader(title: l.elQuizSettings),
                  TextField(controller: _title, decoration: InputDecoration(labelText: '${l.elTitle} (አማርኛ) *')),
                  const SizedBox(height: 10),
                  TextField(controller: _titleEn, decoration: InputDecoration(labelText: '${l.elTitle} (English)')),
                  const SizedBox(height: 10),
                  TextField(controller: _instructions, maxLines: 3, decoration: InputDecoration(labelText: '${l.elInstructions} (አማርኛ)')),
                  const SizedBox(height: 10),
                  TextField(controller: _instructionsEn, maxLines: 3, decoration: InputDecoration(labelText: '${l.elInstructions} (English)')),
                  const SizedBox(height: 10),
                  DateTimeField(label: l.elOpensAt, value: _opens, clearable: true, onChanged: (v) => setState(() => _opens = v)),
                  const SizedBox(height: 10),
                  DateTimeField(label: l.elClosesAt, value: _closes, clearable: true, onChanged: (v) => setState(() => _closes = v)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: _limit, enabled: !_locked, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.elTimeLimit, helperText: l.elTimeLimitHint))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: isMagazine ? 1 : _maxAttempts.clamp(1, 10),
                        decoration: InputDecoration(
                          labelText: l.elMaxAttempts,
                          helperText: isMagazine ? (Localizations.localeOf(context).languageCode == 'en' ? 'Locked to 1 for magazine' : 'ለመጽሔት 1 ብቻ ነው') : null,
                        ),
                        items: isMagazine
                            ? [const DropdownMenuItem(value: 1, child: Text('1'))]
                            : [for (var i = 1; i <= 10; i++) DropdownMenuItem(value: i, child: Text('$i'))],
                        onChanged: (_locked || isMagazine) ? null : (v) => setState(() => _maxAttempts = (v ?? 1).clamp(1, 10)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _scoring == 'last' ? 'last' : 'best',
                    decoration: InputDecoration(labelText: l.elScoring),
                    items: [DropdownMenuItem(value: 'best', child: Text(l.elScoringBest)), DropdownMenuItem(value: 'last', child: Text(l.elScoringLast))],
                    onChanged: _locked ? null : (v) => setState(() => _scoring = v ?? 'best'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: const ['after_close', 'after_submit', 'practice', 'never'].contains(_policy) ? _policy : 'after_close',
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.elReviewPolicy),
                    items: [for (final v in const ['after_close', 'after_submit', 'practice', 'never']) DropdownMenuItem(value: v, child: Text(_policyText(l, v), overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setState(() => _policy = v ?? 'after_close'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: _assessments.any((a) => (asInt(a['assessment_id']) ?? asInt(a['id'])) == _assessmentId) ? _assessmentId : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.elLinkAssessment, helperText: l.elLinkAssessmentHint, helperMaxLines: 3),
                    items: [
                      DropdownMenuItem<int?>(value: null, child: Text(l.elNotOfficial)),
                      for (final a in _assessments) DropdownMenuItem<int?>(value: asInt(a['assessment_id']) ?? asInt(a['id']), child: Text('${a['title']} (/${_n(a['max_score'])})', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _locked ? null : (v) => setState(() => _assessmentId = v),
                  ),
                  if (_lessons.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: _lessons.any((x) => asInt(x['id']) == _lessonId) ? _lessonId : null,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l.elLinkLesson),
                      items: [
                        DropdownMenuItem<int?>(value: null, child: Text(l.none)),
                        for (final x in _lessons) DropdownMenuItem<int?>(value: asInt(x['id']), child: Text(asStr(x['title']) ?? '', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _lessonId = v),
                    ),
                  ],
                  SwitchListTile(contentPadding: EdgeInsets.zero, value: _shuffle, onChanged: (v) => setState(() => _shuffle = v), title: Text(l.elShuffle)),
                  FilledButton(onPressed: () => _saveSettings(), child: Text(l.save)),

                  // ---- questions
                  SectionHeader(title: l.elQuestions, trailing: _locked ? null : l.elAddQuestion, onTrailingTap: _locked ? null : () => setState(() => _questions.add(_QDraft.blank()))),
                  if (_questions.isEmpty) EduEmptyCard(icon: Icons.help_outline_rounded, message: l.elNoQuestions),
                  for (final (i, d) in _questions.indexed)
                    _QuestionEditor(
                      key: ObjectKey(d),
                      index: i,
                      draft: d,
                      locked: _locked,
                      onChanged: () => setState(() {}),
                      onRemove: () => setState(() => _questions.removeAt(i).dispose()),
                      onDuplicate: () => setState(() => _questions.insert(i + 1, d.clone())),
                    ),
                  if (!_locked) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(onPressed: () => setState(() => _questions.add(_QDraft.blank())), icon: const Icon(Icons.add_rounded), label: Text(l.elAddQuestion)),
                    const SizedBox(height: 8),
                    FilledButton.icon(onPressed: _saveQuestions, icon: const Icon(Icons.save_outlined), label: Text(l.elSaveQuestions)),
                  ],
                ]),
    );
  }
}

/// One question being edited.
class _QDraft {
  _QDraft({
    required this.type,
    required this.prompt,
    TextEditingController? promptEn,
    required this.options,
    required this.explanation,
    TextEditingController? explanationEn,
    required this.points,
    this.single,
    Set<int>? multi,
    this.truth = true,
    String? model,
  })  : promptEn = promptEn ?? TextEditingController(),
        explanationEn = explanationEn ?? TextEditingController(),
        multi = multi ?? {},
        model = TextEditingController(text: model ?? '');

  factory _QDraft.blank() => _QDraft(
        type: 'single',
        prompt: TextEditingController(),
        promptEn: TextEditingController(),
        options: [TextEditingController(), TextEditingController()],
        explanation: TextEditingController(),
        explanationEn: TextEditingController(),
        points: TextEditingController(text: '1'),
      );

  factory _QDraft.from(Json q) {
    final opts = asJsonList(q['options']);
    final ids = [for (final o in opts) asStr(o['id'])];
    final answer = q['answer'];
    return _QDraft(
      type: asStr(q['type']) ?? 'single',
      prompt: TextEditingController(text: asStr(q['prompt'])),
      promptEn: TextEditingController(text: asStr(q['prompt_en'])),
      options: [for (final o in opts) TextEditingController(text: asStr(o['text']))],
      explanation: TextEditingController(text: asStr(q['explanation'])),
      explanationEn: TextEditingController(text: asStr(q['explanation_en'])),
      points: TextEditingController(text: _n(q['points'])),
      single: answer is String ? ids.indexOf(answer) : null,
      multi: answer is List ? {for (final a in answer) ids.indexOf('$a')}.where((i) => i >= 0).toSet() : null,
      truth: answer is bool ? answer : true,
      model: q['type'] == 'short_text' ? asStr(answer) : null,
    );
  }

  String type;
  final TextEditingController prompt;
  final TextEditingController promptEn;
  final List<TextEditingController> options;
  final TextEditingController explanation;
  final TextEditingController explanationEn;
  final TextEditingController points;
  final TextEditingController model;
  int? single;
  final Set<int> multi;
  bool truth;

  String? validate(AppLocalizations l) {
    if (prompt.text.trim().isEmpty && promptEn.text.trim().isEmpty) return l.elQuestionNeedsPrompt;
    if (type == 'single' || type == 'multiple') {
      final filled = options.where((o) => o.text.trim().isNotEmpty).length;
      if (filled < 2) return l.elQuestionNeedsOptions;
      if (type == 'single' && (single == null || single! >= options.length || options[single!].text.trim().isEmpty)) return l.elQuestionNeedsAnswer;
      if (type == 'multiple' && multi.where((i) => i < options.length && options[i].text.trim().isNotEmpty).isEmpty) return l.elQuestionNeedsAnswer;
    }
    return null;
  }

  Json toJson() {
    // Empty option boxes are dropped; answers are re-mapped to the server's a, b, c… ids.
    final kept = <int>[for (var i = 0; i < options.length; i++) if (options[i].text.trim().isNotEmpty) i];
    String idOf(int i) => String.fromCharCode(97 + kept.indexOf(i));
    final pmt = prompt.text.trim().isNotEmpty ? prompt.text.trim() : promptEn.text.trim();
    return {
      'type': type,
      'prompt': pmt,
      'prompt_en': promptEn.text.trim().isEmpty ? null : promptEn.text.trim(),
      'points': double.tryParse(points.text.trim()) ?? 1,
      'explanation': explanation.text.trim().isEmpty ? null : explanation.text.trim(),
      'explanation_en': explanationEn.text.trim().isEmpty ? null : explanationEn.text.trim(),
      if (type == 'single' || type == 'multiple') 'options': [for (final i in kept) options[i].text.trim()],
      if (type == 'single') 'answer': (single != null && kept.contains(single!)) ? idOf(single!) : (kept.isNotEmpty ? idOf(kept.first) : 'a'),
      if (type == 'multiple') 'answer': [for (final i in multi.where(kept.contains)) idOf(i)],
      if (type == 'true_false') 'answer': truth,
      if (type == 'short_text') 'answer': model.text.trim().isEmpty ? null : model.text.trim(),
    };
  }

  _QDraft clone() {
    return _QDraft(
      type: type,
      prompt: TextEditingController(text: prompt.text),
      promptEn: TextEditingController(text: promptEn.text),
      options: [for (final o in options) TextEditingController(text: o.text)],
      explanation: TextEditingController(text: explanation.text),
      explanationEn: TextEditingController(text: explanationEn.text),
      points: TextEditingController(text: points.text),
      single: single,
      multi: Set.from(multi),
      truth: truth,
      model: model.text,
    );
  }

  void dispose() {
    prompt.dispose();
    promptEn.dispose();
    for (final o in options) {
      o.dispose();
    }
    explanation.dispose();
    explanationEn.dispose();
    points.dispose();
    model.dispose();
  }
}

class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({
    super.key,
    required this.index,
    required this.draft,
    required this.locked,
    required this.onChanged,
    required this.onRemove,
    this.onDuplicate,
  });
  final int index;
  final _QDraft draft;
  final bool locked;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onDuplicate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = draft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text(l.elQuestionN(index + 1), style: context.sans(13, weight: FontWeight.w700)),
            const Spacer(),
            DropdownButton<String>(
              value: d.type,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(value: 'single', child: Text(l.elTypeSingle)),
                DropdownMenuItem(value: 'multiple', child: Text(l.elTypeMultiple)),
                DropdownMenuItem(value: 'true_false', child: Text(l.elTypeTrueFalse)),
                DropdownMenuItem(value: 'short_text', child: Text(l.elTypeShortText)),
              ],
              onChanged: locked
                  ? null
                  : (v) {
                      d.type = v ?? 'single';
                      onChanged();
                    },
            ),
            if (!locked && onDuplicate != null)
              IconButton(
                tooltip: Localizations.localeOf(context).languageCode == 'en' ? 'Duplicate question' : 'ጥያቄ ቅዳ',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: onDuplicate,
              ),
            if (!locked) IconButton(tooltip: l.delete, icon: const Icon(Icons.close_rounded), onPressed: onRemove),
          ]),
          TextField(controller: d.prompt, enabled: !locked, maxLines: 3, minLines: 1, decoration: InputDecoration(labelText: '${l.elPrompt} (አማርኛ) *')),
          const SizedBox(height: 6),
          TextField(controller: d.promptEn, enabled: !locked, maxLines: 3, minLines: 1, decoration: InputDecoration(labelText: '${l.elPrompt} (English)')),
          const SizedBox(height: 8),
          if (d.type == 'single' || d.type == 'multiple') ...[
            for (final (i, o) in d.options.indexed)
              Row(children: [
                d.type == 'single'
                    ? IconButton(
                        tooltip: l.elMarkCorrect,
                        icon: Icon(d.single == i ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: d.single == i ? AppColors.success : null),
                        onPressed: locked
                            ? null
                            : () {
                                d.single = i;
                                onChanged();
                              },
                      )
                    : Checkbox(value: d.multi.contains(i), onChanged: locked ? null : (v) {
                        v == true ? d.multi.add(i) : d.multi.remove(i);
                        onChanged();
                      }),
                Expanded(child: TextField(controller: o, enabled: !locked, decoration: InputDecoration(hintText: l.elOptionN(i + 1), isDense: true))),
                if (!locked && d.options.length > 2)
                  IconButton(icon: const Icon(Icons.remove_circle_outline_rounded, size: 20), onPressed: () {
                    d.options.removeAt(i).dispose();
                    d.single = d.single == i ? null : (d.single != null && d.single! > i ? d.single! - 1 : d.single);
                    final shifted = {for (final m in d.multi) if (m != i) (m > i ? m - 1 : m)};
                    d.multi
                      ..clear()
                      ..addAll(shifted);
                    onChanged();
                  }),
              ]),
            if (!locked && d.options.length < 10)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(onPressed: () {
                  d.options.add(TextEditingController());
                  onChanged();
                }, icon: const Icon(Icons.add_rounded, size: 18), label: Text(l.elAddOption)),
              ),
            Text(l.elMarkCorrect, style: context.sans(11.5, color: context.palette.muted)),
          ],
          if (d.type == 'true_false')
            SegmentedButton<bool>(
              segments: [ButtonSegment(value: true, label: Text(l.elTrue)), ButtonSegment(value: false, label: Text(l.elFalse))],
              selected: {d.truth},
              onSelectionChanged: locked ? null : (s) {
                d.truth = s.first;
                onChanged();
              },
            ),
          if (d.type == 'short_text') TextField(controller: d.model, enabled: !locked, maxLines: 2, decoration: InputDecoration(labelText: l.elModelAnswer, helperText: l.elShortTextHint, helperMaxLines: 2)),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(width: 90, child: TextField(controller: d.points, enabled: !locked, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l.elPoints, isDense: true))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: d.explanation, enabled: !locked, decoration: InputDecoration(labelText: '${l.elExplanation} (አማርኛ)', isDense: true))),
          ]),
          const SizedBox(height: 6),
          TextField(controller: d.explanationEn, enabled: !locked, decoration: InputDecoration(labelText: '${l.elExplanation} (English)', isDense: true)),
        ]),
      ),
    );
  }
}

// =============================================================================
// Teachers: results, grading written answers, sending scores to the score sheet
// =============================================================================
class EduQuizResultsScreen extends ConsumerStatefulWidget {
  const EduQuizResultsScreen({super.key, required this.quizId});
  final int quizId;

  @override
  ConsumerState<EduQuizResultsScreen> createState() => _EduQuizResultsScreenState();
}

class _EduQuizResultsScreenState extends ConsumerState<EduQuizResultsScreen> {
  late Future<Json> _future = ref.read(eduRepositoryProvider).quizResults(widget.quizId);

  void _reload() => setState(() => _future = ref.read(eduRepositoryProvider).quizResults(widget.quizId));

  Future<void> _transfer() async {
    final l = context.l10n;
    if (!await showConfirm(context, l.elTransferConfirm, confirmLabel: l.elTransfer) || !mounted) return;
    final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).transferQuiz(widget.quizId));
    if (r == null || !mounted) return;
    await showInfo(context, l.elTransferResult(asIntOr(r['transferred']), asIntOr(r['pending_grading']), asIntOr(r['locked'])));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return PatternScaffold(
      appBar: AppBar(title: Text(l.elResults)),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final quiz = asJson(snap.data!['quiz']);
          final students = asJsonList(snap.data!['students']);
          final linked = quiz['assessment_id'] != null;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 32), children: [
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(asStr(quiz['title']) ?? '', style: context.serif(16)),
                  Text(l.elAttemptsCount(students.where((s) => asJsonList(s['attempts']).isNotEmpty).length), style: context.sans(12.5, color: p.muted)),
                  const SizedBox(height: 10),
                  if (linked)
                    FilledButton.icon(onPressed: _transfer, icon: const Icon(Icons.move_to_inbox_rounded), label: Text(l.elTransfer))
                  else
                    Text(l.elNotOfficialNote, style: context.sans(12, color: p.muted)),
                ]),
              ),
              const SizedBox(height: 8),
              if (students.isEmpty) EmptyView(message: l.elNoStudents, icon: Icons.groups_outlined),
              for (final s in students)
                TrackTile(
                  title: asStr(s['full_name']) ?? '',
                  subtitle: asJsonList(s['attempts']).isEmpty
                      ? l.elNotTaken
                      : [
                          if (s['score'] != null) '${_n(s['score'])}/${_n(s['max_score'])}',
                          l.elAttemptsCount(asJsonList(s['attempts']).length),
                          if (asBool(s['needs_grading'])) l.elNeedsGrading,
                          if (s['transferred_at'] != null) l.elTransferred,
                        ].join(' · '),
                  leading: ListThumb(icon: asBool(s['needs_grading']) ? Icons.rate_review_outlined : Icons.person_outline_rounded, active: asJsonList(s['attempts']).isNotEmpty),
                  trailing: asJsonList(s['attempts']).isEmpty ? null : const Icon(Icons.chevron_right_rounded),
                  onTap: asJsonList(s['attempts']).isEmpty
                      ? null
                      : () async {
                          await context.push('/edu/quiz-attempt/${asJsonList(s['attempts']).last['id']}');
                          _reload();
                        },
                ),
            ]),
          );
        },
      ),
    );
  }
}

class EduTeacherAttemptScreen extends ConsumerStatefulWidget {
  const EduTeacherAttemptScreen({super.key, required this.attemptId});
  final int attemptId;

  @override
  ConsumerState<EduTeacherAttemptScreen> createState() => _EduTeacherAttemptScreenState();
}

class _EduTeacherAttemptScreenState extends ConsumerState<EduTeacherAttemptScreen> {
  late Future<Json> _future = ref.read(eduRepositoryProvider).teacherAttempt(widget.attemptId);

  Future<void> _grade(Json q) async {
    final l = context.l10n;
    final isEn = Localizations.localeOf(context).languageCode != 'am';
    final max = asDouble(q['points']);
    final pointsCtrl = TextEditingController(text: q['points_awarded'] == null ? '' : _n(q['points_awarded']));
    final feedbackCtrl = TextEditingController(text: asStr(q['feedback']) ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.elGradeAnswer),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: pointsCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.elPointsOutOf(_n(max)),
                hintText: '0 - ${_n(max)}',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: !isEn ? 'አስተያየት (አማራጭ)' : 'Feedback (optional)',
                hintText: !isEn ? 'ለተማሪው አስተያየት ያክሉ...' : 'Add feedback for student...',
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(pointsCtrl.text.trim().replaceAll(',', '.'));
              if (v == null || v < 0 || v > max) return;
              Navigator.of(ctx).pop(true);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final points = double.tryParse(pointsCtrl.text.trim().replaceAll(',', '.'));
    if (points == null) return;
    final feedback = feedbackCtrl.text.trim().isEmpty ? null : feedbackCtrl.text.trim();

    final r = await runWithProgress(
      context,
      () => ref.read(eduRepositoryProvider).gradeAnswer(
        widget.attemptId,
        asIntOr(q['id']),
        points,
        feedback: feedback,
      ),
      success: l.saved,
    );
    if (r != null) setState(() => _future = Future.value(r));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = Localizations.localeOf(context).languageCode != 'am';
    final p = context.palette;
    return PatternScaffold(
      appBar: AppBar(title: Text(l.elAttempt)),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => setState(() => _future = ref.read(eduRepositoryProvider).teacherAttempt(widget.attemptId)));
          if (!snap.hasData) return const LoadingView();
          final a = snap.data!;
          final qs = asJsonList(a['questions']);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(child: Text(asStr(a['full_name']) ?? '', style: context.serif(16))),
                Text(a['score'] == null ? '—' : '${_n(a['score'])}/${_n(a['max_score'])}', style: context.serif(18, color: AppColors.maroon)),
              ]),
            ),
            for (final (i, q) in qs.indexed) ...[
              SectionHeader(title: l.elQuestionN(i + 1), trailing: q['points_awarded'] == null ? l.elNeedsGrading : '${_n(q['points_awarded'])}/${_n(q['points'])}'),
              Text(asStr(q['prompt']) ?? '', style: context.serif(15, color: p.primary)),
              const SizedBox(height: 8),
              if (q['type'] == 'short_text') ...[
                AppCard(padding: const EdgeInsets.all(12), child: Text(asStr(q['response']) ?? '—', style: context.sans(14, height: 1.5))),
                if (asStr(q['answer']) != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${l.elModelAnswer}: ${q['answer']}', style: context.sans(12.5, color: p.muted))),
                if (asStr(q['feedback']) != null && (asStr(q['feedback']) ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Text('አስተያየት: ${q['feedback']}', style: context.sans(12.5, color: AppColors.goldDark)),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _grade(q),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text(q['points_awarded'] == null ? l.elGradeAnswer : (!isEn ? 'ውጤት/አስተያየት አርትዕ' : 'Edit Grade/Feedback')),
                  ),
                ),
              ] else
                _QuestionInput(question: q, value: q['response'], enabled: false, onChanged: (_) {}, correct: q['answer']),
            ],
          ]);
        },
      ),
    );
  }
}
