import Foundation

enum InputState: Equatable {
    case idle
    case recording(startAt: Date)
    case transcribing
    case inserting
    case error(String)
}
