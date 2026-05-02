import AppKit
import SwiftUI

struct RockyRootView: View {
    @ObservedObject var viewModel: RockyViewModel
    @State private var isHovering = false
    @State private var isMiniTerminalDismissed = false

    private var terminalVisible: Bool {
        viewModel.isStageOpen || viewModel.isThinking || !viewModel.input.isEmpty || (isHovering && !isMiniTerminalDismissed)
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
                    if terminalVisible && !viewModel.isStageOpen && !viewModel.isThinking && viewModel.input.isEmpty {
                        dismissMiniTerminal()
                    } else {
                        isMiniTerminalDismissed = false
                        viewModel.poke()
                    }
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
                if !hovering {
                    isMiniTerminalDismissed = false
                }
            }
        }
        .onChange(of: viewModel.isStageOpen) { _, isOpen in
            isMiniTerminalDismissed = false
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

    private func dismissMiniTerminal() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
            isMiniTerminalDismissed = true
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
                                .lineLimit(nil)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .contextMenu {
                                    Button("Copy Line") {
                                        copyToPasteboard(line)
                                    }
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .onChange(of: lines.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: activeConversationID) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: isStageOpen) { _, _ in
                    scrollToBottom(proxy)
                }
                .onAppear {
                    scrollToBottom(proxy)
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

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if let last = lines.indices.last {
                proxy.scrollTo(last, anchor: .bottom)
            }
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
        case .tronPixel:
            TronPixelBuddyView(mood: mood, animation: animation, isAwake: isAwake)
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

private struct TronPixelBuddyView: View {
    let mood: RockyMood
    let animation: RockyAnimation
    let isAwake: Bool

    @State private var pulse = false
    @State private var blink = false

    private let cyan = Color(red: 0.18, green: 0.94, blue: 1.0)
    private let orange = Color(red: 1.0, green: 0.46, blue: 0.16)
    private let bodyDark = Color(red: 0.025, green: 0.035, blue: 0.055)

    var body: some View {
        GeometryReader { geometry in
            let unit = min(geometry.size.width / 20, geometry.size.height / 18)
            let originX = (geometry.size.width - unit * 20) / 2
            let originY = (geometry.size.height - unit * 18) / 2
            let bob = verticalMotion(unit: unit)

            ZStack(alignment: .topLeading) {
                pixelLayer(gridBlocks(), unit: unit, originX: originX, originY: originY)
                pixelLayer(lightTrailBlocks(), unit: unit, originX: originX + trailMotion(unit: unit), originY: originY)
                    .opacity(isAwake ? 0.96 : 0.62)
                pixelLayer(spriteBlocks(), unit: unit, originX: originX, originY: originY + bob)

                if animation == .happyBounce || animation == .excited {
                    pixelLayer(heartBlocks(), unit: unit, originX: originX, originY: originY + (pulse ? -unit : 0))
                }

                if animation == .think || animation == .workInPlace || animation == .pulse {
                    pixelLayer(scanBlocks(), unit: unit, originX: originX, originY: originY + scanMotion(unit: unit))
                }
            }
        }
        .scaleEffect(isAwake ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true), value: pulse)
        .animation(.easeInOut(duration: 0.16), value: isAwake)
        .onAppear {
            pulse = true
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.0))
                blink = true
                try? await Task.sleep(for: .milliseconds(150))
                blink = false
            }
        }
    }

    private func pixelLayer(_ blocks: [TronPixelBlock], unit: CGFloat, originX: CGFloat, originY: CGFloat) -> some View {
        ForEach(blocks) { block in
            Rectangle()
                .fill(block.color)
                .frame(width: block.w * unit, height: block.h * unit)
                .offset(x: originX + block.x * unit, y: originY + block.y * unit)
        }
    }

    private func verticalMotion(unit: CGFloat) -> CGFloat {
        switch animation {
        case .happyBounce, .excited:
            return pulse ? -1.3 * unit : -0.2 * unit
        case .think, .pulse, .workInPlace:
            return pulse ? -0.7 * unit : 0
        case .thumbsUp, .wave:
            return pulse ? -1.0 * unit : -0.2 * unit
        default:
            return pulse ? -0.55 * unit : 0
        }
    }

    private func trailMotion(unit: CGFloat) -> CGFloat {
        pulse ? unit * 0.5 : -unit * 0.4
    }

    private func scanMotion(unit: CGFloat) -> CGFloat {
        pulse ? -unit * 0.3 : unit * 0.4
    }

    private func gridBlocks() -> [TronPixelBlock] {
        let grid = cyan.opacity(pulse ? 0.28 : 0.18)
        let darkGrid = cyan.opacity(0.10)

        return numbered([
            TronPixelBlock(1, 16, 18, 0.35, grid),
            TronPixelBlock(3, 15, 14, 0.30, darkGrid),
            TronPixelBlock(5, 14, 10, 0.25, darkGrid),
            TronPixelBlock(2, 14, 0.35, 3, darkGrid),
            TronPixelBlock(6, 13, 0.35, 4, grid),
            TronPixelBlock(10, 13, 0.35, 4, darkGrid),
            TronPixelBlock(14, 13, 0.35, 4, grid),
            TronPixelBlock(18, 14, 0.35, 3, darkGrid)
        ])
    }

    private func lightTrailBlocks() -> [TronPixelBlock] {
        numbered([
            TronPixelBlock(1, 12, 5, 1, cyan.opacity(0.24)),
            TronPixelBlock(2, 13, 6, 1, cyan.opacity(0.44)),
            TronPixelBlock(3, 14, 4, 1, orange.opacity(0.55)),
            TronPixelBlock(0, 15, 8, 1, cyan.opacity(0.16))
        ])
    }

    private func spriteBlocks() -> [TronPixelBlock] {
        let outline = Color(red: 0.005, green: 0.008, blue: 0.018)
        let suit = bodyDark
        let suitLight = Color(red: 0.05, green: 0.07, blue: 0.12)
        let visor = cyan.opacity(blink || animation == .sleep ? 0.34 : 0.96)
        let circuit = cyan.opacity(pulse ? 1.0 : 0.68)
        let disc = mood == .happy ? orange : cyan

        var blocks: [TronPixelBlock] = [
            // Identity disc dock.
            TronPixelBlock(14, 6, 3, 1, outline),
            TronPixelBlock(13, 7, 5, 2, outline),
            TronPixelBlock(14, 9, 3, 1, outline),
            TronPixelBlock(14, 7, 3, 2, disc.opacity(0.82)),
            TronPixelBlock(15, 7, 1, 2, Color.white.opacity(0.72)),

            // Helmet.
            TronPixelBlock(7, 2, 6, 1, outline),
            TronPixelBlock(6, 3, 8, 1, outline),
            TronPixelBlock(5, 4, 10, 3, outline),
            TronPixelBlock(6, 7, 8, 1, outline),
            TronPixelBlock(7, 3, 6, 1, suitLight),
            TronPixelBlock(6, 4, 8, 2, suit),
            TronPixelBlock(7, 6, 6, 1, suitLight),
            TronPixelBlock(7, 4, 6, 1, visor),
            TronPixelBlock(8, 5, 4, 1, cyan.opacity(0.30)),
            TronPixelBlock(9, 6, 2, 1, orange.opacity(0.76)),

            // Torso.
            TronPixelBlock(7, 8, 6, 1, outline),
            TronPixelBlock(6, 9, 8, 4, outline),
            TronPixelBlock(7, 13, 6, 1, outline),
            TronPixelBlock(7, 9, 6, 3, suit),
            TronPixelBlock(8, 12, 4, 1, suitLight),
            TronPixelBlock(8, 9, 4, 1, circuit),
            TronPixelBlock(10, 10, 1, 2, circuit),
            TronPixelBlock(9, 11, 3, 1, orange.opacity(0.76)),

            // Left arm.
            TronPixelBlock(4, 8, 3, 1, outline),
            TronPixelBlock(3, 9, 3, 1, outline),
            TronPixelBlock(3, 10, 2, 1, outline),
            TronPixelBlock(4, 9, 2, 1, suit),
            TronPixelBlock(3, 10, 1, 1, circuit),

            // Legs and boots.
            TronPixelBlock(7, 14, 2, 2, outline),
            TronPixelBlock(11, 14, 2, 2, outline),
            TronPixelBlock(7, 14, 1, 2, suit),
            TronPixelBlock(11, 14, 1, 2, suit),
            TronPixelBlock(6, 16, 3, 1, outline),
            TronPixelBlock(11, 16, 3, 1, outline),
            TronPixelBlock(7, 16, 2, 1, circuit),
            TronPixelBlock(11, 16, 2, 1, circuit)
        ]

        if animation == .thumbsUp || animation == .wave {
            blocks.append(contentsOf: [
                TronPixelBlock(13, 8, 2, 1, outline),
                TronPixelBlock(14, 6, 1, 3, outline),
                TronPixelBlock(15, 5, 1, 2, outline),
                TronPixelBlock(16, 4, 1, 1, orange.opacity(0.94)),
                TronPixelBlock(14, 7, 1, 1, circuit)
            ])
        } else {
            blocks.append(contentsOf: [
                TronPixelBlock(13, 8, 3, 1, outline),
                TronPixelBlock(14, 9, 3, 1, outline),
                TronPixelBlock(15, 10, 2, 1, outline),
                TronPixelBlock(14, 9, 2, 1, suit),
                TronPixelBlock(16, 10, 1, 1, circuit)
            ])
        }

        return numbered(blocks)
    }

    private func heartBlocks() -> [TronPixelBlock] {
        numbered([
            TronPixelBlock(16, 2, 1, 1, orange.opacity(0.95)),
            TronPixelBlock(18, 2, 1, 1, orange.opacity(0.95)),
            TronPixelBlock(15, 3, 5, 1, orange.opacity(0.95)),
            TronPixelBlock(16, 4, 3, 1, orange.opacity(0.86)),
            TronPixelBlock(17, 5, 1, 1, orange.opacity(0.70)),
            TronPixelBlock(14, 2, 1, 1, cyan.opacity(0.78)),
            TronPixelBlock(19, 5, 1, 1, cyan.opacity(0.58))
        ])
    }

    private func scanBlocks() -> [TronPixelBlock] {
        numbered([
            TronPixelBlock(3, 1, 5, 1, cyan.opacity(pulse ? 0.82 : 0.34)),
            TronPixelBlock(12, 2, 4, 1, orange.opacity(pulse ? 0.76 : 0.30)),
            TronPixelBlock(2, 4, 2, 1, cyan.opacity(0.42)),
            TronPixelBlock(16, 12, 2, 1, cyan.opacity(pulse ? 0.74 : 0.26)),
            TronPixelBlock(18, 13, 1, 1, orange.opacity(0.62))
        ])
    }

    private func numbered(_ blocks: [TronPixelBlock]) -> [TronPixelBlock] {
        blocks.enumerated().map { index, block in
            var mutable = block
            mutable.id = index
            return mutable
        }
    }
}

