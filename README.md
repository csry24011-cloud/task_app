# 課題の優先度管理アプリ (デスクトップ版)

## 📌 アプリの概要
提出期限と影響度から「今やるべき課題」を自動計算し、優先順位をリアルタイムで提示するWindows常駐型アプリです。
アプリを閉じている間の通知漏れを防ぐため、起動時スキャン機能も実装しています。

## 🔄 状態遷移図 (State Machine Diagram)
```mermaid
stateDiagram-v2
    [*] --> アプリ起動
    アプリ起動 --> 起動時スキャン : Hiveからデータ読み込み

    state 起動時スキャン {
        [*] --> チェック中
        チェック中 --> 通知実行 : 24時間以内の課題あり
        チェック中 --> 通知なし : 24時間以内の課題なし
    }

    起動時スキャン --> リスト待機状態 : スキャン完了

    リスト待機状態 --> 課題入力中 : ユーザーがフォームを入力
    課題入力中 --> リスト待機状態 : バリデーションエラー
    課題入力中 --> 課題登録処理 : 登録ボタン押下

    state 課題登録処理 {
        [*] --> タイマー計算
        タイマー計算 --> 5秒後通知予約 : 期限まで24時間未満(デモ用)
        タイマー計算 --> 24時間前通知予約 : 期限まで24時間以上
        5秒後通知予約 --> Hiveへ保存
        24時間前通知予約 --> Hiveへ保存
    }

    課題登録処理 --> リスト待機状態 : 登録＆スナックバー表示完了

    リスト待機状態 --> タスク削除処理 : 完了(チェック)ボタン押下
    タスク削除処理 --> リスト待機状態 : データ削除＆スナックバー表示
```

## 🏗️ クラス図 (Class Diagram)
```mermaid
classDiagram
    class Task {
        +String title
        +DateTime deadline
        +int impact
        +double priority
        +save()
        +delete()
    }

    class MyApp {
        +build(BuildContext context)
    }

    class TaskManageScreen {
        +createState() State
    }

    class TaskManageScreenState {
        -GlobalKey formKey
        -TextEditingController titleController
        -DateTime selectedDate
        -int selectedImpact
        +initState()
        +dispose()
        -_checkUrgentTasksOnStartup() void
        -_showWindowsNotification(String, String) void
        -_saveTask() void
        +build(BuildContext context) Widget
    }

    MyApp --> TaskManageScreen : 起動
    TaskManageScreen --> TaskManageScreenState : 状態管理
    TaskManageScreenState "1" *-- "*" Task : Hiveを通じて管理・監視
```