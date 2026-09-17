import '../../model/item_field_value_model.dart';
import '../../model/item_type_field_model.dart';
import 'date_utils.dart';

/// Encoding, decoding and validating of dynamic item field values.
///
/// Values are stored as text in item_field_values and interpreted according to
/// the owning field's [FieldType]. Adding a new field or type never requires a
/// code change — the form and the display both go through this class.
class DynamicFieldUtils {
  const DynamicFieldUtils._();

  // ---- Encoding (form -> storage) ----

  static String encode(FieldType type, Object? value) {
    if (value == null) return '';
    switch (type) {
      case FieldType.text:
        return value.toString().trim();
      case FieldType.number:
        if (value is num) return value.toString();
        return (num.tryParse(value.toString().trim()) ?? '').toString();
      case FieldType.date:
        if (value is DateTime) return value.toIso8601String();
        return value.toString().trim();
      case FieldType.bool:
        if (value is bool) return value ? 'true' : 'false';
        return value.toString().toLowerCase() == 'true' ? 'true' : 'false';
    }
  }

  // ---- Decoding (storage -> typed) ----

  static String? decodeText(String raw) => raw.isEmpty ? null : raw;

  static num? decodeNumber(String raw) => num.tryParse(raw.trim());

  static DateTime? decodeDate(String raw) => DateTime.tryParse(raw.trim());

  static bool decodeBool(String raw) => raw.trim().toLowerCase() == 'true';

  static Object? decode(FieldType type, String raw) {
    switch (type) {
      case FieldType.text:
        return decodeText(raw);
      case FieldType.number:
        return decodeNumber(raw);
      case FieldType.date:
        return decodeDate(raw);
      case FieldType.bool:
        return decodeBool(raw);
    }
  }

  /// Display string for a stored value, ready to render in a table cell.
  static String display(FieldType type, String raw, {String fallback = '—'}) {
    if (raw.trim().isEmpty) return fallback;
    switch (type) {
      case FieldType.text:
        return raw;
      case FieldType.number:
        final num? parsed = decodeNumber(raw);
        return parsed?.toString() ?? fallback;
      case FieldType.date:
        final DateTime? parsed = decodeDate(raw);
        return parsed == null ? fallback : AppDateUtils.formatDate(parsed);
      case FieldType.bool:
        return decodeBool(raw) ? 'Yes' : 'No';
    }
  }

  // ---- Validation ----

  /// Validates one raw value against its schema field.
  /// Returns null when valid, otherwise a display-ready message.
  static String? validate(ItemTypeFieldModel field, String raw) {
    final String value = raw.trim();

    if (value.isEmpty) {
      // A bool always has a value (false), so it can never be "missing".
      if (field.isRequired && field.fieldType != FieldType.bool) {
        return '${field.fieldName} is required.';
      }
      return null;
    }

    switch (field.fieldType) {
      case FieldType.text:
        return null;
      case FieldType.number:
        return decodeNumber(value) == null
            ? '${field.fieldName} must be a number.'
            : null;
      case FieldType.date:
        return decodeDate(value) == null
            ? '${field.fieldName} must be a valid date.'
            : null;
      case FieldType.bool:
        return null;
    }
  }

  /// Validates a whole form payload (fieldId -> raw value) against a schema.
  /// Returns a map of fieldId -> error message; empty when everything passes.
  static Map<int, String> validateAll(
    List<ItemTypeFieldModel> schema,
    Map<int, String> values,
  ) {
    final Map<int, String> errors = <int, String>{};
    for (final ItemTypeFieldModel field in schema) {
      final String? error = validate(field, values[field.id] ?? '');
      if (error != null) errors[field.id] = error;
    }
    return errors;
  }

  /// Turns stored values into a fieldId -> raw map for form prefill.
  static Map<int, String> toValueMap(List<ItemFieldValueModel> values) =>
      <int, String>{
        for (final ItemFieldValueModel v in values) v.fieldId: v.value,
      };

  /// Drops empty entries so blank optional fields do not create rows.
  static Map<int, String> pruneEmpty(Map<int, String> values) => <int, String>{
        for (final MapEntry<int, String> e in values.entries)
          if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
      };
}
