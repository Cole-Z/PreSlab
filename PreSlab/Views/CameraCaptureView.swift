import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct CameraCaptureView: View {
    var side: CardSide
    var onCapture: (UIImage) -> Void

    @State private var camera = CameraModel()
    @State private var pickerItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Photograph the \(side.title.lowercased())")
                .font(.title2.bold())
            Text("Fit the whole card inside the frame. Hold about a hand's width away — closer cannot focus. Tap the card to focus before you shoot.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ZStack {
                if camera.isAuthorized {
                    CameraPreview(session: camera.session, onTap: camera.focus(at:))
                    FramingGuide()
                } else {
                    ContentUnavailableView(
                        "Camera unavailable",
                        systemImage: "camera",
                        description: Text(camera.statusMessage)
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button {
                camera.setTorch(!camera.torchOn)
            } label: {
                Label(camera.torchOn ? "Light on" : "Light off", systemImage: camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!camera.isAuthorized)
            .accessibilityIdentifier("torchToggleButton")

            Button {
                camera.capture(onCapture)
            } label: {
                Text(camera.isCapturing ? "Capturing…" : (camera.isFocusing ? "Focusing…" : "Take photo"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!camera.isAuthorized || !camera.isReady || camera.isFocusing || camera.isCapturing)
            .accessibilityIdentifier("takePhotoButton")

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Choose from library")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("photoLibraryButton")
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else {
                            camera.captureError = "That library photo could not be read. Choose another image."
                            return
                        }
                        onCapture(image)
                    } catch {
                        camera.captureError = "That library photo could not be loaded. Choose another image."
                    }
                }
            }
        }
        .padding()
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .alert("Photo unavailable", isPresented: Binding(
            get: { camera.captureError != nil },
            set: { if !$0 { camera.captureError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(camera.captureError ?? "")
        }
    }
}

private struct FramingGuide: View {
    var body: some View {
        GeometryReader { geo in
            let inset = CGSize(width: max(0, geo.size.width - 56), height: max(0, geo.size.height - 56))
            let card = aspectFitRect(content: CGSize(width: 2.5, height: 3.5), in: inset)
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: card.width, height: card.height)
                .position(x: card.midX + 28, y: card.midY + 28)
            Text("Card")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .shadow(radius: 2)
                .position(x: geo.size.width / 2, y: card.minY + 16)
        }
        .allowsHitTesting(false)
    }
}

func aspectFitRect(content: CGSize, in bounds: CGSize) -> CGRect {
    guard content.width > 0, content.height > 0, bounds.width > 0, bounds.height > 0 else {
        return .zero
    }
    let scale = min(bounds.width / content.width, bounds.height / content.height)
    let width = content.width * scale
    let height = content.height * scale
    return CGRect(x: (bounds.width - width) / 2, y: (bounds.height - height) / 2, width: width, height: height)
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var onTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class Coordinator: NSObject {
        var onTap: (CGPoint) -> Void
        weak var view: PreviewView?

        init(onTap: @escaping (CGPoint) -> Void) {
            self.onTap = onTap
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let view, gesture.state == .recognized else { return }
            let layerPoint = gesture.location(in: view)
            onTap(view.previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint))
        }
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

@Observable
final class CameraModel: NSObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "preslab.camera")
    private var onPhoto: ((UIImage) -> Void)?
    private var device: AVCaptureDevice?
    private var focusObservation: NSKeyValueObservation?
    private var lastFocusPoint = CGPoint(x: 0.5, y: 0.5)
    var isAuthorized = false
    var isReady = false
    var isFocusing = false
    var isCapturing = false
    var torchOn = false
    var statusMessage = "Checking camera access."
    var captureError: String?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    self?.statusMessage = granted ? "" : "Camera access is off. You can still choose a photo from your library."
                    if granted { self?.configureAndStart() }
                }
            }
        default:
            isAuthorized = false
            statusMessage = "Camera access is off. You can still choose a photo from your library, or allow the camera in Settings."
        }
    }

    func stop() {
        isReady = false
        queue.async { [weak self] in
            if let device = self?.device, device.hasTorch {
                if (try? device.lockForConfiguration()) != nil {
                    device.torchMode = .off
                    device.unlockForConfiguration()
                }
            }
            if let session = self?.session, session.isRunning { session.stopRunning() }
        }
    }

    func setTorch(_ on: Bool) {
        torchOn = on
        queue.async { [weak self] in
            guard let device = self?.device, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {
                return
            }
        }
    }

    func capture(_ handler: @escaping (UIImage) -> Void) {
        guard isReady, !isCapturing else { return }
        isCapturing = true
        captureError = nil
        onPhoto = handler
        queue.async { [weak self] in
            guard let self else { return }
            self.lockFocusBeforeCapture()
            let settings = AVCapturePhotoSettings()
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    /// Focuses where the user tapped, in preview-layer coordinates (0–1).
    func focus(at devicePoint: CGPoint) {
        queue.async { [weak self] in
            guard let self, let device = self.device else { return }
            let point = CGPoint(x: min(max(devicePoint.x, 0), 1), y: min(max(devicePoint.y, 0), 1))
            self.lastFocusPoint = point
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                }
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                }
                if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                }
                let adjusting = device.isAdjustingFocus
                device.unlockForConfiguration()
                DispatchQueue.main.async { self.isFocusing = adjusting }
            } catch {
                return
            }
        }
    }

    /// Locks focus before the still so the photo uses a settled lens.
    /// Forces a fresh scan at the last tapped point: re-setting an already
    /// locked mode can be a no-op, which used to keep a stale lock forever.
    /// Gives up after a short wait rather than blocking capture forever.
    private func lockFocusBeforeCapture() {
        guard let device, device.isFocusModeSupported(.autoFocus),
              device.isFocusModeSupported(.continuousAutoFocus) else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = lastFocusPoint
            }
            device.focusMode = .continuousAutoFocus
            device.focusMode = .autoFocus
            device.unlockForConfiguration()
        } catch {
            return
        }
        DispatchQueue.main.async { self.isFocusing = true }
        let deadline = Date().addingTimeInterval(1.5)
        while device.isAdjustingFocus, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        DispatchQueue.main.async { self.isFocusing = false }
    }

    private func configureAndStart() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input),
                      self.session.canAddOutput(self.output) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.isAuthorized = false
                        self.statusMessage = "This device has no usable back camera. Choose a photo from your library."
                    }
                    return
                }
                self.session.addInput(input)
                self.session.addOutput(self.output)
                self.device = device
                self.focusObservation = device.observe(\.isAdjustingFocus, options: [.initial, .new]) { [weak self] device, _ in
                    DispatchQueue.main.async { self?.isFocusing = device.isAdjustingFocus }
                }
                if device.hasTorch, (try? device.lockForConfiguration()) != nil {
                    device.torchMode = self.torchOn ? .on : .off
                    device.unlockForConfiguration()
                }
                if let connection = self.output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                self.session.commitConfiguration()
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.isReady = self.session.isRunning }
        }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            self.isCapturing = false
            guard error == nil,
                  let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                self.onPhoto = nil
                self.captureError = "The camera did not produce a usable photo. Please try again."
                return
            }
            self.onPhoto?(image)
            self.onPhoto = nil
        }
    }
}
