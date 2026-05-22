import SwiftUI

// MARK: - macOS 传输列表

struct TransferListView: View {
    @EnvironmentObject var manager: FeiQiuManager
    
    var body: some View {
        Group {
            if manager.transferTasks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("暂无传输任务")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(manager.transferTasks) { task in
                    TransferRow(task: task)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("文件传输")
    }
}

struct TransferRow: View {
    @ObservedObject var task: FileTransferTask
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.direction == .sent ? "arrow.up.doc.fill" : "arrow.down.doc.fill")
                .foregroundColor(.orange)
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.fileName)
                    .font(.system(size: 13, weight: .medium))
                
                ProgressView(value: task.progress)
                    .tint(.orange)
                    .frame(maxWidth: 200)
                
                HStack(spacing: 8) {
                    Text(stateText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    if task.state == .transferring {
                        Text(task.formattedSpeed)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(task.formattedTransferred) / \(task.formattedSize)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 操作按钮
            if task.state == .transferring {
                Button { /* TODO: 暂停 */ } label: {
                    Image(systemName: "pause.circle")
                }
                .buttonStyle(.plain)
                .help("暂停")
            }
            
            if task.state == .paused {
                Button { /* TODO: 继续 */ } label: {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.plain)
                .help("继续")
            }
        }
        .padding(.vertical, 4)
    }
    
    private var stateText: String {
        switch task.state {
        case .waiting: return "等待中"
        case .transferring: return "传输中 \(Int(task.progress * 100))%"
        case .paused: return "已暂停"
        case .completed: return "✅ 已完成"
        case .failed: return "❌ 失败"
        case .cancelled: return "已取消"
        }
    }
}
