// ignore_for_file: avoid_print
//
// Walk-forward (rolling-origin) backtest for the Predictive Timeline forecast.
//
// This script mirrors the OLS + prediction-interval math used by `_forecast`
// in lib/features/trends/presentation/widgets/predictive_timeline.dart and
// evaluates it on reproducible synthetic risk-score series so the viva can
// quote concrete numbers instead of "I think it's reliable".
//
// The trend line is fit on the EWMA-smoothed series (stable slope), exactly
// like the widget. We compare three ways of sizing the 95% prediction band,
// scored by COVERAGE against the real future *raw* daily value — the honest
// test, because the band claims to bound where an actual day could land:
//
//   1. EWMA residuals + Normal z=1.96   (the original code)
//   2. EWMA residuals + Student-t       (the t-fix)
//   3. RAW residuals  + Student-t       (the raw-residual improvement)
//
// A well-calibrated 95% band should cover ~95% of held-out raw observations.
// MAE/RMSE measure the trend forecast against the future EWMA value (the point
// forecast is identical across all three band variants).
//
// Run with:   dart run tool/forecast_backtest.dart
// (Pure dart:math, no Flutter/pub dependencies.)

import 'dart:math' as math;

// ── Config (kept in sync with the widget) ────────────────────────────
const int minHistory = 7; // _minHistoryForProjection
const int maxHorizon = 7; // _forecastDays
const double ewmaAlpha = 0.30; // DailyRiskScoreService._ewmaAlpha

const int numSeries = 500;
const int daysPerSeries = 21;
const int seed = 42;

// ── Student-t 95% critical values (same table as the widget) ─────────
const Map<int, double> tTable = {
  1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571,
  6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262, 10: 2.228,
  11: 2.201, 12: 2.179, 13: 2.160, 14: 2.145, 15: 2.131,
  16: 2.120, 17: 2.110, 18: 2.101, 19: 2.093, 20: 2.086,
  21: 2.080, 22: 2.074, 23: 2.069, 24: 2.064, 25: 2.060,
  26: 2.056, 27: 2.052, 28: 2.048, 29: 2.045, 30: 2.042,
};

double tCritical95(int df) => df < 1 ? 1.96 : (tTable[df] ?? 1.96);
double normalCritical95(int df) => 1.96;

/// An OLS fit on the EWMA series, carrying both the EWMA- and raw-residual
/// standard errors so we can size each band variant from the same fit.
class Fit {
  Fit({
    required this.n,
    required this.slope,
    required this.intercept,
    required this.xMean,
    required this.sxx,
    required this.rseEwma,
    required this.rseRaw,
  });

  final int n;
  final double slope;
  final double intercept;
  final double xMean;
  final double sxx;
  final double rseEwma; // residual SE from smoothed values
  final double rseRaw; // residual SE from raw values

  /// Unclamped point forecast `step` days past the last observation.
  double yHat(int step) => intercept + slope * ((n - 1) + step);

  /// Half-width of the 95% prediction interval for the given residual SE and
  /// critical-value function — identical formula to the widget.
  double halfWidth(int step, double rse, double Function(int) crit) {
    final xF = (n - 1).toDouble() + step;
    final se = rse *
        math.sqrt(1 + 1 / n + ((xF - xMean) * (xF - xMean)) / math.max(1e-9, sxx));
    return crit(n - 2) * se;
  }
}

/// Fit the trend on `ewma`, but also measure residuals against `raw`.
Fit fitSeries(List<double> ewma, List<double> raw) {
  final n = ewma.length;
  final xs = List.generate(n, (i) => i.toDouble());
  final xMean = xs.reduce((a, b) => a + b) / n;
  final yMean = ewma.reduce((a, b) => a + b) / n;

  double sxy = 0, sxx = 0;
  for (int i = 0; i < n; i++) {
    sxy += (xs[i] - xMean) * (ewma[i] - yMean);
    sxx += (xs[i] - xMean) * (xs[i] - xMean);
  }
  final slope = sxx == 0 ? 0.0 : sxy / sxx;
  final intercept = yMean - slope * xMean;

  double ssEwma = 0, ssRaw = 0;
  for (int i = 0; i < n; i++) {
    final line = intercept + slope * xs[i];
    ssEwma += (ewma[i] - line) * (ewma[i] - line);
    ssRaw += (raw[i] - line) * (raw[i] - line);
  }
  final denom = math.max(1, n - 2);

  return Fit(
    n: n,
    slope: slope,
    intercept: intercept,
    xMean: xMean,
    sxx: sxx,
    rseEwma: math.sqrt(ssEwma / denom),
    rseRaw: math.sqrt(ssRaw / denom),
  );
}

/// Standard Normal sample via Box–Muller.
double gauss(math.Random r) {
  final u1 = r.nextDouble().clamp(1e-9, 1.0);
  final u2 = r.nextDouble();
  return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
}

