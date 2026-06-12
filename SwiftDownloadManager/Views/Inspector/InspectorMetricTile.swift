import SwiftUI

struct InspectorMetricTile: View {
  let icon: String
  let title: String
  let value: String
  var tint: Color = .accentColor
  var valueColor: Color = .primary

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 5) {
        Image(systemName: icon)
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(tint)
        Text(title)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Text(value)
        .font(.system(size: 13, weight: .semibold).monospacedDigit())
        .foregroundStyle(valueColor)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.primary.opacity(0.045))
        .overlay {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }
  }
}

struct InspectorMetricTileGrid: View {
  let tiles: [InspectorMetricTileData]

  var body: some View {
    LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
      ],
      alignment: .leading,
      spacing: 8
    ) {
      ForEach(tiles) { tile in
        InspectorMetricTile(
          icon: tile.icon,
          title: tile.title,
          value: tile.value,
          tint: tile.tint,
          valueColor: tile.valueColor
        )
      }
    }
  }
}

struct InspectorMetricTileData: Identifiable {
  let id = UUID()
  let icon: String
  let title: String
  let value: String
  var tint: Color = .accentColor
  var valueColor: Color = .primary
}
