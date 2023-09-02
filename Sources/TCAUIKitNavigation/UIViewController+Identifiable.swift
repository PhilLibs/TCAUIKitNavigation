#if canImport(UIKit)
import UIKit
import Dependencies

extension DependencyValues {
    var caseLetHelper: CaseLetHelper {
        get { self[CaseLetHelperKey.self] }
        set { self[CaseLetHelperKey.self] = newValue }
    }
    
    private enum CaseLetHelperKey: DependencyKey {
        static let liveValue: CaseLetHelper = LiveCaseLetHelper()
        static let testValue: CaseLetHelper = TestCaseLetHelper(
            isResolvedCaseLetViewController: { _ in
                XCTFail(#"Unimplemented: @Dependency(\.caseLetHelper)"#)
                return false
            },
            markAsCaseLetViewController: { _,_ in
                XCTFail(#"Unimplemented: @Dependency(\.caseLetHelper)"#)
            }
        )
    }
}

protocol CaseLetHelper {
    func isResolvedCaseLetViewController(_ resolvedViewController: UIViewController) -> Bool
    func markAsCaseLetViewController(_ resolvedViewController: UIViewController, of caseLetViewController: UIViewController)
}

struct LiveCaseLetHelper: CaseLetHelper {
    private let table = MapTable<UIViewController, UIViewController>(keyOptions: .weakMemory, valueOptions: .weakMemory)
    
    func isResolvedCaseLetViewController(_ resolvedViewController: UIViewController) -> Bool {
        table[resolvedViewController] != nil
    }
    
    func markAsCaseLetViewController(_ resolvedViewController: UIViewController, of caseLetViewController: UIViewController) {
        table[resolvedViewController] = caseLetViewController
    }
}

struct TestCaseLetHelper: CaseLetHelper {
    private let _isResolvedCaseLetViewController: @Sendable (UIViewController) -> Bool
    private let _markAsCaseLetViewController: @Sendable (UIViewController, UIViewController) -> Void
    
    init(isResolvedCaseLetViewController: @escaping @Sendable (UIViewController) -> Bool, markAsCaseLetViewController: @escaping @Sendable (UIViewController, UIViewController) -> Void) {
        self._isResolvedCaseLetViewController = isResolvedCaseLetViewController
        self._markAsCaseLetViewController = markAsCaseLetViewController
    }
    
    func isResolvedCaseLetViewController(_ resolvedViewController: UIViewController) -> Bool {
        _isResolvedCaseLetViewController(resolvedViewController)
    }
    
    func markAsCaseLetViewController(_ resolvedViewController: UIViewController, of caseLetViewController: UIViewController) {
        
    }
}

final class MapTable<KeyType, ObjectType> where KeyType: AnyObject, ObjectType: AnyObject {
    private let mapTable: NSMapTable<KeyType, ObjectType>

    init(keyOptions: NSPointerFunctions.Options, valueOptions: NSPointerFunctions.Options) {
        self.mapTable = NSMapTable(keyOptions: keyOptions, valueOptions: valueOptions)
    }

    subscript(key: KeyType?) -> ObjectType? {
        get {
            mapTable.object(forKey: key)
        }
        set {
            mapTable.setObject(newValue, forKey: key)
        }
    }
}
#endif
