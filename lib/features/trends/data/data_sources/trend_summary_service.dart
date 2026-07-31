import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/foundation.dart';

import 'package:arteria/env/env.dart';
import 'package:arteria/features/home/data/data_sources/daily_risk_score_service.dart';

/// One-shot trend headline summary for the top of the Trends page.
///
/// Computes structured week-over-week trend facts from the user's
/// Firestore data (BP, medication adherence, symptoms, DRS series), feeds
/// them into a tightly-rule-bound LLM prompt, and returns a one-to-two
/// sentence conversational headline. Results are cached per-day at
/// `users/{uid}/dailyDigest/{yyyy-mm-dd}` so we don't pay the LLM tax on
/// every page view.
class TrendSummaryService {
  TrendSummaryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _openAIModel = 'gpt-4.1-mini-2025-04-14';

  /// How long a cached headline is considered fresh. After this, we
  /// regenerate so the headline reflects newly logged readings.
  static const Duration _cacheTtl = Duration(hours: 12);

  /// Returns a headline + structured deltas, generating one if no fresh
  /// cache exists. Cached per (user, day, language) so switching the
  /// app's locale regenerates a localized headline instead of serving
  /// yesterday's English one. Never throws — on failure (no API key,
  /// no network, insufficient data) returns null and the caller hides
  /// the card.
  Future<TrendSummary?> getSummary({
    required String userId,
    required List<DailyRiskScore> dailySeries,
    String languageCode = 'en',
  }) async {
    try {
      final cached = await _readCache(userId, languageCode);
      if (cached != null && _isFresh(cached.generatedAt)) {
        return cached;
      }

      final facts = await _gatherFacts(userId, dailySeries);
      if (facts == null) return cached; // not enough data; serve stale if any

      final headline =
          await _generateHeadline(facts, languageCode) ??
              _fallbackHeadline(facts, languageCode);

      final summary = TrendSummary(
        headline: headline,
        sbpCurrent: facts.sbpCurrent,
        sbpDelta: facts.sbpDelta,
        dbpCurrent: facts.dbpCurrent,
        dbpDelta: facts.dbpDelta,
        drsCurrent: facts.drsCurrent,
        drsDelta: facts.drsDelta,
        generatedAt: DateTime.now(),
      );

      await _writeCache(userId, summary, languageCode);
      return summary;
    } catch (e) {
      debugPrint('⚠️ TrendSummaryService.getSummary failed: $e');
      return null;
    }
  }

  // ── Cache I/O ──────────────────────────────────────────────────────

