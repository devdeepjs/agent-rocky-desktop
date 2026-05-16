import AppKit
import SwiftUI

struct RootView: View {
    @ObservedObject var viewModel: CompanionAppViewModel
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
                TerminalView(
                    input: $viewModel.input,
                    model: $viewModel.model,
                    brainProvider: $viewModel.brainProvider,
                    providerBaseURL: $viewModel.providerBaseURL,
                    agentPrompt: $viewModel.agentPrompt,
                    providerAPIKey: $viewModel.providerAPIKey,
                    lines: viewModel.terminalLines,
                    isThinking: viewModel.isThinking,
                    isUsingFallback: viewModel.isUsingFallback,
                    brainStatus: viewModel.brainStatus,
                    apiKeyStatus: viewModel.apiKeyStatus,
                    isStageOpen: viewModel.isStageOpen,
                    activeProfile: viewModel.activeProfile,
                    availableProfiles: viewModel.availableProfiles,
                    modelChoices: viewModel.modelChoices,
                    conversations: viewModel.conversations,
                    activeConversationID: viewModel.activeConversationID,
                    send: viewModel.send,
                    newChat: viewModel.newChat,
                    openStage: viewModel.openStage,
                    closeStage: viewModel.closeStage,
                    switchProvider: viewModel.switchProvider,
                    selectModel: viewModel.selectModel,
                    switchProfile: viewModel.switchProfile,
                    saveBrainSettings: { viewModel.saveBrainSettings() },
                    resetAgentPrompt: viewModel.resetAgentPrompt,
                    previewNormalState: viewModel.previewNormalState,
                    previewThinkingState: viewModel.previewThinkingState,
                    previewIdleAction: viewModel.previewIdleAction,
                    selectChat: viewModel.selectChat,
                    deleteChat: viewModel.deleteActiveChat,
                    hide: viewModel.hidePanel
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
                .padding(.bottom, viewModel.isStageOpen ? 108 : 94)
            }

            CompanionCreatureView(profile: viewModel.activeProfile, mood: viewModel.mood, animation: viewModel.animation, isAwake: terminalVisible)
                .frame(width: isLargeWindow ? 190 : 130, height: isLargeWindow ? 152 : 108)
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
            idealWidth: viewModel.isStageOpen ? 760 : 330,
            maxWidth: viewModel.isStageOpen ? 940 : 620,
            minHeight: viewModel.isStageOpen ? 500 : 220,
            idealHeight: viewModel.isStageOpen ? 660 : 320,
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
                try? await Task.sleep(for: .milliseconds(viewModel.nextIdleDelayMilliseconds()))
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
            window.setContentSize(isStageOpen ? NSSize(width: 760, height: 660) : NSSize(width: 330, height: 320))
            return
        }

        let size = isStageOpen
            ? NSSize(width: min(760, screenFrame.width * 0.72), height: min(660, screenFrame.height * 0.72))
            : NSSize(width: 330, height: 320)
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

private struct TerminalView: View {
    @Binding var input: String
    @Binding var model: String
    @Binding var brainProvider: BrainProvider
    @Binding var providerBaseURL: String
    @Binding var agentPrompt: String
    @Binding var providerAPIKey: String
    let lines: [String]
    let isThinking: Bool
    let isUsingFallback: Bool
    let brainStatus: String
    let apiKeyStatus: String
    let isStageOpen: Bool
    let activeProfile: CompanionProfile
    let availableProfiles: [CompanionProfile]
    let modelChoices: [String]
    let conversations: [ConversationSummary]
    let activeConversationID: String
    let send: () -> Void
    let newChat: () -> Void
    let openStage: () -> Void
    let closeStage: () -> Void
    let switchProvider: (BrainProvider) -> Void
    let selectModel: (String) -> Void
    let switchProfile: (String) -> Void
    let saveBrainSettings: () -> Void
    let resetAgentPrompt: () -> Void
    let previewNormalState: () -> Void
    let previewThinkingState: () -> Void
    let previewIdleAction: () -> Void
    let selectChat: (String) -> Void
    let deleteChat: () -> Void
    let hide: () -> Void

