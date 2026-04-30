import AppKit
import SwiftUI

struct RockyRootView: View {
    @ObservedObject var viewModel: RockyViewModel
    @State private var isHovering = false

    private var terminalVisible: Bool {
        viewModel.isStageOpen || isHovering || viewModel.isThinking || !viewModel.input.isEmpty
    }

    private var isLargeWindow: Bool {
        viewModel.isStageOpen
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
                    isStageOpen: viewModel.isStageOpen,
                    activeProfile: viewModel.activeProfile,
                    availableProfiles: viewModel.availableProfiles,
                    conversations: viewModel.conversations,
                    activeConversationID: viewModel.activeConversationID,
                    send: viewModel.send,
                    newChat: viewModel.newChat,
                    openStage: viewModel.openStage,
                    closeStage: viewModel.closeStage,
                    switchProfile: viewModel.switchProfile,
                    selectChat: viewModel.selectChat,
                    deleteChat: viewModel.deleteActiveChat,
                    quit: viewModel.quit
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
                .padding(.bottom, viewModel.isStageOpen ? 126 : 118)
            }

            CompanionCreatureView(profile: viewModel.activeProfile, mood: viewModel.mood, animation: viewModel.animation, isAwake: terminalVisible)
                .frame(width: isLargeWindow ? 220 : 156, height: isLargeWindow ? 176 : 132)
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
        .frame(
            minWidth: viewModel.isStageOpen ? 560 : 240,
            idealWidth: viewModel.isStageOpen ? 760 : 360,
            maxWidth: viewModel.isStageOpen ? 940 : 620,
            minHeight: viewModel.isStageOpen ? 500 : 250,
            idealHeight: viewModel.isStageOpen ? 660 : 390,
            maxHeight: viewModel.isStageOpen ? 820 : 720
        )
        .background(Color.clear)
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                isHovering = hovering
            }
        }
        .onChange(of: viewModel.isStageOpen) { _, isOpen in
            resizePanelForStage(isOpen)
        }
        .task(id: "\(viewModel.activeConversationID)-\(viewModel.activeProfile.id)") {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(14))
                viewModel.performIdleBehavior()
            }
        }
        .task(id: "\(viewModel.activeProfile.id)-\(viewModel.isStageOpen)") {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7))
                if viewModel.activeMovementMode == .dynamic && !viewModel.isStageOpen {
                    nudgePanelForDynamicCompanion()
                }
            }
        }
    }

    private func resizePanelForStage(_ isStageOpen: Bool) {
        guard let window = NSApp.windows.first(where: { $0.title == "Agent Rocky" }) else {
            return
        }

        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        guard screenFrame.width > 1, screenFrame.height > 1 else {
            window.setContentSize(isStageOpen ? NSSize(width: 760, height: 660) : NSSize(width: 360, height: 390))
            return
        }

        let size = isStageOpen
            ? NSSize(width: min(760, screenFrame.width * 0.72), height: min(660, screenFrame.height * 0.72))
            : NSSize(width: 360, height: 390)
        let origin = isStageOpen
            ? NSPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.midY - size.height / 2)
            : NSPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.minY + 18)

        window.setFrame(NSRect(origin: origin, size: size), display: true, animate: true)
    }

    private func nudgePanelForDynamicCompanion() {
        guard let window = NSApp.windows.first(where: { $0.title == "Agent Rocky" }) else {
            return
        }

        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        guard screenFrame.width > window.frame.width + 80,
              screenFrame.height > window.frame.height + 80 else {
            return
        }

        let maxX = screenFrame.maxX - window.frame.width - 24
        let minX = screenFrame.minX + 24
        let minY = screenFrame.minY + 18
        let maxY = max(minY, screenFrame.midY - window.frame.height * 0.3)
        let nextOrigin = NSPoint(
            x: CGFloat.random(in: minX...maxX),
            y: CGFloat.random(in: minY...maxY)
        )

        window.setFrameOrigin(nextOrigin)
    }
}

