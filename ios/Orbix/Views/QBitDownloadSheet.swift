import SwiftUI

struct QBitDownloadSheet: View {
    let result: SearchResult
    let categories: [String]
    @State private var category = ""
    @State private var savePath = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.fileName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.label)
                            .lineLimit(2)
                        Text(formatBytes(Int64(result.fileSize)))
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text(OrbixStrings.sectionTorrentInfo)
                }

                Section {
                    if categories.isEmpty {
                        HStack {
                            Text(OrbixStrings.labelDownloadCategory)
                                .foregroundColor(AppColors.secondaryLabel)
                            Spacer()
                            Text(OrbixStrings.miscNoCategories)
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                    } else {
                        Picker(OrbixStrings.labelDownloadCategory, selection: $category) {
                            Text(OrbixStrings.miscNoCategory).tag("")
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                    }

                    HStack {
                        Text(OrbixStrings.labelSavePath)
                            .foregroundColor(AppColors.secondaryLabel)
                        Spacer()
                        TextField(OrbixStrings.phDefaultPath, text: $savePath)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                } header: {
                    Text(OrbixStrings.sectionDownloadSettings)
                } footer: {
                    Text(OrbixStrings.infoDefaultPathHint)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.mainBg)
            .navigationTitle(OrbixStrings.navAddTask)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(OrbixStrings.btnCancel) { dismiss() }
                        .foregroundColor(AppColors.secondaryLabel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(OrbixStrings.btnConfirmDownload) { confirmDownload() }
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func confirmDownload() {
        Task {
            do {
                _ = try await QBitApi.shared.addMagnet(
                    [result.descr],
                    category: category.isEmpty ? nil : category,
                    savePath: savePath.isEmpty ? nil : savePath
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                await MainActor.run { dismiss() }
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

#if DEBUG
#Preview {
    QBitDownloadSheet(result: .demo(), categories: ["Movies", "TV", "Music"])
}
#endif
