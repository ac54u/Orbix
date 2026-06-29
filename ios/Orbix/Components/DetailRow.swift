import SwiftUI

struct DetailRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var valueColor: Color = AppColors.secondaryLabel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 15))
                .foregroundColor(AppColors.label)
            Spacer()
            Text(value)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#if DEBUG
#Preview {
    DetailRow(icon: "arrow.down", iconColor: .blue, label: "下载速度", value: "10.5 MB/s")
}
#endif
