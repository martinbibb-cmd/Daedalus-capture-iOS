import SwiftUI
import DaedalusScanCore

@main
struct DaedalusScanApp: App {
    @StateObject private var viewModel = VisitListViewModel(repository: VisitRepository())

    var body: some Scene {
        WindowGroup {
            VisitListView(viewModel: viewModel)
        }
    }
}