  String _todayKey(String languageCode) {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}-$languageCode';
  }

  bool _isFresh(DateTime generatedAt) =>
      DateTime.now().difference(generatedAt) < _cacheTtl;

  Future<TrendSummary?> _readCache(String userId, String languageCode) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailyDigest')
          .doc(_todayKey(languageCode))
          .get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return TrendSummary(
        headline: (data['headline'] as String?) ?? '',
        sbpCurrent: (data['sbpCurrent'] as num?)?.toInt() ?? 0,
        sbpDelta: (data['sbpDelta'] as num?)?.toInt() ?? 0,
        dbpCurrent: (data['dbpCurrent'] as num?)?.toInt() ?? 0,
        dbpDelta: (data['dbpDelta'] as num?)?.toInt() ?? 0,
        drsCurrent: (data['drsCurrent'] as num?)?.toDouble() ?? 0,
        drsDelta: (data['drsDelta'] as num?)?.toDouble() ?? 0,
        generatedAt: (data['generatedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(
    String userId,
    TrendSummary s,
    String languageCode,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailyDigest')
          .doc(_todayKey(languageCode))
          .set({
        'headline': s.headline,
        'sbpCurrent': s.sbpCurrent,
        'sbpDelta': s.sbpDelta,
        'dbpCurrent': s.dbpCurrent,
        'dbpDelta': s.dbpDelta,
        'drsCurrent': s.drsCurrent,
        'drsDelta': s.drsDelta,
        'generatedAt': Timestamp.fromDate(s.generatedAt),
      });
    } catch (e) {
      debugPrint('⚠️ TrendSummaryService cache write failed: $e');
    }
  }

  // ── Fact gathering (the prompt's structured inputs) ────────────────

  Future<_TrendFacts?> _gatherFacts(
    String userId,
    List<DailyRiskScore> dailySeries,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last7Start = today.subtract(const Duration(days: 6));
    final prev7Start = today.subtract(const Duration(days: 13));
    final windowStart = prev7Start;

    final readings = await _fetchReadings(userId, windowStart);
    if (readings.isEmpty) return null;

    final lastWeek = readings.where((r) => !r.date.isBefore(last7Start));
    final prevWeek = readings
        .where((r) => r.date.isBefore(last7Start) && !r.date.isBefore(prev7Start));

    if (lastWeek.isEmpty) return null;

    final sbpCurr = _mean(lastWeek.map((r) => r.systolic.toDouble())).round();
    final dbpCurr = _mean(lastWeek.map((r) => r.diastolic.toDouble())).round();
    final sbpPrev = prevWeek.isEmpty
        ? sbpCurr
        : _mean(prevWeek.map((r) => r.systolic.toDouble())).round();
    final dbpPrev = prevWeek.isEmpty
        ? dbpCurr
        : _mean(prevWeek.map((r) => r.diastolic.toDouble())).round();

    final peakReading = lastWeek
        .reduce((a, b) => a.systolic >= b.systolic ? a : b);

    final amReadings = lastWeek.where((r) => r.date.hour < 12).toList();
    final pmReadings = lastWeek.where((r) => r.date.hour >= 18).toList();

    final drsCurrent = dailySeries.isEmpty ? 0.0 : dailySeries.last.ewma;
    // Compare to ~7 days ago in the EWMA series, or earliest available.
    final drsPriorIdx = dailySeries.length >= 8 ? dailySeries.length - 8 : 0;
    final drsPrior =
        dailySeries.isEmpty ? drsCurrent : dailySeries[drsPriorIdx].ewma;

    final adherence = await _adherenceStats(userId, last7Start);
    final symptoms = await _symptomsInWindow(userId, last7Start);

    return _TrendFacts(
      sbpCurrent: sbpCurr,
      dbpCurrent: dbpCurr,
      sbpDelta: sbpCurr - sbpPrev,
      dbpDelta: dbpCurr - dbpPrev,
      sbpPeak: peakReading.systolic,
      peakDate: peakReading.date,
      amSbp: amReadings.isEmpty
          ? null
          : _mean(amReadings.map((r) => r.systolic.toDouble())).round(),
      amDbp: amReadings.isEmpty
          ? null
          : _mean(amReadings.map((r) => r.diastolic.toDouble())).round(),
      pmSbp: pmReadings.isEmpty
          ? null
          : _mean(pmReadings.map((r) => r.systolic.toDouble())).round(),
      pmDbp: pmReadings.isEmpty
          ? null
          : _mean(pmReadings.map((r) => r.diastolic.toDouble())).round(),
      drsCurrent: drsCurrent,
      drsDelta: drsCurrent - drsPrior,
      adherencePct: adherence.pct,
      missedDoses: adherence.missed,
      hasMeds: adherence.hasMeds,
      symptoms: symptoms,
    );
  }

  Future<List<_RawReading>> _fetchReadings(String userId, DateTime since) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('readings')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('date')
        .get();
    return snap.docs
        .map((d) {
          final data = d.data();
          final ts = (data['date'] as Timestamp?)?.toDate();
          final sys = (data['systolic'] as num?)?.toInt();
          final dia = (data['diastolic'] as num?)?.toInt();
          if (ts == null || sys == null || dia == null) return null;
          return _RawReading(date: ts, systolic: sys, diastolic: dia);
        })
        .whereType<_RawReading>()
        .toList();
  }

  Future<({double pct, int missed, bool hasMeds})> _adherenceStats(
    String userId,
    DateTime since,
  ) async {
    try {
      final medsSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .where('isActive', isEqualTo: true)
          .get();
      int dosesPerDay = 0;
      for (final m in medsSnap.docs) {
        final freq = (m.data()['frequency'] as String?) ?? 'onceDaily';
        dosesPerDay += _dosesPerDay(freq);
      }
      const windowDays = 7;
      final prescribed = dosesPerDay * windowDays;
      // No active medications → no adherence concept. Signal this so the
      // headline never claims "perfect adherence" for a user with no meds.
      if (prescribed == 0) return (pct: 100.0, missed: 0, hasMeds: false);

      final logsSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicationLogs')
          .get();
      int taken = 0;
      for (final doc in logsSnap.docs) {
        final data = doc.data();
        final raw = data['takenAt'];
        DateTime? ts;
        if (raw is Timestamp) ts = raw.toDate();
        if (raw is String) ts = DateTime.tryParse(raw);
        if (ts == null || ts.isBefore(since)) continue;
        if (data['skipped'] == true) continue;
        taken++;
      }
      final missed = (prescribed - taken).clamp(0, prescribed);
      return (pct: (taken / prescribed) * 100, missed: missed, hasMeds: true);
    } catch (_) {
      // On error we can't prove meds exist — treat as none so we stay silent
      // about medication rather than fabricating an adherence claim.
      return (pct: 0.0, missed: 0, hasMeds: false);
    }
  }

  int _dosesPerDay(String frequency) => switch (frequency) {
        'twiceDaily' => 2,
        'threeTimesDaily' => 3,
        'weekly' || 'asNeeded' => 0,
        _ => 1,
      };

  Future<List<String>> _symptomsInWindow(String userId, DateTime since) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('symptoms')
          .where('loggedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get();
      return snap.docs
          .map((d) => (d.data()['name'] as String?)?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  double _mean(Iterable<double> xs) {
    var sum = 0.0;
    var n = 0;
    for (final x in xs) {
      sum += x;
      n++;
    }
    return n == 0 ? 0 : sum / n;
  }

  // ── LLM call ───────────────────────────────────────────────────────

  Future<String?> _generateHeadline(
    _TrendFacts f,
    String languageCode,
  ) async {
    final key = Env.openaiApiKey;
    if (key.isEmpty) return null;
    OpenAI.apiKey = key;

    final languageName = _languageName(languageCode);
    final systemPrompt = '''
You are a hypertension health coach summarizing a patient's trends.
Write ONE conversational sentence (max 2). Rules:
- Write the ENTIRE response in $languageName. Do not mix languages.
- Lead with the most clinically meaningful change.
- Quote one specific number with its delta (e.g., "dropped 3 mmHg").
- If there is a behavioral correlate (medication, symptom, time-of-day),
  name it — that is what makes it actionable.
- Only mention medication, adherence, or doses if the inputs contain
  medication data. If the medication line says none is tracked, do NOT
  mention medication, adherence, doses, or "perfect"/"missed" anything.
- No greetings, no medical advice, no hedging ("might", "may want to").
- Tone: a knowledgeable friend, not a doctor's note.
- Never invent data not in the inputs.
Return JSON: {"headline": "..."}
''';

    final userPrompt = f.toPromptBlock();

    try {
      final completion = await OpenAI.instance.chat.create(
        model: _openAIModel,
        responseFormat: const {'type': 'json_object'},
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                systemPrompt,
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(userPrompt),
            ],
          ),
        ],
      );
      final text = completion.choices.first.message.content?.first.text;
      if (text == null || text.isEmpty) return null;
      final parsed = jsonDecode(text) as Map<String, dynamic>;
      final headline = parsed['headline']?.toString().trim();
      return (headline == null || headline.isEmpty) ? null : headline;
    } catch (e) {
      debugPrint('⚠️ OpenAI trend summary failed: $e');
      return null;
    }
  }

  /// Templated fallback used when the LLM is unreachable. Localized so a
  /// French user never sees an English fallback when the API is down.
  String _fallbackHeadline(_TrendFacts f, String languageCode) {
    if (languageCode == 'fr') {
      // Only append the medication clause when the user actually has meds.
      final medClause = f.hasMeds
          ? ', avec ${f.missedDoses} doses manquées enregistrées'
          : '';
      if (f.sbpDelta == 0) {
        return 'Votre tension systolique est restée stable cette semaine à '
            '${f.sbpCurrent} mmHg$medClause.';
      }
      if (f.sbpDelta < 0) {
        return 'Votre tension systolique a baissé de ${-f.sbpDelta} mmHg cette '
            'semaine à ${f.sbpCurrent}$medClause.';
      }
      return 'Votre tension systolique a augmenté de ${f.sbpDelta} mmHg cette '
          'semaine à ${f.sbpCurrent}$medClause.';
    }
    final dir = f.sbpDelta == 0
        ? 'held steady'
        : (f.sbpDelta < 0 ? 'dropped ${-f.sbpDelta}' : 'rose ${f.sbpDelta}');
    final medClause =
        f.hasMeds ? ', with ${f.missedDoses} missed doses logged' : '';
    return 'Your systolic average $dir mmHg this week to ${f.sbpCurrent}'
        '$medClause.';
  }

  String _languageName(String code) =>
      switch (code) { 'fr' => 'French', _ => 'English' };
}

