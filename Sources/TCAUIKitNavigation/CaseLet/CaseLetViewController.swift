#if canImport(UIKit)
import Combine
import ComposableArchitecture
import UIKit

public class CaseLetViewController<EnumState, EnumAction, CaseState, CaseAction, Content: UIViewController>: UIViewController {
    public let store: Store<EnumState, EnumAction>
    public let toCaseState: (EnumState) -> CaseState?
    public let fromCaseAction: (CaseAction) -> EnumAction
    public let content: (_ store: Store<CaseState, CaseAction>) -> Content
    private var cancellables = Set<AnyCancellable>()
    
   public init(store: Store<EnumState, EnumAction>,
         toCaseState: @escaping (EnumState) -> CaseState?,
         action fromCaseAction: @escaping (CaseAction) -> EnumAction,
         then content: @escaping (_ store: Store<CaseState, CaseAction>) -> Content) {
        self.store = store
        self.toCaseState = toCaseState
        self.fromCaseAction = fromCaseAction
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        store.scope(state: toCaseState, action: fromCaseAction)
            .ifLet { [weak self] store in
                self?.embedContent(store: store)
            }
            .store(in: &cancellables)
    }
    
    private func embedContent(store: Store<CaseState, CaseAction>) {
        let content = content(store)
        
        self.view.subviews.forEach { $0.removeFromSuperview() }
        self.children.forEach { $0.removeFromParent() }
        
        guard let contentView = content.view else {
            return
        }
        self.view.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: self.view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
        
        self.addChild(content)
        content.didMove(toParent: self)
    }
}
#endif
