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
                    send: viewModel.send,
                    newChat: viewModel.newChat,
                    quit: viewModel.quit
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
                .padding(.bottom, 150)
            }

            PixelRockyView(mood: viewModel.mood, animation: viewModel.animation, isAwake: terminalVisible)
                .frame(width: 170, height: 160)
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
    let send: () -> Void
    let newChat: () -> Void
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

private struct PixelRockyView: View {
    let mood: RockyMood
    let animation: RockyAnimation
    let isAwake: Bool

    @State private var bounce = false
    @State private var blink = false

    var body: some View {
        GeometryReader { geometry in
            let unit = min(geometry.size.width / 18, geometry.size.height / 17)
            let originX = (geometry.size.width - unit * 18) / 2
            let originY = (geometry.size.height - unit * 17) / 2

            ZStack(alignment: .topLeading) {
                shadow(unit: unit)
                    .offset(x: originX + unit * 3.5, y: originY + unit * 14.2)

                ForEach(pixelBlocks(unit: unit), id: \.id) { block in
                    Rectangle()
                        .fill(block.color)
                        .frame(width: block.w * unit, height: block.h * unit)
                        .offset(x: originX + block.x * unit, y: originY + block.y * unit)
                }
            }
            .offset(y: verticalMotion)
            .scaleEffect(isAwake ? 1.04 : 1.0)
            .animation(.easeInOut(duration: 0.78).repeatForever(autoreverses: true), value: bounce)
            .animation(.easeInOut(duration: 0.16), value: isAwake)
            .onAppear {
                bounce = true
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

    private func shadow(unit: CGFloat) -> some View {
        Rectangle()
            .fill(.black.opacity(0.38))
            .frame(width: unit * 11, height: unit * 1.2)
            .blur(radius: unit * 0.4)
    }

    private var verticalMotion: CGFloat {
        switch animation {
        case .bounce:
            return bounce ? -8 : -2
        case .pulse:
            return bounce ? -4 : 1
        default:
            return bounce ? -3 : 1
        }
    }

    private func pixelBlocks(unit: CGFloat) -> [PixelBlock] {
        let dark = Color(red: 0.17, green: 0.10, blue: 0.05)
        let outline = Color(red: 0.08, green: 0.05, blue: 0.03)
        let brown = Color(red: 0.53, green: 0.31, blue: 0.12)
        let gold = Color(red: 0.86, green: 0.55, blue: 0.19)
        let light = Color(red: 1.0, green: 0.70, blue: 0.30)
        let teal = Color(red: 0.02, green: 0.74, blue: 0.58)
        let eye = blink ? brown : Color(red: 0.02, green: 0.02, blue: 0.015)
        let accent = moodAccent

        return [
            // Back legs.
            PixelBlock(2, 8, 1, 4, outline), PixelBlock(3, 7, 1, 4, brown), PixelBlock(1, 12, 3, 1, dark),
            PixelBlock(15, 8, 1, 4, outline), PixelBlock(14, 7, 1, 4, brown), PixelBlock(14, 12, 3, 1, dark),
            PixelBlock(5, 10, 1, 4, outline), PixelBlock(6, 10, 1, 4, brown), PixelBlock(5, 14, 3, 1, dark),
            PixelBlock(12, 10, 1, 4, outline), PixelBlock(11, 10, 1, 4, brown), PixelBlock(10, 14, 3, 1, dark),

            // Raised cute arms.
            PixelBlock(4, 4, 1, 4, outline), PixelBlock(5, 3, 1, 4, gold), PixelBlock(5, 2, 1, 1, teal),
            PixelBlock(13, 4, 1, 4, outline), PixelBlock(12, 3, 1, 4, gold), PixelBlock(12, 2, 1, 1, teal),

            // Body outline and faceted center.
            PixelBlock(6, 5, 6, 1, outline),
            PixelBlock(5, 6, 8, 1, outline),
            PixelBlock(4, 7, 10, 4, outline),
            PixelBlock(5, 11, 8, 2, outline),
            PixelBlock(6, 13, 6, 1, outline),

            PixelBlock(6, 6, 6, 1, light),
            PixelBlock(5, 7, 8, 1, gold),
            PixelBlock(5, 8, 8, 2, brown),
            PixelBlock(5, 10, 8, 1, gold.opacity(0.82)),
            PixelBlock(6, 11, 6, 1, brown),
            PixelBlock(7, 12, 4, 1, dark.opacity(0.95)),

            // Facet highlights.
            PixelBlock(6, 7, 3, 1, Color.white.opacity(0.32)),
            PixelBlock(6, 8, 2, 1, Color.white.opacity(0.18)),
            PixelBlock(11, 8, 1, 1, dark.opacity(0.62)),
            PixelBlock(9, 11, 2, 1, Color.black.opacity(0.2)),

            // Face.
            PixelBlock(7, 8, 1, 1, eye),
            PixelBlock(11, 8, 1, 1, eye),
            PixelBlock(8, 10, 3, 1, dark.opacity(0.64)),

            // Mood core.
            PixelBlock(8, 12, 2, 1, accent),
            PixelBlock(8, 13, 2, 1, accent.opacity(0.72))
        ].enumerated().map { index, block in
            var mutable = block
            mutable.id = index
            return mutable
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

private struct PixelBlock {
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
