import 'package:flutter/material.dart';
import 'package:arteria/features/trends/domain/entities/time_range.dart';

/// Time Range Selector Widget
class TimeRangeSelector extends StatefulWidget {
  final TimeRange selectedRange;
  final Function(TimeRange) onRangeChanged;
  final bool isSimpleView;

  const TimeRangeSelector({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
    this.isSimpleView = false,
  });

  @override
  State<TimeRangeSelector> createState() => _TimeRangeSelectorState();
}

class _TimeRangeSelectorState extends State<TimeRangeSelector> {
  late TimeRange _selectedRange;

  @override
  void initState() {
    super.initState();
    _selectedRange = widget.selectedRange;
  }

  @override
  void didUpdateWidget(TimeRangeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRange != widget.selectedRange) {
      _selectedRange = widget.selectedRange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.isSimpleView) {
      return _buildSimpleSelector(theme);
    }

    return _buildFullSelector(theme);
  }

  Widget _buildSimpleSelector(ThemeData theme) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _getSimpleRanges()
            .map((range) => _buildRangeChip(range, theme))
            .toList(),
      ),
    );
  }

  Widget _buildFullSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Time Range',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _getAllRanges()
                .map((range) => _buildRangeChip(range, theme))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeChip(TimeRange range, ThemeData theme) {
    final isSelected = _selectedRange == range;
    final isDark = theme.brightness == Brightness.dark;

    return FilterChip(
      label: Text(
        range.displayName ?? range.formattedName,
        style: TextStyle(
          color: isSelected
              ? (isDark ? Colors.white : Colors.white)
              : theme.textTheme.bodyMedium?.color,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedRange = range);
          widget.onRangeChanged(range);
        }
      },
      backgroundColor: isDark
          ? theme.cardColor
          : theme.cardColor.withValues(alpha: 0.8),
      selectedColor: theme.primaryColor,
      checkmarkColor: isDark ? Colors.white : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? theme.primaryColor : theme.dividerColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  List<TimeRange> _getSimpleRanges() {
    return [
      TimeRange.last7Days(),
      TimeRange.last30Days(),
      TimeRange.last90Days(),
    ];
  }

  List<TimeRange> _getAllRanges() {
    return [
      TimeRange.last7Days(),
      TimeRange.last30Days(),
      TimeRange.last90Days(),
      TimeRange.thisYear(),
    ];
  }
}

/// Preset Time Range Chips for horizontal scrolling
class TimeRangeChips extends StatelessWidget {
  final TimeRange selectedRange;
  final Function(TimeRange) onRangeChanged;
  final bool showLabels;

  const TimeRangeChips({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: showLabels ? 80 : 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _getPresetRanges()
            .map((range) => _buildChip(range, theme, isDark))
            .toList(),
      ),
    );
  }

  Widget _buildChip(TimeRange range, ThemeData theme, bool isDark) {
    final isSelected = selectedRange == range;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          range.displayName ?? range.formattedName,
          style: TextStyle(
            color: isSelected
                ? (isDark ? Colors.white : Colors.white)
                : theme.textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: showLabels ? 14 : 12,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            onRangeChanged(range);
          }
        },
        backgroundColor: isDark
            ? theme.cardColor.withValues(alpha: 0.8)
            : theme.cardColor.withValues(alpha: 0.6),
        selectedColor: theme.primaryColor,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? theme.primaryColor
                : theme.dividerColor.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: showLabels ? 16 : 12,
          vertical: showLabels ? 12 : 8,
        ),
        elevation: isSelected ? 2 : 0,
        shadowColor: theme.primaryColor.withValues(alpha: 0.3),
      ),
    );
  }

  List<TimeRange> _getPresetRanges() {
    return [
      TimeRange.last7Days(),
      TimeRange.last30Days(),
      TimeRange.last90Days(),
      TimeRange.thisYear(),
    ];
  }
}

/// Custom Date Range Picker Widget
class CustomDateRangePicker extends StatefulWidget {
  final DateTimeRange? initialRange;
  final Function(DateTimeRange) onRangeSelected;

  const CustomDateRangePicker({
    super.key,
    this.initialRange,
    required this.onRangeSelected,
  });

  @override
  State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    _selectedRange = widget.initialRange;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom Date Range',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectStartDate(context),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedRange?.start != null
                          ? _formatDate(_selectedRange!.start)
                          : 'Start Date',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectEndDate(context),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedRange?.end != null
                          ? _formatDate(_selectedRange!.end)
                          : 'End Date',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedRange != null
                        ? () => widget.onRangeSelected(_selectedRange!)
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Apply Range'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedRange = null);
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedRange?.start ??
          DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null && mounted) {
      setState(() {
        final end = _selectedRange?.end ?? picked.add(const Duration(days: 7));
        _selectedRange = DateTimeRange(start: picked, end: end);
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedRange?.end ?? DateTime.now(),
      firstDate:
          _selectedRange?.start ??
          DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null && _selectedRange != null && mounted) {
      setState(() {
        _selectedRange = DateTimeRange(
          start: _selectedRange!.start,
          end: picked,
        );
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
