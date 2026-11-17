import Foundation

enum Rating: Int, CaseIterable {
    case again, hard, good, easy
}

enum CardStatus: Equatable {
    case new, learning, known
}

struct SRSState: Equatable {
    var due: Date
    var interval: Double
    var ease: Double
    var reps: Int
    var lapses: Int
}

enum SRS {
    static let startEase = 2.5
    static let minEase = 1.3
    static let knownDays = 21.0
    static let againDelay = 10.0 * 60

    static func state(of e: VocabEntry) -> SRSState? {
        guard e.lastReview != nil, let due = e.due else { return nil }
        return SRSState(due: due, interval: e.interval ?? 0, ease: e.ease ?? startEase, reps: e.reps ?? 0, lapses: e.lapses ?? 0)
    }

    static func status(of e: VocabEntry) -> CardStatus {
        guard let s = state(of: e) else { return .new }
        return s.interval >= knownDays ? .known : .learning
    }

    static func isDue(_ e: VocabEntry, now: Date) -> Bool {
        guard let s = state(of: e) else { return true }
        return s.due <= now
    }

    static func review(_ s: SRSState?, rating: Rating, now: Date) -> SRSState {
        let cur = s ?? SRSState(due: now, interval: 0, ease: startEase, reps: 0, lapses: 0)
        var interval = cur.interval
        var ease = cur.ease
        var reps = cur.reps
        var lapses = cur.lapses
        switch rating {
        case .again:
            return SRSState(due: now.addingTimeInterval(againDelay), interval: 0, ease: max(minEase, ease - 0.2), reps: 0, lapses: lapses + 1)
        case .hard:
            interval = cur.reps == 0 ? 1 : max(cur.interval + 1, (cur.interval * 1.2).rounded())
            ease = max(minEase, ease - 0.15)
        case .good:
            switch cur.reps {
            case 0: interval = 1
            case 1: interval = max(3, cur.interval + 1)
            default: interval = max(cur.interval + 1, (cur.interval * ease).rounded())
            }
        case .easy:
            interval = cur.reps == 0 ? 4 : max(cur.interval + 2, (cur.interval * ease * 1.3).rounded())
            ease += 0.15
        }
        reps += 1
        lapses = cur.lapses
        return SRSState(due: now.addingTimeInterval(interval * 86400), interval: interval, ease: ease, reps: reps, lapses: lapses)
    }

    static func apply(_ s: SRSState, to e: inout VocabEntry, now: Date) {
        e.due = s.due
        e.interval = s.interval
        e.ease = s.ease
        e.reps = s.reps
        e.lapses = s.lapses
        e.lastReview = now
    }

    static func label(days: Double) -> String {
        if days <= 0 { return "10m" }
        if days < 30 { return "\(Int(days.rounded()))d" }
        if days < 365 { return "\(Int((days / 30).rounded()))mo" }
        return String(format: "%.1fy", days / 365)
    }

    static func intervalLabel(_ s: SRSState?, rating: Rating, now: Date) -> String {
        let r = review(s, rating: rating, now: now)
        return rating == .again ? label(days: 0) : label(days: r.interval)
    }

    static func queue(_ entries: [VocabEntry], now: Date, newLimit: Int) -> [String] {
        let reviewed = entries.filter { state(of: $0) != nil && isDue($0, now: now) }
            .sorted { (state(of: $0)?.due ?? now) < (state(of: $1)?.due ?? now) }
        let fresh = entries.filter { state(of: $0) == nil }.sorted { $0.date < $1.date }.prefix(max(0, newLimit))
        return reviewed.map { $0.id } + fresh.map { $0.id }
    }

    static func statusKey(_ e: VocabEntry) -> S {
        switch status(of: e) {
        case .new: return .statusNew
        case .learning: return .statusLearning
        case .known: return .statusKnown
        }
    }

    static func dueCount(_ entries: [VocabEntry], now: Date, newLimit: Int = 10) -> Int {
        queue(entries, now: now, newLimit: newLimit).count
    }
}
