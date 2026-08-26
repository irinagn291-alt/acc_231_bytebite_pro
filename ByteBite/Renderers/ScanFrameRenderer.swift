import AVFoundation
import SwiftUI
import UIKit

/// ScanFrameRenderer is the full-screen live capture overlay.
@MainActor
struct ScanFrameRenderer: View {
    @ObservedObject var processor: ScanFrameProcessor
    @State private var box = ScanCaptureBox()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool

    var body: some View {
        render(model: processor.model)
            .onAppear {
                processor.dispatch(.appear)
                refreshPermission()
            }
            .onDisappear {
                box.stop()
                processor.dispatch(.disappear)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background || phase == .inactive {
                    box.stop()
                    processor.dispatch(.appBackgrounded)
                } else if phase == .active, processor.model.shouldRunSession {
                    box.start()
                }
            }
            .onChange(of: processor.model.shouldRunSession) { _, run in
                if run {
                    if box.configure() { box.start() }
                } else {
                    box.stop()
                }
            }
    }

    func render(model: ScanFrameModel) -> some View {
        VStack(spacing: GridUnit.n(2)) {
            HStack {
                Text("scan frame")
                    .font(GlyphType.font(.title))
                    .foregroundStyle(PhosphorPalette.ink)
                Spacer()
                Button {
                    processor.dispatch(.dismiss)
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(PhosphorPalette.ink)
                .accessibilityLabel("close scanner")
            }

            ZStack {
                if model.shouldRunSession {
                    ScanPreviewHost(box: box)
                } else {
                    Image("byb_ScanOverlay")
                        .resizable()
                        .scaledToFit()
                        .opacity(0.4)
                        .accessibilityHidden(true)
                }
                ScanReticleCanvas(
                    flashUntil: model.flashUntil,
                    reduceMotion: reduceMotion
                )
                if model.resolving {
                    ProgressView()
                        .tint(PhosphorPalette.accent)
                        .accessibilityLabel("resolving code")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .background(PhosphorPalette.surface)
            .overlay(Rectangle().stroke(PhosphorPalette.muted, lineWidth: 1))

            permissionBlock(model)

            TextField("manual barcode", text: Binding(
                get: { model.typed },
                set: { processor.dispatch(.typed($0)) }
            ))
            .keyboardType(.numberPad)
            .font(GlyphType.font(.body))
            .foregroundStyle(PhosphorPalette.ink)
            .padding(GridUnit.n(1))
            .overlay(Rectangle().stroke(PhosphorPalette.muted, lineWidth: 1))
            .focused($focused)
            .frame(minHeight: 44)
            .accessibilityLabel("manual barcode")

            Button("resolve") { processor.dispatch(.submitManual) }
                .buttonStyle(PhosphorButtonStyle(disabled: model.resolving))
                .disabled(model.resolving)
                .accessibilityLabel("resolve typed barcode")

            if let fault = model.faultCopy {
                VStack(spacing: GridUnit.n(1)) {
                    Text(fault)
                        .font(GlyphType.font(.caption))
                        .foregroundStyle(PhosphorPalette.accent)
                        .multilineTextAlignment(.center)
                    Button("retry") { processor.dispatch(.clearFault) }
                        .buttonStyle(PhosphorGhostStyle())
                        .accessibilityLabel("clear scan fault")
                }
            }

            if !model.hasDevice {
                Text("no capture device — shelf samples")
                    .font(GlyphType.font(.caption))
                    .foregroundStyle(PhosphorPalette.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GridUnit.n(1)) {
                        ForEach(model.samples) { sample in
                            Button(sample.name) { processor.dispatch(.pickSample(sample.barcode)) }
                                .buttonStyle(PhosphorGhostStyle())
                                .accessibilityLabel("sample \(sample.name)")
                        }
                    }
                }
            }
        }
        .padding(GridUnit.n(2))
        .background(TextureBackdrop())
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { focused = false }
    }

    @ViewBuilder
    private func permissionBlock(_ model: ScanFrameModel) -> some View {
        switch model.permission {
        case .denied:
            VStack(spacing: GridUnit.n(1)) {
                Text("camera denied. open settings to score packets from barcodes.")
                    .font(GlyphType.font(.body))
                    .foregroundStyle(PhosphorPalette.accent)
                    .multilineTextAlignment(.center)
                Button("open settings") { openSettings() }
                    .buttonStyle(PhosphorButtonStyle())
                    .accessibilityLabel("open settings")
            }
        case .restricted:
            VStack(spacing: GridUnit.n(1)) {
                Text("camera restricted by parental controls. use manual entry.")
                    .font(GlyphType.font(.body))
                    .foregroundStyle(PhosphorPalette.accent)
                    .multilineTextAlignment(.center)
                Button("open settings") { openSettings() }
                    .buttonStyle(PhosphorButtonStyle())
                    .accessibilityLabel("open settings")
            }
        case .asking:
            Text("requesting camera…")
                .font(GlyphType.font(.caption))
                .foregroundStyle(PhosphorPalette.muted)
        case .unknown, .allowed, .noDevice:
            EmptyView()
        }
    }

    private func refreshPermission() {
        let device = AVCaptureDevice.default(for: .video)
        let hasDevice = device != nil
        if !hasDevice {
            processor.applyPermission(.noDevice, hasDevice: false)
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            processor.applyPermission(.allowed, hasDevice: true)
            box.onDecode = { raw in processor.dispatch(.decoded(raw)) }
            if box.configure() { box.start() }
        case .denied:
            processor.applyPermission(.denied, hasDevice: true)
        case .restricted:
            processor.applyPermission(.restricted, hasDevice: true)
        case .notDetermined:
            processor.applyPermission(.asking, hasDevice: true)
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    processor.applyPermission(granted ? .allowed : .denied, hasDevice: true)
                    if granted {
                        box.onDecode = { raw in processor.dispatch(.decoded(raw)) }
                        if box.configure() { box.start() }
                    }
                }
            }
        @unknown default:
            processor.applyPermission(.denied, hasDevice: true)
        }
    }

    private func openSettings() {
        processor.dispatch(.openSettings)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
