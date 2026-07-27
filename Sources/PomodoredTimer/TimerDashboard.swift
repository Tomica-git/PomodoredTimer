import SwiftUI

enum Palette {
    static let canvas = Color(red: 0.86, green: 0.93, blue: 0.89)
    static let panel = Color(red: 0.94, green: 0.97, blue: 0.94)
    static let ink = Color(red: 0.08, green: 0.20, blue: 0.20)
    static let muted = Color(red: 0.31, green: 0.42, blue: 0.40)
    static let teal = Color(red: 0.05, green: 0.36, blue: 0.36)
    static let coral = Color(red: 0.91, green: 0.31, blue: 0.27)
    static let breakBlue = Color(red: 0.20, green: 0.48, blue: 0.72)
    static let remainingLight = Color(red: 0.31, green: 0.73, blue: 0.88)
    static let overlapPink = Color(red: 0.96, green: 0.58, blue: 0.72)
    static let navy = Color(red: 0.07, green: 0.09, blue: 0.09)
    static let mint = Color(red: 0.63, green: 0.84, blue: 0.75)
}

struct TimerDashboard: View {
    @ObservedObject var model: TimerViewModel
    @State private var showingHistory = false

    var body: some View {
        Group {
            if model.isCompactMode {
                compactDashboard
            } else {
                standardDashboard
            }
        }
        .background {
            WindowConfigurationView(
                isCompact: model.isCompactMode,
                isAlwaysOnTop: model.isAlwaysOnTop,
                toggleCompact: {
                    model.setCompactMode(!model.isCompactMode)
                }
            )
        }
        .foregroundStyle(Palette.ink)
        .alert("ポモドーロを最初に戻しますか？", isPresented: $model.showResetConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("最初に戻す", role: .destructive) { model.reset() }
        } message: {
            Text("現在の集中・休憩を終了し、セット数を0にして「集中 · SET 1」へ戻します。時間や音量などの設定は残ります。")
        }
        .alert("保存データを保護しました", isPresented: $model.showStateRecoveryWarning) {
            Button("既存データを保持", role: .cancel) {
                model.keepUnreadableState()
            }
            Button("初期状態で保存を再開", role: .destructive) {
                model.replaceUnreadableStateWithFreshState()
            }
        } message: {
            Text("保存データを読み込めなかったため、元データをバックアップして自動保存を停止しました。初期状態で保存を再開するまで元データは上書きしません。")
        }
        .overlay(alignment: .top) {
            if model.showCompletion {
                completionBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 18)
            }
        }
        .animation(model.settings.reduceMotion ? nil : .spring(response: 0.38), value: model.showCompletion)
    }

    private var standardDashboard: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            HStack(spacing: 0) {
                Group {
                    if showingHistory {
                        ActivityHistoryView(model: model) {
                            showingHistory = false
                        }
                    } else {
                        timerStage
                    }
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !showingHistory {
                    settingsPanel
                        .frame(width: 280)
                }
            }
        }
    }

    private var compactDashboard: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("POMODORED")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(Palette.teal)
                        Text("\(model.phase.title) · SET \(model.completedFocusSets + 1)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }

                    Spacer()

                    compactIconButton(
                        systemImage: model.isAlwaysOnTop ? "pin.fill" : "pin",
                        label: model.isAlwaysOnTop ? "常に手前を解除" : "常に手前に表示"
                    ) {
                        model.toggleAlwaysOnTop()
                    }

                    compactIconButton(
                        systemImage: "arrow.up.left.and.arrow.down.right",
                        label: "通常サイズに戻す"
                    ) {
                        model.setCompactMode(false)
                    }
                }

                HStack(spacing: 14) {
                    DualNeedleClock(
                        fastNeedleElapsed: model.projection.fastNeedleElapsed,
                        remaining: model.projection.remaining,
                        fastRateLabel: model.fastNeedleRate,
                        reduceMotion: model.settings.reduceMotion
                    )
                    .frame(width: 122, height: 122)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(formatDuration(model.projection.remaining))
                            .font(.system(size: 39, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())

                        Text("赤 ×\(model.fastNeedleRate.formatted(.number.precision(.fractionLength(1))))  黒 1分/目盛")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Palette.muted)

                        Button {
                            model.toggleNeedleSoundsMuted()
                        } label: {
                            Label(
                                model.settings.needleSoundsMuted ? "消音中" : "針音オン",
                                systemImage: model.settings.needleSoundsMuted
                                    ? "speaker.slash.fill"
                                    : "speaker.wave.2.fill"
                            )
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(model.settings.needleSoundsMuted ? Palette.coral : Palette.teal)
                    }
                }

                HStack(spacing: 8) {
                    Button(action: model.primaryAction) {
                        Label(model.primaryActionTitle, systemImage: primaryIcon)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.space, modifiers: [])

                    Button(action: model.requestReset) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 38)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel("リセット")
                    .keyboardShortcut("r", modifiers: .command)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 14)
        }
    }

    private var timerStage: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("POMODORED")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(2.8)
                        .foregroundStyle(Palette.teal)
                    Text(model.phase.title)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                }

                Spacer()

                Button {
                    showingHistory = true
                } label: {
                    Label("記録", systemImage: "chart.bar.xaxis")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Palette.teal)

                Button {
                    model.toggleAlwaysOnTop()
                } label: {
                    Label(
                        model.isAlwaysOnTop ? "手前固定中" : "常に手前",
                        systemImage: model.isAlwaysOnTop ? "pin.fill" : "pin"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(model.isAlwaysOnTop ? Palette.coral : Palette.teal)

                Button {
                    model.setCompactMode(true)
                } label: {
                    Label("縮小", systemImage: "arrow.down.right.and.arrow.up.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Palette.teal)

                Text("SET \(model.completedFocusSets + 1)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Palette.panel, in: Capsule())
            }

            Spacer(minLength: 0)

            DualNeedleClock(
                fastNeedleElapsed: model.projection.fastNeedleElapsed,
                remaining: model.projection.remaining,
                fastRateLabel: model.fastNeedleRate,
                reduceMotion: model.settings.reduceMotion
            )
            .frame(width: 310, height: 310)

            VStack(spacing: 3) {
                Text(formatDuration(model.projection.remaining))
                    .font(.system(size: 66, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityLabel("残り時間 \(spokenDuration(model.projection.remaining))")

                Text("終了時刻は実時間で変わりません")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.muted)
            }

            HStack(spacing: 10) {
                MetricPill(
                    title: "赤い倍速針",
                    value: "×\(model.fastNeedleRate.formatted(.number.precision(.fractionLength(1))))",
                    color: Palette.coral
                )
                MetricPill(
                    title: "黒い残り針",
                    value: "1分 / 目盛",
                    color: Palette.navy
                )
                MetricPill(
                    title: "次",
                    value: model.nextPhase.title,
                    color: Palette.teal
                )
            }

            HStack(spacing: 12) {
                Button(action: model.primaryAction) {
                    Label(model.primaryActionTitle, systemImage: primaryIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(minWidth: 150)
                        .padding(.vertical, 12)
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.space, modifiers: [])

                Button(action: model.requestReset) {
                    Label("リセット", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.vertical, 12)
                }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut("r", modifiers: .command)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 42)
        .padding(.top, 34)
        .padding(.bottom, 30)
    }

    private var settingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("時間を整える")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                VStack(spacing: 14) {
                MinuteEditor(title: "集中", value: $model.settings.focusMinutes, range: 10...90)
                MinuteEditor(title: "短い休憩", value: $model.settings.shortBreakMinutes, range: 3...30)
                MinuteEditor(title: "長い休憩", value: $model.settings.longBreakMinutes, range: 3...30)
                }
                .onChange(of: model.settings) { _, _ in model.applySettings() }

            Divider().overlay(Palette.teal.opacity(0.18))

            VStack(alignment: .leading, spacing: 11) {
                Text("赤い針の速さ")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.muted)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                    spacing: 6
                ) {
                    ForEach([1.0, 1.5, 2.0, 3.0, 4.0, 5.0], id: \.self) { speed in
                        Button(speedLabel(speed)) {
                            model.setSpeed(speed)
                        }
                        .buttonStyle(SpeedButtonStyle(isSelected: model.fastNeedleRate == speed))
                    }
                }

                Slider(
                    value: Binding(
                        get: { model.fastNeedleRate },
                        set: { model.setSpeed($0) }
                    ),
                    in: 0.5...5,
                    step: 0.1
                )
                .tint(Palette.coral)

                Toggle(
                    "自動で次のセッションへ移行",
                    isOn: Binding(
                        get: { model.settings.automaticallyStartNextSession },
                        set: {
                            model.settings.automaticallyStartNextSession = $0
                            model.applySettings()
                        }
                    )
                )
                    .toggleStyle(.switch)

                Text("集中と休憩を自動で開始します。")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }


            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("針の音")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.muted)
                    Spacer()
                    Button {
                        model.toggleNeedleSoundsMuted()
                    } label: {
                        Label(
                            model.settings.needleSoundsMuted ? "ミュート解除" : "ミュート",
                            systemImage: model.settings.needleSoundsMuted
                                ? "speaker.slash.fill"
                                : "speaker.wave.2.fill"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(model.settings.needleSoundsMuted ? Palette.coral : Palette.teal)
                }

                SoundVolumeControl(
                    title: "カチ",
                    subtitle: "赤い針の1秒ごと",
                    volume: $model.settings.tickVolume,
                    preview: model.previewTick
                )
                SoundVolumeControl(
                    title: "コチ",
                    subtitle: "赤い針の1周ごと",
                    volume: $model.settings.tockVolume,
                    preview: model.previewTock
                )

                if model.settings.needleSoundsMuted {
                    Text("針の音をミュート中です")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.coral)
                }
            }
            .onChange(of: model.settings) { _, _ in model.applySettings() }

                VStack(alignment: .leading, spacing: 8) {
                    Label("端末内だけに保存", systemImage: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("針の速さは見え方だけを変えます。タイマーの終了時刻には影響しません。")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 34)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.automatic)
        .tint(Palette.teal)
        .background(Palette.panel.opacity(0.92))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Palette.teal.opacity(0.12))
                .frame(width: 1)
        }
    }

    private var completionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.mint)
                .font(.title2)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(model.phase.title)が完了しました")
                    .font(.system(size: 14, weight: .bold))
                Text("次は\(model.nextPhase.title)です")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.74))
            }
            Button("閉じる") { model.dismissCompletion() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .bold))
                .padding(.leading, 12)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Palette.teal, in: Capsule())
        .shadow(color: Palette.teal.opacity(0.22), radius: 16, y: 8)
    }

    private var primaryIcon: String {
        switch model.session.status {
        case .running: "pause.fill"
        case .completed: "forward.fill"
        case .idle, .paused: "play.fill"
        }
    }

    private func speedLabel(_ value: Double) -> String {
        value == 1 ? "通常" : "×\(value.formatted(.number.precision(.fractionLength(value == 1.5 ? 1 : 0))))"
    }


    private func compactIconButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 26, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.teal)
        .background(Palette.panel.opacity(0.9), in: RoundedRectangle(cornerRadius: 7))
        .accessibilityLabel(label)
        .help(label)
    }
}

