import SwiftUI
import UniformTypeIdentifiers

struct GroupSectionView: View {
    let group: ConnectionGroup
    let connections: [Connection]
    
    // Dependencies needed for row rendering
    let highlightedID: UUID?
    let selectedID: UUID?
    let hideCommand: Bool
    let searchText: String
    
    // Callbacks
    let onToggleExpand: (UUID) -> Void
    // Updated signature: (GroupID, IsRecursive/ShiftPressed)
    let onDeleteGroup: (UUID, Bool) -> Void
    let onMoveConnection: (UUID, UUID?) -> Void
    let onRowTap: (Connection) -> Void
    let onRowConnect: (Connection) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Group Header
            HStack {
                Image(systemName: group.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .frame(width: 15)
                
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { 
                    // Detect Shift key for recursive delete
                    let isShift = NSEvent.modifierFlags.contains(.shift)
                    onDeleteGroup(group.id, isShift) 
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.borderless)
                .help("Delete Group (Hold Shift to delete contents too)")
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.gray.opacity(0.1))
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleExpand(group.id)
            }
            // DROP TARGET: Add Connection to Group
            .onDrop(of: [UTType.text, UTType.plainText], isTargeted: nil) { providers in
                if UserDefaults.standard.bool(forKey: "debugMode") {
                    print("DEBUG: DROP EVENT - Group '\(group.name)' received items")
                }
                
                guard let item = providers.first else { return false }
                
                item.loadObject(ofClass: NSString.self) { (object, error) in
                    if let error = error {
                        print("DEBUG: Drop Load Error: \(error)")
                        return
                    }
                    
                    if let idStr = object as? String, let uuid = UUID(uuidString: idStr) {
                        if UserDefaults.standard.bool(forKey: "debugMode") {
                            print("DEBUG: Moving connection \(uuid) to group \(group.name)")
                        }
                        DispatchQueue.main.async {
                            onMoveConnection(uuid, group.id)
                        }
                    } else {
                        print("DEBUG: Could not parse dropped object as UUID string")
                    }
                }
                return true
            }

            // Group Items
            if group.isExpanded {
                ForEach(connections) { conn in
                    ConnectionRowView(
                        connection: conn,
                        isHighlighted: highlightedID == conn.id,
                        isEditing: selectedID == conn.id,
                        hideCommand: hideCommand,
                        searchText: searchText,
                        onTap: { onRowTap(conn) },
                        onConnect: { onRowConnect(conn) }
                    )
                    .padding(.leading, 16) // Indentation for tree view effect
                }
            }
        }
    }
}
