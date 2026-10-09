import 'project_failure.dart';

final _projectId = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void validateProjectId(String value) {
  if (!_projectId.hasMatch(value)) invalidProject();
}

String normalizeProjectName(String value) {
  final name = value.trim();
  if (name.isEmpty ||
      name.runes.length > 80 ||
      name.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
    throw const ProjectFailure('Nama proyek harus berisi 1–80 karakter.');
  }
  return name;
}

Never invalidProject() => throw const ProjectFailure(
  'Data proyek tidak valid atau versinya belum didukung.',
);

/// Pembaca ketat: tipe yang salah tidak boleh berubah menjadi default diam-diam.
Map<String, dynamic> jsonObject(Object? value) {
  if (value is! Map<String, dynamic>) invalidProject();
  return value;
}

void jsonFields(Map<String, dynamic> json, Set<String> fields) {
  if (json.keys.any((key) => !fields.contains(key))) invalidProject();
}

String jsonString(Object? value) {
  if (value is! String) invalidProject();
  return value;
}

int jsonInt(Object? value) {
  if (value is! int) invalidProject();
  return value;
}

double jsonDouble(Object? value) {
  if (value is! num || !value.isFinite) invalidProject();
  return value.toDouble();
}

bool jsonBool(Object? value) {
  if (value is! bool) invalidProject();
  return value;
}

List<dynamic> jsonList(Object? value, int maximum) {
  if (value is! List || value.length > maximum) invalidProject();
  return value;
}

T jsonEnum<T extends Enum>(Object? value, List<T> values) {
  final name = jsonString(value);
  for (final item in values) {
    if (item.name == name) return item;
  }
  invalidProject();
}

void validateNumber(
  double value,
  double minimum,
  double maximum, {
  bool positive = false,
}) {
  if (!value.isFinite ||
      value < minimum ||
      value > maximum ||
      (positive && value == 0)) {
    invalidProject();
  }
}

void validateColor(int value) {
  if (value < 0 || value > 0xffffffff) invalidProject();
}

DateTime jsonDate(Object? value) {
  final text = jsonString(value);
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d{1,6})?(Z|([+-])(\d{2}):(\d{2}))$',
  ).firstMatch(text);
  if (match == null) invalidProject();
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  // DateTime.parse menormalkan overflow (31 Februari menjadi Maret).
  // Dokumen persisten harus menolak tanggal rusak alih-alih mengubah nilainya.
  if (year < 1 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > DateTime.utc(year, month + 1, 0).day ||
      int.parse(match.group(4)!) > 23 ||
      int.parse(match.group(5)!) > 59 ||
      int.parse(match.group(6)!) > 59 ||
      (match.group(10) != null &&
          (int.parse(match.group(10)!) > 23 ||
              int.parse(match.group(11)!) > 59))) {
    invalidProject();
  }
  final date = DateTime.tryParse(text);
  if (date == null) invalidProject();
  validateProjectDate(date);
  return date.toUtc();
}

void validateProjectDate(DateTime value) {
  final year = value.toUtc().year;
  if (year < 1 || year > 9999) invalidProject();
}