// ── Public types ────────────────────────────────────────────────────

class TrendSummary {
  const TrendSummary({
    required this.headline,
    required this.sbpCurrent,
    required this.sbpDelta,
    required this.dbpCurrent,
    required this.dbpDelta,
    required this.drsCurrent,
    required this.drsDelta,
    required this.generatedAt,
  });

  final String headline;
  final int sbpCurrent;
  final int sbpDelta;
  final int dbpCurrent;
  final int dbpDelta;
  final double drsCurrent;
  final double drsDelta;
  final DateTime generatedAt;
}

// ── Private types ──────────────────────────────────────────────────

class _RawReading {
  const _RawReading({
    required this.date,
    required this.systolic,
    required this.diastolic,
  });
  final DateTime date;
  final int systolic;
  final int diastolic;
}

class _TrendFacts {
  const _TrendFacts({
    required this.sbpCurrent,
    required this.dbpCurrent,
    required this.sbpDelta,
    required this.dbpDelta,
    required this.sbpPeak,
    required this.peakDate,
    required this.amSbp,
    required this.amDbp,
    required this.pmSbp,
    required this.pmDbp,
    required this.drsCurrent,
    required this.drsDelta,
    required this.adherencePct,
    required this.missedDoses,
    required this.hasMeds,
    required this.symptoms,
  });