private struct TronPixelBlock: Identifiable {
    var id = 0
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat
    let color: Color

    init(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.color = color
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

                if showsWorkRig {
                    RockyWorkRig(active: gaitFrame, accent: moodAccent, boxed: animation == .rollInBox)
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
            .frame(width: 106, height: 17)
            .blur(radius: 4)
            .offset(x: 37, y: 123)
    }

    private var showsGraceHalo: Bool {
        switch animation {
        case .happyBounce, .excited:
            return true
        default:
            return false
        }
    }

    private var showsWorkRig: Bool {
        animation == .rollInBox || animation == .workInPlace || animation == .think
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
                resting: [CGPoint(x: 64, y: 78), CGPoint(x: 42, y: 91), CGPoint(x: 24, y: 125)],
                stepping: [CGPoint(x: 64, y: 78), CGPoint(x: 39, y: 86), CGPoint(x: 19, y: 118)],
                active: gaitFrame,
                lineWidth: 8.4,
                tint: Color(red: 0.46, green: 0.25, blue: 0.10)
            )
            RockyLimb(
                resting: [CGPoint(x: 116, y: 78), CGPoint(x: 139, y: 91), CGPoint(x: 157, y: 125)],
                stepping: [CGPoint(x: 116, y: 78), CGPoint(x: 142, y: 86), CGPoint(x: 162, y: 118)],
                active: !gaitFrame,
                lineWidth: 8.4,
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
                resting: [CGPoint(x: 70, y: 57), CGPoint(x: 52, y: 40), CGPoint(x: 42, y: 19)],
                stepping: [CGPoint(x: 70, y: 57), CGPoint(x: 49, y: 36), CGPoint(x: 38, y: 15)],
                active: gaitFrame,
                lineWidth: 7.2,
                tint: Color(red: 0.72, green: 0.43, blue: 0.17),
                tipColor: moodAccent
            )
            RockyLimb(
                resting: rightArmRestingPoints,
                stepping: rightArmSteppingPoints,
                active: !gaitFrame,
                lineWidth: 7.2,
                tint: Color(red: 0.72, green: 0.43, blue: 0.17),
                tipColor: moodAccent
            )
        }
    }

    private var rightArmRestingPoints: [CGPoint] {
        if animation == .thumbsUp {
            return [CGPoint(x: 110, y: 57), CGPoint(x: 130, y: 37), CGPoint(x: 146, y: 24)]
        }

        return [CGPoint(x: 110, y: 57), CGPoint(x: 129, y: 40), CGPoint(x: 139, y: 19)]
    }

    private var rightArmSteppingPoints: [CGPoint] {
        if animation == .thumbsUp {
            return [CGPoint(x: 110, y: 57), CGPoint(x: 136, y: 29), CGPoint(x: 155, y: 17)]
        }

        return [CGPoint(x: 110, y: 57), CGPoint(x: 132, y: 36), CGPoint(x: 143, y: 15)]
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

private struct RockyWorkRig: View {
    let active: Bool
    let accent: Color
    let boxed: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if boxed {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(red: 0.30, green: 0.82, blue: 0.95).opacity(0.11))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color(red: 0.55, green: 0.96, blue: 1.0).opacity(0.62), lineWidth: 2.2)
                    )
                    .frame(width: 122, height: 66)
                    .rotationEffect(.degrees(active ? -4 : 4))
                    .offset(x: 29, y: 68)
            }

            RockyLine(
                points: [
                    CGPoint(x: 18, y: active ? 93 : 101),
                    CGPoint(x: 47, y: active ? 85 : 92),
                    CGPoint(x: 72, y: 84)
                ],
                lineWidth: 2.2,
                color: Color(red: 0.54, green: 0.93, blue: 1.0).opacity(0.74)
            )
            RockyLine(
                points: [
                    CGPoint(x: 162, y: active ? 86 : 95),
                    CGPoint(x: 134, y: active ? 82 : 89),
                    CGPoint(x: 109, y: 87)
                ],
                lineWidth: 2.2,
                color: Color(red: 0.54, green: 0.93, blue: 1.0).opacity(0.74)
            )

            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == 1 ? accent.opacity(0.92) : Color(red: 0.54, green: 0.93, blue: 1.0).opacity(0.72))
                    .frame(width: CGFloat(10 + index * 6), height: 2.4)
                    .rotationEffect(.degrees(index == 1 ? -8 : 10))
                    .offset(
                        x: CGFloat(43 + index * 18),
                        y: CGFloat(active ? 58 + index * 4 : 63 + index * 3)
                    )
            }

            Circle()
                .fill(accent.opacity(active ? 0.95 : 0.55))
                .frame(width: 7, height: 7)
                .position(x: active ? 72 : 68, y: active ? 84 : 88)
                .shadow(color: accent.opacity(0.6), radius: 6)
            Circle()
                .fill(Color(red: 0.54, green: 0.93, blue: 1.0).opacity(active ? 0.92 : 0.52))
                .frame(width: 6, height: 6)
                .position(x: active ? 109 : 114, y: active ? 87 : 91)
                .shadow(color: Color(red: 0.54, green: 0.93, blue: 1.0).opacity(0.55), radius: 5)
        }
        .frame(width: 180, height: 150)
        .allowsHitTesting(false)
    }
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
