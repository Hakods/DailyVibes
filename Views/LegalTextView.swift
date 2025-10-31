//
//  LegalTextView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 29.10.2025.
//

import SwiftUI

enum LegalContent: String {
    case privacyPolicy = "legal.privacyPolicy.content"
    case termsOfService = "legal.termsOfService.content"
    
    var titleKey: String {
        switch self {
        case .privacyPolicy:
            return "legal.privacyPolicy.title"
        case .termsOfService:
            return "legal.termsOfService.title"
        }
    }
}

struct LegalTextView: View {
    let content: LegalContent

    var body: some View {
        ScrollView {
            Text(LocalizedStringKey(content.rawValue))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(LocalizedStringKey(content.titleKey))
        .navigationBarTitleDisplayMode(.inline)
    }
}
