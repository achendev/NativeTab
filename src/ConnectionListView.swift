import SwiftUI

struct Connection: Identifiable, Codable {
    var id = UUID()
    var name: String
    var command: String
}

class ConnectionStore: ObservableObject {
    @Published var connections: [Connection] = []
    
    private let fileURL: URL
    
    init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        fileURL = paths[0].appendingPathComponent("mt_connections.json")
        load()
    }
    
    func add(name: String, command: String) {
        connections.append(Connection(name: name, command: command))
        save()
    }
    
    func remove(at offsets: IndexSet) {
        connections.remove(atOffsets: offsets)
        save()
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(connections) {
            try? data.write(to: fileURL)
        }
    }
    
    func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Connection].self, from: data) {
            connections = decoded
        }
    }
}

struct ConnectionListView: View {
    @StateObject var store = ConnectionStore()
    @State private var newName = ""
    @State private var newCommand = ""
    
    var body: some View {
        VStack {
            List {
                ForEach(store.connections) { conn in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(conn.name).font(.headline)
                            Text(conn.command).font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        Button("Connect") {
                            TerminalBridge.launch(command: conn.command)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: store.remove)
            }
            
            Divider()
            
            VStack(alignment: .leading) {
                Text("New Connection").font(.headline)
                TextField("Name (e.g. Prod DB)", text: $newName)
                TextField("Command (e.g. ssh user@1.2.3.4)", text: $newCommand)
                Button("Add Connection") {
                    if !newName.isEmpty && !newCommand.isEmpty {
                        store.add(name: newName, command: newCommand)
                        newName = ""
                        newCommand = ""
                    }
                }
                .disabled(newName.isEmpty || newCommand.isEmpty)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}
