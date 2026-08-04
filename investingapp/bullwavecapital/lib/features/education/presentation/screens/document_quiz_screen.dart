import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../models/investment_doc_model.dart';
import '../provider/education_provider.dart';

class DocumentQuizScreen extends StatefulWidget {
  final String quizId;

  const DocumentQuizScreen({super.key, required this.quizId});

  @override
  State<DocumentQuizScreen> createState() => _DocumentQuizScreenState();
}

class _DocumentQuizScreenState extends State<DocumentQuizScreen> {
  int _index = 0;
  int? _selected;
  bool _answered = false;
  bool _finished = false;
  bool _loading = true;
  bool _submitting = false;
  InvestmentDocQuiz? _quiz;
  QuizAttemptResult? _result;
  final List<int?> _answers = [];

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    final provider = context.read<EducationProvider>();
    final quiz = await provider.fetchQuiz(widget.quizId, force: true);
    if (!mounted) return;
    setState(() {
      _quiz = quiz;
      if (quiz != null) {
        _answers.clear();
        _answers.addAll(List.filled(quiz.questions.length, null));
      }
      _loading = false;
    });
  }

  void _submitAnswer() {
    final quiz = _quiz;
    if (quiz == null || _selected == null || _answered) return;
    setState(() {
      _answers[_index] = _selected;
      _answered = true;
    });
  }

  Future<void> _finishQuiz() async {
    final quiz = _quiz;
    if (quiz == null || _submitting) return;

    if (!_answered && _selected != null) {
      _answers[_index] = _selected;
    }

    setState(() => _submitting = true);
    final provider = context.read<EducationProvider>();
    final result = await provider.submitQuiz(widget.quizId, _answers);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _result = result ?? _buildLocalResult(quiz);
      _finished = true;
    });
  }

  QuizAttemptResult _buildLocalResult(InvestmentDocQuiz quiz) {
    final results = <QuizQuestionResult>[];
    var score = 0;
    for (var i = 0; i < quiz.questions.length; i++) {
      final q = quiz.questions[i];
      final selected = i < _answers.length ? _answers[i] : null;
      final isCorrect = selected != null && selected == q.correctIndex;
      if (isCorrect) score++;
      results.add(QuizQuestionResult(
        prompt: q.prompt,
        options: q.options,
        selectedIndex: selected,
        correctIndex: q.correctIndex,
        isCorrect: isCorrect,
        explanation: q.explanation,
      ));
    }
    final total = quiz.questions.length;
    return QuizAttemptResult(
      attemptId: '',
      quizSlug: quiz.id,
      quizTitle: quiz.title,
      score: score,
      total: total,
      percent: total == 0 ? 0 : ((score / total) * 100).round(),
      results: results,
    );
  }

  void _next() {
    final quiz = _quiz;
    if (quiz == null) return;
    if (_index >= quiz.questions.length - 1) {
      _finishQuiz();
      return;
    }
    setState(() {
      _index++;
      _selected = _answers[_index];
      _answered = _selected != null;
    });
  }

  void _retry() {
    final quiz = _quiz;
    if (quiz == null) return;
    setState(() {
      _index = 0;
      _selected = null;
      _answered = false;
      _finished = false;
      _result = null;
      _answers.fillRange(0, _answers.length, null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Quiz'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final quiz = _quiz;
    if (quiz == null || quiz.questions.isEmpty) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Quiz'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Quiz not found or has no questions'),
                const SizedBox(height: 16),
                FilledButton(onPressed: _loadQuiz, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    if (_finished && _result != null) {
      return _ResultsView(
        result: _result!,
        onRetry: _retry,
      );
    }

    if (_submitting) {
      return Scaffold(
        appBar: CustomAppBar(title: quiz.title),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final question = quiz.questions[_index];
    final p = context.palette;
    final progress = (_index + 1) / quiz.questions.length;
    final prompt = question.prompt.isNotEmpty ? question.prompt : 'Question ${_index + 1}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(title: quiz.title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: p.borderLight,
              color: ThemeA.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Question ${_index + 1} of ${quiz.questions.length}',
            style: ThemeAType.label(size: 12, color: p.textMuted),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Text(
              prompt,
              style: ThemeAType.sectionTitle(size: 18, color: p.textDark).copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          ...question.options.asMap().entries.map((entry) {
            final i = entry.key;
            final label = entry.value;
            final selected = _selected == i;
            Color? borderColor;
            if (_answered) {
              if (i == question.correctIndex) {
                borderColor = AppColors.green;
              } else if (selected) {
                borderColor = AppColors.error;
              }
            } else if (selected) {
              borderColor = ThemeA.primary;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                onTap: _answered ? null : () => setState(() => _selected = i),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      _answered
                          ? (i == question.correctIndex
                              ? Icons.check_circle_rounded
                              : (selected ? Icons.cancel_rounded : Icons.radio_button_off))
                          : (selected ? Icons.radio_button_checked : Icons.radio_button_off),
                      color: borderColor ?? p.textGrey,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(label, style: ThemeAType.body(color: p.textDark)),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_answered) ...[
            const SizedBox(height: 8),
            PremiumAlertBanner(
              message: question.explanation,
              type: _selected == question.correctIndex
                  ? PremiumAlertType.success
                  : PremiumAlertType.info,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _answered
                ? _next
                : (_selected == null ? null : _submitAnswer),
            child: Text(_answered
                ? (_index >= quiz.questions.length - 1 ? 'Submit & see marks' : 'Next question')
                : 'Check answer'),
          ),
        ],
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  final QuizAttemptResult result;
  final VoidCallback onRetry;

  const _ResultsView({
    required this.result,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final message = result.percent >= 80
        ? 'Excellent — strong grasp of the material!'
        : result.percent >= 50
            ? 'Good effort — re-read weak topics in Documents.'
            : 'Keep learning — start with Beginner guides and retry.';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(title: result.quizTitle),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  result.percent >= 50 ? Icons.emoji_events_outlined : Icons.menu_book_outlined,
                  size: 56,
                  color: ThemeA.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your marks',
                  style: ThemeAType.secondary(size: 13, color: p.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.score} / ${result.total}',
                  style: ThemeAType.sectionTitle(size: 32, color: p.textDark),
                ),
                Text(
                  '${result.percent}%',
                  style: ThemeAType.sectionTitle(color: ThemeA.primary),
                ),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center, style: ThemeAType.body(color: p.textGrey)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Answer review', style: ThemeAType.sectionTitle(color: p.textDark, size: 16)),
          const SizedBox(height: 12),
          ...result.results.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReviewCard(index: idx + 1, item: item),
            );
          }),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('Retry quiz')),
          const SizedBox(height: 10),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Documents')),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final int index;
  final QuizQuestionResult item;

  const _ReviewCard({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final statusColor = item.isCorrect ? AppColors.green : AppColors.error;
    final selectedLabel = item.selectedIndex != null && item.selectedIndex! < item.options.length
        ? item.options[item.selectedIndex!]
        : 'Not answered';
    final correctLabel = item.correctIndex < item.options.length
        ? item.options[item.correctIndex]
        : '—';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.isCorrect ? 'Correct' : 'Wrong',
                  style: ThemeAType.label(size: 10, color: statusColor),
                ),
              ),
              const Spacer(),
              Text('Q$index', style: ThemeAType.label(size: 11, color: p.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.prompt, style: ThemeAType.cardTitle(color: p.textDark, size: 14)),
          const SizedBox(height: 10),
          _AnswerRow(
            label: 'Your answer',
            value: selectedLabel,
            color: item.isCorrect ? AppColors.green : AppColors.error,
          ),
          const SizedBox(height: 6),
          _AnswerRow(
            label: 'Correct answer',
            value: correctLabel,
            color: AppColors.green,
          ),
          if (item.explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.explanation,
              style: ThemeAType.secondary(size: 13, color: p.textGrey).copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnswerRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: ThemeAType.label(size: 12, color: color)),
        ),
        Expanded(
          child: Text(value, style: ThemeAType.body(size: 13)),
        ),
      ],
    );
  }
}