private struct RockyTerminal: View {
    @Binding var input: String
    @Binding var model: String
    let lines: [String]
    let isThinking: Bool
    let isUsingFallback: Bool
    let brainStatus: String
    let isStageOpen: Bool
    let activeProfile: CompanionProfile
    let availableProfiles: [CompanionProfile]
    let conversations: [RockyConversationSummary]
    let activeConversationID: String
    let send: () -> Void
    let newChat: () -> Void
    let openStage: () -> Void
    let closeStage: () -> Void
    let switchProfile: (String) -> Void
    let selectChat: (String) -> Void
    let deleteChat: () -> Void
    let quit: () -> Void

    @FocusState private var inputFocused: Bool

    private var terminalTitle: String {
        activeProfile.id == "rocky" ? "rocky.term" : "\(activeProfile.id).term"
    }

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
        .frame(
            minWidth: isStageOpen ? 520 : 220,
            idealWidth: isStageOpen ? 700 : 330,
            maxWidth: .infinity,
            minHeight: isStageOpen ? 350 : 126,
            idealHeight: isStageOpen ? 500 : 178,
            maxHeight: .infinity
        )
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

            Text(terminalTitle)
                .foregroundStyle(Color(red: 0.78, green: 1.0, blue: 0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: isStageOpen ? 190 : 92, alignment: .leading)

            Spacer(minLength: 4)

            if isStageOpen {
                TextField("default", text: $model)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 78)
                    .help("Model override. Leave blank for Codex default.")

                Menu {
                    ForEach(availableProfiles) { profile in
                        Button {
                            switchProfile(profile.id)
                        } label: {
                            Label(
                                profile.name,
                                systemImage: profile.id == activeProfile.id ? "checkmark.circle.fill" : "person.crop.circle"
                            )
                        }
                    }
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .black))
                        .frame(width: 24, height: 20)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Profiles")
            }

            Button(action: isStageOpen ? closeStage : openStage) {
                Image(systemName: isStageOpen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .black))
                    .frame(width: 24, height: 20)
            }
            .buttonStyle(TerminalIconButtonStyle(color: Color(red: 0.78, green: 0.68, blue: 1.0)))
            .help(isStageOpen ? "Mini mode" : "Open stage")

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

private struct CompanionCreatureView: View {
    let profile: CompanionProfile
    let mood: RockyMood
    let animation: RockyAnimation
    let isAwake: Bool

    var body: some View {
        switch profile.visualStyle {
        case .orangePixelCat:
            OrangePixelCatView(mood: mood, animation: animation, isAwake: isAwake)
        case .cuteBuddy:
            CuteBuddyView(mood: mood, animation: animation, isAwake: isAwake)
        default:
            RockyCreatureView(mood: mood, animation: animation, isAwake: isAwake)
        }
    }
}

private struct OrangePixelCatView: View {
    let mood: RockyMood
    let animation: RockyAnimation
    let isAwake: Bool

    @State private var wiggle = false
    @State private var blink = false

