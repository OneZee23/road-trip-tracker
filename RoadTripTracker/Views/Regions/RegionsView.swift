import SwiftUI

struct RegionsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Scratch Map",
                systemImage: "map.fill",
                description: Text("Coming soon — track regions you've visited on the map")
            )
            .navigationTitle("Regions")
        }
    }
}

#Preview {
    RegionsView()
        .preferredColorScheme(.dark)
}
