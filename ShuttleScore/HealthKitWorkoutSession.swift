import HealthKit
import ShuttleCore

/// Séance « Badminton » en salle, enregistrée dans Santé avec calories et fréquence cardiaque.
/// C'est aussi ce qui garde l'app au premier plan entre deux échanges.
@MainActor
final class HealthKitWorkoutSession: WorkoutSession {
    enum Failure: Error {
        case healthDataUnavailable
        case notAuthorized
    }

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    func start() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw Failure.healthDataUnavailable }
        // Ne montre la demande d'accès qu'au premier match.
        try await store.requestAuthorization(
            toShare: [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)],
            read: [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)])
        guard store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
        else { throw Failure.notAuthorized }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .badminton
        configuration.locationType = .indoor
        let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: store, workoutConfiguration: configuration)

        let startDate = Date()
        session.startActivity(with: startDate)
        try await builder.beginCollection(at: startDate)
        self.session = session
        self.builder = builder
    }

    func pause() {
        session?.pause()
    }

    func resume() {
        session?.resume()
    }

    /// Après un plantage, watchOS garde la séance du match active : on la reprend.
    func recover() async -> Bool {
        guard session == nil, let recovered = try? await store.recoverActiveWorkoutSession()
        else { return false }
        let builder = recovered.associatedWorkoutBuilder()
        // La source de données ne survit pas forcément au plantage : on la rebranche.
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: store, workoutConfiguration: recovered.workoutConfiguration)
        session = recovered
        self.builder = builder
        recovered.resume()
        return true
    }

    func endRecoveredSession() async {
        guard await recover() else { return }
        await end(save: true)
    }

    func end(save: Bool) async {
        guard let session, let builder else { return }
        self.session = nil
        self.builder = nil
        session.end()
        do {
            try await builder.endCollection(at: Date())
            if save {
                _ = try await builder.finishWorkout()
            } else {
                builder.discardWorkout()
            }
        } catch {
            // La séance est perdue, mais le match, lui, n'est pas affecté.
            builder.discardWorkout()
        }
    }
}

/// Séance factice pour les tests UI : évite la demande d'accès HealthKit, qui bloquerait l'écran.
@MainActor
final class NoWorkoutSession: WorkoutSession {
    func start() async throws {}
    func pause() {}
    func resume() {}
    func end(save: Bool) async {}
    func recover() async -> Bool { false }
    func endRecoveredSession() async {}
}
