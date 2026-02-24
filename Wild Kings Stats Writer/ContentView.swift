import SwiftUI

struct Player: Identifiable, Codable {
    var id = UUID()
    var name: String
    var wonHands: Int = 0
    var buyIns: Int = 0
    var saldo: Double = 0.0
    var playedHands: Int = 0
}

struct GameSession: Codable {
    var sessionHands: Int
    var players: [Player]
}

struct ContentView: View {
    
    @State private var players: [Player] = []
    @State private var newPlayerName: String = ""
    @State private var sessionHands: Int = 0
    @State private var isUploading = false
    @State private var uploadMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                
                // Session Hände
                VStack(alignment: .leading) {
                    Text("Session gespielte Hände")
                        .font(.headline)
                    
                    Stepper(value: $sessionHands, in: 0...10000) {
                        Text("\(sessionHands)")
                            .font(.title2)
                    }
                }
                .padding()
                
                Divider()
                
                // Spieler hinzufügen
                HStack {
                    TextField("Spielername", text: $newPlayerName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Hinzufügen") {
                        guard !newPlayerName.isEmpty else { return }
                        players.append(Player(name: newPlayerName))
                        newPlayerName = ""
                    }
                }
                .padding()
                
                Divider()
                
                // Spielerliste
                ScrollView {
                    ForEach($players) { $player in
                        PlayerRow(player: $player)
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Upload Button
                Button(action: uploadGame) {
                    if isUploading {
                        ProgressView()
                    } else {
                        Text("Upload")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding()
            }
            .navigationTitle("Wild Kings Session")
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
    
    func uploadGame() {
        let session = GameSession(sessionHands: sessionHands, players: players)
        
        guard let url = URL(string: "https://DEINE-API-URL/poker") else { return }
        
        isUploading = true
        
        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(session)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                uploadMessage = "Erfolgreich hochgeladen"
                
            } catch {
                uploadMessage = "Fehler beim Upload"
            }
            
            isUploading = false
        }
    }
}

struct PlayerRow: View {
    
    @Binding var player: Player
    
    var body: some View {
        VStack(alignment: .leading) {
            
            Text(player.name)
                .font(.headline)
            
            HStack {
                CounterView(title: "Gewonnene Hände", value: $player.wonHands)
                CounterView(title: "Buy-Ins", value: $player.buyIns)
            }
            
            HStack {
                CounterView(title: "Gespielte Hände", value: $player.playedHands)
                
                VStack(alignment: .leading) {
                    Text("Saldo")
                    TextField("0.0", value: $player.saldo, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
            }
        }
        .padding()
    }
}

struct CounterView: View {
    
    var title: String
    @Binding var value: Int
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
            
            HStack {
                Button("-") {
                    if value > 0 { value -= 1 }
                }
                .frame(width: 30)
                
                Text("\(value)")
                    .frame(width: 40)
                
                Button("+") {
                    value += 1
                }
                .frame(width: 30)
            }
        }
        .padding(4)
    }
}
