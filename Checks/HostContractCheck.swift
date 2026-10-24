import Foundation

@main struct HostContractCheck {
    static func main() throws {
        let peer = PartyPeerReference(accountID: 1, encodedPeerID: 42)
        let otherAccount = PartyPeerReference(accountID: 2, encodedPeerID: 42)
        let message = PartyMessageReference(peer: peer, namespace: 0, id: 7)
        let localMessage = PartyMessageReference(peer: peer, namespace: 1, id: 7)
        assert(Set([peer, otherAccount]).count == 2, "Accounts must not share identity")
        assert(Set([message, localMessage]).count == 2, "Message namespaces must remain distinct")
        assert(PartyStickerPlacement(stickerKey: "", message: message, x: 0.5, y: 0.5) == nil)
        assert(PartyStickerPlacement(stickerKey: "gift", message: message, x: .nan, y: 0.5) == nil)
        assert(PartyStickerPlacement(stickerKey: "gift", message: message, x: 1.01, y: 0.5) == nil)
        let placement = PartyStickerPlacement(stickerKey: "gift", message: message, x: 0.25, y: 0.75)!
        let encoder = JSONEncoder()
        let data = try encoder.encode(placement)
        let decoded = try JSONDecoder().decode(PartyStickerPlacement.self, from: data)
        assert(decoded == placement)
        var invalid = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        invalid["x"] = -1
        let invalidData = try JSONSerialization.data(withJSONObject: invalid)
        do {
            _ = try JSONDecoder().decode(PartyStickerPlacement.self, from: invalidData)
            assertionFailure("Stored placement must use the same validation as a gesture")
        } catch DecodingError.dataCorrupted { }
        print("PASS: account/message identity, normalized placement, Codable validation")
    }
}
