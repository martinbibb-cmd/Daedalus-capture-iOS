import SwiftUI

struct LiveCaptureView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    @State private var isPresentingReview = false
    @State private var isPresentingSummary = false
    @State private var isPresentingShareSheet = false
    @State private var isPresentingContext = false
    @State private var shareURL: URL?

    private var visit: Visit? {
        viewModel.visit(id: visitID)
    }

    var body: some View {
        Group {
            if let visit {
                SurveySectionCaptureView(
                    viewModel: viewModel,
                    visitID: visitID
                )
                .navigationTitle(visit.reference)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isPresentingReview = true
                        } label: {
                            Label("Review Capture", systemImage: "list.bullet.rectangle")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Visit Context") { isPresentingContext = true }
                            Button("Capture Summary") { isPresentingSummary = true }
                            Button("Export Package") {
                                if let url = viewModel.makeExportTempURL(for: visitID) {
                                    shareURL = url
                                    isPresentingShareSheet = true
                                }
                            }
                        } label: {
                            Label("Capture Tools", systemImage: "ellipsis.circle")
                        }
                    }
                }
                .navigationDestination(isPresented: $isPresentingReview) {
                    VisitDetailView(viewModel: viewModel, visitID: visitID)
                }
                .navigationDestination(isPresented: $isPresentingSummary) {
                    VisitSummaryView(visit: visit)
                }
                .sheet(isPresented: $isPresentingShareSheet) {
                    if let url = shareURL {
                        ActivityView(url: url)
                    }
                }
                .sheet(isPresented: $isPresentingContext) {
                    VisitContextSheet(viewModel: viewModel, visitID: visitID)
                }
            } else {
                ContentUnavailableView("Visit not found", systemImage: "exclamationmark.triangle")
            }
        }
    }
}