    @FocusState private var inputFocused: Bool
    @State private var showSettings = false

    private var terminalTitle: String {
        activeProfile.id == "rocky" ? "rocky.term" : "\(activeProfile.id).term"
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            if isStageOpen && showSettings {
                settingsPanel
            }

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
                Text(brainProvider.displayName)
                    .foregroundStyle(Color(red: 0.78, green: 0.97, blue: 1.0).opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(width: 94, alignment: .trailing)

                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                        showSettings.toggle()
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 10, weight: .black))
                        .frame(width: 24, height: 20)
                }
                .buttonStyle(TerminalIconButtonStyle(color: Color(red: 0.76, green: 0.84, blue: 1.0)))
                .help("Brain settings")

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

            Button(action: hide) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .black))
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(TerminalIconButtonStyle(color: Color(red: 1.0, green: 0.36, blue: 0.28)))
            .help("Hide. Restore from menu bar.")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(red: 0.04, green: 0.12, blue: 0.07).opacity(0.96))
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(BrainProvider.allCases, id: \.self) { provider in
                        Button {
                            switchProvider(provider)
                        } label: {
                            Label(
                                provider.displayName,
                                systemImage: provider == brainProvider ? "checkmark.circle.fill" : "circle"
                            )
                        }
                    }
                } label: {
                    Label(brainProvider.displayName, systemImage: "bolt.horizontal")
                        .frame(minWidth: 126, alignment: .leading)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(TerminalIconButtonStyle(color: Color(red: 0.62, green: 0.90, blue: 1.0)))

                Menu {
                    ForEach(modelChoices, id: \.self) { choice in
                        Button {
                            selectModel(choice)
                        } label: {
                            Label(
                                choice.isEmpty ? "\(brainProvider.displayName) default" : choice,
                                systemImage: normalizedModelChoice(choice) == normalizedModelChoice(model) ? "checkmark.circle.fill" : "cpu"
                            )
                        }
                    }
                } label: {
                    Label(normalizedModelChoice(model).isEmpty ? "\(brainProvider.displayName) default" : normalizedModelChoice(model), systemImage: "cpu")
                        .frame(minWidth: 128, alignment: .leading)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(TerminalIconButtonStyle(color: Color(red: 0.72, green: 1.0, blue: 0.62)))

                TextField("custom model", text: $model)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white.opacity(0.84))
                    .frame(minWidth: 110)
                    .onSubmit(saveBrainSettings)

                Button(action: saveBrainSettings) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                        .frame(width: 24, height: 20)
                }
                .buttonStyle(TerminalIconButtonStyle(color: Color(red: 0.65, green: 1.0, blue: 0.54)))
                .help("Save brain settings")
            }

            if brainProvider.supportsBaseURL {
                HStack(spacing: 8) {
                    TextField("base URL", text: $providerBaseURL)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white.opacity(0.86))
                        .onSubmit(saveBrainSettings)

                    Text(brainProvider.defaultBaseURL.isEmpty ? "No default URL" : brainProvider.defaultBaseURL)
                        .foregroundStyle(Color.white.opacity(0.54))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 210, alignment: .trailing)
                }
            }

            if brainProvider.requiresAPIKey {
                HStack(spacing: 8) {
                    SecureField(brainProvider.apiKeyPlaceholder, text: $providerAPIKey)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white.opacity(0.86))
                        .onSubmit(saveBrainSettings)

                    Text(apiKeyStatus)
                        .foregroundStyle(Color.white.opacity(0.54))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 170, alignment: .trailing)
                }
            }

            HStack(spacing: 8) {
                Button(action: previewNormalState) {
                    Label("Normal", systemImage: "circle")
                        .frame(height: 20)
                }
                .buttonStyle(TerminalIconButtonStyle(color: Color(red: 0.62, green: 0.90, blue: 1.0)))
                .help("Preview normal state")

                Button(action: previewThinkingState) {
                    Label("Thinking", systemImage: "gearshape")
                        .frame(height: 20)
                }
                .buttonStyle(TerminalIconButtonStyle(color: Color(red: 0.78, green: 0.68, blue: 1.0)))
                .help("Preview thinking state")

                Button(action: previewIdleAction) {
                    Label("Idle", systemImage: "sparkles")
                        .frame(height: 20)
                }
                .buttonStyle(TerminalIconButtonStyle(color: Color(red: 1.0, green: 0.78, blue: 0.42)))
                .help("Preview a random idle action")

                Spacer()
            }

            TextEditor(text: $agentPrompt)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.88))
                .scrollContentBackground(.hidden)
                .frame(height: 86)
                .padding(7)
                .background(Color.black.opacity(0.26))
                .overlay(Rectangle().stroke(Color.white.opacity(0.14), lineWidth: 1))

            HStack(spacing: 8) {
                Button(action: resetAgentPrompt) {
                    Label("Reset prompt", systemImage: "arrow.counterclockwise")
                        .frame(height: 20)
                }
                .buttonStyle(TerminalIconButtonStyle(color: Color(red: 1.0, green: 0.78, blue: 0.42)))

                Spacer()

                Text("Prompt, provider, model, and BYOK settings are local.")
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color(red: 0.03, green: 0.07, blue: 0.055).opacity(0.96))
        .overlay(Rectangle().stroke(Color(red: 0.42, green: 1.0, blue: 0.54).opacity(0.22), lineWidth: 1))
    }

    private func normalizedModelChoice(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
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
    let mood: CompanionMood
    let animation: CompanionAnimation
    let isAwake: Bool

    var body: some View {
        if let asset = profile.asset(for: animation),
           let image = CompanionAssetView.image(for: asset) {
            CompanionAssetView(image: image, kind: asset.kind)
        } else {
            switch profile.visualStyle {
            case .cartoonCat:
                CartoonCatView(mood: mood, animation: animation, isAwake: isAwake)
            case .cuteBuddy:
                CuteBuddyView(mood: mood, animation: animation, isAwake: isAwake)
            default:
                RockyCreatureView(mood: mood, animation: animation, isAwake: isAwake)
            }
        }
    }
}