private struct SoundVolumeControl: View {
    let title: String
    let subtitle: String
    @Binding var volume: Double
    let preview: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Button("試聴", action: preview)
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.teal)
            }
            HStack(spacing: 8) {
                Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.wave.1.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.muted)
                Slider(value: $volume, in: 0...1, step: 0.05)
                    .tint(Palette.teal)
                Text("\(Int(volume * 100))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .frame(width: 24, alignment: .trailing)
            }
        }
    }
}

private struct DualNeedleClock: View {
    let fastNeedleElapsed: TimeInterval
    let remaining: TimeInterval
    let fastRateLabel: Double
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Palette.panel, Palette.canvas],
                            center: .topLeading,
                            startRadius: 10,
                            endRadius: side * 0.64
                        )
                    )
                    .overlay {
                        Circle().stroke(Palette.teal.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: Palette.teal.opacity(0.12), radius: 24, y: 12)

                RemainingTimeSector(
                    fraction: TimerMath.remainingSectorFraction(remaining: remaining)
                )
                .fill(Palette.remainingLight.opacity(0.48))
                .padding(side * 0.055)
                .animation(reduceMotion ? nil : .linear(duration: 0.1), value: remaining)

                RemainingTimeSector(
                    fraction: TimerMath.remainingOverlapSectorFraction(remaining: remaining)
                )
                .fill(Palette.overlapPink.opacity(0.78))
                .padding(side * 0.055)
                .animation(reduceMotion ? nil : .linear(duration: 0.1), value: remaining)

                ForEach(0..<60, id: \.self) { tick in
                    Capsule()
                        .fill(tick.isMultiple(of: 5) ? Palette.teal : Palette.teal.opacity(0.28))
                        .frame(width: tick.isMultiple(of: 5) ? 3 : 1, height: tick.isMultiple(of: 5) ? 14 : 6)
                        .offset(y: -side * 0.425)
                        .rotationEffect(.degrees(Double(tick) * 6))
                }

                Circle()
                    .trim(from: 0, to: CGFloat((fastNeedleElapsed.truncatingRemainder(dividingBy: 60)) / 60))
                    .stroke(Palette.coral.opacity(0.50), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(side * 0.08)

                Needle(length: side * 0.39, width: 7, color: Palette.coral)
                    .rotationEffect(.degrees(TimerMath.handAngle(elapsed: fastNeedleElapsed, rate: 1)))
                    .animation(reduceMotion ? nil : .linear(duration: 0.1), value: fastNeedleElapsed)

                TaperedCountdownNeedle(length: side * 0.31)
                    .rotationEffect(.degrees(TimerMath.countdownHandAngle(remaining: remaining)))
                    .animation(reduceMotion ? nil : .linear(duration: 0.1), value: remaining)

                Circle()
                    .fill(Palette.teal)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Palette.panel, lineWidth: 4))
                    .shadow(color: Palette.teal.opacity(0.24), radius: 5, y: 3)
            }
            .frame(width: side, height: side)
            .position(center)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "赤い針 \(fastRateLabel.formatted()) 倍、黒い針の残り時間 \(spokenDuration(remaining))"
            )
        }
    }
}

