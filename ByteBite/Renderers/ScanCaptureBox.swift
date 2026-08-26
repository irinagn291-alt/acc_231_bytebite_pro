import AVFoundation
import SwiftUI

/// ScanCaptureBox owns the live AVCaptureMetadataOutput session.
/// Session start/stop is serialized on a lock. The AVFoundation callback hops to MainActor immediately.
/// @unchecked Sendable: the box is a single-owner session wrapper; UI never mutates session fields concurrently.
final class ScanCaptureBox: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let lock = NSLock()
    private var configured = false
    var onDecode: ((String) -> Void)?

    func configure() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if configured { return true }
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return false }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        let wanted: [AVMetadataObject.ObjectType] = [.ean8, .ean13, .upce, .qr]
        output.metadataObjectTypes = wanted.filter { output.availableMetadataObjectTypes.contains($0) }
        configured = true
        return true
    }

    func start() {
        // startRunning blocks; must not occupy the main actor.
        Task.detached(priority: .userInitiated) { [self] in
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        Task.detached(priority: .userInitiated) { [self] in
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = first.stringValue
        else { return }
        onDecode?(value)
    }
}

/// ScanPreviewHost embeds the capture preview layer.
@MainActor
struct ScanPreviewHost: UIViewRepresentable {
    let box: ScanCaptureBox

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.preview.session = box.session
        view.preview.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.preview.session = box.session
    }
}

@MainActor
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    /// layerClass is AVCaptureVideoPreviewLayer, so this cast cannot fail at runtime.
    var preview: AVCaptureVideoPreviewLayer {
        guard let preview = layer as? AVCaptureVideoPreviewLayer else {
            return AVCaptureVideoPreviewLayer()
        }
        return preview
    }
}
