import Foundation

/// Proposed adapter boundary, not a Telegram API implementation.
/// Keep the complete encoded PeerId and the account identity; never use a row index.
public struct PartyPeerReference: Hashable, Sendable, Codable {
    public let accountID: Int64
    public let encodedPeerID: Int64

    public init(accountID: Int64, encodedPeerID: Int64) {
        self.accountID = accountID
        self.encodedPeerID = encodedPeerID
    }
}

public struct PartyMessageReference: Hashable, Sendable, Codable {
    public let peer: PartyPeerReference
    public let namespace: Int32
    public let id: Int32

    public init(peer: PartyPeerReference, namespace: Int32, id: Int32) {
        self.peer = peer
        self.namespace = namespace
        self.id = id
    }
}

public enum PartyThemeID: String, CaseIterable, Sendable, Codable {
    case meadow, peach, sand, mint, lagoon, lavender, newYear
}

/// Host-issued sticker key, not an index into the demo asset catalog.
/// Coordinates are normalized to the message bubble, independent of scrolling.
public struct PartyStickerPlacement: Hashable, Sendable, Codable {
    public let stickerKey: String
    public let message: PartyMessageReference
    public let x: Double
    public let y: Double

    public init?(stickerKey: String, message: PartyMessageReference, x: Double, y: Double) {
        guard !stickerKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else { return nil }
        self.stickerKey = stickerKey
        self.message = message
        self.x = x
        self.y = y
    }

    // Decode through the same validation boundary as drag input.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let key = try values.decode(String.self, forKey: .stickerKey)
        let message = try values.decode(PartyMessageReference.self, forKey: .message)
        let x = try values.decode(Double.self, forKey: .x)
        let y = try values.decode(Double.self, forKey: .y)
        guard let placement = Self(stickerKey: key, message: message, x: x, y: y) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Invalid sticker placement"))
        }
        self = placement
    }
}

/// Implement this using the host's engine, permissions, cancellation and storage.
/// Mutations complete after confirmation; thrown errors must leave editable UI intact.
@MainActor public protocol PartyModeHost: AnyObject {
    func createGroup(members: [PartyPeerReference]) async throws -> PartyPeerReference
    func updateTitle(_ title: String, group: PartyPeerReference) async throws
    func updateAvatar(jpegData: Data, group: PartyPeerReference) async throws
    func applyTheme(_ theme: PartyThemeID, group: PartyPeerReference) async throws

    /// Host storage policy: local experiment or explicitly designed synchronized state.
    func setPartyEnabled(_ enabled: Bool, group: PartyPeerReference) async throws
    /// No equivalent Telegram network operation is supplied by this repository.
    func storeStickerPlacement(_ placement: PartyStickerPlacement) async throws
}
