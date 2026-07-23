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
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer()
                            ForEach(Array(logger.logItems.enumerated()), id: \.element.id) { index, log in
                                StepCardView(
                                    index: index,
                                    log: log,
                                    isLast: index == logger.logItems.count - 1
                                )
                                .id(log.id)
                                .padding(.horizontal, 6)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: logger.logItems.count)
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

// MARK: - 步骤卡片视图

struct StepCardView: View {
    let index: Int
    let log: LogItem
    let isLast: Bool
    
    // iOS 26 超通透玻璃
    private let cardBg = Color.white.opacity(0.05)
    private let cardBorder = Color.white.opacity(0.10)
    
    private var stepColor: Color {
        switch log.type {
        case .success:
            return Color(red: 0.20, green: 0.78, blue: 0.35)
        case .warning:
            return Color.orange
        case .error:
            return Color.red
        case .info:
            return Color(red: 0.35, green: 0.60, blue: 0.95)
        }
    }
    
    private var iconName: String {
        switch log.type {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .info:
            return "arrow.right.circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(stepColor)
                .frame(width: 20)
            
            Text(log.message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardBg)
                // 顶部微高光
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.clear],
                        startPoint: .top, endPoint: .center
                    ))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(cardBorder, lineWidth: 1)
        )
        .padding(.bottom, isLast ? 0 : 10)
    }
}
