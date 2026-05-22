import SwiftUI

// MARK: - 传输任务列表

struct TransferListView: View {
    @EnvironmentObject var manager: FeiQiuManager
    
    var body: some View {
        Group {
            if manager.transferTasks.isEmpty {
                emptyState
            } else {
                List(manager.transferTasks) { task in
                    TransferRow(task: task)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("文件传输")
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("暂无传输任务")
                .foregroundColor(.secondary)
        }
    }
}

struct TransferRow: View {
    @ObservedObject var task: FileTransferTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: task.direction == .sent ? "arrow.up.doc" : "arrow.down.doc")
                    .foregroundColor(.orange)
                Text(task.fileName).font(.headline)
                Spacer()
                Text(task.formattedSize).font(.caption).foregroundColor(.secondary)
            }
            
            ProgressView(value: task.progress)
                .tint(.orange)
            
            HStack {
                Text(stateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if task.state == .transferring {
                    Text(task.formattedSpeed)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var stateText: String {
        switch task.state {
        case .waiting: return "等待中"
        case .transferring: return "传输中 \(Int(task.progress * 100))%"
        case .paused: return "已暂停"
        case .completed: return "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }
}
