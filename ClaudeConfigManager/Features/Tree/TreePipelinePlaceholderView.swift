import SwiftUI

/// Temporary placeholder view for the Pipeline (Tree) destination.
///
/// This will be replaced by `TreePipelineView` in Packet T2 once the
/// pipeline shell and overview strip are implemented.
struct TreePipelinePlaceholderView: View {

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Pipeline View")
                .font(.title2.weight(.semibold))

            Text("The configuration pipeline visualization will appear here.\nThis view is under construction.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Pipeline")
    }
}
