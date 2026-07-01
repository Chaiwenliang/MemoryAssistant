import SwiftUI

struct MemoryRowView: View {
    let record: MemoryRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: record.category.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(categoryColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(record.title)
                        .font(.headline)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(record.category.title)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryColor.opacity(0.12))
                        .foregroundStyle(categoryColor)
                        .clipShape(Capsule())
                }

                Text(record.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if !record.tags.isEmpty {
                    Text(record.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var categoryColor: Color {
        switch record.category {
        case .location: return .blue
        case .schedule: return .orange
        case .note: return .green
        }
    }
}
