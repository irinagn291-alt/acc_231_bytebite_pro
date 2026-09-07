@preconcurrency import AVFoundation
import SwiftUI
import UIKit

/// ScanPreviewHost embeds live capture. Session start/stop matches the 19AUG MetadataOutput scanners.
struct ScanPreviewHost: UIViewRepresentable {
    var onDecode: (String) -> Void
    var running: Bool

    func makeUIView(context: Context) -> ScanCaptureBox {
        let canvas = ScanCaptureBox()
        canvas.onCode = onDecode
        if running { canvas.startSession() }
        return canvas
    }

    func updateUIView(_ uiView: ScanCaptureBox, context: Context) {
        uiView.onCode = onDecode
        if running {
            uiView.startSession()
        } else {
            uiView.stopSession()
        }
    }

    static func dismantleUIView(_ uiView: ScanCaptureBox, coordinator: ()) {
        uiView.stopSession()
    }
}

final class ScanCaptureBox: UIView, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    nonisolated(unsafe) private let session = AVCaptureSession()
    private let preview = AVCaptureVideoPreviewLayer()
    private let sessionQueue = DispatchQueue(label: "bytebite.scan.session")
    private var lastEmit: TimeInterval = 0
    private var didConfigure = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        preview.videoGravity = .resizeAspectFill
        preview.session = session
        layer.insertSublayer(preview, at: 0)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        preview.frame = bounds
    }

    func startSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            boot()
        default:
            break
        }
    }

    func stopSession() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func boot() {
        configureIfNeeded()
        sessionQueue.async { [session] in
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    private func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true
        session.beginConfiguration()
        session.sessionPreset = .high
        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        let wanted: [AVMetadataObject.ObjectType] = [.ean8, .ean13, .upce, .code128, .qr]
        output.metadataObjectTypes = wanted.filter { output.availableMetadataObjectTypes.contains($0) }
        session.commitConfiguration()
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        let now = Date().timeIntervalSince1970
        guard now - lastEmit > 0.7 else { return }
        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let raw = object.stringValue
        else { return }
        lastEmit = now
        onCode?(raw)
    }
}
