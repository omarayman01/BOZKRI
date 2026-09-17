import '../../model/item_field_value_model.dart';
import '../../model/item_model.dart';
import '../../model/item_type_field_model.dart';
import '../../model/item_type_model.dart';

/// Which of the agency's three real revenue streams an admin-defined item
/// type matches. Matched by keyword on the type name (Arabic or English)
/// since item types are admin-defined, not a fixed enum column.
enum ItemCategory { apartment, flight, car, other }

ItemCategory categoryOf(ItemTypeModel type) {
  final String name = type.name.toLowerCase();
  if (name.contains('شقق') || name.contains('عقار') || name.contains('apartment')) {
    return ItemCategory.apartment;
  }
  if (name.contains('طيران') || name.contains('تذاكر') || name.contains('flight')) {
    return ItemCategory.flight;
  }
  if (name.contains('سيار') || name.contains('car')) {
    return ItemCategory.car;
  }
  return ItemCategory.other;
}

/// An item's dynamic field values keyed by field *name* rather than id, so
/// callers can look a value up by admin-typed label without knowing its id.
Map<String, String> fieldValuesByName(ItemModel item, ItemTypeModel type) {
  final Map<int, String> byFieldId = <int, String>{
    for (final ItemFieldValueModel v in item.fieldValues) v.fieldId: v.value,
  };
  return <String, String>{
    for (final ItemTypeFieldModel f in type.fields)
      f.fieldName.trim(): byFieldId[f.id] ?? '',
  };
}

/// First non-empty value whose field name contains any of [candidates]
/// (case-insensitive) — admin-typed field names vary in wording/spelling.
String pickFieldValue(Map<String, String> byName, List<String> candidates) {
  for (final MapEntry<String, String> entry in byName.entries) {
    if (entry.value.trim().isEmpty) continue;
    final String key = entry.key.toLowerCase();
    if (candidates.any((String c) => key.contains(c.toLowerCase()))) {
      return entry.value;
    }
  }
  return '';
}
