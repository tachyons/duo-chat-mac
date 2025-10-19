import SwiftUI

struct HelpView: View {
    var body: some View {
        VStack {
            Text("Help")
                .font(.largeTitle)
                .padding()
            
            Text("This is the help dialog for the Duo Chat application.")
                .padding()
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}
