import SwiftUI

struct ContentView: View {
    @StateObject private var trackingVM = TrackingViewModel()
    @State private var tripsVM: TripsViewModel?

    var body: some View {
        TabView {
            TrackingView()
                .environmentObject(trackingVM)
                .tabItem {
                    Label("Tracking", systemImage: "location.fill")
                }

            TripsListView(viewModel: tripsViewModel)
                .tabItem {
                    Label("Trips", systemImage: "list.bullet")
                }

            RegionsView()
                .tabItem {
                    Label("Regions", systemImage: "map")
                }
        }
        .tint(.blue)
    }

    private var tripsViewModel: TripsViewModel {
        if let existing = tripsVM {
            return existing
        }
        let vm = TripsViewModel(tripManager: trackingVM.tripManager)
        DispatchQueue.main.async {
            tripsVM = vm
        }
        return vm
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
