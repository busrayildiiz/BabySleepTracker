import Foundation

struct APIConfig {
    static var geminiKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GeminiApiKey") as? String else {
            print("⚠️ HATA: Info.plist içinde 'GeminiApiKey' bulunamadı!")
            return ""
        }
        // Eğer her ihtimale karşı ham string veya boşluk kaldıysa temizleriz
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
