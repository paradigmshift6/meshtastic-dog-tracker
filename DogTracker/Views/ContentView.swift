import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MapScreen()
                .tabItem { Label("Map", systemImage: "map") }

            CompassScreen()
                .tabItem { Label("Compass", systemImage: "location.north.line") }

            TrackersScreen()
                .tabItem { Label("Dogs", systemImage: "pawprint") }

            TileManagerScreen()
                .tabItem { Label("Tiles", systemImage: "square.grid.3x3.square") }

            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
}
