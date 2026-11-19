//
//  DashboardSheet.swift
//  BoomOrBonus
//
//  我的紀錄 (02-screens-ux.md §10, prototype showDash): a bottom panel with four tabs (總覽 / 今日挑戰 / 難度 / 祝福),
//  the empty state with 「先看範例」, and sample data under a gold 「範例資料，不是你的紀錄」 label.
//  The sample is only ever shown while there is no real data; the real save is never touched here.
//  The tabs are pinned above the scrolling content and the buttons below it, so they stay on screen on an iPhone SE.
//  The legacy 「舊版紀錄」 link (04 §5, decided: keep the old daily records) opens the existing DailyRecordsView.
//

import SwiftUI

struct DashboardSheet: View {
    let stats: Stats
    let daily: [Int: DailyRecord]
    let unlock: Int
    let today: Int
    let hasRecords: Bool
    /// RecordID raw values broken in the run on screen (「這局剛破」).
    let broken: [String]
    let close: () -> Void

    enum Tab: String, CaseIterable {
        case overview, daily, levels, blessings

        var title: LocalizedStringKey {
            switch self {
            case .overview: return "總覽"
            case .daily: return "今日挑戰"
            case .levels: return "難度"
            case .blessings: return "祝福"
            }
        }
    }

    @State private var tab = Tab.overview
    @State private var showSample = false
    @State private var showLegacy = false
    @StateObject private var legacyRecords = GameRecordManager.live()

    /// 03 §5: the old daily records stay reachable, but the link only shows when there are some.
    private var hasLegacy: Bool { !legacyRecords.records.isEmpty }

    private var sample: (stats: Stats, daily: [Int: DailyRecord], unlock: Int) { SampleData.make(today: today) }

    var body: some View {
        Group {
            if !hasRecords && !showSample {
                emptyState
            } else {
                populated
            }
        }
        .sheet(isPresented: $showLegacy) {
            DailyRecordsView(recordManager: legacyRecords)
        }
    }

    // MARK: Empty state (02 §10.5)

    private var emptyState: some View {
        SheetContainer {
            title
            SheetBody(text: Text("打完第一局後，這裡會出現你的最高分、最長連中、今日挑戰第幾次破關等紀錄。每一項都有下一個目標可以挑戰。"))
                .accessibilityIdentifier("dash.empty")
            HStack(spacing: 8) {
                Button("先看範例") { showSample = true; tab = .overview }
                    .buttonStyle(SheetButtonStyle())
                    .accessibilityIdentifier("dash.sample")
                Button("開始玩", action: close)
                    .buttonStyle(SheetButtonStyle(primary: true))
                    .accessibilityIdentifier("dash.start")
            }
            .padding(.top, 4)
            if hasLegacy { legacyLink }
        }
    }

    // MARK: Tabs

    private var populated: some View {
        let data = showSample ? sample : (stats, daily, unlock)
        return SheetScaffold {
            VStack(alignment: .leading, spacing: 8) {
                title
                if showSample {
                    Text("範例資料，不是你的紀錄")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.goldText)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Theme.gold, in: RoundedRectangle(cornerRadius: 6))
                        .accessibilityIdentifier("dash.badge.sample")
                }
                tabBar
            }
        } list: {
            VStack(alignment: .leading, spacing: 10) {
                switch tab {
                case .overview:
                    OverviewTab(stats: data.0, unlock: data.2, broken: showSample ? [] : broken)
                case .daily:
                    DailyTab(log: data.1, today: today)
                case .levels:
                    LevelsTab(stats: data.0, unlock: data.2)
                case .blessings:
                    BlessingsTab(stats: data.0)
                }
                if hasLegacy { legacyLink }
            }
        } footer: {
            HStack(spacing: 8) {
                if showSample {
                    Button("看我的紀錄") { showSample = false }
                        .buttonStyle(SheetButtonStyle(height: 46))
                        .accessibilityIdentifier("dash.back")
                }
                Button("回到遊戲", action: close)
                    .buttonStyle(SheetButtonStyle(primary: true, height: 46))
                    .accessibilityIdentifier("dash.close")
            }
        }
        .id(tab)        // a new tab starts at the top, not where the last one was scrolled to
    }

    private var title: some View {
        SheetTitle(small: Text("INTUITION++"), big: Text("我的紀錄"))
            .accessibilityIdentifier("dash.title")
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    Text(t.title)
                        .font(.system(size: 13.5, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(tab == t ? Color.white : Theme.sheetText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(tab == t ? Theme.sheetPrimary : Theme.sheetButton, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == t ? .isSelected : [])
                .accessibilityIdentifier("dash.tab.\(t.rawValue)")
            }
        }
    }

    private var legacyLink: some View {
        Button { showLegacy = true } label: {
            Text("舊版紀錄")
                .font(.system(size: 13, weight: .semibold))
                .underline()
                .foregroundStyle(Theme.sheetMuted)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityHint("打開更新前的每日最高紀錄")
        .accessibilityIdentifier("dash.legacy")
    }
}

// MARK: - Shared pieces

/// One of the 2x2 number tiles: label, big value, one line under it.
struct DashTile: View {
    let label: Text
    let value: String
    let sub: String
    let id: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            label.font(.system(size: 12)).foregroundStyle(Theme.sheetMuted).lineLimit(1).minimumScaleFactor(0.8)
            Text(verbatim: value)
                .font(Theme.number(24))
                .foregroundStyle(Theme.sheetText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(verbatim: sub.isEmpty ? " " : sub)
                .font(.system(size: 11)).foregroundStyle(Theme.sheetMuted).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(hex: 0xF0F1FA), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dash.tile.\(id)")
    }
}

struct DashTiles<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) { content }
    }
}

/// A small grey table in the sheet style (難度 and 祝福 tabs).
struct DashTable<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 9) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.system(size: 13))
            .foregroundStyle(Theme.sheetText)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color(hex: 0xF0F1FA), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// "—" for nothing yet, otherwise the grouped number.
func dashNumber(_ n: Int?) -> String { n.map { $0 > 0 ? Fmt.int($0) : "—" } ?? "—" }

func dashPercent(_ a: Int, of b: Int) -> String {
    b > 0 ? "\(Int((Double(a) / Double(b) * 100).rounded()))%" : "—"
}

extension GameRecordManager {
    /// The old records from UserDefaults. A Debug `-seed ... -legacySample` launch shows three fixed ones instead,
    /// so QA never has to write the real UserDefaults.
    @MainActor static func live() -> GameRecordManager {
        let m = GameRecordManager()
        #if DEBUG
        if GameViewModel.debugLaunchSeed() != nil, DebugHooks.parse().legacySample {
            // Oldest first, as the old writer appends them.
            m.records = [("2025年8月30日", 41), ("2025年9月5日", 63), ("2025年10月2日", 77)].map {
                GameRecord(id: UUID(), date: $0.0, score: $0.1, finalValue: $0.1 * 10, levelsPassed: 5, IntuitionLevel: "L\($0.1 / 10)")
            }
        }
        #endif
        return m
    }
}
