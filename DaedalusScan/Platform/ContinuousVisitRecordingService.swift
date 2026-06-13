import AVFoundation
import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ContinuousVisitRecordingService: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var activeVisitID: UUID?
    @Published private(set) var activeRecordingID: UUID?
    @Published var errorMessage: String?

    private let viewModel: VisitListViewModel
    private let chunkDuration: TimeInterval
    private var recorder: AVAudioRecorder?
    private var chunkTimer: Timer?
    private var shouldResumeAfterInterruption = false
    private var notificationObservers: [NSObjectProtocol] = []

    init(viewModel: VisitListViewModel, chunkDuration: TimeInterval = 600) {
        self.viewModel = viewModel
        self.chunkDuration = chunkDuration
        super.init()
        installObservers()
    }

    deinit {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        chunkTimer?.invalidate()
    }

    func startRecording(visitID: UUID) {
        guard !isRecording else { return }
        activeVisitID = visitID
        saveRecoverySnapshot(for: visitID, shouldOfferResumeRecording: true)
        startNewChunk(for: visitID)
    }

    func stopRecording() {
        guard let visitID = activeVisitID else { return }
        finishCurrentChunk(for: visitID, status: .completed)
        clearCompletedRecordingRecovery()
        activeVisitID = nil
        shouldResumeAfterInterruption = false
    }

    func rotateChunk() {
        guard let visitID = activeVisitID, isRecording else { return }
        finishCurrentChunk(for: visitID, status: .completed)
        startNewChunk(for: visitID)
    }

    func handleBackgroundTransition() {
        guard isRecording else { return }
        recorder?.record()
        if let activeVisitID {
            saveRecoverySnapshot(for: activeVisitID, shouldOfferResumeRecording: true)
        }
    }

    func handleInterruptionBegan() {
        guard let visitID = activeVisitID, isRecording else { return }
        shouldResumeAfterInterruption = true
        finishCurrentChunk(for: visitID, status: .interrupted)
    }

    func handleInterruptionEnded(shouldResume: Bool) {
        guard shouldResumeAfterInterruption, shouldResume, let visitID = activeVisitID else {
            shouldResumeAfterInterruption = false
            return
        }
        shouldResumeAfterInterruption = false
        saveRecoverySnapshot(for: visitID, shouldOfferResumeRecording: true)
        startNewChunk(for: visitID)
    }

    private func startNewChunk(for visitID: UUID) {
        guard let chunk = viewModel.prepareVisitRecordingChunkURL(for: visitID) else { return }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let nextRecorder = try AVAudioRecorder(url: chunk.url, settings: settings)
            nextRecorder.delegate = self
            nextRecorder.record()

            let recordingID = viewModel.attachVisitRecordingChunk(
                localFileName: chunk.url.lastPathComponent,
                sequenceNumber: chunk.sequenceNumber,
                to: visitID
            )

            recorder = nextRecorder
            activeRecordingID = recordingID
            isRecording = true
            saveRecoverySnapshot(
                for: visitID,
                activeRecordingID: recordingID,
                activeRecordingFileName: chunk.url.lastPathComponent,
                shouldOfferResumeRecording: true
            )
            scheduleChunkTimer()
        } catch {
            errorMessage = error.localizedDescription
            isRecording = false
            activeRecordingID = nil
        }
    }

    private func finishCurrentChunk(for visitID: UUID, status: VisitRecordingStatus) {
        chunkTimer?.invalidate()
        chunkTimer = nil

        recorder?.stop()
        recorder = nil
        isRecording = false

        if let activeRecordingID {
            viewModel.completeVisitRecordingChunk(
                recordingID: activeRecordingID,
                visitID: visitID,
                status: status
            )
            saveRecoverySnapshot(
                for: visitID,
                activeRecordingID: activeRecordingID,
                shouldOfferResumeRecording: status == .interrupted
            )
        }
        activeRecordingID = nil
    }

    private func saveRecoverySnapshot(
        for visitID: UUID,
        activeRecordingID: UUID? = nil,
        activeRecordingFileName: String? = nil,
        shouldOfferResumeRecording: Bool
    ) {
        var snapshot = viewModel.pendingCaptureRecoverySnapshot ?? CaptureRecoverySnapshot(visitID: visitID)
        snapshot.visitID = visitID
        snapshot.activeRecordingID = activeRecordingID
        snapshot.activeRecordingFileName = activeRecordingFileName ?? snapshot.activeRecordingFileName
        snapshot.shouldOfferResumeRecording = shouldOfferResumeRecording
        snapshot.updatedAt = Date()
        viewModel.saveCaptureRecoverySnapshot(snapshot)
    }

    private func clearCompletedRecordingRecovery() {
        guard var snapshot = viewModel.pendingCaptureRecoverySnapshot else { return }
        snapshot.activeRecordingID = nil
        snapshot.activeRecordingFileName = nil
        snapshot.shouldOfferResumeRecording = false
        snapshot.updatedAt = Date()

        if snapshot.unsavedEvidenceDrafts.isEmpty {
            viewModel.clearCaptureRecoverySnapshot()
        } else {
            viewModel.saveCaptureRecoverySnapshot(snapshot)
        }
    }

    private func scheduleChunkTimer() {
        chunkTimer?.invalidate()
        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.rotateChunk()
            }
        }
    }

    private func installObservers() {
        let center = NotificationCenter.default
        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    self?.handleAudioSessionInterruption(notification)
                }
            }
        )

        #if canImport(UIKit)
        notificationObservers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleBackgroundTransition()
                }
            }
        )
        #endif
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            handleInterruptionBegan()
        case .ended:
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            handleInterruptionEnded(shouldResume: options.contains(.shouldResume))
        @unknown default:
            break
        }
    }
}

extension ContinuousVisitRecordingService: AVAudioRecorderDelegate {}
