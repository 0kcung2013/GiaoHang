import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Minimal SpreadsheetML writer for immutable reports (no formulas or macros).
/// Existing archive/xml dependencies avoid a second incompatible ZIP runtime.
Uint8List writeReportWorkbook(Map<String, List<List<Object>>> sheets) {
  const main = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  const rel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  const packageRel =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  final zip = Archive();
  void add(String path, String content) {
    final bytes = utf8.encode(content);
    zip.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  add(
    '[Content_Types].xml',
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '${List.generate(sheets.length, (i) => '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join()}'
        '</Types>',
  );
  add(
    '_rels/.rels',
    '<Relationships xmlns="$packageRel"><Relationship Id="rId1" Type="$rel/officeDocument" Target="xl/workbook.xml"/></Relationships>',
  );
  add(
    'xl/workbook.xml',
    '<workbook xmlns="$main" xmlns:r="$rel"><sheets>'
        '${sheets.keys.indexed.map((s) => '<sheet name="${_xml(s.$2)}" sheetId="${s.$1 + 1}" r:id="rId${s.$1 + 1}"/>').join()}'
        '</sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<Relationships xmlns="$packageRel">'
        '${List.generate(sheets.length, (i) => '<Relationship Id="rId${i + 1}" Type="$rel/worksheet" Target="worksheets/sheet${i + 1}.xml"/>').join()}'
        '<Relationship Id="styles" Type="$rel/styles" Target="styles.xml"/></Relationships>',
  );
  add(
    'xl/styles.xml',
    '<styleSheet xmlns="$main">'
        '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
        '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font></fonts>'
        '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
        '<fill><patternFill patternType="solid"><fgColor rgb="FF0F1B2D"/><bgColor indexed="64"/></patternFill></fill></fills>'
        '<borders count="1"><border/></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>'
        '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf>'
        '<xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs>'
        '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>',
  );
  for (final sheet in sheets.entries.indexed) {
    final rows = sheet.$2.value;
    final columns = rows.fold<int>(1, (n, r) => n > r.length ? n : r.length);
    final content = StringBuffer(
      '<worksheet xmlns="$main"><sheetViews><sheetView workbookViewId="0">'
      '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><cols>',
    );
    for (var col = 1; col <= columns; col++) {
      content.write(
        '<col min="$col" max="$col" width="${sheet.$1 == 0 && col == 1
            ? 85
            : col == 1
            ? 38
            : 24}" customWidth="1"/>',
      );
    }
    content.write('</cols><sheetData>');
    for (final row in rows.indexed) {
      content.write(
        '<row r="${row.$1 + 1}" ht="${row.$1 == 0
            ? 44
            : sheet.$1 == 0
            ? 42
            : 34}" customHeight="1">',
      );
      for (final cell in row.$2.indexed) {
        final ref = '${_column(cell.$1)}${row.$1 + 1}';
        final value = cell.$2;
        final style = row.$1 == 0
            ? 1
            : value is int
            ? 2
            : 0;
        content.write(
          value is int
              ? '<c r="$ref" s="$style"><v>$value</v></c>'
              : '<c r="$ref" s="$style" t="inlineStr"><is><t xml:space="preserve">${_xml(value.toString())}</t></is></c>',
        );
      }
      content.write('</row>');
    }
    content.write('</sheetData>');
    if (sheet.$1 != 0 && rows.isNotEmpty)
      content.write(
        '<autoFilter ref="A1:${_column(columns - 1)}${rows.length}"/>',
      );
    content.write('</worksheet>');
    add('xl/worksheets/sheet${sheet.$1 + 1}.xml', content.toString());
  }
  return Uint8List.fromList(ZipEncoder().encode(zip));
}

String _xml(String value) => XmlText(
  value.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), ''),
).toXmlString().replaceAll('"', '&quot;');
String _column(int index) {
  var result = '';
  var value = index + 1;
  while (value > 0) {
    value--;
    result = String.fromCharCode(65 + value % 26) + result;
    value ~/= 26;
  }
  return result;
}
