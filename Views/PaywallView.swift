//
//  PaywallView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 25.09.2025.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var vm: PaywallVM

    var body: some View {
        VStack(spacing: 16) {
            Text("Daily Vibes Pro").font(.largeTitle).bold()

            VStack(alignment: .leading, spacing: 8) {
                Label("Zaman penceresini özelleştir", systemImage: "checkmark.circle")
                Label("Günde birden fazla ping", systemImage: "checkmark.circle")
                Label("Sınırsız geçmiş + dışa aktarım", systemImage: "checkmark.circle")
                Label("Tema ve streak", systemImage: "checkmark.circle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Ürün fiyatını göstermek için StoreKit Product API'si
            if let pro = vm.store.products.first(where: { $0.id == "pro_unlock" }) {
                Text(pro.displayPrice).font(.title3).bold()
            }

            Button {
                vm.buy()
            } label: {
                HStack { if vm.isPurchasing { ProgressView() }; Text("Pro'yu Satın Al").fontWeight(.semibold) }
                    .frame(maxWidth: .infinity).padding()
                    .background(.blue).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(vm.isPurchasing)

            Button("Satın alımı geri yükle") { vm.restore() }.font(.footnote)

            if let err = vm.errorMessage {
                Text(err).foregroundStyle(.red).font(.footnote)
            }

            Text("Satın alma Apple Kimliğinize bağlıdır. Aile Paylaşımı ve iade hakları Apple politikalarına tabidir.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
    }
}
