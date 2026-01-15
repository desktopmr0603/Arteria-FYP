import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:arteria/features/trends/domain/entities/trend_data.dart';
import 'package:arteria/features/trends/domain/entities/chart_config.dart';

/// Firestore model for trend data
class TrendDataModel extends Equatable {
  final String id;
  final DateTime timestamp;
  final int systolic;
  final int diastolic;
  final int? pulse;
  final BPCategory category;
  final String userId;

  const TrendDataModel({
    required this.id,
    required this.timestamp,
    required this.systolic,
    required this.diastolic,
    this.pulse,
    required this.category,
    required this.userId,
  });

  /// Create TrendDataModel from Firestore document
  factory TrendDataModel.fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
    required String userId,
  }) {
    final timestamp = data['date'] as Timestamp?;
    final systolic = data['systolic'] as int;
    final diastolic = data['diastolic'] as int;
    final pulse = data['pulse'] as int?;

    return TrendDataModel(
      id: documentId,
      userId: userId,
      timestamp: timestamp?.toDate() ?? DateTime.now(),
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
      category: TrendDataModel.classifyBP(systolic, diastolic),
    );
  }

  /// Create from domain entity
  factory TrendDataModel.fromEntity(TrendData trendData, String userId) {
    return TrendDataModel(
      id: trendData.id,
      userId: userId,
      timestamp: trendData.timestamp,
      systolic: trendData.systolic,
      diastolic: trendData.diastolic,
      pulse: trendData.pulse,
      category: trendData.category,
    );
  }

  /// Convert to domain entity
  TrendData toEntity() {
    return TrendData(
      id: id,
      timestamp: timestamp,
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
      category: category,
    );
  }

  /// Convert to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'systolic': systolic,
      'diastolic': diastolic,
      'pulse': pulse,
      'date': Timestamp.fromDate(timestamp),
      'category': category.name,
      'userId': userId,
    };
  }

  /// Classifies blood pressure based on AHA guidelines
  static BPCategory classifyBP(int systolic, int diastolic) {
    // Normal: systolic <= 120 AND diastolic <= 80 (includes 120/80)
    if (systolic <= 120 && diastolic <= 80) {
      return BPCategory.normal;
    }
    // Elevated: systolic 121-129 AND diastolic <= 80
    if (systolic > 120 && systolic < 130 && diastolic <= 80) {
      return BPCategory.elevated;
    }
    // Stage 1 Hypertension: systolic 130-139 OR diastolic 81-89
    if ((systolic >= 130 && systolic <= 139) ||
        (diastolic > 80 && diastolic <= 89)) {
      return BPCategory.hypertensionStage1;
    }
    // Stage 2 Hypertension: systolic >= 140 OR diastolic >= 90
    if (systolic >= 140 || diastolic >= 90) {
      // Hypertensive Crisis: systolic >= 180 OR diastolic >= 120
      if (systolic >= 180 || diastolic >= 120) {
        return BPCategory.hypertensiveCrisis;
      }
      return BPCategory.hypertensionStage2;
    }
    return BPCategory.normal;
  }

  /// Create a copy with updated values
  TrendDataModel copyWith({
    String? id,
    DateTime? timestamp,
    int? systolic,
    int? diastolic,
    int? pulse,
    BPCategory? category,
    String? userId,
  }) {
    return TrendDataModel(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      pulse: pulse ?? this.pulse,
      category: category ?? this.category,
      userId: userId ?? this.userId,
    );
  }

  @override
  List<Object> get props => [
    id,
    timestamp,
    systolic,
    diastolic,
    pulse ?? 0,
    category,
    userId,
  ];

  @override
  String toString() {
    return 'TrendDataModel(id: $id, timestamp: $timestamp, systolic: $systolic, diastolic: $diastolic)';
  }
}

/// Chart configuration model for Firestore
class ChartConfigModel extends Equatable {
  final String id;
  final String userId;
  final ChartType chartType;
  final ViewMode viewMode;
  final bool showGrid;
  final bool showAnnotations;
  final bool showAverageLine;
  final ChartTheme theme;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChartConfigModel({
    required this.id,
    required this.userId,
    required this.chartType,
    required this.viewMode,
    required this.showGrid,
    required this.showAnnotations,
    required this.showAverageLine,
    required this.theme,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory ChartConfigModel.fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
    required String userId,
  }) {
    return ChartConfigModel(
      id: documentId,
      userId: userId,
      chartType: ChartType.values.firstWhere(
        (e) => e.name == data['chartType'],
      ),
      viewMode: ViewMode.values.firstWhere((e) => e.name == data['viewMode']),
      showGrid: data['showGrid'] ?? true,
      showAnnotations: data['showAnnotations'] ?? false,
      showAverageLine: data['showAverageLine'] ?? false,
      theme: ChartTheme.values.firstWhere((e) => e.name == data['theme']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create from domain entity
  factory ChartConfigModel.fromEntity(ChartConfig config, String userId) {
    return ChartConfigModel(
      id: config.hashCode.toString(), // Generate unique ID
      userId: userId,
      chartType: config.chartType,
      viewMode: config.viewMode,
      showGrid: config.showGrid,
      showAnnotations: config.showAnnotations,
      showAverageLine: config.showAverageLine,
      theme: config.theme,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Convert to domain entity
  ChartConfig toEntity() {
    return ChartConfig(
      chartType: chartType,
      viewMode: viewMode,
      showGrid: showGrid,
      showAnnotations: showAnnotations,
      showAverageLine: showAverageLine,
      theme: theme,
    );
  }

  /// Convert to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'chartType': chartType.name,
      'viewMode': viewMode.name,
      'showGrid': showGrid,
      'showAnnotations': showAnnotations,
      'showAverageLine': showAverageLine,
      'theme': theme.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated values
  ChartConfigModel copyWith({
    String? id,
    String? userId,
    ChartType? chartType,
    ViewMode? viewMode,
    bool? showGrid,
    bool? showAnnotations,
    bool? showAverageLine,
    ChartTheme? theme,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChartConfigModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      chartType: chartType ?? this.chartType,
      viewMode: viewMode ?? this.viewMode,
      showGrid: showGrid ?? this.showGrid,
      showAnnotations: showAnnotations ?? this.showAnnotations,
      showAverageLine: showAverageLine ?? this.showAverageLine,
      theme: theme ?? this.theme,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object> get props => [
    id,
    userId,
    chartType,
    viewMode,
    showGrid,
    showAnnotations,
    showAverageLine,
    theme,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() {
    return 'ChartConfigModel(id: $id, chartType: $chartType, viewMode: $viewMode)';
  }
}
