#if canImport(UIKit)
import UIKit

public enum PresentationStyle: Hashable, Sendable {
    case fullScreen
    @available(tvOS, unavailable)
    case pageSheet
    @available(tvOS, unavailable)
    case formSheet
    case currentContext
    case custom
    case overFullScreen
    case overCurrentContext
    @available(tvOS, unavailable)
    case popover
    @available(tvOS, introduced: 11)
    @available(iOS, unavailable)
    @available(watchOS, unavailable)
    case blurOverFullScreen
    case none
    case automatic
    
    var modalPresentationStyle: UIModalPresentationStyle {
        switch self {
        case .fullScreen:
            return .fullScreen
        case .pageSheet:
            return .pageSheet
        case .formSheet:
            return .formSheet
        case .currentContext:
            return .currentContext
        case .custom:
            return .custom
        case .overFullScreen:
            return .overFullScreen
        case .overCurrentContext:
            return .overCurrentContext
        case .popover:
            return .popover
        case .blurOverFullScreen:
            #if os(tvOS)
            if #available(tvOS 11, *) {
                return .blurOverFullScreen
            }
            else {
                fatalError("This should never happen.") // TODO: Refactor
            }
            #else
            fatalError("This should never happen.") // TODO: Refactor
            #endif
        case .none:
            return .none
        case .automatic:
            return .automatic
        }
    }
}
#endif
