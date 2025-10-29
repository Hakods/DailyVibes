//
//  LegalTextView.swift
//  Daily Vibes
//
//  Created by Ahmet Hakan Altıparmak on 29.10.2025.
//

import SwiftUI

// Metin içeriğini merkezi bir yerden yönetmek için enum
enum LegalContent: String {
    // BURADAKİ E-POSTA VE TARİH BİLGİLERİNİ KENDİNE GÖRE DÜZENLE
    
    case privacyPolicy = """
    **Gizlilik Politikası**
    
    Son Güncelleme: 29 Ekim 2025
    
    Daily Vibes'ı kullandığınız için teşekkür ederiz. Gizliliğiniz bizim için çok önemlidir.
    
    **1. Topladığımız Veriler**
    
    Uygulamayı kullandığınızda aşağıdaki veriler SADECE cihazınızda yerel olarak saklanır:
    * Ruh hali girişleriniz (emoji, puan, notlar).
    * Girişlerinizin zaman damgaları.
    
    **2. Üçüncü Taraf Veri Paylaşımı (Vibe Koçu)**
    
    "Vibe Koçu" özelliğini kullandığınızda, analiz ve cevap üretilmesi amacıyla aşağıdaki veriler Firebase AI (Google Gemini) servisine GÜVENLİ BİR ŞEKİLDE gönderilir:
    * Geçmiş kayıtlarınızdaki ruh hali, puan ve not metinleri (eğer varsa).
    * Koça sorduğunuz sorular.
    
    Bu veriler, Google'ın gizlilik politikalarına tabi olarak işlenir ve sadece size cevap üretmek amacıyla kullanılır. Kişisel tanımlayıcı bilgiler (isim, e-posta vb.) toplanmaz veya gönderilmez.
    
    **3. İzinler**
    
    * **Bildirimler:** Uygulamanın size günlük hatırlatma ("ping") gönderebilmesi için bildirim izni istenir.
    * **Mikrofon ve Konuşma Tanıma:** Sesli not özelliğini (eğer kullanırsanız) etkinleştirmek için mikrofon ve konuşma tanıma izinleri istenir. Ses veriniz cihazınızda işlenir ve Apple'ın konuşma tanıma servisine gönderilebilir.
    
    **4. Veri Güvenliği**
    
    Vibe Koçu özelliği dışında, tüm verileriniz sadece kendi cihazınızda, Core Data kullanılarak saklanır. Verilerinize sizden başka kimse erişemez.
    
    **5. İletişim**
    
    Sorularınız için lütfen [destek@senin-emailin.com] adresinden bize ulaşın.
    """
    
    case termsOfService = """
    **Kullanım Koşulları (EULA)**
    
    Son Güncelleme: 29 Ekim 2025
    
    Lütfen bu Kullanım Koşullarını dikkatlice okuyun.
    
    **1. Hizmetin Tanımı**
    
    Daily Vibes ("Uygulama"), kullanıcıların günlük ruh hallerini ve notlarını kaydetmelerine, analiz etmelerine ve bir yapay zeka ("Vibe Koçu") aracılığıyla içgörüler almalarına olanak tanıyan bir mobil uygulamadır.
    
    **2. Abonelikler**
    
    Uygulamanın bazı özellikleri ("Pro" olarak işaretlenenler) ücretli bir abonelik gerektirebilir.
    * Ödemeler Apple Kimliği hesabınız üzerinden alınacaktır.
    * Abonelikler, mevcut dönemin bitiminden en az 24 saat önce iptal edilmediği sürece otomatik olarak yenilenir.
    * Aboneliklerinizi App Store hesap ayarlarınızdan yönetebilir ve iptal edebilirsiniz.
    
    **3. Sorumluluk Reddi (ÖNEMLİ)**
    
    "Vibe Koçu" tarafından sağlanan içerikler, yapay zeka tarafından üretilmiştir ve **tıbbi tavsiye, psikolojik danışmanlık veya teşhis niteliği taşımaz.**
    
    Uygulama, profesyonel bir ruh sağlığı uzmanının yerini alamaz. Ciddi zihinsel veya duygusal zorluklar yaşıyorsanız, lütfen lisanslı bir terapiste veya doktora danışın. Vibe Koçu'nun verdiği bilgilere dayanarak aldığınız kararlar tamamen kendi sorumluluğunuzdadır.
    
    **4. İletişim**
    
    Sorularınız için lütfen [destek@senin-emailin.com] adresinden bize ulaşın.
    """
}

struct LegalTextView: View {
    let title: String
    let content: LegalContent

    var body: some View {
        ScrollView {
            // .init(String) veya LocalizedStringKey kullanımı Markdown'u render eder.
            Text(LocalizedStringKey(content.rawValue))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
