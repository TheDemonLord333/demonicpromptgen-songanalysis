import SwiftUI

@main
struct DemonicPromptGenApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: dependencies.mainViewModel, dependencies: dependencies)
                .preferredColorScheme(.dark)
                .tint(Theme.blurple)
        }
    }
}
