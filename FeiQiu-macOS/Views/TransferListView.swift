import SwiftUI

// MARK: - macOS 传输列表

struct TransferListView: View {
    @EnvironmentObject var manager: FeiQiuManager
    
    var body: some View {
        Group {
            if manager.transferTasks.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(manager.transferTasks) { task in
                        TransferRow(task: task)
                            .contextMenu {
                                transferContextMenu(for: task)
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("文件传输")
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无传输任务")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func transferContextMenu(for task: FileTransferTask) -> some View {
        if task.state == .completed, let saveURL = task.saveURL {
            Button("打开文件") {
                NSWorkspace.shared.open(saveURL)
            }
            Button("打开所在文件夹") {
                NSWorkspace.shared.selectFile(saveURL.path, inFileViewerRootedAtPath: "")
            }
            Divider()
        }
        
        Button("在 Finder 中显示") {
            if let saveURL = task.saveURL {
                NSWorkspace.shared.selectFile(saveURL.path, inFileViewerRootedAtPath: "")
            }
        }
        .disabled(task.saveURL == nil)
        
        if task.state == .failed {
            Button("重新下载") {
                // TODO: 重试
            }
        }
        
        if task.state == .transferring {
            Divider()
            Button("取消") {
                task.state = .cancelled
            }
        }
        
        if task.state == .completed || task.state == .failed || task.state == .cancelled {
            Divider()
            Button("清除记录") {
                manager.transferTasks.removeAll { $0.id == task.id }
            }
        }
    }
}

struct TransferRow: View {
    @ObservedObject var task: FileTransferTask
    
    var body: some View {
        HStack(spacing: 12) {
            // 方向图标
            Image(systemName: task.direction == .sent ? "arrow.up.doc.fill" : "arrow.down.doc.fill")
                .foregroundColor(task.direction == .sent ? .blue : .orange)
                .font(.system(size: 20))
            
            // 文件信息 + 进度
            VStack(alignment: .leading, spacing: 4) {
                // 文件名
                HStack {
                    Text(task.fileName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 状态标签
                    stateBadge
                }
                
                // 进度条
                if task.state == .transferring {
                    ProgressView(value: task.progress)
                        .tint(.orange)
                        .frame(maxWidth: .infinity)
                }
                
                // 详情
                HStack(spacing: 12) {
                    Text(stateText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    if task.state == .transferring {
                        Text(task.formattedSpeed)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(task.remainingTime)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(task.formattedTransferred) / \(task.formattedSize)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    if task.direction == .sent {
                        Text("→ \(task.remoteIP)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        Text("← \(task.remoteIP)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 快捷操作
            if task.state == .completed, let saveURL = task.saveURL {
                Button {
                    NSWorkspace.shared.open(saveURL)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.plain)
                .help("打开文件")
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var stateBadge: some View {
        switch task.state {
        case .waiting:
            Text("等待中")
                .font(.system(size: 10))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .clipShape(Capsule())
        case .transferring:
            Text("\(Int(task.progress * 100))%")
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .clipShape(Capsule())
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 14))
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 14))
        case .paused:
            Text("暂停")
                .font(.system(size: 10))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.yellow.opacity(0.2))
                .foregroundColor(.yellow)
                .clipShape(Capsule())
        case .cancelled:
            Text("取消")
                .font(.system(size: 10))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.secondary)
                .clipShape(Capsule())
        }
    }
    
    private var stateText: String {
        switch task.state {
        case .waiting: return "等待中"
        case .transferring: return "传输中"
        case .paused: return "已暂停"
        case .completed: return "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }
}
