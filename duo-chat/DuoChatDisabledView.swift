//
//  DuoChatDisabledView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//

import SwiftUI
struct DuoChatDisabledView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("GitLab Duo Chat Not Available")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("GitLab Duo Chat is not enabled for your account or GitLab instance.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("This could be because:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    BulletPoint("Your GitLab instance doesn't have Duo Chat enabled")
                    BulletPoint("You don't have the required permissions to use AI features")
                    BulletPoint("Your organization hasn't enabled Duo Chat for your user role")
                    BulletPoint("AI features are disabled for this resource type")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            Link("Learn more about GitLab AI features", 
                 destination: URL(string: "https://docs.gitlab.com/ee/user/ai_features/")!)
                .font(.subheadline)
        }
        .padding()
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview{
    DuoChatDisabledView()
}
