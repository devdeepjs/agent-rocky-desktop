import AppKit
import SwiftUI

struct RockyRootView: View {
    @ObservedObject var viewModel: RockyViewModel
    @State private var isHovering = false

    private var terminalVisible: Bool {
        isHovering || viewModel.isThinking || !viewModel.input.isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if terminalVisible {
                RockyTerminal(
                    input: $viewModel.input,
                    model: $viewModel.model,
                    lines: viewModel.terminalLines,
                    isThinking: viewModel.isThinking,
                    isUsingFallback: viewModel.isUsingFallback,
                    brainStatus: viewModel.brainStatus,
                    conversations: viewModel.conversations,
                    activeConversationID: viewModel.activeConversationID,
                    send: viewModel.send,
                    newChat: viewModel.newChat,
                    selectChat: viewModel.selectChat,
                    deleteChat: viewModel.deleteActiveChat,
                    quit: viewModel.quit
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
                .padding(.bottom, 118)
            }

            RockyCreatureView(mood: viewModel.mood, animation: viewModel.animation, isAwake: terminalVisible)
                .frame(width: 156, height: 132)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.poke()
                }
                .offset(y: terminalVisible ? 6 : -2)

            WindowResizeGrip()
                .frame(width: 30, height: 30)
                .opacity(terminalVisible ? 0.95 : 0.28)
                .padding(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 240, idealWidth: 360, maxWidth: 620, minHeight: 250, idealHeight: 390, maxHeight: 720)
        .background(Color.clear)
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                isHovering = hovering
            }
        }
    }
}

private struct RockyTerminal: View {
    @Binding var input: String
    @Binding var model: String
    let lines: [String]
    let isThinking: Bool
    let isUsingFallback: Bool
    let brainStatus: String
    let conversations: [RockyConversationSummary]
    let activeConversationID: String
    let send: () -> Void
    let newChat: () -> Void
    let selectChat: (String) -> Void
    let deleteChat: () -> Void
    let quit: () -> Void

    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .id(index)
                                .foregroundStyle(line.hasPrefix(">") ? Color(red: 0.78, green: 0.97, blue: 1.0) : Color(red: 0.63, green: 1.0, blue: 0.58))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .onChange(of: lines.count) { _, _ in
                    if let last = lines.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            Divider()
                .overlay(Color(red: 0.24, green: 0.55, blue: 0.35).opacity(0.65))

            HStack(spacing: 7) {
                Text("$")
                    .foregroundStyle(Color(red: 0.86, green: 1.0, blue: 0.42))

                TextField("talk to rocky", text: $input)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .foregroundStyle(.white)
                    .onSubmit(send)

                Button(action: send) {
                    Image(systemName: isThinking ? "hourglass" : "return")
                        .font(.system(size: 12, weight: .black))
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(TerminalIconButtonStyle(color: Color(red: 0.65, green: 1.0, blue: 0.54)))
                .disabled(isThinking || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .frame(minWidth: 220, idealWidth: 330, maxWidth: .infinity, minHeight: 126, idealHeight: 178, maxHeight: .infinity)
        .background(
            PixelTerminalShape(cut: 10)
                .fill(Color(red: 0.02, green: 0.035, blue: 0.025).opacity(0.94))
        )
        .overlay(
            PixelTerminalShape(cut: 10)
                .stroke(Color(red: 0.42, green: 1.0, blue: 0.54).opacity(0.55), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.72), radius: 18, x: 0, y: 12)
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isUsingFallback ? Color(red: 1.0, green: 0.25, blue: 0.18) : Color(red: 0.34, green: 1.0, blue: 0.45))
                .frame(width: 8, height: 8)
                .shadow(color: isUsingFallback ? .red.opacity(0.7) : .green.opacity(0.7), radius: 5)
                .help(brainStatus)

            Text("agent-rocky.term")
                .foregroundStyle(Color(red: 0.78, green: 1.0, blue: 0.72))

            Spacer()

            TextField("default", text: $model)
                .textFieldStyle(.plain)
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 62)
                .help("Model override. Leave blank for Codex default.")

            Menu {
                if conversations.isEmpty {
                    Text("No chats yet")
                } else {
                    ForEach(conversations) { conversation in
                        Button {
                            selectChat(conversation.id)
                        } label: {
                            Label(
                                conversation.title,
                                systemImage: conversation.id == activeConversationID ? "checkmark.circle.fill" : "bubble.left"
                            )
                        }
                    }

                    Divider()

                    Button(role: .destructive, action: deleteChat) {
                        Label("Delete current", systemImage: "trash")
                    }
                    .disabled(activeConversationID.isEmpty)
                }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10, weight: .black))
                    .frame(width: 24, height: 20)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Old chats")

            Button(action: newChat) {
                Image(systemName: "plus.bubble")
                    .font(.system(size: 10, weight: .black))
                    .frame(width: 24, height: 20)
            }
            .buttonStyle(TerminalIconButtonStyle(color: Color(red: 0.44, green: 0.85, blue: 1.0)))
            .help("New chat")

            Button(action: quit) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .black))
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(TerminalIconButtonStyle(color: Color(red: 1.0, green: 0.36, blue: 0.28)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(red: 0.04, green: 0.12, blue: 0.07).opacity(0.96))
    }
}

