import SwiftUI

@main
struct KosoujiApp: App {
    @State var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                // 間取り図の紙と曇りの見え方を保つため、ライトに固定する（StudyReel と同じ判断）
                .preferredColorScheme(.light)
                .tint(Palette.mintDeep)
                .task { await model.purchases.load() }
        }
    }
}

/// 今日・間取り・暦・設定。iPhone Duo の内側（regular）では TabView がサイドバーにもなる
struct RootView: View {
    @Environment(AppModel.self) var model

    var body: some View {
        @Bindable var model = model
        Group {
            if model.onboardingDone {
                TabView(selection: $model.tab) {
                    Tab("今日", systemImage: "sparkles", value: AppTab.today) { TodayView() }
                    Tab("間取り", systemImage: "square.split.2x2", value: AppTab.plan) { PlanView() }
                    Tab("暦", systemImage: "calendar", value: AppTab.calendar) { CalendarView() }
                    Tab("設定", systemImage: "gearshape", value: AppTab.settings) { SettingsView() }
                }
                .tabViewStyle(.sidebarAdaptable)
                .transition(.opacity)
            } else {
                OnboardingView().transition(.opacity)
            }
        }
        .sheet(isPresented: $model.showPaywall) {
            PaywallView().presentationBackground(Palette.ground)
        }
    }
}
