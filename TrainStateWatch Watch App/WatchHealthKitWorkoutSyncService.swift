import Foundation
import HealthKit
import WatchConnectivity

@MainActor
final class WatchHealthKitWorkoutSyncService: NSObject {
    static let shared = WatchHealthKitWorkoutSyncService()

    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var hasStarted = false

    private override init() {
        super.init()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        activateWatchConnectivity()

        guard HKHealthStore.isHealthDataAvailable() else { return }

        let workoutType = HKObjectType.workoutType()
        Task {
            do {
                try await healthStore.requestAuthorization(toShare: [], read: [workoutType])
                try await enableBackgroundDelivery(for: workoutType)
                observeWorkouts(workoutType: workoutType)
            } catch {
                print("[WatchHealthKitSync] Failed to start: \(error.localizedDescription)")
            }
        }
    }

    private func activateWatchConnectivity() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func observeWorkouts(workoutType: HKSampleType) {
        if let observerQuery {
            healthStore.stop(observerQuery)
        }

        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error {
                print("[WatchHealthKitSync] Observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }

            Task { @MainActor in
                self?.notifyPhone()
                completionHandler()
            }
        }

        observerQuery = query
        healthStore.execute(query)
    }

    private func enableBackgroundDelivery(for workoutType: HKSampleType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.enableBackgroundDelivery(
                for: workoutType,
                frequency: .immediate
            ) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "WatchHealthKitWorkoutSyncService",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKit background delivery was not enabled."]
                    ))
                }
            }
        }
    }

    private func notifyPhone() {
        guard WCSession.isSupported() else { return }

        let payload: [String: Any] = [
            "event": "healthKitWorkoutsChanged",
            "sentAt": Date().timeIntervalSince1970
        ]

        let session = WCSession.default
        if session.activationState == .activated, session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("[WatchHealthKitSync] Reachable message failed: \(error.localizedDescription)")
            }
        }

        do {
            try session.updateApplicationContext(payload)
        } catch {
            print("[WatchHealthKitSync] Application context failed: \(error.localizedDescription)")
        }

        session.transferUserInfo(payload)
    }
}

extension WatchHealthKitWorkoutSyncService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("[WatchHealthKitSync] Activation failed: \(error.localizedDescription)")
        }
    }
}