    var body: some View {
        GeometryReader { geometry in
            let unit = min(geometry.size.width / 18, geometry.size.height / 16)
            let originX = (geometry.size.width - unit * 18) / 2
            let originY = (geometry.size.height - unit * 16) / 2

            ZStack(alignment: .topLeading) {
                Ellipse()
                    .fill(.black.opacity(0.28))
                    .frame(width: unit * 12, height: unit * 1.2)
                    .blur(radius: unit * 0.35)
                    .offset(x: originX + unit * 3.2, y: originY + unit * 13.7)

                ForEach(pixelBlocks(), id: \.id) { block in
                    let pixelOffset = offset(for: block.motion, unit: unit)

                    Rectangle()
                        .fill(block.color)
                        .frame(width: block.w * unit, height: block.h * unit)
                        .offset(
                            x: originX + block.x * unit + pixelOffset.width,
                            y: originY + block.y * unit + pixelOffset.height
                        )
                }
            }
            .offset(y: verticalMotion)
            .scaleEffect(isAwake ? 1.04 : 1.0)
            .animation(.easeInOut(duration: 0.36).repeatForever(autoreverses: true), value: wiggle)
            .animation(.easeInOut(duration: 0.16), value: isAwake)
            .onAppear {
                wiggle = true
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3.2))
                    blink = true
                    try? await Task.sleep(for: .milliseconds(180))
                    blink = false
                }
            }
        }
    }

    private var verticalMotion: CGFloat {
        switch animation {
        case .happyBounce, .excited:
            return wiggle ? -7 : -1
        case .walk, .play, .playBall:
            return wiggle ? -4 : 0
        case .sleep:
            return 3
        default:
            return wiggle ? -2 : 0
        }
    }

    private func offset(for motion: PixelCatMotion, unit: CGFloat) -> CGSize {
        switch motion {
        case .none:
            return .zero
        case .tail:
            return CGSize(width: 0, height: wiggle ? -unit : unit * 0.2)
        case .pawA:
            return animation == .walk || animation == .play ? CGSize(width: wiggle ? -unit : unit, height: 0) : .zero
        case .pawB:
            return animation == .walk || animation == .play ? CGSize(width: wiggle ? unit : -unit, height: 0) : .zero
        case .head:
            return animation == .happyBounce || animation == .excited ? CGSize(width: 0, height: wiggle ? -unit : 0) : .zero
        case .tongue:
            return animation == .lick ? CGSize(width: 0, height: wiggle ? unit * 0.4 : 0) : .zero
        case .ball:
            return CGSize(width: wiggle ? unit : -unit, height: 0)
        case .purr:
            return CGSize(width: 0, height: wiggle ? -unit * 0.5 : unit * 0.2)
        }
    }

    private func pixelBlocks() -> [PixelCatBlock] {
        let outline = Color(red: 0.10, green: 0.055, blue: 0.025)
        let dark = Color(red: 0.30, green: 0.13, blue: 0.045)
        let orange = Color(red: 0.96, green: 0.47, blue: 0.12)
        let light = Color(red: 1.0, green: 0.70, blue: 0.32)
        let cream = Color(red: 1.0, green: 0.84, blue: 0.58)
        let pink = Color(red: 1.0, green: 0.42, blue: 0.52)
        let eye = blink || animation == .sleep ? dark.opacity(0.78) : Color.black.opacity(0.9)
        let ball = Color(red: 0.16, green: 0.76, blue: 1.0)

        var blocks: [PixelCatBlock] = [
            // Tail.
            PixelCatBlock(14, 7, 1, 4, outline, .tail),
            PixelCatBlock(15, 5, 1, 3, outline, .tail),
            PixelCatBlock(16, 5, 1, 1, outline, .tail),
            PixelCatBlock(14, 8, 1, 2, orange, .tail),
            PixelCatBlock(15, 6, 1, 2, light, .tail),

            // Body.
            PixelCatBlock(5, 7, 9, 1, outline),
            PixelCatBlock(4, 8, 11, 4, outline),
            PixelCatBlock(5, 12, 9, 1, outline),
            PixelCatBlock(5, 8, 9, 3, orange),
            PixelCatBlock(6, 11, 6, 1, light),
            PixelCatBlock(7, 8, 1, 3, dark.opacity(0.52)),
            PixelCatBlock(10, 8, 1, 3, dark.opacity(0.45)),
            PixelCatBlock(13, 9, 1, 2, dark.opacity(0.5)),

            // Paws.
            PixelCatBlock(5, 12, 2, 1, outline, .pawA),
            PixelCatBlock(11, 12, 2, 1, outline, .pawB),
            PixelCatBlock(6, 12, 1, 1, cream, .pawA),
            PixelCatBlock(12, 12, 1, 1, cream, .pawB),

            // Ears and head.
            PixelCatBlock(5, 2, 1, 2, outline, .head),
            PixelCatBlock(6, 3, 1, 1, orange, .head),
            PixelCatBlock(11, 2, 1, 2, outline, .head),
            PixelCatBlock(10, 3, 1, 1, light, .head),
            PixelCatBlock(4, 4, 9, 1, outline, .head),
            PixelCatBlock(3, 5, 11, 4, outline, .head),
            PixelCatBlock(4, 9, 9, 1, outline, .head),
            PixelCatBlock(4, 5, 9, 3, light, .head),
            PixelCatBlock(5, 8, 7, 1, cream, .head),
            PixelCatBlock(6, 5, 1, 2, orange, .head),
            PixelCatBlock(10, 5, 1, 2, orange, .head),

            // Face.
            PixelCatBlock(6, 6, 1, animation == .sleep ? 0.3 : 1, eye, .head),
            PixelCatBlock(10, 6, 1, animation == .sleep ? 0.3 : 1, eye, .head),
            PixelCatBlock(8, 7, 1, 1, dark, .head),
            PixelCatBlock(7, 8, 1, 0.4, dark.opacity(0.72), .head),
            PixelCatBlock(9, 8, 1, 0.4, dark.opacity(0.72), .head)
        ]

        if animation == .lick {
            blocks.append(PixelCatBlock(8, 8, 1, 2, pink, .tongue))
        }

        if animation == .play || animation == .playBall {
            blocks.append(contentsOf: [
                PixelCatBlock(1, 11, 2, 2, outline, .ball),
                PixelCatBlock(1, 11, 1, 1, ball, .ball),
                PixelCatBlock(2, 12, 1, 1, ball.opacity(0.82), .ball),
                PixelCatBlock(1, 12, 1, 1, Color.white.opacity(0.8), .ball)
            ])
        }

        if animation == .purr {
            blocks.append(contentsOf: [
                PixelCatBlock(2, 4, 1, 1, Color(red: 1.0, green: 0.84, blue: 0.24).opacity(wiggle ? 0.95 : 0.42), .purr),
                PixelCatBlock(14, 4, 1, 1, Color(red: 1.0, green: 0.84, blue: 0.24).opacity(wiggle ? 0.95 : 0.42), .purr),
                PixelCatBlock(3, 3, 1, 1, Color(red: 1.0, green: 0.84, blue: 0.24).opacity(0.45), .purr),
                PixelCatBlock(13, 3, 1, 1, Color(red: 1.0, green: 0.84, blue: 0.24).opacity(0.45), .purr)
            ])
        }

        if animation == .sleep {
            blocks.append(contentsOf: [
                PixelCatBlock(13, 5, 1, 1, Color.white.opacity(0.8), .none),
                PixelCatBlock(14, 4, 1, 1, Color.white.opacity(0.62), .none),
                PixelCatBlock(15, 3, 1, 1, Color.white.opacity(0.42), .none)
            ])
        }

        return blocks.enumerated().map { index, block in
            var mutable = block
            mutable.id = index
            return mutable
        }
    }
}