/// Synthetic series: a random linear trend plus Gaussian noise. Returns the
/// raw daily DRS and the EWMA-smoothed version (what the widget regresses on).
({List<double> raw, List<double> ewma}) generateSeries(
  math.Random r,
  int days,
) {
  final baseline = 30 + r.nextDouble() * 30; // 30..60
  final slope = (r.nextDouble() * 2 - 1) * 1.5; // -1.5..+1.5 per day
  final noiseSd = 4 + r.nextDouble() * 6; // 4..10

  final raw = <double>[];
  for (int i = 0; i < days; i++) {
    raw.add((baseline + slope * i + gauss(r) * noiseSd).clamp(0.0, 100.0));
  }

  final ewma = <double>[];
  double prev = raw.first;
  ewma.add(prev);
  for (int i = 1; i < raw.length; i++) {
    prev = ewmaAlpha * raw[i] + (1 - ewmaAlpha) * prev;
    ewma.add(prev);
  }
  return (raw: raw, ewma: ewma);
}

bool covers(double yHat, double half, double actual) {
  final lower = (yHat - half).clamp(0.0, 100.0);
  final upper = (yHat + half).clamp(0.0, 100.0);
  return actual >= lower && actual <= upper;
}

class HorizonStats {
  int count = 0;
  double absErr = 0;
  double sqErr = 0;
  int covEwmaZ = 0; // variant 1: EWMA residuals + z
  int covEwmaT = 0; // variant 2: EWMA residuals + t
  int covRawT = 0; // variant 3: raw residuals + t
}

void main() {
  final r = math.Random(seed);
  final stats = List.generate(maxHorizon + 1, (_) => HorizonStats());

  for (int s = 0; s < numSeries; s++) {
    final series = generateSeries(r, daysPerSeries);
    final n = series.raw.length;

    // Rolling origin: fit on [0..origin], predict the following days.
    for (int origin = minHistory - 1; origin < n - 1; origin++) {
      final histEwma = series.ewma.sublist(0, origin + 1);
      final histRaw = series.raw.sublist(0, origin + 1);
      final fit = fitSeries(histEwma, histRaw);

      for (int step = 1; step <= maxHorizon; step++) {
        final idx = origin + step;
        if (idx >= n) break;

        final actualRaw = series.raw[idx]; // the real future day
        final actualEwma = series.ewma[idx]; // the smoothed trend target
        final yHat = fit.yHat(step);

        final st = stats[step];
        st.count++;

        // Point-forecast error is scored against the trend (EWMA) target.
        final err = (yHat - actualEwma).abs();
        st.absErr += err;
        st.sqErr += err * err;

        // Coverage is scored against the REAL future raw observation.
        final halfEwmaZ = fit.halfWidth(step, fit.rseEwma, normalCritical95);
        final halfEwmaT = fit.halfWidth(step, fit.rseEwma, tCritical95);
        final halfRawT = fit.halfWidth(step, fit.rseRaw, tCritical95);
        if (covers(yHat, halfEwmaZ, actualRaw)) st.covEwmaZ++;
        if (covers(yHat, halfEwmaT, actualRaw)) st.covEwmaT++;
        if (covers(yHat, halfRawT, actualRaw)) st.covRawT++;
      }
    }
  }

  // ── Report ─────────────────────────────────────────────────────────
  print('Predictive Timeline — walk-forward backtest');
  print('  series=$numSeries  days/series=$daysPerSeries  '
      'minHistory=$minHistory  seed=$seed');
  print('  Trend fit on EWMA; coverage scored vs the real future RAW day.');
  print('  MAE/RMSE vs EWMA trend, in DRS points (0–100). Target = 95%.\n');

  print('  h | n      |  MAE  | RMSE  | cov EWMA·z | cov EWMA·t | cov RAW·t');
  print('  --+--------+-------+-------+------------+------------+----------');

  int totN = 0, totEz = 0, totEt = 0, totRt = 0;
  double totAbs = 0, totSq = 0;
  for (int h = 1; h <= maxHorizon; h++) {
    final st = stats[h];
    if (st.count == 0) continue;
    final mae = st.absErr / st.count;
    final rmse = math.sqrt(st.sqErr / st.count);
    String pct(int c) => '${(100 * c / st.count).toStringAsFixed(1)}%';
    print('  $h | ${st.count.toString().padLeft(6)} | '
        '${mae.toStringAsFixed(2).padLeft(5)} | '
        '${rmse.toStringAsFixed(2).padLeft(5)} | '
        '${pct(st.covEwmaZ).padLeft(10)} | '
        '${pct(st.covEwmaT).padLeft(10)} | '
        '${pct(st.covRawT).padLeft(8)}');
    totN += st.count;
    totEz += st.covEwmaZ;
    totEt += st.covEwmaT;
    totRt += st.covRawT;
    totAbs += st.absErr;
    totSq += st.sqErr;
  }

  String tot(int c) => '${(100 * c / totN).toStringAsFixed(1)}%';
  print('  --+--------+-------+-------+------------+------------+----------');
  print('  Σ | ${totN.toString().padLeft(6)} | '
      '${(totAbs / totN).toStringAsFixed(2).padLeft(5)} | '
      '${math.sqrt(totSq / totN).toStringAsFixed(2).padLeft(5)} | '
      '${tot(totEz).padLeft(10)} | '
      '${tot(totEt).padLeft(10)} | '
      '${tot(totRt).padLeft(8)}');

  print('\nReading this:');
  print('  • MAE = typical 1–7 day trend-forecast error in risk points.');
  print('  • Coverage = % of real future days that fell inside the 95% band.');
  print('    EWMA·z (old) under-covers badly; the t-fix helps; sizing the band');
  print('    from RAW residuals lands it closest to the 95% target.');
}
