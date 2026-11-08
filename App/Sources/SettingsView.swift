import SwiftUI
import UserNotifications

/// 毎日のお知らせ（端末の中だけ。サーバーなし）
enum Reminder {
    static let id = "kosouji.daily"

    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 許可を求めて、毎日 hour:minute に登録する。許可がなければ false
    static func schedule(hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = "今日の小掃除"
        content.body = "今日の 1 か所が決まっています。10 分ほどで、家がひとつ澄みます。"
        var date = DateComponents()
        date.hour = hour
        date.minute = minute
        let request = UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true))
        try? await center.add(request)
        return true
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @AppStorage("kosouji.reminderOn") private var reminderOn = false
    @AppStorage("kosouji.reminderMinutes") private var reminderMinutes = 20 * 60
    @State private var denied = false
    @State private var confirmReset = false
    @State private var showAdd = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Picker("1 か所の時間", selection: Binding(get: { model.household.budget }, set: { model.setBudget($0) })) {
                        ForEach(AppModel.budgets, id: \.self) { Text("\($0) 分まで").tag($0) }
                    }
                    if model.isPro {
                        Picker("1 日の数", selection: Binding(get: { model.household.dailyCount }, set: { model.setDailyCount($0) })) {
                            ForEach(AppModel.proDailyCounts, id: \.self) { Text("\($0) か所").tag($0) }
                        }
                    } else {
                        lockedRow("1 日に 2〜3 か所（年末に追い込みたい日に）")
                    }
                } header: {
                    Text("今日の札")
                } footer: {
                    Text("時間の上限を変えると、今日の札も選び直します。")
                }

                Section {
                    ForEach(Room.allCases) { room in
                        Toggle(room.name, isOn: Binding(
                            get: { !model.household.hiddenRooms.contains(room) },
                            set: { model.setRoom(room, present: $0) }
                        ))
                    }
                } header: {
                    Text("家の部屋")
                } footer: {
                    Text("ない部屋を外すと、その部屋の場所は札に出なくなります。")
                }

                Section("自分の場所") {
                    if model.isPro {
                        ForEach(model.household.customSpots) { spot in
                            HStack {
                                Text(spot.name)
                                Spacer()
                                Text("\(spot.room.name)・\(spot.intervalText)").font(.caption).foregroundStyle(Palette.sub)
                            }
                        }
                        Button("場所を足す") { showAdd = true }
                    } else {
                        lockedRow("自分の家だけの場所を足す")
                    }
                }

                Section {
                    Toggle("毎日のお知らせ", isOn: $reminderOn)
                    if reminderOn {
                        DatePicker("時刻", selection: Binding(get: { reminderDate }, set: { setReminder($0) }), displayedComponents: .hourAndMinute)
                    }
                    if denied {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("お知らせが許可されていません。iPhone の設定で、このアプリの通知をオンにしてください。")
                                .font(.footnote).foregroundStyle(Palette.sub)
                            Button("設定を開く") {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                            }
                        }
                    }
                    Toggle("振動", isOn: $model.hapticsOn)
                } header: {
                    Text("お知らせと振動")
                }

                Section("Pro") {
                    if model.isPro {
                        Label("Pro を使っています。ありがとうございます。", systemImage: "checkmark.seal")
                            .foregroundStyle(Palette.mintDeep)
                    } else {
                        Button("Pro でできること") { model.showPaywall = true }
                    }
                    Button("購入を復元") { Task { await model.purchases.restore() } }
                }

                Section("このアプリについて") {
                    Button("使い方をもう一度見る") { model.onboardingDone = false }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("記録は端末の中だけ").font(.subheadline)
                        Text("掃除した日と設定は、この iPhone の中だけに保存します。アカウント・広告・解析はありません。")
                            .font(.footnote).foregroundStyle(Palette.sub)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("薬剤について").font(.subheadline)
                        Text("塩素系と酸性（クエン酸など）は混ぜないでください。素材によって使えない物があります。製品の表示と、家電の取扱説明書を先に確かめてください。")
                            .font(.footnote).foregroundStyle(Palette.sub)
                    }
                    Button("記録をすべて消す", role: .destructive) { confirmReset = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.ground)
            .navigationTitle("設定")
            .confirmationDialog("掃除した記録と設定を消します。元に戻せません。", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("すべて消す", role: .destructive) { model.resetAll() }
            }
            .sheet(isPresented: $showAdd) {
                AddSpotView().presentationBackground(Palette.ground)
            }
            .onChange(of: reminderOn) { _, on in
                if on { setReminder(reminderDate) } else { Reminder.cancel(); denied = false }
            }
            .task {
                if reminderOn { denied = await Reminder.status() == .denied }
            }
        }
    }

    private var reminderDate: Date {
        Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: Date()) ?? Date()
    }

    private func setReminder(_ date: Date) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        reminderMinutes = (c.hour ?? 20) * 60 + (c.minute ?? 0)
        Task {
            let ok = await Reminder.schedule(hour: reminderMinutes / 60, minute: reminderMinutes % 60)
            denied = !ok
            if !ok { reminderOn = false }
        }
    }

    private func lockedRow(_ text: String) -> some View {
        Button { model.showPaywall = true } label: {
            HStack {
                Text(text).foregroundStyle(Palette.ink)
                Spacer()
                Image(systemName: "lock").foregroundStyle(Palette.mintDeep)
            }
        }
    }
}

/// Pro：自分の場所を足す
struct AddSpotView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var room: Room = .living
    @State private var interval = 30
    @State private var minutes = 10

    var body: some View {
        NavigationStack {
            Form {
                TextField("場所の名前（例：金魚の水槽）", text: $name)
                Picker("部屋", selection: $room) {
                    ForEach(Room.allCases) { Text($0.name).tag($0) }
                }
                Picker("間隔", selection: $interval) {
                    ForEach([7, 14, 30, 60, 90, 180, 365], id: \.self) { Text(Spot.intervalText($0)).tag($0) }
                }
                Picker("時間", selection: $minutes) {
                    ForEach([5, 10, 15, 20], id: \.self) { Text("\($0) 分").tag($0) }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("場所を足す")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("やめる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("足す") {
                        model.addCustomSpot(name: name, room: room, interval: interval, minutes: minutes)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
