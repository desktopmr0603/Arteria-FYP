import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arteria/features/trends/presentation/bloc/trends_event.dart';
import 'package:arteria/features/trends/presentation/bloc/trends_state.dart';
import 'package:arteria/features/trends/domain/entities/chart_config.dart';
import 'package:arteria/features/trends/domain/entities/time_range.dart';
import 'package:arteria/features/trends/domain/entities/trend_data.dart';
import 'package:arteria/features/trends/domain/repositories/trends_repository.dart';
import 'package:arteria/features/trends/data/repositories/trends_repository_impl.dart';

class TrendsBloc extends Bloc<TrendsEvent, TrendsState> {
  final TrendsRepository _repository;

  TrendsBloc({TrendsRepository? repository})
    : _repository = repository ?? TrendsRepositoryImpl(),
      super(const TrendsInitial()) {
    on<LoadTrendsData>(_onLoadTrendsData);
    on<ChangeTimeRange>(_onChangeTimeRange);
    on<ChangeViewMode>(_onChangeViewMode);
    on<ChangeChartType>(_onChangeChartType);
    on<ResetToDefaults>(_onResetToDefaults);
  }

  Future<void> _onLoadTrendsData(
    LoadTrendsData event,
    Emitter<TrendsState> emit,
  ) async {
    emit(const TrendsLoading(message: 'Loading trends data...'));

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        emit(const TrendsError('User not logged in'));
        return;
      }

      final trendData = await _repository.getTrendData(
        userId: userId,
        timeRange: event.timeRange,
      );

      final analysis = await _repository.getTrendAnalysis(
        userId: userId,
        timeRange: event.timeRange,
      );

      final aggregatedData = await _repository.getAggregatedData(
        userId: userId,
        timeRange: event.timeRange,
        aggregationType: AggregationType.daily,
      );

      emit(
        TrendsLoaded(
          trendData: trendData,
          chartConfig: ChartConfig.simpleView(),
          selectedTimeRange: event.timeRange,
          viewMode: event.viewMode,
          analysis: analysis,
          aggregatedData: aggregatedData,
        ),
      );
    } catch (e) {
      emit(TrendsError('Failed to load trends data: $e'));
    }
  }

  Future<void> _onChangeTimeRange(
    ChangeTimeRange event,
    Emitter<TrendsState> emit,
  ) async {
    if (state is TrendsLoaded) {
      final currentState = state as TrendsLoaded;

      emit(
        TrendsTimeRangeChanging(
          newTimeRange: event.newTimeRange,
          previousTimeRange: currentState.selectedTimeRange,
        ),
      );

      add(
        LoadTrendsData(
          timeRange: event.newTimeRange,
          viewMode: currentState.viewMode,
        ),
      );
    }
  }

  Future<void> _onChangeViewMode(
    ChangeViewMode event,
    Emitter<TrendsState> emit,
  ) async {
    if (state is TrendsLoaded) {
      final currentState = state as TrendsLoaded;

      emit(
        TrendsViewModeChanging(
          newViewMode: event.newViewMode,
          previousViewMode: currentState.viewMode,
        ),
      );

      add(
        LoadTrendsData(
          timeRange: currentState.selectedTimeRange,
          viewMode: event.newViewMode,
        ),
      );
    }
  }

  Future<void> _onChangeChartType(
    ChangeChartType event,
    Emitter<TrendsState> emit,
  ) async {
    if (state is TrendsLoaded) {
      final currentState = state as TrendsLoaded;

      emit(
        currentState.copyWith(
          chartConfig: currentState.chartConfig.copyWith(
            chartType: event.newChartType,
          ),
        ),
      );
    }
  }

  Future<void> _onResetToDefaults(
    ResetToDefaults event,
    Emitter<TrendsState> emit,
  ) async {
    emit(const TrendsLoading(message: 'Resetting to defaults...'));

    add(
      LoadTrendsData(
        timeRange: TimeRange.last30Days(),
        viewMode: ViewMode.simple,
      ),
    );
  }

  TimeRange? get currentTimeRange {
    if (state is TrendsLoaded) {
      return (state as TrendsLoaded).selectedTimeRange;
    }
    return null;
  }

  ViewMode? get currentViewMode {
    if (state is TrendsLoaded) {
      return (state as TrendsLoaded).viewMode;
    }
    return null;
  }

  List<TrendData>? get currentTrendData {
    if (state is TrendsLoaded) {
      return (state as TrendsLoaded).trendData;
    }
    return null;
  }
}
