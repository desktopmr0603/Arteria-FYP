import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;

import 'whatif_bloc.dart';
import 'whatif_event.dart';
import 'whatif_state.dart';
import 'bp_predictor_service.dart';

class WhatIfScreen extends StatelessWidget {
  final Map<String, dynamic> userProfile;

  const WhatIfScreen({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          WhatIfBloc(predictorService: BPPredictorService())
            ..add(InitializeWhatIf(userProfile: userProfile)),
      child: const _WhatIfScreenContent(),
    );
  }
}

class _WhatIfScreenContent extends StatelessWidget {
  const _WhatIfScreenContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0E21)
          : const Color(0xFFF5F7FA),
      body: BlocBuilder<WhatIfBloc, WhatIfState>(
        builder: (context, state) {
          if (state.status == WhatIfStatus.loading) {
            return const _LoadingView();
          }

          if (state.status == WhatIfStatus.error) {
            return _ErrorView(message: state.errorMessage ?? 'Unknown error');
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'What If?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.read<WhatIfBloc>().add(
                        const ResetModifications(),
                      );
                    },
                  ),
                ],
              ),

              // Risk Comparison Card
              SliverToBoxAdapter(
                child: _RiskComparisonCard(state: state, isDark: isDark),
              ),

              // Scenario Cards
              SliverToBoxAdapter(
                child: _ScenarioCardsSection(state: state, isDark: isDark),
              ),

              // Interactive Sliders
              SliverToBoxAdapter(
                child: _SlidersSection(state: state, isDark: isDark),
              ),

              // Projection Results
              if (state.projection != null)
                SliverToBoxAdapter(
                  child: _ProjectionCard(
                    projection: state.projection!,
                    isDark: isDark,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(height: 16),
          Text(
            'Loading AI Model...',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Unable to Load',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated risk comparison with dual gauge
class _RiskComparisonCard extends StatelessWidget {
  final WhatIfState state;
  final bool isDark;

  const _RiskComparisonCard({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1F36), const Color(0xFF0E1225)]
              : [Colors.white, const Color(0xFFF8F9FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.blueGrey).withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RiskGauge(
                label: 'Current',
                risk: state.baselineRisk,
                riskLevel: state.baselineRiskLevel,
                isDark: isDark,
              ),
              Container(
                width: 1,
                height: 80,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
              ),
              _RiskGauge(
                label: 'Projected',
                risk: state.projectedRisk,
                riskLevel: state.projectedRiskLevel,
                isDark: isDark,
                isProjected: true,
              ),
            ],
          ),
          if (state.riskReduction > 0) ...[
            const SizedBox(height: 20),
            _ImprovementBadge(
              reduction: state.riskReduction,
              improvement: state.relativeImprovement,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

class _RiskGauge extends StatelessWidget {
  final String label;
  final double risk;
  final String riskLevel;
  final bool isDark;
  final bool isProjected;

  const _RiskGauge({
    required this.label,
    required this.risk,
    required this.riskLevel,
    required this.isDark,
    this.isProjected = false,
  });

  Color get _riskColor {
    if (risk < 0.3) return const Color(0xFF4CAF50);
    if (risk < 0.6) return const Color(0xFFFFA726);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : Colors.black54,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 100,
          height: 100,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: risk),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return CustomPaint(
                painter: _RiskGaugePainter(
                  progress: value,
                  color: _riskColor,
                  isDark: isDark,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(value * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        riskLevel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _riskColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RiskGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _RiskGaugePainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background arc
    final bgPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.6), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RiskGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _ImprovementBadge extends StatelessWidget {
  final double reduction;
  final double improvement;
  final bool isDark;

  const _ImprovementBadge({
    required this.reduction,
    required this.improvement,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.2),
            const Color(0xFF00BCD4).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_down, color: Color(0xFF4CAF50), size: 20),
          const SizedBox(width: 8),
          Text(
            '${improvement.toStringAsFixed(1)}% potential improvement',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF4CAF50),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal scrolling scenario cards
class _ScenarioCardsSection extends StatelessWidget {
  final WhatIfState state;
  final bool isDark;

  const _ScenarioCardsSection({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            'Quick Scenarios',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.availableScenarios.length,
            itemBuilder: (context, index) {
              final scenario = state.availableScenarios[index];
              final isSelected = state.selectedScenarioId == scenario.id;

              return _ScenarioCard(
                scenario: scenario,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.read<WhatIfBloc>().add(
                    SelectScenario(scenarioId: scenario.id),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final WhatIfScenario scenario;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ScenarioCard({
    required this.scenario,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        width: 140,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? const Color(0xFF1A1F36) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? Colors.white12 : Colors.grey.shade200),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(scenario.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                scenario.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${scenario.expectedBpChange.toInt()} mmHg',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white70
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive sliders section
class _SlidersSection extends StatelessWidget {
  final WhatIfState state;
  final bool isDark;

  const _SlidersSection({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fine-Tune Your Plan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...state.sliderConfigs.map(
            (config) => _LifestyleSlider(
              config: config,
              currentValue:
                  state.modifications[config.feature] ?? config.defaultValue,
              isDark: isDark,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                context.read<WhatIfBloc>().add(
                  UpdateSlider(feature: config.feature, value: value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LifestyleSlider extends StatelessWidget {
  final SliderConfig config;
  final double currentValue;
  final bool isDark;
  final ValueChanged<double> onChanged;

  const _LifestyleSlider({
    required this.config,
    required this.currentValue,
    required this.isDark,
    required this.onChanged,
  });

  String get _valueLabel {
    if (config.isReduction) {
      return '${(currentValue * 100).toInt()}%';
    }
    return '${currentValue.toStringAsFixed(1)}x';
  }

  Color get _sliderColor {
    final change = currentValue - config.defaultValue;
    if (config.isReduction) {
      return change < -0.1 ? const Color(0xFF4CAF50) : const Color(0xFF667EEA);
    }
    return change > 0.2 ? const Color(0xFF4CAF50) : const Color(0xFF667EEA);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F36) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(config.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  config.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _sliderColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _valueLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _sliderColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _sliderColor,
              inactiveTrackColor: _sliderColor.withOpacity(0.2),
              thumbColor: _sliderColor,
              overlayColor: _sliderColor.withOpacity(0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: currentValue,
              min: config.min,
              max: config.max,
              onChanged: onChanged,
            ),
          ),
          Text(
            config.description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Projection result card
class _ProjectionCard extends StatelessWidget {
  final ProjectionResult projection;
  final bool isDark;

  const _ProjectionCard({required this.projection, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF667EEA).withOpacity(isDark ? 0.2 : 0.1),
            const Color(0xFF764BA2).withOpacity(isDark ? 0.2 : 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF667EEA).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF667EEA),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Projection',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Expected in ${projection.timeframe}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${projection.estimatedSystolicChange} mmHg',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            projection.recommendation,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          if (projection.tips.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...projection.tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
