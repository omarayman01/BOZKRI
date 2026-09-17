import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;

import '../../../view_model/utils/date_utils.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';

/// Compact from/to selector with quick presets, used by the dashboard and the
/// expenses section.
class DateRangePickerField extends StatelessWidget {
  const DateRangePickerField({
    super.key,
    required this.range,
    required this.onChanged,
    this.label = 'Period',
  });

  final AppDateRange range;
  final ValueChanged<AppDateRange> onChanged;
  final String label;

  Future<void> _pick(BuildContext context) async {
    final material.DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      initialDateRange: material.DateTimeRange(
        start: range.start,
        end: range.end,
      ),
    );
    if (picked != null) {
      onChanged(AppDateRange(
        start: AppDateUtils.startOfDay(picked.start),
        end: AppDateUtils.endOfDay(picked.end),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () => _pick(context),
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(
            '${AppDateUtils.formatDate(range.start)}  →  '
            '${AppDateUtils.formatDate(range.end)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.primary),
            textDirection: TextDirection.ltr,
          ),
        ),
        _Preset(
          label: '7d',
          onTap: () => onChanged(AppDateUtils.lastNDays(7)),
        ),
        _Preset(
          label: '30d',
          onTap: () => onChanged(AppDateUtils.lastNDays(30)),
        ),
        _Preset(
          label: 'هذا الشهر',
          onTap: () => onChanged(AppDateUtils.currentMonth()),
        ),
      ],
    );
  }
}

class _Preset extends StatelessWidget {
  const _Preset({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: AppTextStyles.caption),
      onPressed: onTap,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
    );
  }
}

/// Single optional date field with a clear button, used for expiry and rent
/// dates on deal lines and item forms.
class SingleDateField extends StatelessWidget {
  const SingleDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled
          ? () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: firstDate ?? DateTime(2015),
                lastDate:
                    lastDate ?? DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) onChanged(picked);
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: value == null
              ? const Icon(Icons.event_outlined,
                  size: 18, color: AppColors.secondary)
              : IconButton(
                  tooltip: 'مسح',
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: enabled ? () => onChanged(null) : null,
                ),
        ),
        child: Text(
          value == null ? '—' : AppDateUtils.formatDate(value!),
          style: value == null ? AppTextStyles.bodyMuted : AppTextStyles.body,
          textDirection: TextDirection.ltr,
        ),
      ),
    );
  }
}

/// Same as [SingleDateField] but also captures a time of day — used for the
/// car-rental start datetime, which must keep the exact hour/minute (not
/// silently zeroed to midnight).
class SingleDateTimeField extends StatelessWidget {
  const SingleDateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;
  final DateTime? firstDate;
  final DateTime? lastDate;

  Future<void> _pick(BuildContext context) async {
    final DateTime initial = value ?? DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(2015),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 3650)),
    );
    if (pickedDate == null || !context.mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return;

    onChanged(DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: value == null
              ? const Icon(Icons.event_outlined,
                  size: 18, color: AppColors.secondary)
              : IconButton(
                  tooltip: 'مسح',
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: enabled ? () => onChanged(null) : null,
                ),
        ),
        child: Text(
          value == null ? '—' : AppDateUtils.formatDateTime(value!),
          style: value == null ? AppTextStyles.bodyMuted : AppTextStyles.body,
          textDirection: TextDirection.ltr,
        ),
      ),
    );
  }
}