private struct CompanionAssetView: NSViewRepresentable {
    let image: NSImage
    let kind: CompanionAssetKind

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = kind == .gif
        return imageView
    }

    func updateNSView(_ imageView: NSImageView, context: Context) {
        imageView.image = image
        imageView.animates = kind == .gif
    }

    static func image(for asset: CompanionVisualAsset) -> NSImage? {
        let rawPath = asset.path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawPath.isEmpty else {
            return nil
        }

        if rawPath.hasPrefix("/") || rawPath.hasPrefix("~/") {
            return NSImage(contentsOf: resolvedURL(for: rawPath))
        }

        if let resource = NSImage(named: rawPath) {
            return resource
        }

        let profilesURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("AgentRocky/profiles", isDirectory: true)
            .appendingPathComponent(rawPath)
        if let profilesURL,
           let image = NSImage(contentsOf: profilesURL) {
            return image
        }

        return nil
    }

    private static func resolvedURL(for path: String) -> URL {
        if path.hasPrefix("~/") {
            let suffix = String(path.dropFirst(2))
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(suffix)
        }

        return URL(fileURLWithPath: path)
    }
}

private struct CartoonCatView: View {
    let mood: CompanionMood
    let animation: CompanionAnimation
    let isAwake: Bool

    @State private var wiggle = false
    @State private var blink = false

