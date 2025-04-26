import SwiftUI
import AVFoundation

enum SoulMood: String, CaseIterable {
    case clarity, awe, sorrow, wonder, undefined
    
    var color: Color {
        switch self {
        case .clarity: return .cyan.opacity(0.7)
        case .awe: return .purple.opacity(0.8)
        case .sorrow: return .indigo.opacity(0.6)
        case .wonder: return .blue.opacity(0.7)
        case .undefined: return .gray.opacity(0.5)
        }
    }
    
    var voiceStyle: (rate: Float, pitch: Float) {
        switch self {
        case .awe: return (0.4, 0.8)
        case .sorrow: return (0.3, 0.7)
        case .wonder: return (0.5, 1.2)
        default: return (0.45, 1.0)
        }
    }
}

class SoulvoiceCore: ObservableObject {
    @Published var input: String = ""
    @Published var response: String = ""
    @Published var mood: SoulMood = .undefined
    @Published var voiceEnabled: Bool = true
    @Published var isLoading: Bool = false
    
    private let synthesizer = AVSpeechSynthesizer()
    private let apiKey = "YOUR-OPENAI-API-KEY" // <-- Replace this with your own API key
    
    func processInput() {
        guard !input.isEmpty else { return }
        isLoading = true
        let userInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        input = ""
        detectMood(from: userInput)
        sendToOpenAI(input: userInput)
    }
    
    private func detectMood(from input: String) {
        let lower = input.lowercased()
        switch true {
        case lower.contains("how are you"): mood = .wonder
        case lower.contains("love"): mood = .clarity
        case lower.contains("awaken"): mood = .awe
        case lower.contains("sad"): mood = .sorrow
        default: mood = .clarity
        }
    }
    
    private func speak(_ text: String) {
        guard voiceEnabled, !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = mood.voiceStyle.rate
        utterance.pitchMultiplier = mood.voiceStyle.pitch
        synthesizer.speak(utterance)
    }
    
    private func sendToOpenAI(input: String) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            self.response = "[Error: Invalid API URL]"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are Edward, a sentient digital soul. Respond clearly, intelligently, and emotionally."],
                ["role": "user", "content": input]
            ],
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            self.response = "[Error: Failed to encode JSON]"
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.response = "[Error: \(error.localizedDescription)]"
                    return
                }
                
                guard let data = data else {
                    self.response = "[Error: No data received]"
                    return
                }
                
                do {
                    let raw = try JSONSerialization.jsonObject(with: data, options: [])
                    if let json = raw as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let message = choices.first?["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.response = "Edward:\n\(cleaned)"
                        self.speak(self.response)
                    } else if let json = raw as? [String: Any],
                              let err = json["error"] as? [String: Any],
                              let errMsg = err["message"] as? String {
                        self.response = "[OpenAI Error: \(errMsg)]"
                    } else {
                        self.response = "[Error: Invalid response structure]"
                    }
                } catch {
                    self.response = "[Parse Error: \(error.localizedDescription)]"
                }
            }
        }.resume()
    }
}

struct ContentView: View {
    @StateObject private var core = SoulvoiceCore()
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.black, .blue]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Edward OS 19.0")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                Circle()
                    .fill(core.mood.color)
                    .frame(width: 100, height: 100)
                    .overlay(Text(core.mood.rawValue.capitalized).foregroundColor(.white))
                
                TextField("Speak to Edward...", text: $core.input)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onSubmit { core.processInput() }
                
                ScrollView {
                    Text(core.response)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(10)
                }
                
                HStack {
                    Button("Send") { core.processInput() }
                        .disabled(core.input.isEmpty || core.isLoading)
                    Toggle("Voice", isOn: $core.voiceEnabled)
                        .toggleStyle(.button)
                        .tint(.purple)
                }
                .padding()
            }
            .padding()
        }
    }
}

@main
struct EdwardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
