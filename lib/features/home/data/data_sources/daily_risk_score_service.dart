import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Daily Risk Score (DRS) service.
///
/// Produces a per-day, 0–100 weighted risk index from the user's actual
/// logged inputs (BP readings, medication adherence, symptoms, lifestyle),
/// then smooths the series with an exponentially-weighted moving average
/// (EWMA). The DRS shifts day-over-day in response to new data; the EWMA
/// gives the trend curve enough inertia that a single outlier reading does
/// not whipsaw the projection downstream.
///
/// Component weights:
///   BP        50%   — the day's worst reading (safety bias)
///   Symptom   20%   — sum of severity scores, capped at 100
///   Adherence 20%   — missed/prescribed doses ratio
///   Lifestyle 10%   — placeholder for sleep/stress/sodium when added
class DailyRiskScoreService {
  DailyRiskScoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const double _wBp = 0.50;
  static const double _wSymptom = 0.20;
  static const double _wAdherence = 0.20;
  static const double _wLifestyle = 0.10;

  /// EWMA smoothing factor. α≈0.30 ⇒ effective window ≈ 7 days. Lower α =
  /// smoother but slower to react; higher α = more responsive but noisier.
  static const double _ewmaAlpha = 0.30;

  /// Compute the daily risk score series for the last [days] days.
  ///
  /// Only days that have ANY input (a reading, a medication log, or a
  /// symptom entry) get a DRS — we never fabricate data. Days with input
  /// but missing components fall back to neutral defaults for those
  /// components (documented per helper below). The EWMA chains across the
  /// produced points in chronological order.
  Future<List<DailyRiskScore>> getDailySeries({
    required String userId,
    int days = 14,
  }) async {
    final now = DateTime.now();
    final startOfWindow = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));

    try {
      final readingsByDay = await _fetchReadingsByDay(userId, startOfWindow);
      final symptomsByDay = await _fetchSymptomsByDay(userId, startOfWindow);
      final medLogsByDay = await _fetchMedLogsByDay(userId, startOfWindow);
      final dailyExpectedDoses = await _fetchDailyExpectedDoses(userId);

      // Union of days that have any input — we score only those.
      final activeDays = <DateTime>{
        ...readingsByDay.keys,
        ...symptomsByDay.keys,
        ...medLogsByDay.keys,
      }.toList()
        ..sort();

      final raw = <DailyRiskScore>[];
      for (final day in activeDays) {
        final components = DrsComponents(
          bp: _bpComponent(readingsByDay[day] ?? const []),
          symptom: _symptomComponent(symptomsByDay[day] ?? const []),
          adherence: _adherenceComponent(
            takenLogs: medLogsByDay[day] ?? const [],
            prescribedDoses: dailyExpectedDoses,
            isToday: _isSameDay(day, now),
            now: now,
          ),
          lifestyle: _lifestyleComponent(),
        );

        final drs = (_wBp * components.bp +
                _wSymptom * components.symptom +
                _wAdherence * components.adherence +
                _wLifestyle * components.lifestyle)
            .clamp(0.0, 100.0);

        raw.add(
          DailyRiskScore(
            date: day,
            drs: drs,
            ewma: drs, // placeholder, overwritten below
            band: _bandFor(drs),
            components: components,
          ),
        );
      }

      return _applyEwma(raw);
    } catch (e) {
      debugPrint('⚠️ DailyRiskScoreService.getDailySeries failed: $e');
      return const [];
    }
  }

  // ── Component calculators ──────────────────────────────────────────

  /// BP component — uses the day's worst reading (max severity across
  /// systolic and diastolic) so a single dangerous spike is not averaged
  /// away by surrounding normal readings. SBP severity scales 110→180,
  /// DBP scales 70→110.
  ///
  /// Returns 0 if no readings (treated as missing, not "felt great"). The
  /// adherence/symptom signals can still produce a non-zero DRS that day.
  double _bpComponent(List<_Reading> readings) {
    if (readings.isEmpty) return 0.0;
    double worst = 0;
    for (final r in readings) {
      final sbp = ((r.systolic - 110) / (180 - 110)) * 100;
      final dbp = ((r.diastolic - 70) / (110 - 70)) * 100;
      final point = math.max(sbp, dbp).clamp(0.0, 100.0);
      if (point > worst) worst = point;
    }
    return worst;
  }

  /// Symptom component — sum of per-symptom severity points, capped at
  /// 100. Names are matched case-insensitively against [_symptomSeverity];
  /// unknown symptoms contribute a small default (10) so the user is still
  /// credited for logging something.
  double _symptomComponent(List<_Symptom> symptoms) {
    if (symptoms.isEmpty) return 0.0;
    double total = 0;
    for (final s in symptoms) {
      total += _symptomSeverity[s.name.trim().toLowerCase()] ?? 10.0;
    }
    return total.clamp(0.0, 100.0);
  }

  static const Map<String, double> _symptomSeverity = {
    'headache': 15,
    'dizziness': 25,
    'chest pain': 60,
    'blurred vision': 40,
    'palpitations': 30,
    'shortness of breath': 35,
    'nausea': 15,
    'fatigue': 10,
  };

  /// Adherence component — fraction of prescribed doses NOT taken,
  /// expressed 0–100. Past days use the full prescribed schedule; today
  /// only counts doses whose scheduled time has already passed (so the
  /// user isn't penalized for an 8pm dose at 2pm).
  ///
  /// Returns 0 if nothing is prescribed (no penalty for users with no
  /// active meds).
  double _adherenceComponent({
    required List<_MedLog> takenLogs,
    required int prescribedDoses,
    required bool isToday,
    required DateTime now,
  }) {
    if (prescribedDoses == 0) return 0.0;
    // Simple proxy for "doses due so far today": linear by hour of day.
    // Good enough for a 0–100 weighted index; exact per-schedule logic can
    // come later if we start carrying medication schedules into this service.
    final due = isToday
        ? math.max(1, (prescribedDoses * (now.hour / 24)).round())
        : prescribedDoses;
    final taken = takenLogs.where((l) => !l.skipped).length;
    final missed = (due - taken).clamp(0, due);
    return (missed / due) * 100;
  }

  /// Lifestyle component — neutral baseline (50) until we wire up sodium,
  /// sleep, stress signals. Kept as its own component so the weight is
  /// already reserved and adding the real signal later doesn't shift the
  /// historical curve.
  double _lifestyleComponent() => 50.0;

  // ── EWMA smoothing ─────────────────────────────────────────────────

  /// Apply exponentially-weighted moving average to the raw daily series.
  /// The first point seeds itself; each subsequent point blends 30% of the
  /// new DRS with 70% of the previous smoothed value.
  List<DailyRiskScore> _applyEwma(List<DailyRiskScore> raw) {
    if (raw.isEmpty) return raw;
    final out = <DailyRiskScore>[];
    double prev = raw.first.drs;
    out.add(raw.first.copyWith(ewma: prev));
    for (int i = 1; i < raw.length; i++) {
      final smoothed = _ewmaAlpha * raw[i].drs + (1 - _ewmaAlpha) * prev;
      out.add(raw[i].copyWith(ewma: smoothed));
      prev = smoothed;
    }
    return out;
  }

  RiskBand _bandFor(double score) {
    if (score < 30) return RiskBand.green;
    if (score < 60) return RiskBand.amber;
    if (score < 80) return RiskBand.orange;
    return RiskBand.red;
  }

  // ── Firestore fetches (one query per collection, grouped client-side) ─

  Future<Map<DateTime, List<_Reading>>> _fetchReadingsByDay(
    String userId,
    DateTime since,
  ) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('readings')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('date')
        .get();

    final out = <DateTime, List<_Reading>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final ts = (data['date'] as Timestamp?)?.toDate();
      final sys = (data['systolic'] as num?)?.toInt();
      final dia = (data['diastolic'] as num?)?.toInt();
      if (ts == null || sys == null || dia == null) continue;
      final day = DateTime(ts.year, ts.month, ts.day);
      (out[day] ??= []).add(_Reading(systolic: sys, diastolic: dia));
    }
    return out;
  }

  /// Reads from `users/{uid}/symptoms` if the collection exists. Schema
  /// expected: `{name: String, loggedAt: Timestamp}`. Returns an empty map
  /// (not an error) if the collection is missing or unreadable — symptom
  /// logging is optional in the current app, and the DRS degrades
  /// gracefully without it.
  Future<Map<DateTime, List<_Symptom>>> _fetchSymptomsByDay(
    String userId,
    DateTime since,
  ) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('symptoms')
          .where('loggedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('loggedAt')
          .get();

      final out = <DateTime, List<_Symptom>>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = (data['loggedAt'] as Timestamp?)?.toDate();
        final name = (data['name'] as String?)?.trim();
        if (ts == null || name == null || name.isEmpty) continue;
        final day = DateTime(ts.year, ts.month, ts.day);
        (out[day] ??= []).add(_Symptom(name: name));
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  Future<Map<DateTime, List<_MedLog>>> _fetchMedLogsByDay(
    String userId,
    DateTime since,
  ) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('medicationLogs')
        .get();

    final out = <DateTime, List<_MedLog>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final takenAtRaw = data['takenAt'];
      DateTime? ts;
      if (takenAtRaw is Timestamp) {
        ts = takenAtRaw.toDate();
      } else if (takenAtRaw is String) {
        ts = DateTime.tryParse(takenAtRaw);
      }
      if (ts == null || ts.isBefore(since)) continue;
      final day = DateTime(ts.year, ts.month, ts.day);
      (out[day] ??= []).add(_MedLog(skipped: data['skipped'] == true));
    }
    return out;
  }

  /// Total doses prescribed per day from currently-active medications.
  /// This is a snapshot of "what should be taken today" — past days assume
  /// the same schedule since we don't store activation history.
  Future<int> _fetchDailyExpectedDoses(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('medications')
        .where('isActive', isEqualTo: true)
        .get();

    int total = 0;
    for (final doc in snap.docs) {
      final freq = (doc.data()['frequency'] as String?) ?? 'onceDaily';
      total += _dosesPerDayFor(freq);
    }
    return total;
  }

  int _dosesPerDayFor(String frequency) {
    switch (frequency) {
      case 'twiceDaily':
        return 2;
      case 'threeTimesDaily':
        return 3;
      case 'weekly':
      case 'asNeeded':
        return 0;
      case 'onceDaily':
      default:
        return 1;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Public types ────────────────────────────────────────────────────

enum RiskBand { green, amber, orange, red }

class DrsComponents {
  const DrsComponents({
    required this.bp,
    required this.symptom,
    required this.adherence,
    required this.lifestyle,
  });

  final double bp;
  final double symptom;
  final double adherence;
  final double lifestyle;
}

class DailyRiskScore {
  const DailyRiskScore({
    required this.date,
    required this.drs,
    required this.ewma,
    required this.band,
    required this.components,
  });

  /// Midnight of the calendar day this score covers.
  final DateTime date;

  /// Raw weighted score for the day, 0–100.
  final double drs;

  /// Exponentially-smoothed score for trend display / regression input.
  final double ewma;

  /// Clinical band of the smoothed score — drives chart color and UI copy.
  final RiskBand band;

  /// Per-component breakdown, useful for tooltips, the LLM TL;DR prompt,
  /// and debugging the weighting.
  final DrsComponents components;

  DailyRiskScore copyWith({double? ewma}) => DailyRiskScore(
        date: date,
        drs: drs,
        ewma: ewma ?? this.ewma,
        band: band,
        components: components,
      );
}

// ── Private input records ──────────────────────────────────────────

class _Reading {
  const _Reading({required this.systolic, required this.diastolic});
  final int systolic;
  final int diastolic;
}

class _Symptom {
  const _Symptom({required this.name});
  final String name;
}

class _MedLog {
  const _MedLog({required this.skipped});
  final bool skipped;
}