private struct TerminalIconButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.black.opacity(0.86))
            .background(
                Rectangle()
                    .fill(color.opacity(configuration.isPressed ? 0.64 : 0.94))
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

private struct PixelTerminalShape: Shape {
    let cut: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

private struct WindowResizeGrip: View {
    @State private var startFrame: NSRect?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ForEach(0..<3, id: \.self) { index in
                Rectangle()
                    .fill(Color.white.opacity(0.28 + Double(index) * 0.14))
                    .frame(width: CGFloat(8 + index * 6), height: 2)
                    .rotationEffect(.degrees(-45))
                    .offset(x: CGFloat(-2 - index * 5), y: CGFloat(-2 - index * 5))
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    resize(with: value.translation)
                }
                .onEnded { _ in
                    startFrame = nil
                }
        )
        .help("Drag to resize")
    }

    private func resize(with translation: CGSize) {
        guard let window = NSApp.windows.first(where: { $0.title == "Agent Rocky" }) else {
            return
        }

        if startFrame == nil {
            startFrame = window.frame
        }

        guard let startFrame else {
            return
        }

        let minSize = window.minSize
        let maxSize = window.maxSize
        let newWidth = min(max(startFrame.width + translation.width, minSize.width), maxSize.width)
        let newHeight = min(max(startFrame.height + translation.height, minSize.height), maxSize.height)
        let top = startFrame.origin.y + startFrame.height
        let nextFrame = NSRect(
            x: startFrame.origin.x,
            y: top - newHeight,
            width: newWidth,
            height: newHeight
        )

        window.setFrame(nextFrame, display: true)
    }
}

private struct RockyCreatureView: View {
    let mood: RockyMood
    let animation: RockyAnimation
    let isAwake: Bool

    @State private var gaitFrame = false
    @State private var blink = false
    @State private var glowPulse = false

