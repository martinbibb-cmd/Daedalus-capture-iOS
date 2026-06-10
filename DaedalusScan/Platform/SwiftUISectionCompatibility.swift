import SwiftUI

extension Section where Content: View, Parent == Text, Footer == EmptyView {
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.init {
            content()
        } header: {
            Text(title)
        }
    }
}

extension Section where Content: View, Parent == Text, Footer: View {
    init(
        _ title: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.init {
            content()
        } header: {
            Text(title)
        } footer: {
            footer()
        }
    }
}
