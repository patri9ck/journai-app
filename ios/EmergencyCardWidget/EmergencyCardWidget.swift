// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import SwiftUI
import WidgetKit

private let appGroupId = "group.xyz.journai.app"

struct EmergencyCardEntry: TimelineEntry {
    let date: Date
    let imagePath: String?
}

struct EmergencyCardProvider: TimelineProvider {
    func placeholder(in context: Context) -> EmergencyCardEntry {
        EmergencyCardEntry(date: Date(), imagePath: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (EmergencyCardEntry) -> Void) {
        completion(currentEntry(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EmergencyCardEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry(in: context)], policy: .never))
    }

    private func currentEntry(in context: Context) -> EmergencyCardEntry {
        let userDefaults = UserDefaults(suiteName: appGroupId)

        userDefaults?.set(Int(context.displaySize.width), forKey: "emergency_card_width")
        userDefaults?.set(Int(context.displaySize.height), forKey: "emergency_card_height")

        return EmergencyCardEntry(date: Date(), imagePath: userDefaults?.string(forKey: "emergency_card"))
    }
}

struct EmergencyCardWidgetView: View {
    let entry: EmergencyCardEntry

    var body: some View {
        Group {
            if let path = entry.imagePath, let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "cross.case")
                        .font(.system(size: 40))
                        .opacity(0.7)
                    Text("Journai")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .widgetURL(URL(string: "journai://emergency-card?homeWidget"))
        .containerBackground(Color(red: 0x34 / 255, green: 0x78 / 255, blue: 0xF0 / 255), for: .widget)
    }
}

@main
struct EmergencyCardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "EmergencyCardWidget", provider: EmergencyCardProvider()) { entry in
            EmergencyCardWidgetView(entry: entry)
        }
        .configurationDisplayName("Journai")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}
