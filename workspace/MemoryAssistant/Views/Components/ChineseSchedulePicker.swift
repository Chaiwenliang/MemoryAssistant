import SwiftUI

/// 简洁的中文日程时间选择：主界面两行摘要，点开滚轮选择。
struct ChineseSchedulePicker: View {
    @Binding var date: Date

    @State private var showDateSheet = false
    @State private var showTimeSheet = false

    private var chineseCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = 2
        return calendar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            quickDayChips

            pickerRow(label: "日期", value: dateText) {
                showDateSheet = true
            }

            pickerRow(label: "时间", value: timeText) {
                showTimeSheet = true
            }
        }
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .environment(\.calendar, chineseCalendar)
        .sheet(isPresented: $showDateSheet) {
            wheelSheet(
                title: "选择日期",
                components: .date
            ) {
                showDateSheet = false
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTimeSheet) {
            wheelSheet(
                title: "选择时间",
                components: .hourAndMinute
            ) {
                showTimeSheet = false
            }
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
    }

    private var quickDayChips: some View {
        HStack(spacing: 8) {
            quickChip("今天") { date = merge(day: Date(), time: date) }
            quickChip("明天") {
                let tomorrow = chineseCalendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                date = merge(day: tomorrow, time: date)
            }
            Spacer()
        }
    }

    private func quickChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func pickerRow(label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)

                Text(value)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func wheelSheet(
        title: String,
        components: DatePickerComponents,
        onDone: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            VStack {
                DatePicker("", selection: $date, displayedComponents: components)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .environment(\.calendar, chineseCalendar)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: onDone)
                }
            }
        }
    }

    private var dateText: String {
        Self.dateFormatter.string(from: date)
    }

    private var timeText: String {
        Self.timeFormatter.string(from: date)
    }

    private func merge(day: Date, time: Date) -> Date {
        let dayParts = chineseCalendar.dateComponents([.year, .month, .day], from: day)
        let timeParts = chineseCalendar.dateComponents([.hour, .minute], from: time)
        var merged = DateComponents()
        merged.year = dayParts.year
        merged.month = dayParts.month
        merged.day = dayParts.day
        merged.hour = timeParts.hour
        merged.minute = timeParts.minute
        return chineseCalendar.date(from: merged) ?? day
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()
}
