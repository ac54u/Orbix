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
                    Text("种子信息")
                }

                Section {
                    if categories.isEmpty {
                        HStack {
                            Text("下载分类")
                                .foregroundColor(AppColors.secondaryLabel)
                            Spacer()
                            Text("无可用分类")
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                    } else {
                        Picker("下载分类", selection: $category) {
                            Text("无分类").tag("")
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                    }

                    HStack {
                        Text("保存路径")
                            .foregroundColor(AppColors.secondaryLabel)
                        Spacer()
                        TextField("默认路径", text: $savePath)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                } header: {
                    Text("下载设置")
                } footer: {
                    Text("留空则使用 qBittorrent 默认下载路径")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.mainBg)
            .navigationTitle("添加任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppColors.secondaryLabel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定下载") { confirmDownload() }
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
