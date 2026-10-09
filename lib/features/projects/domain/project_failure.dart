/// Pesan aman untuk kegagalan validasi atau penyimpanan proyek lokal.
class ProjectFailure implements Exception {
  const ProjectFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
