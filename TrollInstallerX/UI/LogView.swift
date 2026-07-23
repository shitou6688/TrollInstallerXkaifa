import SwiftUI

struct StdoutLog: Identifiable, Equatable {
    let message: String
    let id = UUID()
}

struct LogView: View {
    @StateObject var logger = Logger.shared
    @Binding var installationFinished: Bool
    
    @AppStorage("verbose", store: TIXDefaults()) var verbose: Bool = false
    
    let pipe = Pipe()
    let sema = DispatchSemaphore(value: 0)
    @State private var stdoutString = ""
    @State private var stdoutItems = [StdoutLog]()
    
    @State var verboseID = UUID()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    if verbose {
                        ForEach(stdoutItems) { item in
                            HStack {
                                Text(item.message)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.white)
                                    .id(item.id)
                                Spacer()
                            }
                            .frame(width: geometry.size.width)
                        }
                        .onChange(of: stdoutItems) { _ in
                            DispatchQueue.main.async {
                                proxy.scrollTo(stdoutItems.last!.id, anchor: .bottom)
                            }
                        }
                    } else {
                        // 卡片步骤式布局 - 软研风格
                        VStack(spacing: 14) {
                            // 顶部：标题 + 全局进度条
                            VStack(spacing: 12) {
                                HStack {
                                    Text("安装进度")
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Spacer()
                                    HStack(spacing: 6) {
                                        Text("\(logger.logItems.count)")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(Color(red: 0.23, green: 0.51, blue: 0.96))
                                        Text("/ \(max(logger.logItems.count, 5))")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.50))
                                    }
                                }
                                
                                // 全局进度条
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white.opacity(0.08))
                                            .frame(height: 6)
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(LinearGradient(
                                                colors: [
                                                    Color(red: 0.23, green: 0.51, blue: 0.96),
                                                    Color(red: 0.31, green: 0.40, blue: 0.90)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                            .frame(width: geo.size.width * CGFloat(logger.logItems.count) / CGFloat(max(logger.logItems.count, 5)))
                                            .animation(.easeInOut(duration: 0.5), value: logger.logItems.count)
                                    }
                                }
                                .frame(height: 6)
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                            
                            ScrollView {
                                // 步骤卡片列表
                                VStack(spacing: 12) {
                                    ForEach(Array(logger.logItems.enumerated()), id: \.element.id) { index, log in
                                        StepCardView(
                                            stepNumber: index + 1,
                                            totalSteps: max(logger.logItems.count, 5),
                                            log: log,
                                            isCurrent: index == logger.logItems.count - 1 && !installationFinished,
                                            isCompleted: index < logger.logItems.count - 1 || installationFinished
                                        )
                                        .id(log.id)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                                            removal: .opacity
                                        ))
                                    }
                                    
                                    // 完成卡片
                                    if installationFinished {
                                        CompletionCardView()
                                            .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)))
                                    }
                                }
                            }
                        }
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: logger.logItems.count)
                        .onChange(of: geometry.size.height) { _ in
                            DispatchQueue.main.async {
                                withAnimation {
                                    proxy.scrollTo(logger.logItems.last?.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: logger.logItems) { _ in
                            DispatchQueue.main.async {
                                withAnimation {
                                    proxy.scrollTo(logger.logItems.last?.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    if verbose {
                        pipe.fileHandleForReading.readabilityHandler = { fileHandle in
                            let data = fileHandle.availableData
                            if data.isEmpty  {
                                fileHandle.readabilityHandler = nil
                                sema.signal()
                            } else {
                                if let text = String(data: data, encoding: .utf8) {
                                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        stdoutString += text
                                        stdoutItems.append(StdoutLog(message: text))
                                    }
                                }
                            }
                        }
                        print("Redirecting stdout")
                        setvbuf(stdout, nil, _IONBF, 0)
                        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
                    }
                }
            }
            .contextMenu {
                Button {
                    UIPasteboard.general.string = verbose ? stdoutString : Logger.shared.logString
                } label: {
                    Label("复制到剪贴板", systemImage: "doc.on.doc")
                }
            }
            }
        }
    }
}

// MARK: - 步骤卡片视图（卡片步骤式）

struct StepCardView: View {
    let stepNumber: Int
    let totalSteps: Int
    let log: LogItem
    let isCurrent: Bool
    let isCompleted: Bool
    
    private var stepColor: Color {
        if isCompleted {
            return Color(red: 0.20, green: 0.78, blue: 0.35) // 绿色 - 已完成
        } else if isCurrent {
            return Color(red: 0.23, green: 0.51, blue: 0.96) // 蓝色 - 进行中
        } else {
            return Color.gray.opacity(0.5) // 灰色 - 等待中
        }
    }
    
    private var iconName: String {
        if isCompleted {
            return "checkmark.circle.fill"
        } else if isCurrent {
            switch log.type {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "arrow.right.circle.fill"
            }
        } else {
            return "circle"
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // 左侧：步骤编号圆圈
            ZStack {
                Circle()
                    .fill(stepColor.opacity(isCurrent || isCompleted ? 0.20 : 0.10))
                    .frame(width: 44, height: 44)
                
                if isCurrent && !isCompleted {
                    // 当前步骤：显示加载动画
                    Circle()
                        .stroke(stepColor, lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .scaleEffect(1.2)
                        .opacity(0.3)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isCurrent)
                }
                
                VStack(spacing: 2) {
                    Text("\(stepNumber)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(stepColor)
                }
            }
            
            // 中间：内容区域
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(log.message)
                        .font(.system(size: 15, weight: isCurrent ? .semibold : .medium, design: .rounded))
                        .foregroundColor(.white.opacity(isCurrent || isCompleted ? 0.95 : 0.60))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer(minLength: 0)
                    
                    // 右侧状态图标
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(stepColor)
                }
                
                // 进度条（仅当前步骤）
                if isCurrent && !isCompleted {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.10))
                                .frame(height: 3)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(stepColor)
                                .frame(width: geo.size.width * 0.6)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isCurrent)
                        }
                    }
                    .frame(height: 3)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                // 主背景
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isCurrent ? 0.08 : (isCompleted ? 0.06 : 0.04)))
                
                // 当前步骤高亮边框
                if isCurrent {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(stepColor.opacity(0.40), lineWidth: 2)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                
                // 顶部微高光
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(isCurrent ? 0.06 : 0.03), Color.clear],
                        startPoint: .top, endPoint: .center
                    ))
            }
        )
        .shadow(color: isCurrent ? stepColor.opacity(0.15) : .clear, radius: 12, x: 0, y: 4)
    }
}

// MARK: - 完成卡片视图

struct CompletionCardView: View {
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.20, green: 0.78, blue: 0.35).opacity(0.20))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 0.20, green: 0.78, blue: 0.35))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("安装完成")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("TrollStore 已成功安装")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.70))
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.20, green: 0.78, blue: 0.35).opacity(0.08))
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(red: 0.20, green: 0.78, blue: 0.35).opacity(0.30), lineWidth: 2)
            }
        )
        .shadow(color: Color(red: 0.20, green: 0.78, blue: 0.35).opacity(0.15), radius: 12, x: 0, y: 4)
        .scaleEffect(animate ? 1.0 : 0.95)
        .opacity(animate ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animate = true
            }
        }
    }
}
