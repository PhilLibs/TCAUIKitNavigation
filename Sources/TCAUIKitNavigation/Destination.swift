#if canImport(UIKit)
import ComposableArchitecture
import UIKit

public enum Destination: Equatable {
    /// A single view
    case view(UIViewController)
    /// A subcoordinator
    case coordinator(Coordinator)
    
    public static func == (lhs: Destination, rhs: Destination) -> Bool {
        switch (lhs, rhs) {
        case (.view(let lhsVC), .view(let rhsVC)):
            return lhsVC == rhsVC
        case (.coordinator(let lhsCoordinator), .coordinator(let rhsCoordinator)):
            return lhsCoordinator === rhsCoordinator
        default:
            return false
        }
    }
}

public struct DestinationInstruction<State, Action> {
    /// The state of the destination.
    public let state: State
    /// The parent coordinator.
    ///
    /// This should only be `nil` if this is the root coordinator or the coordinator is being presented.
    public let parent: Coordinator?
    /// The store of the destination.
    public let store: Store<State, Action>
}
#endif
