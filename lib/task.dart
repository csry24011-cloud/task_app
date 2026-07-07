import 'package:hive/hive.dart';

// 「extends HiveObject」を後ろに付け足します
class Task extends HiveObject {
  String title;
  DateTime deadline;
  int impact; // 評定への影響度（1〜5）

  Task({required this.title, required this.deadline, required this.impact});

  // 【自動計算】優先度スコアを返すゲッター
  double get priority {
    final now = DateTime.now();
    final difference = deadline.difference(now).inDays;
    final daysLeft = difference < 0
        ? 0.1
        : (difference == 0 ? 0.5 : difference.toDouble());
    return impact / daysLeft;
  }
}

// （下の TaskAdapter の部分は一切変更なしで大丈夫です！）
class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    return Task(
      title: reader.readString(),
      deadline: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      impact: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer.writeString(obj.title);
    writer.writeInt(obj.deadline.millisecondsSinceEpoch);
    writer.writeInt(obj.impact);
  }
}
