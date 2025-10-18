import SwiftUI

struct AboutView: View {
    @Binding var isShowing: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            
            Text("Duo Chat")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Version 1.0.0 (Build 1)")
                .font(.body)
                .foregroundColor(.secondary)
            
            Text("© 2025 Aboobacker MK. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            ScrollView {
                Text("This application is a native macOS client for GitLab Duo Chat, built with SwiftUI. It allows you to interact with the Duo Chat API, have multiple conversations, and get AI-powered assistance for your development workflows.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button("Close") {
                isShowing = false
            }
        }
        .padding(20)
        .frame(width: 350, height: 400)
    }
}

#Preview {
    AboutView(isShowing: .constant(true))
}
