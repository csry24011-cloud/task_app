import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_notifier/local_notifier.dart';
import 'task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter());
  await Hive.openBox<Task>('tasks');

  await localNotifier.setup(
    appName: 'task_app',
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '課題の優先度管理 (PC版)',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const TaskManageScreen(),
    );
  }
}

class TaskManageScreen extends StatefulWidget {
  const TaskManageScreen({super.key});

  @override
  State<TaskManageScreen> createState() => _TaskManageScreenState();
}

class _TaskManageScreenState extends State<TaskManageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime? _selectedDate;
  int? _selectedImpact;

  @override
  void initState() {
    super.initState();
    // ==========================================================
    // 【新機能】アプリ起動時に、すでに期限が24時間を切っている課題がないかスキャン
    // ==========================================================
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUrgentTasksOnStartup();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // Windowsのデスクトップ通知を出す共通関数
  void _showWindowsNotification(String taskTitle, String messageBody) {
    LocalNotification notification = LocalNotification(
      title: taskTitle,
      body: messageBody,
    );
    notification.show();
  }

  // 起動時スキャン処理の中身
  void _checkUrgentTasksOnStartup() {
    final box = Hive.box<Task>('tasks');
    final now = DateTime.now();
    int urgentCount = 0;

    for (var task in box.values) {
      // 提出期限と現在時刻の差を計算
      final difference = task.deadline.difference(now);

      // まだ期限を過ぎていなくて、かつ残り24時間（1日）を切っている場合
      if (difference.inDays == 0 && !difference.isNegative) {
        urgentCount++;
      }
    }

    // 期限が迫っている課題が1つ以上あれば通知する
    if (urgentCount > 0) {
      _showWindowsNotification(
        "⚠️ 期限が迫っている課題が $urgentCount 件あります！",
        "PC作業を始める前に、優先度リストを確認して早めに着手しましょう。",
      );
    }
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('提出期限を選択してください')));
        return;
      }

      // showDatePickerで選んだ日付は「その日の0時0分」になります
      final newTask = Task(
        title: _titleController.text,
        deadline: _selectedDate!,
        impact: _selectedImpact ?? 3,
      );

      Hive.box<Task>('tasks').add(newTask);

      // ==========================================================
      // 【ロジック修正】締め切りの24時間前（残り1日）を計算してタイマーセット
      // ==========================================================
      final notificationTime = newTask.deadline.subtract(
        const Duration(days: 1),
      );
      final durationUntilNotification = notificationTime.difference(
        DateTime.now(),
      );

      if (durationUntilNotification.isNegative) {
        // もし登録した時点で、すでに提出まで24時間を切っている場合は「5秒後」にすぐ通知（デモ用）
        Timer(const Duration(seconds: 5), () {
          _showWindowsNotification(
            "⚠️ 期限直前アラート！",
            "「${newTask.title}」の提出期限まで残り1日を切っています！",
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '「${newTask.title}」を登録しました！（すでに残り1日を切っているため5秒後に通知します）',
            ),
          ),
        );
      } else {
        // まだ余裕がある場合は、ぴったり24時間前になるタイミングを計算してタイマーをかける
        Timer(durationUntilNotification, () {
          _showWindowsNotification(
            "⚠️ 提出期限24時間前です！",
            "「${newTask.title}」の締め切りが明日になりました。準備は大丈夫ですか？",
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${newTask.title}」を登録しました！（提出の24時間前に通知されます）'),
          ),
        );
      }

      _titleController.clear();
      setState(() {
        _selectedDate = null;
        _selectedImpact = null;
      });
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // (UI部分のコードは以前と全く同じなので省略して安全に動きます)
    return Scaffold(
      appBar: AppBar(
        title: const Text('課題の優先度管理 (デスクトップ版)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: '課題名',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? '課題名を入力してください'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _selectedDate == null
                            ? '提出期限を選択してください'
                            : '提出期限: ${_selectedDate!.year}/${_selectedDate!.month}/${_selectedDate!.day}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (pickedDate != null) {
                          setState(() => _selectedDate = pickedDate);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _selectedImpact,
                      decoration: const InputDecoration(
                        labelText: '評定への影響度 (5が最大)',
                        border: OutlineInputBorder(),
                      ),
                      items: [1, 2, 3, 4, 5]
                          .map(
                            (int value) => DropdownMenuItem<int>(
                              value: value,
                              child: Text('レベル $value'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedImpact = value),
                      validator: (value) =>
                          value == null ? '影響度を選択してください' : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveTask,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          '課題を登録',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '今やるべき課題リスト',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          ValueListenableBuilder(
            valueListenable: Hive.box<Task>('tasks').listenable(),
            builder: (context, Box<Task> box, _) {
              if (box.values.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text('現在登録されている課題はありません。')),
                );
              }
              final tasks = box.values.toList();
              tasks.sort((a, b) => b.priority.compareTo(a.priority));
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return Card(
                    color: index == 0 ? Colors.red.shade50 : Colors.white,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: index == 0 ? Colors.red : Colors.blue,
                        child: Text(
                          task.priority.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        task.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '期限: ${task.deadline.year}/${task.deadline.month}/${task.deadline.day}  |  影響度: ${task.impact}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                          size: 28,
                        ),
                        onPressed: () async {
                          await task.delete();
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