    private let canvas = CGSize(width: 180, height: 150)

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / canvas.width, geometry.size.height / canvas.height)
            let originX = (geometry.size.width - canvas.width * scale) / 2
            let originY = (geometry.size.height - canvas.height * scale) / 2

            ZStack(alignment: .topLeading) {
                shadow

                backLimbs

                RockyShellShape()
                    .fill(shellGradient)
                    .shadow(color: .black.opacity(0.35), radius: 7, x: 0, y: 7)

                facets

                RockyShellShape()
                    .stroke(Color(red: 0.07, green: 0.045, blue: 0.025), lineWidth: 3.4)

                mineralLights

                frontLimbs
            }
            .frame(width: canvas.width, height: canvas.height)
            .scaleEffect(scale, anchor: .topLeading)
            .offset(x: originX, y: originY + verticalMotion)
            .scaleEffect(isAwake ? 1.04 : 1.0)
            .animation(.easeInOut(duration: 0.16), value: isAwake)
            .animation(.easeInOut(duration: isAwake ? 0.42 : 0.72).repeatForever(autoreverses: true), value: gaitFrame)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: glowPulse)
            .onAppear {
                gaitFrame = true
                glowPulse = true
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2.8))
                    blink = true
                    try? await Task.sleep(for: .milliseconds(140))
                    blink = false
                }
            }
        }
    }

    private var shadow: some View {
        Ellipse()
            .fill(.black.opacity(0.34))
            .frame(width: 106, height: 17)
            .blur(radius: 4)
            .offset(x: 37, y: 123)
    }

    private var verticalMotion: CGFloat {
        switch animation {
        case .bounce:
            return gaitFrame ? -5 : -2
        case .wave:
            return gaitFrame ? -3 : -1
        case .pulse:
            return gaitFrame ? -4 : -2
        case .shake:
            return gaitFrame ? -1 : 1
        default:
            return gaitFrame ? -2 : 0
        }
    }

    private var shellGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.66, blue: 0.28),
                Color(red: 0.63, green: 0.34, blue: 0.12),
                Color(red: 0.24, green: 0.13, blue: 0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backLimbs: some View {
        Group {
            RockyLimb(
                resting: [CGPoint(x: 68, y: 72), CGPoint(x: 46, y: 80), CGPoint(x: 27, y: 111)],
                stepping: [CGPoint(x: 68, y: 72), CGPoint(x: 43, y: 76), CGPoint(x: 22, y: 104)],
                active: gaitFrame,
                lineWidth: 8,
                tint: Color(red: 0.46, green: 0.25, blue: 0.10)
            )
            RockyLimb(
                resting: [CGPoint(x: 112, y: 72), CGPoint(x: 135, y: 81), CGPoint(x: 154, y: 112)],
                stepping: [CGPoint(x: 112, y: 72), CGPoint(x: 137, y: 77), CGPoint(x: 159, y: 105)],
                active: !gaitFrame,
                lineWidth: 8,
                tint: Color(red: 0.46, green: 0.25, blue: 0.10)
            )
            RockyLimb(
                resting: [CGPoint(x: 90, y: 96), CGPoint(x: 86, y: 118), CGPoint(x: 79, y: 139)],
                stepping: [CGPoint(x: 90, y: 96), CGPoint(x: 92, y: 116), CGPoint(x: 101, y: 139)],
                active: gaitFrame,
                lineWidth: 7.2,
                tint: Color(red: 0.40, green: 0.21, blue: 0.08)
            )
        }
    }

    private var frontLimbs: some View {
        Group {
            RockyLimb(
                resting: [CGPoint(x: 65, y: 90), CGPoint(x: 45, y: 101), CGPoint(x: 33, y: 133)],
                stepping: [CGPoint(x: 65, y: 90), CGPoint(x: 50, y: 103), CGPoint(x: 48, y: 135)],
                active: !gaitFrame,
                lineWidth: 8.5,
                tint: Color(red: 0.62, green: 0.36, blue: 0.15)
            )
            RockyLimb(
                resting: [CGPoint(x: 115, y: 90), CGPoint(x: 136, y: 102), CGPoint(x: 147, y: 133)],
                stepping: [CGPoint(x: 115, y: 90), CGPoint(x: 131, y: 104), CGPoint(x: 132, y: 135)],
                active: gaitFrame,
                lineWidth: 8.5,
                tint: Color(red: 0.62, green: 0.36, blue: 0.15)
            )
            RockyLimb(
                resting: [CGPoint(x: 70, y: 57), CGPoint(x: 52, y: 40), CGPoint(x: 42, y: 19)],
                stepping: [CGPoint(x: 70, y: 57), CGPoint(x: 49, y: 36), CGPoint(x: 38, y: 15)],
                active: gaitFrame,
                lineWidth: 7.2,
                tint: Color(red: 0.72, green: 0.43, blue: 0.17),
                tipColor: moodAccent
            )
            RockyLimb(
                resting: [CGPoint(x: 110, y: 57), CGPoint(x: 129, y: 40), CGPoint(x: 139, y: 19)],
                stepping: [CGPoint(x: 110, y: 57), CGPoint(x: 132, y: 36), CGPoint(x: 143, y: 15)],
                active: !gaitFrame,
                lineWidth: 7.2,
                tint: Color(red: 0.72, green: 0.43, blue: 0.17),
                tipColor: moodAccent
            )
        }
    }

    private var facets: some View {
        Group {
            RockyFacet(points: [CGPoint(x: 61, y: 47), CGPoint(x: 89, y: 37), CGPoint(x: 96, y: 70), CGPoint(x: 67, y: 75)], color: Color(red: 1.0, green: 0.73, blue: 0.34).opacity(0.72))
            RockyFacet(points: [CGPoint(x: 92, y: 38), CGPoint(x: 121, y: 49), CGPoint(x: 111, y: 76), CGPoint(x: 96, y: 70)], color: Color(red: 0.78, green: 0.42, blue: 0.16).opacity(0.68))
            RockyFacet(points: [CGPoint(x: 48, y: 70), CGPoint(x: 67, y: 75), CGPoint(x: 73, y: 109), CGPoint(x: 53, y: 97)], color: Color(red: 0.35, green: 0.18, blue: 0.07).opacity(0.46))
            RockyFacet(points: [CGPoint(x: 67, y: 75), CGPoint(x: 96, y: 70), CGPoint(x: 102, y: 111), CGPoint(x: 73, y: 109)], color: Color(red: 0.66, green: 0.36, blue: 0.14).opacity(0.62))
            RockyFacet(points: [CGPoint(x: 96, y: 70), CGPoint(x: 131, y: 73), CGPoint(x: 124, y: 99), CGPoint(x: 102, y: 111)], color: Color(red: 0.24, green: 0.12, blue: 0.05).opacity(0.45))
            RockyLine(points: [CGPoint(x: 87, y: 41), CGPoint(x: 95, y: 70), CGPoint(x: 103, y: 110)], lineWidth: 2.0, color: Color.black.opacity(0.28))
            RockyLine(points: [CGPoint(x: 60, y: 68), CGPoint(x: 95, y: 70), CGPoint(x: 126, y: 74)], lineWidth: 1.8, color: Color.white.opacity(0.18))
            RockyLine(points: [CGPoint(x: 76, y: 55), CGPoint(x: 82, y: 66), CGPoint(x: 77, y: 80)], lineWidth: 1.6, color: Color(red: 0.07, green: 0.04, blue: 0.02).opacity(0.5))
            RockyLine(points: [CGPoint(x: 113, y: 58), CGPoint(x: 106, y: 76), CGPoint(x: 112, y: 91)], lineWidth: 1.8, color: Color(red: 0.07, green: 0.04, blue: 0.02).opacity(0.56))
        }
    }

    private var mineralLights: some View {
        Group {
            Circle()
                .fill(moodAccent.opacity(glowPulse ? 0.96 : 0.55))
                .frame(width: 11, height: 11)
                .shadow(color: moodAccent.opacity(glowPulse ? 0.85 : 0.35), radius: glowPulse ? 10 : 4)
                .position(x: 96, y: 88)
            Circle()
                .fill(Color(red: 0.1, green: 0.95, blue: 0.78).opacity(blink ? 0.38 : 0.88))
                .frame(width: 6, height: 6)
                .shadow(color: Color(red: 0.1, green: 0.95, blue: 0.78).opacity(0.5), radius: 5)
                .position(x: 69, y: 63)
            Circle()
                .fill(Color(red: 1.0, green: 0.82, blue: 0.32).opacity(0.72))
                .frame(width: 5, height: 5)
                .position(x: 119, y: 82)
        }
    }

    private var moodAccent: Color {
        switch mood {
        case .happy:
            return Color(red: 1.0, green: 0.83, blue: 0.22)
        case .thinking:
            return Color(red: 0.24, green: 0.86, blue: 1.0)
        case .sleepy:
            return Color(red: 0.54, green: 0.62, blue: 0.94)
        case .curious:
            return Color(red: 0.36, green: 1.0, blue: 0.58)
        case .error:
            return Color(red: 1.0, green: 0.32, blue: 0.22)
        }
    }
}

