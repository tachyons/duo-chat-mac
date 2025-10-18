import SwiftUI

struct SettingsView: View {
    @Binding var isShowing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom)

            Spacer()

            HStack {
                Spacer()
                Button("Done") {
                    isShowing = false
                }
            }
        }
        .padding()
        .frame(width: 300, height: 150)
    }
}

#Preview {
    SettingsView(isShowing: .constant(true))
}
