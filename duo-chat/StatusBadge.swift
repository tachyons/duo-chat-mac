//
//  StatusBadge.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//
import SwiftUI

struct StatusBadge: View {
    let title: String
    let color: Color
    
    var body: some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
