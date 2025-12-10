import 'package:arteria/features/reminders/reminder_bloc.dart';
import 'package:arteria/features/reminders/reminder_event.dart';
import 'package:arteria/features/reminders/reminder_model.dart';
import 'package:arteria/features/reminders/reminder_state.dart';
import 'package:arteria/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  static const Color _primaryBlue = Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    // **KEY CHANGE: Start watching for real-time updates immediately**
    debugPrint('🎬 ReminderSettingsScreen initialized, starting watch');
    context.read<ReminderBloc>().add(WatchReminders());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.reminderSettings,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<ReminderBloc, ReminderState>(
        builder: (context, state) {
          debugPrint('📺 UI Building with state: ${state.runtimeType}');

          if (state is RemindersLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is RemindersError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ReminderBloc>().add(WatchReminders());
                    },
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }

          final reminders = state is RemindersLoaded
              ? state.reminders
              : <Reminder>[];
          debugPrint('📋 Displaying ${reminders.length} reminders');

          return Column(
            children: [
              // Description
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  l10n.reminderSettingsDescription,
                  style: GoogleFonts.openSans(
                    fontSize: 15,
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.7,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Reminders list or empty state
              Expanded(
                child: reminders.isEmpty
                    ? _buildEmptyState(context, theme, isDark)
                    : _buildRemindersList(context, theme, reminders),
              ),

              // Add reminder button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddReminderDialog(context),
                      icon: const Icon(Icons.add_alarm),
                      label: Text(
                        l10n.addReminder,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none,
                size: 50,
                color: _primaryBlue.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noRemindersYet,
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noRemindersDescription,
              style: GoogleFonts.openSans(
                fontSize: 15,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.7,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersList(
    BuildContext context,
    ThemeData theme,
    List<Reminder> reminders,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        return Dismissible(
          key: Key(reminder.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {
            context.read<ReminderBloc>().add(DeleteReminder(reminder.id));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.reminderDeleted),
                action: SnackBarAction(
                  label: l10n.undo,
                  onPressed: () {
                    context.read<ReminderBloc>().add(
                      AddReminder(
                        time: reminder.time,
                        repeatType: reminder.repeatType,
                        customDays: reminder.customDays,
                        label: reminder.label,
                      ),
                    );
                  },
                ),
              ),
            );
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: _buildReminderCard(context, theme, reminder),
        );
      },
    );
  }

  Widget _buildReminderCard(
    BuildContext context,
    ThemeData theme,
    Reminder reminder,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (theme.brightness == Brightness.light)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: reminder.isEnabled
                ? _primaryBlue.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.alarm,
            color: reminder.isEnabled ? _primaryBlue : Colors.grey,
          ),
        ),
        title: Text(
          reminder.formattedTime,
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: reminder.isEnabled
                ? theme.textTheme.titleLarge?.color
                : theme.textTheme.titleLarge?.color?.withValues(alpha: 0.5),
          ),
        ),
        subtitle: Text(
          reminder.formattedRepeat,
          style: GoogleFonts.openSans(
            fontSize: 14,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        trailing: Switch.adaptive(
          value: reminder.isEnabled,
          onChanged: (value) {
            context.read<ReminderBloc>().add(
              ToggleReminder(reminderId: reminder.id, isEnabled: value),
            );
          },
          activeThumbColor: _primaryBlue,
        ),
        onTap: () => _showEditReminderDialog(context, reminder),
      ),
    );
  }

  void _showAddReminderDialog(BuildContext context) {
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    RepeatType selectedRepeat = RepeatType.daily;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final l10n = AppLocalizations.of(context)!;
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.addReminder,
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),

                // Time picker button
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setModalState(() => selectedTime = time);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: _primaryBlue),
                        const SizedBox(width: 16),
                        Text(
                          selectedTime.format(context),
                          style: GoogleFonts.montserrat(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.edit, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Repeat type selection
                Text(
                  l10n.repeat,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: RepeatType.values
                      .where((r) => r != RepeatType.custom)
                      .map((type) {
                        final isSelected = selectedRepeat == type;
                        return ChoiceChip(
                          label: Text(_getRepeatLabel(context, type)),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => selectedRepeat = type);
                            }
                          },
                          selectedColor: _primaryBlue.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? _primaryBlue : null,
                            fontWeight: isSelected ? FontWeight.w600 : null,
                          ),
                        );
                      })
                      .toList(),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      debugPrint('💾 Saving new reminder from dialog');
                      context.read<ReminderBloc>().add(
                        AddReminder(
                          time: selectedTime,
                          repeatType: selectedRepeat,
                        ),
                      );
                      Navigator.pop(bottomSheetContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      l10n.saveReminder,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditReminderDialog(BuildContext context, Reminder reminder) {
    TimeOfDay selectedTime = reminder.time;
    RepeatType selectedRepeat = reminder.repeatType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final l10n = AppLocalizations.of(context)!;
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.editReminder,
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),

                // Time picker button
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setModalState(() => selectedTime = time);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: _primaryBlue),
                        const SizedBox(width: 16),
                        Text(
                          selectedTime.format(context),
                          style: GoogleFonts.montserrat(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.edit, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Repeat type selection
                Text(
                  l10n.repeat,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: RepeatType.values
                      .where((r) => r != RepeatType.custom)
                      .map((type) {
                        final isSelected = selectedRepeat == type;
                        return ChoiceChip(
                          label: Text(_getRepeatLabel(context, type)),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => selectedRepeat = type);
                            }
                          },
                          selectedColor: _primaryBlue.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? _primaryBlue : null,
                            fontWeight: isSelected ? FontWeight.w600 : null,
                          ),
                        );
                      })
                      .toList(),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      debugPrint('💾 Updating reminder ${reminder.id}');
                      context.read<ReminderBloc>().add(
                        UpdateReminder(
                          reminder.copyWith(
                            time: selectedTime,
                            repeatType: selectedRepeat,
                          ),
                        ),
                      );
                      Navigator.pop(bottomSheetContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      l10n.updateReminder,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getRepeatLabel(BuildContext context, RepeatType type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case RepeatType.daily:
        return l10n.daily;
      case RepeatType.weekdays:
        return l10n.weekdays;
      case RepeatType.weekends:
        return l10n.weekends;
      case RepeatType.custom:
        return l10n.custom;
    }
  }
}