private struct RockyShellShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x / 180, y: rect.minY + rect.height * y / 150)
        }

        var path = Path()
        path.move(to: p(88, 36))
        path.addLine(to: p(119, 45))
        path.addLine(to: p(136, 70))
        path.addLine(to: p(128, 101))
        path.addLine(to: p(105, 119))
        path.addLine(to: p(74, 117))
        path.addLine(to: p(51, 98))
        path.addLine(to: p(43, 69))
        path.addLine(to: p(59, 46))
        path.closeSubpath()
        return path
    }
}

private struct RockyLimb: View {
    let resting: [CGPoint]
    let stepping: [CGPoint]
    let active: Bool
    let lineWidth: CGFloat
    let tint: Color
    var tipColor: Color?

    private var points: [CGPoint] {
        active ? stepping : resting
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RockyLine(points: points, lineWidth: lineWidth + 3.2, color: Color(red: 0.06, green: 0.035, blue: 0.018))

            Path { path in
                guard let first = points.first else {
                    return
                }

                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(
                LinearGradient(
                    colors: [tint.opacity(1.0), tint.opacity(0.66), Color(red: 0.20, green: 0.11, blue: 0.045)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                Circle()
                    .fill(index == points.count - 1 ? (tipColor ?? Color(red: 0.11, green: 0.06, blue: 0.03)) : tint.opacity(0.95))
                    .overlay(Circle().stroke(Color.black.opacity(0.34), lineWidth: 1.2))
                    .frame(width: index == points.count - 1 ? lineWidth * 1.18 : lineWidth * 0.82, height: index == points.count - 1 ? lineWidth * 1.18 : lineWidth * 0.82)
                    .position(point)
            }
        }
        .frame(width: 180, height: 150)
    }
}

private struct RockyFacet: View {
    let points: [CGPoint]
    let color: Color

    var body: some View {
        Path { path in
            guard let first = points.first else {
                return
            }

            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
        .fill(color)
        .frame(width: 180, height: 150)
    }
}

private struct RockyLine: View {
    let points: [CGPoint]
    let lineWidth: CGFloat
    let color: Color

    var body: some View {
        Path { path in
            guard let first = points.first else {
                return
            }

            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        .frame(width: 180, height: 150)
    }
}
