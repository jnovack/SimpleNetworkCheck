import SwiftUI

@main
struct SimpleNetworkCheckApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 840, height: 780)
    }
}