private enum PixelCatMotion {
    case none
    case tail
    case pawA
    case pawB
    case head
    case tongue
    case ball
    case purr
}

private struct PixelCatBlock {
    var id = 0
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat
    let color: Color
    let motion: PixelCatMotion

    init(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color, _ motion: PixelCatMotion = .none) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.color = color
        self.motion = motion
    }
}

private struct CuteBuddyView: View {
    let mood: RockyMood
    let animation: RockyAnimation
    let isAwake: Bool

    @State private var pulse = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(.black.opacity(0.28))
                .frame(width: 94, height: 15)
                .blur(radius: 4)
                .offset(y: 54)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.73, green: 1.0, blue: 0.36), Color(red: 0.18, green: 0.55, blue: 0.36)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 92, height: 82)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.48), lineWidth: 3))
                .offset(y: pulse ? -6 : 0)

            Circle()
                .fill(.black.opacity(0.86))
                .frame(width: 9, height: 9)
                .offset(x: -18, y: -10)
            Circle()
                .fill(.black.opacity(0.86))
                .frame(width: 9, height: 9)
                .offset(x: 18, y: -10)
            Capsule()
                .fill(.black.opacity(0.56))
                .frame(width: 28, height: 5)
                .offset(y: 13)
        }
        .scaleEffect(isAwake ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: pulse)
        .onAppear {
            pulse = true
        }
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

                if showsGraceHalo {
                    RockyGraceHalo(active: gaitFrame, accent: moodAccent)
                }

                if animation == .rollInBox {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.18, green: 0.10, blue: 0.05).opacity(0.62))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(red: 0.85, green: 0.55, blue: 0.23).opacity(0.74), lineWidth: 3)
                        )
                        .frame(width: 116, height: 62)
                        .rotationEffect(.degrees(gaitFrame ? -5 : 5))
                        .offset(x: 32, y: 71)
                }

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
            .rotationEffect(.degrees(animation == .rollInBox ? (gaitFrame ? -7 : 7) : 0))
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
            .frame(width: 128, height: 18)
            .blur(radius: 4)
            .offset(x: 26, y: 126)
    }

    private var showsGraceHalo: Bool {
        switch animation {
        case .happyBounce, .excited, .thumbsUp, .rollInBox:
            return true
        default:
            return mood == .happy
        }
    }

    private var verticalMotion: CGFloat {
        switch animation {
        case .bounce, .happyBounce, .excited:
            return gaitFrame ? -5 : -2
        case .wave, .thumbsUp:
            return gaitFrame ? -3 : -1
        case .pulse, .think, .workInPlace:
            return gaitFrame ? -4 : -2
        case .shake, .rollInBox:
            return gaitFrame ? -1 : 1
        case .sleep:
            return 2
        default:
            return gaitFrame ? -2 : 0
        }
    }

    private var shellGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.69, blue: 0.36),
                Color(red: 0.73, green: 0.39, blue: 0.16),
                Color(red: 0.30, green: 0.15, blue: 0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backLimbs: some View {
        Group {
            RockyLimb(
                resting: [CGPoint(x: 58, y: 80), CGPoint(x: 31, y: 92), CGPoint(x: 17, y: 126)],
                stepping: [CGPoint(x: 58, y: 80), CGPoint(x: 28, y: 86), CGPoint(x: 14, y: 118)],
                active: gaitFrame,
                lineWidth: 8.6,
                tint: Color(red: 0.46, green: 0.25, blue: 0.10)
            )
            RockyLimb(
                resting: [CGPoint(x: 121, y: 80), CGPoint(x: 150, y: 94), CGPoint(x: 164, y: 126)],
                stepping: [CGPoint(x: 121, y: 80), CGPoint(x: 153, y: 88), CGPoint(x: 167, y: 118)],
                active: !gaitFrame,
                lineWidth: 8.6,
                tint: Color(red: 0.46, green: 0.25, blue: 0.10)
            )
            RockyLimb(
                resting: [CGPoint(x: 91, y: 101), CGPoint(x: 84, y: 124), CGPoint(x: 72, y: 143)],
                stepping: [CGPoint(x: 91, y: 101), CGPoint(x: 94, y: 123), CGPoint(x: 108, y: 143)],
                active: gaitFrame,
                lineWidth: 7.8,
                tint: Color(red: 0.40, green: 0.21, blue: 0.08)
            )
        }
    }

    private var frontLimbs: some View {
        Group {
            RockyLimb(
                resting: [CGPoint(x: 64, y: 94), CGPoint(x: 41, y: 110), CGPoint(x: 31, y: 143)],
                stepping: [CGPoint(x: 64, y: 94), CGPoint(x: 50, y: 111), CGPoint(x: 55, y: 143)],
                active: !gaitFrame,
                lineWidth: 9.2,
                tint: Color(red: 0.62, green: 0.36, blue: 0.15)
            )
            RockyLimb(
                resting: [CGPoint(x: 116, y: 94), CGPoint(x: 139, y: 110), CGPoint(x: 149, y: 143)],
                stepping: [CGPoint(x: 116, y: 94), CGPoint(x: 130, y: 112), CGPoint(x: 125, y: 143)],
                active: gaitFrame,
                lineWidth: 9.2,
                tint: Color(red: 0.62, green: 0.36, blue: 0.15)
            )

            if showsGraceHalo {
                RockyLimb(
                    resting: [CGPoint(x: 63, y: 62), CGPoint(x: 38, y: 57), CGPoint(x: 24, y: 75)],
                    stepping: [CGPoint(x: 63, y: 62), CGPoint(x: 35, y: 51), CGPoint(x: 20, y: 67)],
                    active: gaitFrame,
                    lineWidth: 7.2,
                    tint: Color(red: 0.72, green: 0.43, blue: 0.17),
                    tipColor: moodAccent
                )
                RockyPeaceArm(
                    active: gaitFrame,
                    tint: Color(red: 0.72, green: 0.43, blue: 0.17),
                    accent: moodAccent
                )
            } else {
                RockyLimb(
                    resting: [CGPoint(x: 63, y: 62), CGPoint(x: 39, y: 58), CGPoint(x: 25, y: 76)],
                    stepping: [CGPoint(x: 63, y: 62), CGPoint(x: 35, y: 54), CGPoint(x: 21, y: 70)],
                    active: gaitFrame,
                    lineWidth: 7.2,
                    tint: Color(red: 0.72, green: 0.43, blue: 0.17),
                    tipColor: moodAccent
                )
                RockyLimb(
                    resting: [CGPoint(x: 116, y: 62), CGPoint(x: 141, y: 57), CGPoint(x: 155, y: 75)],
                    stepping: [CGPoint(x: 116, y: 62), CGPoint(x: 145, y: 53), CGPoint(x: 160, y: 68)],
                    active: !gaitFrame,
                    lineWidth: 7.2,
                    tint: Color(red: 0.72, green: 0.43, blue: 0.17),
                    tipColor: moodAccent
                )
            }
        }
    }

    private var facets: some View {
        Group {
            RockyFacet(points: [CGPoint(x: 49, y: 58), CGPoint(x: 85, y: 34), CGPoint(x: 94, y: 71), CGPoint(x: 61, y: 83)], color: Color(red: 1.0, green: 0.76, blue: 0.42).opacity(0.72))
            RockyFacet(points: [CGPoint(x: 85, y: 34), CGPoint(x: 119, y: 42), CGPoint(x: 133, y: 69), CGPoint(x: 94, y: 71)], color: Color(red: 0.78, green: 0.43, blue: 0.18).opacity(0.70))
            RockyFacet(points: [CGPoint(x: 39, y: 78), CGPoint(x: 61, y: 83), CGPoint(x: 76, y: 119), CGPoint(x: 53, y: 108)], color: Color(red: 0.34, green: 0.17, blue: 0.07).opacity(0.50))
            RockyFacet(points: [CGPoint(x: 61, y: 83), CGPoint(x: 94, y: 71), CGPoint(x: 110, y: 115), CGPoint(x: 76, y: 119)], color: Color(red: 0.70, green: 0.38, blue: 0.15).opacity(0.68))
            RockyFacet(points: [CGPoint(x: 94, y: 71), CGPoint(x: 135, y: 70), CGPoint(x: 130, y: 97), CGPoint(x: 110, y: 115)], color: Color(red: 0.25, green: 0.12, blue: 0.05).opacity(0.48))
            RockyLine(points: [CGPoint(x: 84, y: 39), CGPoint(x: 94, y: 71), CGPoint(x: 110, y: 115)], lineWidth: 2.0, color: Color.black.opacity(0.28))
            RockyLine(points: [CGPoint(x: 56, y: 77), CGPoint(x: 94, y: 71), CGPoint(x: 128, y: 73)], lineWidth: 1.8, color: Color.white.opacity(0.18))
            RockyLine(points: [CGPoint(x: 68, y: 61), CGPoint(x: 78, y: 77), CGPoint(x: 73, y: 96)], lineWidth: 1.6, color: Color(red: 0.07, green: 0.04, blue: 0.02).opacity(0.5))
            RockyLine(points: [CGPoint(x: 115, y: 56), CGPoint(x: 106, y: 78), CGPoint(x: 118, y: 94)], lineWidth: 1.8, color: Color(red: 0.07, green: 0.04, blue: 0.02).opacity(0.56))
        }
    }

    private var mineralLights: some View {
        Group {
            Circle()
                .fill(moodAccent.opacity(glowPulse ? 0.96 : 0.55))
                .frame(width: 12, height: 12)
                .shadow(color: moodAccent.opacity(glowPulse ? 0.85 : 0.35), radius: glowPulse ? 10 : 4)
                .position(x: 92, y: 86)
            Circle()
                .fill(Color(red: 0.1, green: 0.95, blue: 0.78).opacity(blink ? 0.38 : 0.88))
                .frame(width: 6, height: 6)
                .shadow(color: Color(red: 0.1, green: 0.95, blue: 0.78).opacity(0.5), radius: 5)
                .position(x: 59, y: 72)
            Circle()
                .fill(Color(red: 1.0, green: 0.82, blue: 0.32).opacity(0.72))
                .frame(width: 5, height: 5)
                .position(x: 122, y: 73)
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

private struct RockyGraceHalo: View {
    let active: Bool
    let accent: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .trim(from: 0.08, to: 0.88)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.80, green: 0.62, blue: 1.0).opacity(0.82),
                            Color(red: 0.95, green: 0.68, blue: 0.90).opacity(0.56),
                            Color(red: 0.72, green: 0.54, blue: 1.0).opacity(0.76)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
                )
                .frame(width: 150, height: 104)
                .rotationEffect(.degrees(active ? -7 : 5))
                .offset(x: 15, y: 11)

            HeartShape()
                .fill(Color(red: 1.0, green: 0.38, blue: 0.58).opacity(0.92))
                .frame(width: 15, height: 13)
                .rotationEffect(.degrees(active ? 7 : -4))
                .offset(x: 81, y: active ? 2 : 5)
                .shadow(color: Color(red: 1.0, green: 0.38, blue: 0.58).opacity(0.5), radius: 5)

            ForEach(Array(stars.enumerated()), id: \.offset) { index, star in
                StarShape(points: 5, innerRatio: 0.48)
                    .fill(index.isMultiple(of: 2) ? Color(red: 1.0, green: 0.92, blue: 0.58) : accent)
                    .frame(width: star.size, height: star.size)
                    .rotationEffect(.degrees(active ? star.rotation + 16 : star.rotation - 10))
                    .offset(
                        x: star.x,
                        y: star.y + (active == star.liftsOnActive ? -4 : 2)
                    )
                    .shadow(color: accent.opacity(0.28), radius: 4)
            }
        }
        .frame(width: 180, height: 150)
        .opacity(active ? 0.98 : 0.78)
        .allowsHitTesting(false)
    }

    private var stars: [GraceStar] {
        [
            GraceStar(x: 31, y: 23, size: 11, rotation: -12, liftsOnActive: true),
            GraceStar(x: 54, y: 6, size: 8, rotation: 8, liftsOnActive: false),
            GraceStar(x: 126, y: 16, size: 10, rotation: 18, liftsOnActive: true),
            GraceStar(x: 146, y: 40, size: 7, rotation: -24, liftsOnActive: false),
            GraceStar(x: 23, y: 55, size: 7, rotation: 32, liftsOnActive: true)
        ]
    }
}

