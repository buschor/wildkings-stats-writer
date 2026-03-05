import SwiftUI

// MARK: - Models

struct Player: Identifiable, Codable {
    var id = UUID()
    var apiId: Int
    var name: String
    var status: Int

    var wonHands: Int = 0
    var buyIns: Int = 0
    var saldo: Double = 0.0
    var playedHands: Int = 0
}

struct GameSession: Codable {
    var location: String
    var date: Date
    var sessionHands: Int
    var players: [Player]
}

struct AvailablePlayer: Identifiable, Codable, Hashable {
    var id: Int
    var name: String
    var status: Int
}

// MARK: - Root Tabs

struct ContentView: View {
    var body: some View {
        TabView {
            SessionView()
                .tabItem {
                    Label("Session", systemImage: "suit.club.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

// MARK: - Session View

struct SessionView: View {

    @State private var players: [Player] = []
    @State private var showAddDialog = false
    @State private var newPlayerName = ""

    @State private var location = ""
    @State private var date = Date()
    @State private var sessionHands = 0

    @State private var availablePlayers: [AvailablePlayer] = []
    @State private var selectedPlayer: AvailablePlayer?
    @State private var isLoadingPlayers = false

    @State private var showClearAlert = false
    @State private var isUploading = false

    @State private var showUploadConfirm = false
    @State private var playerToDelete: Int? = nil
    
    @AppStorage("apiURL") private var apiURL: String = ""
    @AppStorage("apiToken") private var apiToken: String = ""
    @AppStorage("autoIncrementHands") private var autoIncrementHands: Bool = false

    var totalSaldo: Double {
        players.reduce(0) { $0 + $1.saldo }
    }

    var body: some View {

        NavigationView {
            VStack(spacing: 12) {

                // Session Header Compact
                VStack(spacing: 8) {

                    HStack {
                        TextField("Location", text: $location)
                            .textFieldStyle(.roundedBorder)

                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                    }

                    HStack {
                        Text("Played Hands")
                            .font(.subheadline)

                        Spacer()

                        Button("-") {
                            if sessionHands > 0 { sessionHands -= 1 }
                        }

                        Text("\(sessionHands)")
                            .frame(width: 50)

                        Button("+") {
                            sessionHands += 1
                        }
                    }
                }
                .padding(.horizontal)

                Divider()

                // Player List
                VStack(spacing: 6) {

                    // Header Row
                    HStack(spacing: 8) {
                        Text("Player")
                            .frame(width: 80, alignment: .leading)

                        Text("Won")
                            .frame(width: 70)

                        Text("Buy Ins")
                            .frame(width: 45)

                        Text("Hands")
                            .frame(width: 45)

                        Text("Saldo")
                            .frame(width: 65)

                        Spacer()
                            .frame(width: 24)
                    }
                    .font(.caption)
                    .foregroundColor(.gray)

                    ForEach(players.indices, id: \.self) { index in
                        PlayerRow(
                            player: $players[index],
                            sessionHands: $sessionHands,
                            onDelete: {
                                playerToDelete = index
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                // Footer Total
                HStack(spacing: 8) {

                    Text("Total")
                        .frame(width: 80, alignment: .leading)

                    Spacer()

                    Text(totalSaldo.formatted(.number.precision(.fractionLength(2))))
                        .frame(width: 65, alignment: .trailing)
                        .foregroundColor(totalSaldo == 0 ? .primary : .red)

                    Spacer()
                        .frame(width: 24)
                }
                .font(.headline)
                .padding(.vertical, 6)
                .padding(.horizontal)

                Spacer()

                // Buttons
                HStack {
                    Button("Clear") {
                        showClearAlert = true
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(10)

                    Button {
                        showUploadConfirm = true
                    } label: {
                        if isUploading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Upload")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Poker Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Player") {
                        showAddDialog = true
                    }
                }
            }
        }
        .alert("Clear all data?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                clearAll()
            }
        }
        // Confirm Player Delete
        .alert("Delete Player?", isPresented: Binding(
            get: { playerToDelete != nil },
            set: { if !$0 { playerToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let index = playerToDelete {
                    players.remove(at: index)
                }
                playerToDelete = nil
            }
        }
        // Confirm Upload
        .alert("Upload session to server?", isPresented: $showUploadConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Upload") {
                uploadGame()
            }
        }
        .sheet(isPresented: $showAddDialog) {
            NavigationView {
                VStack {

                    if isLoadingPlayers {
                        ProgressView("Loading players...")
                            .padding()
                    } else {
                        Picker("Select Player", selection: $selectedPlayer) {
                            ForEach(availablePlayers, id: \.self) { player in
                                Text(player.name)
                                    .font(player.status > 1 ? .headline : .body)
                                    .tag(Optional(player))
                            }
                        }
                        .pickerStyle(.wheel)
                        .padding()
                    }

                    Spacer()
                }
                .navigationTitle("Add Player")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showAddDialog = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            if let selected = selectedPlayer {

                                // Optional: Doppeltes Hinzufügen verhindern
                                if !players.contains(where: { $0.apiId == selected.id }) {
                                    players.append(
                                        Player(
                                            apiId: selected.id,
                                            name: selected.name,
                                            status: selected.status
                                        )
                                    )
                                }

                                selectedPlayer = nil
                                showAddDialog = false
                            }
                        }
                        .disabled(selectedPlayer == nil)
                    }
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            loadPlayers()
        }
    }

    func clearAll() {
        players.removeAll()
        location = ""
        sessionHands = 0
    }

    func uploadGame() {

        guard !apiURL.isEmpty else { return }

        let session = GameSession(
            location: location,
            date: date,
            sessionHands: sessionHands,
            players: players
        )

        guard let url = URL(string: apiURL) else { return }

        isUploading = true

        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                if !apiToken.isEmpty {
                    request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
                }

                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601

                request.httpBody = try encoder.encode(session)

                let (_, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }

                clearAll()

            } catch {
                print("Upload error:", error)
            }

            isUploading = false
        }
    }

    func loadPlayers() {
        guard !apiURL.isEmpty else { return }
        guard let url = URL(string: apiURL + "/players.php") else { return }

        isLoadingPlayers = true

        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"

                if !apiToken.isEmpty {
                    request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
                }

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }

                let decoded = try JSONDecoder().decode([AvailablePlayer].self, from: data)

                await MainActor.run {
                    availablePlayers = decoded   // ← keine Sortierung mehr
                    isLoadingPlayers = false
                }

            } catch {
                print("Error loading players:", error)
                await MainActor.run {
                    isLoadingPlayers = false
                }
            }
        }
    }
}

// MARK: - Player Row Compact

struct PlayerRow: View {

    @Binding var player: Player
    @Binding var sessionHands: Int
    @AppStorage("autoIncrementHands") private var autoIncrementHands: Bool = false
    var onDelete: () -> Void

    var body: some View {

        HStack(spacing: 8) {

            // Name
            Text(player.name)
                .frame(width: 80, alignment: .leading)

            // Won Hands (+/-)
            HStack(spacing: 4) {
                Button("-") {
                    if player.wonHands > 0 { player.wonHands -= 1 }
                }
                .frame(width: 22)

                Text("\(player.wonHands)")
                    .frame(width: 26)

                Button("+") {
                    player.wonHands += 1
                    if autoIncrementHands {
                        sessionHands += 1
                    }
                }
                .frame(width: 22)
            }
            .frame(width: 70)

            // Buy Ins (kleiner)
            TextField("", value: $player.buyIns, format: .number)
                .keyboardType(.numberPad)
                .frame(width: 45)
                .textFieldStyle(.roundedBorder)

            // Hands (kleiner)
            TextField("", value: $player.playedHands, format: .number)
                .keyboardType(.numberPad)
                .frame(width: 45)
                .textFieldStyle(.roundedBorder)

            // Saldo
            TextField("", value: $player.saldo, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 65)
                .textFieldStyle(.roundedBorder)

            // Delete
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .frame(width: 24)
        }
        .padding(6)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Settings

struct SettingsView: View {

    @AppStorage("apiURL") private var apiURL: String = ""
    @AppStorage("apiToken") private var apiToken: String = ""
    @AppStorage("autoIncrementHands") private var autoIncrementHands: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API")) {
                    TextField("Upload URL", text: $apiURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)

                    SecureField("Bearer Token", text: $apiToken)
                        .autocapitalization(.none)
                }
                Section(header: Text("Behaviour")) {

                    //Toggle("Keep Screen Awake", isOn: $keepScreenAwake)

                    Toggle("Auto increment played hands", isOn: $autoIncrementHands)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
