import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

DateTime? chatLocalTime(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal();
String chatTime(Object? value) {
  final date = chatLocalTime(value);
  return date == null ? '' : DateFormat('HH:mm').format(date);
}

String chatDay(Object? value, {bool arabic = true, DateTime? now}) {
  final date = chatLocalTime(value);
  if (date == null) return arabic ? 'تاريخ غير متوفر' : 'Date unavailable';
  final today = now?.toLocal() ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final current = DateTime(today.year, today.month, today.day);
  if (day == current) return arabic ? 'اليوم' : 'Today';
  if (day == DateTime(current.year, current.month, current.day - 1)) {
    return arabic ? 'أمس' : 'Yesterday';
  }
  return DateFormat('yyyy/MM/dd').format(date);
}

List<Map<String, dynamic>> chatDatedRows(List<Map<String, dynamic>> rows) {
  final output = <Map<String, dynamic>>[];
  String? previous;
  for (final row in rows) {
    final date = chatLocalTime(row['created_at']);
    final day = date == null ? '' : '${date.year}-${date.month}-${date.day}';
    if (date != null && day != previous) {
      output.add({
        'date_separator': true,
        'created_at': row['created_at'],
        'id': 'date-$day'
      });
    }
    output.add(row);
    previous = day;
  }
  return output;
}

class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({super.key, required this.value, this.arabic = true});
  final Object? value;
  final bool arabic;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: Chip(label: Text(chatDay(value, arabic: arabic)))));
}
