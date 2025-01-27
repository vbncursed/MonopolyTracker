import SwiftUI

struct LaunchScreen: View {
    @State private var isActive = false
    @State private var scale = 0.8
    @State private var opacity = 0.3

    var body: some View {
        if isActive {
            ContentView()
        } else {
            VStack {
                Image(systemName: "dollarsign.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.green)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.2)) {
                            scale = 1.2
                            opacity = 1.0
                        }
                    }
                
                Text("Монополия: Трекер")
                    .font(.title)
                    .bold()
                    .padding(.top, 10)
                    .opacity(opacity)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    LaunchScreen()
}
