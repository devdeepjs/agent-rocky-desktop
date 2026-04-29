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
                .padding(.bottom, 118)
            }

            PixelRockyView(mood: viewModel.mood, animation: viewModel.animation, isAwake: terminalVisible)
                .frame(width: 138, height: 122)
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

    @State private var gaitFrame = false
    @State private var blink = false

    var body: some View {
        GeometryReader { geometry in
            let unit = min(geometry.size.width / 18, geometry.size.height / 17)
            let originX = (geometry.size.width - unit * 18) / 2
            let originY = (geometry.size.height - unit * 17) / 2

            ZStack(alignment: .topLeading) {
                shadow(unit: unit)
                    .offset(x: originX + unit * 4.2, y: originY + unit * 14.4)

                ForEach(pixelBlocks(), id: \.id) { block in
                    let spriteOffset = spriteOffset(for: block.motion, unit: unit)

                    Rectangle()
                        .fill(block.color)
                        .frame(width: block.w * unit, height: block.h * unit)
                        .offset(
                            x: originX + block.x * unit + spriteOffset.width,
                            y: originY + block.y * unit + spriteOffset.height
                        )
                }
            }
            .offset(y: verticalMotion)
            .scaleEffect(isAwake ? 1.04 : 1.0)
            .animation(.easeInOut(duration: 0.16), value: isAwake)
            .task(id: isAwake) {
                while !Task.isCancelled {
                    try? await Task.sleep(for: isAwake ? .milliseconds(220) : .milliseconds(340))
                    gaitFrame.toggle()
                }
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
            .frame(width: unit * 9.5, height: unit * 1.0)
            .blur(radius: unit * 0.4)
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

    private func spriteOffset(for motion: PixelMotion, unit: CGFloat) -> CGSize {
        switch motion {
        case .none:
            return .zero
        case .stepA:
            return gaitFrame ? CGSize(width: -unit, height: 0) : CGSize(width: 0, height: -unit)
        case .stepB:
            return gaitFrame ? CGSize(width: unit, height: -unit) : .zero
        case .grabberA:
            return gaitFrame ? CGSize(width: 0, height: -unit) : .zero
        case .grabberB:
            return gaitFrame ? .zero : CGSize(width: 0, height: -unit)
        }
    }

    private func pixelBlocks() -> [PixelBlock] {
        let crack = Color(red: 0.09, green: 0.05, blue: 0.025)
        let dark = Color(red: 0.18, green: 0.10, blue: 0.045)
        let outline = Color(red: 0.055, green: 0.035, blue: 0.02)
        let rust = Color(red: 0.43, green: 0.22, blue: 0.075)
        let brown = Color(red: 0.60, green: 0.34, blue: 0.13)
        let gold = Color(red: 0.86, green: 0.55, blue: 0.18)
        let light = Color(red: 1.0, green: 0.74, blue: 0.34)
        let teal = Color(red: 0.0, green: 0.76, blue: 0.62)
        let mineral = blink ? moodAccent.opacity(0.45) : moodAccent
        let accent = moodAccent

        return [
            // Rear splayed legs.
            PixelBlock(3, 7, 1, 3, outline, motion: .stepA), PixelBlock(2, 9, 1, 3, rust, motion: .stepA), PixelBlock(0, 12, 3, 1, outline, motion: .stepA),
            PixelBlock(14, 7, 1, 3, outline, motion: .stepB), PixelBlock(15, 9, 1, 3, rust, motion: .stepB), PixelBlock(15, 12, 3, 1, outline, motion: .stepB),

            // Middle walking legs.
            PixelBlock(5, 10, 1, 2, outline, motion: .stepB), PixelBlock(4, 12, 1, 3, brown, motion: .stepB), PixelBlock(2, 15, 3, 1, outline, motion: .stepB),
            PixelBlock(12, 10, 1, 2, outline, motion: .stepA), PixelBlock(13, 12, 1, 3, brown, motion: .stepA), PixelBlock(13, 15, 3, 1, outline, motion: .stepA),

            // Front angled legs.
            PixelBlock(6, 11, 1, 3, outline, motion: .stepA), PixelBlock(7, 13, 1, 2, rust, motion: .stepA), PixelBlock(6, 15, 3, 1, outline, motion: .stepA),
            PixelBlock(11, 11, 1, 3, outline, motion: .stepB), PixelBlock(10, 13, 1, 2, rust, motion: .stepB), PixelBlock(9, 15, 3, 1, outline, motion: .stepB),

            // Rocky-style raised grabbers.
            PixelBlock(5, 4, 1, 3, outline, motion: .grabberA), PixelBlock(4, 3, 1, 2, brown, motion: .grabberA), PixelBlock(3, 2, 1, 2, gold, motion: .grabberA), PixelBlock(3, 1, 1, 1, teal, motion: .grabberA),
            PixelBlock(12, 4, 1, 3, outline, motion: .grabberB), PixelBlock(13, 3, 1, 2, brown, motion: .grabberB), PixelBlock(14, 2, 1, 2, gold, motion: .grabberB), PixelBlock(14, 1, 1, 1, teal, motion: .grabberB),

            // Jagged rock shell outline.
            PixelBlock(7, 4, 4, 1, outline),
            PixelBlock(6, 5, 6, 1, outline),
            PixelBlock(5, 6, 8, 1, outline),
            PixelBlock(4, 7, 10, 3, outline),
            PixelBlock(5, 10, 8, 2, outline),
            PixelBlock(6, 12, 6, 1, outline),
            PixelBlock(7, 13, 4, 1, outline),

            // Faceted mineral body.
            PixelBlock(7, 5, 4, 1, light),
            PixelBlock(6, 6, 6, 1, gold),
            PixelBlock(5, 7, 3, 2, brown),
            PixelBlock(8, 7, 4, 1, light.opacity(0.9)),
            PixelBlock(12, 7, 1, 2, rust),
            PixelBlock(5, 9, 4, 1, gold.opacity(0.86)),
            PixelBlock(9, 8, 3, 2, brown),
            PixelBlock(12, 9, 1, 1, dark),
            PixelBlock(6, 10, 3, 1, rust),
            PixelBlock(9, 10, 3, 1, gold.opacity(0.78)),
            PixelBlock(7, 11, 4, 1, brown),
            PixelBlock(8, 12, 2, 1, dark.opacity(0.92)),

            // Asymmetric cracks, not a face.
            PixelBlock(8, 6, 1, 2, crack.opacity(0.72)),
            PixelBlock(9, 8, 1, 1, crack.opacity(0.82)),
            PixelBlock(10, 9, 1, 2, crack.opacity(0.72)),
            PixelBlock(6, 9, 2, 1, Color.white.opacity(0.18)),
            PixelBlock(10, 7, 2, 1, Color.white.opacity(0.24)),
            PixelBlock(11, 11, 1, 1, crack.opacity(0.8)),

            // Tiny mineral lights.
            PixelBlock(6, 8, 1, 1, teal.opacity(0.88)),
            PixelBlock(11, 9, 1, 1, mineral),
            PixelBlock(9, 12, 1, 1, accent.opacity(0.78))
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

private enum PixelMotion {
    case none
    case stepA
    case stepB
    case grabberA
    case grabberB
}

private struct PixelBlock {
    var id = 0
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat
    let color: Color
    let motion: PixelMotion

    init(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color, motion: PixelMotion = .none) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.color = color
        self.motion = motion
    }
}