    private let canvas = CGSize(width: 150, height: 128)

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / canvas.width, geometry.size.height / canvas.height)
            let originX = (geometry.size.width - canvas.width * scale) / 2
            let originY = (geometry.size.height - canvas.height * scale) / 2

            ZStack(alignment: .topLeading) {
                Ellipse()
                    .fill(.black.opacity(0.25))
                    .frame(width: 88, height: 14)
                    .blur(radius: 4)
                    .position(x: 75, y: 112)

                tail
                    .offset(y: tailMotion)

                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(bodyGradient)
                    .frame(width: 74, height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 27, style: .continuous)
                            .stroke(outline, lineWidth: 3)
                    )
                    .position(x: 78, y: 78)
                    .offset(y: bodyMotion)

                Ellipse()
                    .fill(cream.opacity(0.92))
                    .frame(width: 40, height: 28)
                    .position(x: 78, y: 84)
                    .offset(y: bodyMotion)

                paw(x: 55, activeOffset: pawMotionA)
                paw(x: 96, activeOffset: pawMotionB)

                ears
                    .offset(y: headMotion)

                Circle()
                    .fill(headGradient)
                    .frame(width: 60, height: 56)
                    .overlay(Circle().stroke(outline, lineWidth: 3))
                    .position(x: 70, y: 43)
                    .offset(y: headMotion)

                cheek(x: 52)
                cheek(x: 88)

                face
                    .offset(y: headMotion)

                if animation == .lick {
                    Capsule()
                        .fill(pink)
                        .frame(width: 8, height: wiggle ? 15 : 10)
                        .position(x: 70, y: 62)
                        .offset(y: headMotion)
                }

                if animation == .play || animation == .playBall {
                    playBall
                }

                if animation == .purr || mood == .happy {
                    purrMarks
                }

                if animation == .sleep {
                    sleepMarks
                }
            }
            .frame(width: canvas.width, height: canvas.height)
            .scaleEffect(scale, anchor: .topLeading)
            .offset(x: originX, y: originY + verticalMotion)
            .scaleEffect(isAwake ? 1.03 : 1.0)
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
            return wiggle ? -5 : -1
        case .walk, .play, .playBall:
            return wiggle ? -3 : 0
        case .sleep:
            return 4
        default:
            return wiggle ? -1.5 : 0
        }
    }

    private var bodyMotion: CGFloat {
        animation == .happyBounce || animation == .excited ? (wiggle ? -2 : 1) : 0
    }

    private var headMotion: CGFloat {
        switch animation {
        case .happyBounce, .excited, .purr:
            return wiggle ? -3 : 0
        case .sleep:
            return 3
        default:
            return wiggle ? -1 : 0
        }
    }

    private var tailMotion: CGFloat {
        animation == .sleep ? 3 : (wiggle ? -3 : 2)
    }

    private var pawMotionA: CGSize {
        animation == .walk || animation == .play ? CGSize(width: wiggle ? -4 : 3, height: wiggle ? -1 : 1) : .zero
    }

    private var pawMotionB: CGSize {
        animation == .walk || animation == .play ? CGSize(width: wiggle ? 3 : -4, height: wiggle ? 1 : -1) : .zero
    }

    private var outline: Color {
        Color(red: 0.17, green: 0.09, blue: 0.045)
    }

    private var orange: Color {
        Color(red: 0.96, green: 0.50, blue: 0.20)
    }

    private var lightOrange: Color {
        Color(red: 1.0, green: 0.69, blue: 0.35)
    }

    private var cream: Color {
        Color(red: 1.0, green: 0.87, blue: 0.66)
    }

    private var pink: Color {
        Color(red: 1.0, green: 0.48, blue: 0.58)
    }

    private var moodTint: Color {
        switch mood {
        case .happy:
            return Color(red: 1.0, green: 0.80, blue: 0.22)
        case .thinking:
            return Color(red: 0.34, green: 0.82, blue: 1.0)
        case .sleepy:
            return Color(red: 0.62, green: 0.66, blue: 1.0)
        case .curious:
            return Color(red: 0.56, green: 0.95, blue: 0.58)
        case .error:
            return Color(red: 1.0, green: 0.34, blue: 0.24)
        }
    }

    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [lightOrange, orange, Color(red: 0.78, green: 0.30, blue: 0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var headGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.78, blue: 0.45), orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var tail: some View {
        Group {
            Path { path in
                path.move(to: CGPoint(x: 109, y: 75))
                path.addCurve(to: CGPoint(x: 132, y: 39), control1: CGPoint(x: 130, y: 73), control2: CGPoint(x: 138, y: 54))
                path.addCurve(to: CGPoint(x: 119, y: 31), control1: CGPoint(x: 130, y: 32), control2: CGPoint(x: 123, y: 30))
            }
            .stroke(outline, style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))

            Path { path in
                path.move(to: CGPoint(x: 109, y: 75))
                path.addCurve(to: CGPoint(x: 132, y: 39), control1: CGPoint(x: 130, y: 73), control2: CGPoint(x: 138, y: 54))
                path.addCurve(to: CGPoint(x: 119, y: 31), control1: CGPoint(x: 130, y: 32), control2: CGPoint(x: 123, y: 30))
            }
            .stroke(lightOrange, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
        }
    }

    private var ears: some View {
        Group {
            Path { path in
                path.move(to: CGPoint(x: 48, y: 30))
                path.addLine(to: CGPoint(x: 53, y: 7))
                path.addLine(to: CGPoint(x: 66, y: 29))
                path.closeSubpath()
            }
            .fill(orange)
            .overlay(
                Path { path in
                    path.move(to: CGPoint(x: 48, y: 30))
                    path.addLine(to: CGPoint(x: 53, y: 7))
                    path.addLine(to: CGPoint(x: 66, y: 29))
                    path.closeSubpath()
                }
                .stroke(outline, lineWidth: 3)
            )

            Path { path in
                path.move(to: CGPoint(x: 74, y: 29))
                path.addLine(to: CGPoint(x: 90, y: 8))
                path.addLine(to: CGPoint(x: 93, y: 31))
                path.closeSubpath()
            }
            .fill(lightOrange)
            .overlay(
                Path { path in
                    path.move(to: CGPoint(x: 74, y: 29))
                    path.addLine(to: CGPoint(x: 90, y: 8))
                    path.addLine(to: CGPoint(x: 93, y: 31))
                    path.closeSubpath()
                }
                .stroke(outline, lineWidth: 3)
            )

            Path { path in
                path.move(to: CGPoint(x: 54, y: 24))
                path.addLine(to: CGPoint(x: 56, y: 15))
                path.addLine(to: CGPoint(x: 61, y: 25))
                path.closeSubpath()
            }
            .fill(pink.opacity(0.72))

            Path { path in
                path.move(to: CGPoint(x: 83, y: 25))
                path.addLine(to: CGPoint(x: 88, y: 16))
                path.addLine(to: CGPoint(x: 89, y: 26))
                path.closeSubpath()
            }
            .fill(pink.opacity(0.72))
        }
    }

    private var face: some View {
        Group {
            if blink || animation == .sleep {
                Capsule()
                    .fill(outline.opacity(0.82))
                    .frame(width: 11, height: 2.5)
                    .position(x: 58, y: 42)
                Capsule()
                    .fill(outline.opacity(0.82))
                    .frame(width: 11, height: 2.5)
                    .position(x: 82, y: 42)
            } else {
                Circle()
                    .fill(Color.black.opacity(0.9))
                    .frame(width: 8, height: 9)
                    .position(x: 58, y: 42)
                Circle()
                    .fill(Color.black.opacity(0.9))
                    .frame(width: 8, height: 9)
                    .position(x: 82, y: 42)
                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 2.5, height: 2.5)
                    .position(x: 56.5, y: 40)
                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 2.5, height: 2.5)
                    .position(x: 80.5, y: 40)
            }

            Capsule()
                .fill(pink)
                .frame(width: 9, height: 6)
                .position(x: 70, y: 52)

            Path { path in
                path.move(to: CGPoint(x: 70, y: 55))
                path.addCurve(to: CGPoint(x: 62, y: 60), control1: CGPoint(x: 68, y: 59), control2: CGPoint(x: 65, y: 61))
                path.move(to: CGPoint(x: 70, y: 55))
                path.addCurve(to: CGPoint(x: 78, y: 60), control1: CGPoint(x: 72, y: 59), control2: CGPoint(x: 75, y: 61))
            }
            .stroke(outline.opacity(0.74), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            whiskers
        }
    }

    private var whiskers: some View {
        Path { path in
            path.move(to: CGPoint(x: 48, y: 51))
            path.addLine(to: CGPoint(x: 31, y: 47))
            path.move(to: CGPoint(x: 48, y: 56))
            path.addLine(to: CGPoint(x: 30, y: 57))
            path.move(to: CGPoint(x: 92, y: 51))
            path.addLine(to: CGPoint(x: 110, y: 47))
            path.move(to: CGPoint(x: 92, y: 56))
            path.addLine(to: CGPoint(x: 111, y: 57))
        }
        .stroke(outline.opacity(0.55), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    private func cheek(x: CGFloat) -> some View {
        Circle()
            .fill(pink.opacity(animation == .purr ? 0.35 : 0.22))
            .frame(width: 13, height: 9)
            .position(x: x, y: 54)
            .offset(y: headMotion)
    }

    private func paw(x: CGFloat, activeOffset: CGSize) -> some View {
        Capsule()
            .fill(cream)
            .frame(width: 19, height: 11)
            .overlay(Capsule().stroke(outline.opacity(0.82), lineWidth: 2))
            .position(x: x, y: 102)
            .offset(x: activeOffset.width, y: activeOffset.height + bodyMotion)
    }

    private var playBall: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.24, green: 0.76, blue: 1.0))
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(outline, lineWidth: 2))
            Circle()
                .fill(.white.opacity(0.84))
                .frame(width: 6, height: 6)
                .offset(x: -4, y: -4)
        }
        .position(x: wiggle ? 30 : 36, y: 96)
    }

    private var purrMarks: some View {
        Group {
            Circle()
                .fill(moodTint.opacity(wiggle ? 0.82 : 0.36))
                .frame(width: 7, height: 7)
                .position(x: 29, y: 29)
            Circle()
                .fill(moodTint.opacity(wiggle ? 0.36 : 0.72))
                .frame(width: 5, height: 5)
                .position(x: 110, y: 25)
            Circle()
                .fill(moodTint.opacity(0.45))
                .frame(width: 4, height: 4)
                .position(x: 119, y: 37)
        }
        .offset(y: wiggle ? -2 : 1)
    }

    private var sleepMarks: some View {
        Group {
            Text("z")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.86))
                .position(x: 113, y: 30)
            Text("Z")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.62))
                .position(x: 128, y: 18)
        }
    }
}

private struct CuteBuddyView: View {
    let mood: CompanionMood
    let animation: CompanionAnimation
    let isAwake: Bool

    @State private var pulse = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(.black.opacity(0.28))
                .frame(width: 76, height: 12)
                .blur(radius: 4)
                .offset(y: 45)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.73, green: 1.0, blue: 0.36), Color(red: 0.18, green: 0.55, blue: 0.36)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 76, height: 68)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.48), lineWidth: 2.5))
                .offset(y: pulse ? -4 : 0)

            Circle()
                .fill(.black.opacity(0.86))
                .frame(width: 7, height: 7)
                .offset(x: -15, y: -8)
            Circle()
                .fill(.black.opacity(0.86))
                .frame(width: 7, height: 7)
                .offset(x: 15, y: -8)
            Capsule()
                .fill(.black.opacity(0.56))
                .frame(width: 23, height: 4)
                .offset(y: 10)
        }
        .scaleEffect(isAwake ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: pulse)
        .onAppear {
            pulse = true
        }
    }
}

private struct RockyCreatureView: View {
    let mood: CompanionMood
    let animation: CompanionAnimation
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
