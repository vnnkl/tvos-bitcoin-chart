import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Bitcoin Terminal")
                .font(.largeTitle)
                .foregroundColor(.white)
        }
    }
}

#Preview {
    ContentView()
}
