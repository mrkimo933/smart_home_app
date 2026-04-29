// lib/features/analytics/services/export_service.dart

import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/consumption_record.dart';

class ExportService {
  Future<void> exportToPdf(List<ConsumptionRecord> records) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          children: [
            pw.Text('Monthly Consumption Report', style: const pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'kWh'],
              data: records.map((r) => [r.date.toString(), r.kwh.toString()]).toList(),
            ),
          ],
        ),
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/consumption_report.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Consumption Report PDF');
  }

  Future<void> exportToCsv(List<ConsumptionRecord> records) async {
    List<List<dynamic>> rows = [];
    rows.add(["Date", "kWh"]);
    for (var record in records) {
      rows.add([record.date.toString(), record.kwh.toString()]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/consumption_report.csv");
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Consumption Report CSV');
  }
}