  final int sbpCurrent;
  final int dbpCurrent;
  final int sbpDelta;
  final int dbpDelta;
  final int sbpPeak;
  final DateTime peakDate;
  final int? amSbp;
  final int? amDbp;
  final int? pmSbp;
  final int? pmDbp;
  final double drsCurrent;
  final double drsDelta;
  final double adherencePct;
  final int missedDoses;
  final bool hasMeds;
  final List<String> symptoms;

  String toPromptBlock() {
    String sign(num n) => n >= 0 ? '+$n' : '$n';
    final peakDayLabel = '${peakDate.year}-'
        '${peakDate.month.toString().padLeft(2, '0')}-'
        '${peakDate.day.toString().padLeft(2, '0')}';
    final peakTimeLabel = '${peakDate.hour.toString().padLeft(2, '0')}:'
        '${peakDate.minute.toString().padLeft(2, '0')}';
    final amBlock = (amSbp == null || amDbp == null)
        ? 'morning avg: insufficient data'
        : 'morning avg: $amSbp/$amDbp';
    final pmBlock = (pmSbp == null || pmDbp == null)
        ? 'evening avg: insufficient data'
        : 'evening avg: $pmSbp/$pmDbp';
    final symptomList = symptoms.isEmpty ? 'none' : symptoms.join(', ');
    final medBlock = hasMeds
        ? 'Medication: ${adherencePct.round()}% adherence, $missedDoses missed.'
        : 'Medication: none tracked — DO NOT mention medication, adherence, '
            'or doses in the summary.';

    return '''
Patient trend window: last 7 days vs. previous 7 days.

BP:
- Avg SBP: $sbpCurrent mmHg (Δ ${sign(sbpDelta)} vs prior week)
- Avg DBP: $dbpCurrent mmHg (Δ ${sign(dbpDelta)} vs prior week)
- Peak SBP: $sbpPeak on $peakDayLabel ($peakTimeLabel)
- $amBlock vs $pmBlock

Risk score (EWMA): ${drsCurrent.toStringAsFixed(1)} '
'(Δ ${sign(double.parse(drsDelta.toStringAsFixed(1)))})

$medBlock

Symptoms logged: $symptomList

Write the summary now.
''';
  }
}
