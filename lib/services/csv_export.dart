import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/palette.dart';
import '../core/app_locale.dart';

/// Real CSV export: builds the file text from live rows, previews it and
/// copies it to the clipboard (paste straight into Excel / Numbers /
/// Google Sheets). Every “Export” button in the app lands here.
void showCsvExport(
  BuildContext context, {
  required String title,
  required String filename,
  required List<String> header,
  required List<List<String>> rows,
}) {
  final csv = [
    header.join(','),
    for (final r in rows) r.map(_escape).join(','),
  ].join('\n');

  final previewRows = rows.take(6).toList();

  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (dialogCtx) => AlertDialog(
      title: Text(AppLocale.tf('Export — {n}', {'n': title}),
          style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocale.tf('{n} · {m} data row(s) + header', {'n': filename, 'm': rows.length}),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: AppPalette.muted),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.fill.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.stroke),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      header.join(' , '),
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.primary),
                    ),
                    const SizedBox(height: 4),
                    for (final r in previewRows)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          r.join(' , '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              color: AppPalette.body),
                        ),
                      ),
                    if (rows.length > previewRows.length)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          '… and ${rows.length - previewRows.length} more row(s)',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: AppPalette.muted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocale.t(
                  'Copy places the full CSV on your clipboard — paste it into any spreadsheet.'),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11.5,
                  height: 1.4,
                  color: AppPalette.muted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: Text(AppLocale.t('Close'),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily, color: AppPalette.body)),
        ),
        FilledButton.icon(
          style:
              FilledButton.styleFrom(backgroundColor: AppPalette.primary),
          icon: const Icon(Icons.copy_rounded, size: 15),
          label: Text(AppLocale.t('Copy CSV'),
              style: const TextStyle(fontFamily: AppTheme.fontFamily)),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: csv));
            Navigator.pop(dialogCtx);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  AppLocale.tf('{n} exported — {m} copied to clipboard ({k} rows)', {'n': title, 'm': filename, 'k': rows.length})),
              behavior: SnackBarBehavior.floating,
            ));
          },
        ),
      ],
    ),
  );
}

String _escape(String cell) {
  if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
    return '"${cell.replaceAll('"', '""')}"';
  }
  return cell;
}
