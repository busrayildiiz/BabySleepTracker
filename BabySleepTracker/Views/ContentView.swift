import SwiftUI

struct ContentView: View {

    @State private var selectedTab: Tab = .home
    @State private var showAddSheet = false
    @State private var records: [SleepRecord] = []


    enum Tab {
        case home, history, insights, settings
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Tab content — hepsi yüklenmiş, sadece görünürlük değişiyor ──
            ZStack {
                SleepListView()
                    .opacity(selectedTab == .home ? 1 : 0)
                    .allowsHitTesting(selectedTab == .home)

                HistoryView()
                    .opacity(selectedTab == .history ? 1 : 0)
                    .allowsHitTesting(selectedTab == .history)

                InsightsPlaceholderView()
                    .opacity(selectedTab == .insights ? 1 : 0)
                    .allowsHitTesting(selectedTab == .insights)

                SettingsPlaceholderView()
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .settings)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 72)
            }

            // ── Custom Tab Bar ────────────────────────────────
            customTabBar
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showAddSheet) {
            AddRecordView(
                defaultDate: Date(),
                vm: AddRecordViewModel(),
                onSave: { _ in }
            )
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabItem(icon: "house", label: "Home", tab: .home)
            tabItem(icon: "calendar.badge.clock", label: "History", tab: .history)

            // Center + button
            Button {
                showAddSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.22))
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.orange)
                }
            }
            .frame(maxWidth: .infinity)
            .offset(y: -8)

            tabItem(icon: "chart.line.uptrend.xyaxis", label: "Insights", tab: .insights)
            tabItem(icon: "gearshape", label: "Settings", tab: .settings)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(icon: String, label: String, tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? filledIcon(icon) : icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.orange : Color(uiColor: .secondaryLabel))
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.orange : Color(uiColor: .secondaryLabel))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func filledIcon(_ icon: String) -> String {
        ["house": "house.fill",
         "gearshape": "gearshape.fill"][icon] ?? icon
    }
}

// MARK: - Placeholders

struct HistoryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange.opacity(0.5))
                Text("History").font(.title2.weight(.bold))
                Text("Coming soon").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct InsightsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange.opacity(0.5))
                Text("Insights").font(.title2.weight(.bold))
                Text("Coming soon").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange.opacity(0.5))
                Text("Settings").font(.title2.weight(.bold))
                Text("Coming soon").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
