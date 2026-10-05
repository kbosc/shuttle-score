import ShuttleCore
import Testing

@MainActor
private final class FakeSession: WorkoutSession {
    enum Call: Equatable {
        case start
        case pause
        case resume
        case end(save: Bool)
        case endRecovered
        case recover
    }

    var hasRecoverableSession = false

    var calls: [Call] = []
    var startError: (any Error)?
    /// Si renseigné, `start()` reste suspendu jusqu'à `finishStart()`.
    private var pendingStart: CheckedContinuation<Void, Never>?
    var holdsStart = false

    func start() async throws {
        calls.append(.start)
        if holdsStart {
            await withCheckedContinuation { pendingStart = $0 }
        }
        if let startError { throw startError }
    }

    func finishStart() {
        pendingStart?.resume()
        pendingStart = nil
    }

    func pause() { calls.append(.pause) }
    func resume() { calls.append(.resume) }
    func end(save: Bool) async { calls.append(.end(save: save)) }
    func endRecoveredSession() async { calls.append(.endRecovered) }
    func recover() async -> Bool {
        calls.append(.recover)
        return hasRecoverableSession
    }
}

private struct Denied: Error {}

@MainActor
@Suite struct WorkoutTrackerTests {
    @Test func aMatchStartsTheWorkout() async {
        let session = FakeSession()
        let tracker = WorkoutTracker(session: session)
        await tracker.matchStarted()
        #expect(session.calls == [.start])
        #expect(tracker.status == .running)
    }

    @Test func aDeniedWorkoutLeavesTheMatchPlayable() async {
        let session = FakeSession()
        session.startError = Denied()
        let tracker = WorkoutTracker(session: session)
        await tracker.matchStarted()
        #expect(tracker.status == .unavailable)
        tracker.matchChanged(isOver: true)
        await tracker.matchLeft(hadRallies: true)
        #expect(session.calls == [.start])
        #expect(tracker.status == .idle)
    }

    @Test func theWorkoutPausesWhenTheMatchEndsAndResumesIfUndoReopensIt() async {
        let session = FakeSession()
        let tracker = WorkoutTracker(session: session)
        await tracker.matchStarted()
        tracker.matchChanged(isOver: false)
        tracker.matchChanged(isOver: true)
        tracker.matchChanged(isOver: true)
        #expect(tracker.status == .paused)
        tracker.matchChanged(isOver: false)
        #expect(tracker.status == .running)
        #expect(session.calls == [.start, .pause, .resume])
    }

    @Test func leavingAPlayedMatchSavesTheWorkout() async {
        let session = FakeSession()
        let tracker = WorkoutTracker(session: session)
        await tracker.matchStarted()
        tracker.matchChanged(isOver: true)
        await tracker.matchLeft(hadRallies: true)
        #expect(session.calls == [.start, .pause, .end(save: true)])
        #expect(tracker.status == .idle)
    }

    @Test func leavingBeforeTheFirstPointDiscardsTheWorkout() async {
        let session = FakeSession()
        let tracker = WorkoutTracker(session: session)
        await tracker.matchStarted()
        await tracker.matchLeft(hadRallies: false)
        #expect(session.calls == [.start, .end(save: false)])
    }

    @Test func resumingAMatchRecoversItsWorkout() async {
        let session = FakeSession()
        session.hasRecoverableSession = true
        let tracker = WorkoutTracker(session: session)
        await tracker.matchResumed()
        #expect(session.calls == [.recover])
        #expect(tracker.status == .running)
    }

    @Test func resumingAMatchWhoseWorkoutIsGoneStartsANewOne() async {
        let session = FakeSession()
        let tracker = WorkoutTracker(session: session)
        await tracker.matchResumed()
        #expect(session.calls == [.recover, .start])
        #expect(tracker.status == .running)
    }

    @Test func aNewMatchNeverRecoversAnOldWorkout() async {
        let session = FakeSession()
        session.hasRecoverableSession = true
        let tracker = WorkoutTracker(session: session)
        await tracker.matchStarted()
        #expect(session.calls == [.start])
    }

    @Test func launchingWithoutAMatchToResumeEndsAnOrphanWorkout() async {
        let session = FakeSession()
        let tracker = WorkoutTracker(session: session)
        await tracker.appLaunched(withMatchToResume: false)
        #expect(session.calls == [.endRecovered])
    }

    @Test func launchingWithAMatchToResumeKeepsItsWorkoutForTheDecision() async {
        let session = FakeSession()
        let tracker = WorkoutTracker(session: session)
        await tracker.appLaunched(withMatchToResume: true)
        #expect(session.calls.isEmpty)
    }

    @Test func decliningTheResumeEndsTheWorkoutLeftByTheCrash() async {
        let session = FakeSession()
        let tracker = WorkoutTracker(session: session)
        await tracker.resumeDeclined()
        #expect(session.calls == [.endRecovered])
        #expect(tracker.status == .idle)
    }

    @Test func decliningTheResumeDoesNotTouchAWorkoutInProgress() async {
        let session = FakeSession()
        let tracker = WorkoutTracker(session: session)
        await tracker.matchStarted()
        await tracker.resumeDeclined()
        #expect(session.calls == [.start])
        #expect(tracker.status == .running)
    }

    @Test func leavingWithoutAnyMatchDoesNothing() async {
        let session = FakeSession()
        let tracker = WorkoutTracker(session: session)
        await tracker.matchLeft(hadRallies: true)
        tracker.matchChanged(isOver: true)
        #expect(session.calls.isEmpty)
    }

    @Test func aSecondMatchStartsANewWorkout() async {
        let session = FakeSession()
        let tracker = WorkoutTracker(session: session)
        await tracker.matchStarted()
        await tracker.matchLeft(hadRallies: false)
        await tracker.matchStarted()
        #expect(session.calls == [.start, .end(save: false), .start])
        #expect(tracker.status == .running)
    }

    @Test func leavingWhileTheWorkoutIsStartingDiscardsItOnceStarted() async {
        let session = FakeSession()
        session.holdsStart = true
        let tracker = WorkoutTracker(session: session)
        let starting = Task { await tracker.matchStarted() }
        // Attente bornée : si start() n'est jamais appelé, le test échoue au lieu de bloquer.
        for _ in 0..<1_000 where session.calls.isEmpty { await Task.yield() }
        #expect(tracker.status == .starting)

        await tracker.matchLeft(hadRallies: false)
        session.finishStart()
        starting.cancel()
        await starting.value
        #expect(session.calls == [.start, .end(save: false)])
        #expect(tracker.status == .idle)
    }
}