private struct GraceStar {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let rotation: Double
    let liftsOnActive: Bool
}

private struct StarShape: Shape {
    let points: Int
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRatio
        let step = .pi / CGFloat(points)

        var path = Path()
        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = CGFloat(index) * step - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: rect.minX + w * 0.50, y: rect.minY + h * 0.88))
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.05, y: rect.minY + h * 0.34),
            control1: CGPoint(x: rect.minX + w * 0.18, y: rect.minY + h * 0.66),
            control2: CGPoint(x: rect.minX - w * 0.04, y: rect.minY + h * 0.42)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.50, y: rect.minY + h * 0.18),
            control1: CGPoint(x: rect.minX + w * 0.12, y: rect.minY - h * 0.02),
            control2: CGPoint(x: rect.minX + w * 0.42, y: rect.minY + h * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.95, y: rect.minY + h * 0.34),
            control1: CGPoint(x: rect.minX + w * 0.58, y: rect.minY + h * 0.02),
            control2: CGPoint(x: rect.minX + w * 0.88, y: rect.minY - h * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.50, y: rect.minY + h * 0.88),
            control1: CGPoint(x: rect.minX + w * 1.04, y: rect.minY + h * 0.42),
            control2: CGPoint(x: rect.minX + w * 0.82, y: rect.minY + h * 0.66)
        )
        path.closeSubpath()
        return path
    }
}

