import 'package:penpeeper/repositories/report_section_repository.dart';

class ReportRepository {
  final _sectionRepo = ReportSectionRepository();

  Future<String> getReportSection(int projectId, String sectionType) async {
    final section = await _sectionRepo.getReportSection(projectId, sectionType);
    return section?.content ?? '';
  }
}
