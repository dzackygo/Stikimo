/// Kegagalan impor yang pesannya aman ditampilkan tanpa detail foto pengguna.
class ImportFailure implements Exception {
  const ImportFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