private struct RockyShellShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x / 180, y: rect.minY + rect.height * y / 150)
        }

        var path = Path()
        path.move(to: p(88, 36))
        path.addLine(to: p(119, 42))
        path.addLine(to: p(140, 67))
        path.addLine(to: p(134, 94))
        path.addLine(to: p(113, 116))
        path.addLine(to: p(81, 124))
        path.addLine(to: p(53, 109))
        path.addLine(to: p(39, 80))
        path.addLine(to: p(49, 56))
        path.closeSubpath()
        return path
    }
}

private struct RockyPeaceArm: View {
    let active: Bool
    let tint: Color
    let accent: Color

    private var fingerBase: CGPoint {
        active ? CGPoint(x: 151, y: 16) : CGPoint(x: 146, y: 22)
    }

    private var fingerA: CGPoint {
        active ? CGPoint(x: 146, y: 3) : CGPoint(x: 140, y: 10)
    }

    private var fingerB: CGPoint {
        active ? CGPoint(x: 159, y: 7) : CGPoint(x: 155, y: 13)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RockyLimb(
                resting: [CGPoint(x: 116, y: 62), CGPoint(x: 135, y: 39), CGPoint(x: 146, y: 22)],
                stepping: [CGPoint(x: 116, y: 62), CGPoint(x: 139, y: 35), CGPoint(x: 151, y: 16)],
                active: active,
                lineWidth: 7.2,
                tint: tint,
                tipColor: accent
            )

            RockyLine(points: [fingerBase, fingerA], lineWidth: 6.0, color: Color(red: 0.06, green: 0.035, blue: 0.018))
            RockyLine(points: [fingerBase, fingerB], lineWidth: 6.0, color: Color(red: 0.06, green: 0.035, blue: 0.018))
            RockyLine(points: [fingerBase, fingerA], lineWidth: 3.2, color: tint.opacity(0.96))
            RockyLine(points: [fingerBase, fingerB], lineWidth: 3.2, color: tint.opacity(0.96))

            Circle()
                .fill(Color(red: 0.14, green: 0.90, blue: 0.82))
                .overlay(Circle().stroke(Color.black.opacity(0.36), lineWidth: 1.2))
                .frame(width: 8, height: 8)
                .position(x: active ? 139 : 135, y: active ? 35 : 39)
        }
        .frame(width: 180, height: 150)
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