private struct RemainingTimeSector: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let safeFraction = min(1, max(0, fraction))
        if safeFraction >= 0.999_999 {
            return Path(ellipseIn: rect)
        }
        guard safeFraction > 0 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + safeFraction * 360),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct TaperedCountdownNeedle: View {
    let length: CGFloat

    var body: some View {
        TaperedNeedleShape()
            .fill(Palette.navy)
            .frame(width: 16, height: length)
            .offset(y: -length / 2)
            .shadow(color: Palette.navy.opacity(0.24), radius: 3, y: 2)
    }
}

private struct TaperedNeedleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - rect.width / 2, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX - 1.2, y: rect.minY + 1))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX + 1.2, y: rect.minY + 1),
            control: CGPoint(x: rect.midX, y: rect.minY - 1)
        )
        path.addLine(to: CGPoint(x: rect.midX + rect.width / 2, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct Needle: View {
    let length: CGFloat
    let width: CGFloat
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2 + width / 2)
            .shadow(color: color.opacity(0.22), radius: 3, y: 2)
    }
}

private struct MetricPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Palette.muted)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Palette.panel.opacity(0.88), in: Capsule())
    }
}

private struct MinuteEditor: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    @State private var draft: String
    @FocusState private var isFocused: Bool

    init(title: String, value: Binding<Int>, range: ClosedRange<Int>) {
        self.title = title
        self._value = value
        self.range = range
        self._draft = State(initialValue: String(value.wrappedValue))
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Spacer()

            HStack(spacing: 5) {
                minuteButton(systemImage: "minus", label: "\(title)を1分減らす") {
                    value = max(range.lowerBound, value - 1)
                }
                .disabled(value <= range.lowerBound)

                HStack(spacing: 2) {
                    TextField("", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .frame(width: 31)
                        .focused($isFocused)
                        .onSubmit(commitDraft)
                        .accessibilityLabel("\(title)の分数")
                        .accessibilityHint("数字を入力してReturnで確定。全角数字は半角へ変換")

                    Text("分")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                }
                .padding(.horizontal, 7)
                .frame(height: 28)
                .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isFocused ? Palette.coral : Palette.teal.opacity(0.16),
                            lineWidth: isFocused ? 2 : 1
                        )
                }

                minuteButton(systemImage: "plus", label: "\(title)を1分増やす") {
                    value = min(range.upperBound, value + 1)
                }
                .disabled(value >= range.upperBound)
            }
        }
        .onChange(of: draft) { _, newValue in
            let filtered = DurationInput.asciiDigits(from: newValue)
            if filtered != newValue {
                draft = filtered
                return
            }
            if let entered = Int(filtered), range.contains(entered) {
                value = entered
            }
        }
        .onChange(of: value) { _, newValue in
            if !isFocused {
                draft = String(newValue)
            }
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                draft = ""
            } else {
                commitDraft()
            }
        }
    }

    private func minuteButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.teal)
        .background(Palette.canvas, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Palette.teal.opacity(0.16), lineWidth: 1)
        }
        .accessibilityLabel(label)
    }

    private func commitDraft() {
        value = DurationInput.committedValue(
            from: draft,
            currentValue: value,
            range: range
        )
        draft = String(value)
        isFocused = false
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .background(Palette.teal.opacity(configuration.isPressed ? 0.78 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Palette.teal)
            .padding(.horizontal, 16)
            .background(Palette.panel.opacity(configuration.isPressed ? 0.6 : 1), in: Capsule())
            .overlay(Capsule().stroke(Palette.teal.opacity(0.18), lineWidth: 1))
    }
}

private struct SpeedButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(isSelected ? Color.white : Palette.teal)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(isSelected ? Palette.teal : Palette.canvas, in: Capsule())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private func formatDuration(_ seconds: TimeInterval) -> String {
    TimerMath.clockString(seconds)
}

private func spokenDuration(_ seconds: TimeInterval) -> String {
    let rounded = max(0, Int(ceil(seconds)))
    return "\(rounded / 60)分\(rounded % 60)秒"
}
