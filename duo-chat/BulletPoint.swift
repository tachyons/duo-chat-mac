//
//  BulletPoint.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//

import SwiftUI

struct BulletPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
            Spacer()
        }
    }
}
