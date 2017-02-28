import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

private enum SecretChatOutgoingFileValue: Int32 {
    case remote = 0
    case uploadedRegular = 1
    case uploadedLarge = 2
}

enum SecretChatOutgoingFileReference: Coding {
    case remote(id: Int64, accessHash: Int64)
    case uploadedRegular(id: Int64, partCount: Int32, md5Digest: String, keyFingerprint: Int32)
    case uploadedLarge(id: Int64, partCount: Int32, keyFingerprint: Int32)
    
    init(decoder: Decoder) {
        switch decoder.decodeInt32ForKey("v") as Int32 {
            case SecretChatOutgoingFileValue.remote.rawValue:
                self = .remote(id: decoder.decodeInt64ForKey("i"), accessHash: decoder.decodeInt64ForKey("a"))
            case SecretChatOutgoingFileValue.uploadedRegular.rawValue:
                self = .uploadedRegular(id: decoder.decodeInt64ForKey("i"), partCount: decoder.decodeInt32ForKey("p"), md5Digest: decoder.decodeStringForKey("d"), keyFingerprint: decoder.decodeInt32ForKey("f"))
            case SecretChatOutgoingFileValue.uploadedLarge.rawValue:
                self = .uploadedLarge(id: decoder.decodeInt64ForKey("i"), partCount: decoder.decodeInt32ForKey("p"), keyFingerprint: decoder.decodeInt32ForKey("f"))
            default:
                assertionFailure()
                self = .remote(id: 0, accessHash: 0)
        }
    }
    
    func encode(_ encoder: Encoder) {
        switch self {
            case let .remote(id, accessHash):
                encoder.encodeInt32(SecretChatOutgoingFileValue.remote.rawValue, forKey: "v")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "a")
            case let .uploadedRegular(id, partCount, md5Digest, keyFingerprint):
                encoder.encodeInt32(SecretChatOutgoingFileValue.uploadedRegular.rawValue, forKey: "v")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt32(partCount, forKey: "p")
                encoder.encodeString(md5Digest, forKey: "d")
                encoder.encodeInt32(keyFingerprint, forKey: "f")
            case let .uploadedLarge(id, partCount, keyFingerprint):
                encoder.encodeInt32(SecretChatOutgoingFileValue.uploadedLarge.rawValue, forKey: "v")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt32(partCount, forKey: "p")
                encoder.encodeInt32(keyFingerprint, forKey: "f")
        }
    }
}

struct SecretChatOutgoingFile: Coding {
    let reference: SecretChatOutgoingFileReference
    let size: Int32
    let key: SecretFileEncryptionKey
    
    init(reference: SecretChatOutgoingFileReference, size: Int32, key: SecretFileEncryptionKey) {
        self.reference = reference
        self.size = size
        self.key = key
    }
    
    init(decoder: Decoder) {
        self.reference = decoder.decodeObjectForKey("r", decoder: { SecretChatOutgoingFileReference(decoder: $0) }) as! SecretChatOutgoingFileReference
        self.size = decoder.decodeInt32ForKey("s")
        self.key = SecretFileEncryptionKey(aesKey: decoder.decodeBytesForKey("k")!.makeData(), aesIv: decoder.decodeBytesForKey("i")!.makeData())
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeObject(self.reference, forKey: "r")
        encoder.encodeInt32(self.size, forKey: "s")
        encoder.encodeBytes(MemoryBuffer(data: self.key.aesKey), forKey: "k")
        encoder.encodeBytes(MemoryBuffer(data: self.key.aesIv), forKey: "i")
    }
}

enum SecretChatSequenceBasedLayer: Int32 {
    case layer46 = 46
}

private enum SecretChatOutgoingOperationValue: Int32 {
    case initialHandshakeAccept = 0
    case sendMessage = 1
    case readMessagesContent = 2
    case deleteMessages = 3
    case screenshotMessages = 4
    case clearHistory = 5
    case resendOperations = 6
    case reportLayerSupport = 7
    case pfsRequestKey = 8
    case pfsAcceptKey = 9
    case pfsAbortSession = 10
    case pfsCommitKey = 11
    case noop = 12
    case setMessageAutoremoveTimeout = 13
    case terminate = 14
}

enum SecretChatOutgoingOperationContents: Coding {
    case initialHandshakeAccept(gA: MemoryBuffer, accessHash: Int64, b: MemoryBuffer)
    case sendMessage(layer: SecretChatLayer, id: MessageId, file: SecretChatOutgoingFile?)
    case readMessagesContent(layer: SecretChatLayer, actionGloballyUniqueId: Int64, globallyUniqueIds: [Int64])
    case deleteMessages(layer: SecretChatLayer, actionGloballyUniqueId: Int64, globallyUniqueIds: [Int64])
    case screenshotMessages(layer: SecretChatLayer, actionGloballyUniqueId: Int64, globallyUniqueIds: [Int64])
    case clearHistory(layer: SecretChatLayer, actionGloballyUniqueId: Int64)
    case resendOperations(layer : SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, fromSeqNo: Int32, toSeqNo: Int32)
    case reportLayerSupport(layer: SecretChatLayer, actionGloballyUniqueId: Int64, layerSupport: Int32)
    case pfsRequestKey(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, a: MemoryBuffer)
    case pfsAcceptKey(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, gA: MemoryBuffer, b: MemoryBuffer)
    case pfsAbortSession(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64)
    case pfsCommitKey(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, keyFingerprint: Int64)
    case noop(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64)
    case setMessageAutoremoveTimeout(layer: SecretChatLayer, actionGloballyUniqueId: Int64, timeout: Int32)
    case terminate
    
    init(decoder: Decoder) {
        switch decoder.decodeInt32ForKey("r") as Int32 {
            case SecretChatOutgoingOperationValue.initialHandshakeAccept.rawValue:
                self = .initialHandshakeAccept(gA: decoder.decodeBytesForKey("g")!, accessHash: decoder.decodeInt64ForKey("h"), b: decoder.decodeBytesForKey("b")!)
            case SecretChatOutgoingOperationValue.sendMessage.rawValue:
                self = .sendMessage(layer: SecretChatLayer(rawValue: decoder.decodeInt32ForKey("l"))!, id: MessageId(peerId: PeerId(decoder.decodeInt64ForKey("i.p")), namespace: decoder.decodeInt32ForKey("i.n"), id: decoder.decodeInt32ForKey("i.i")), file: decoder.decodeObjectForKey("f", decoder: { SecretChatOutgoingFile(decoder: $0) }) as? SecretChatOutgoingFile)
            case SecretChatOutgoingOperationValue.readMessagesContent.rawValue:
                self = .readMessagesContent(layer: SecretChatLayer(rawValue: decoder.decodeInt32ForKey("l"))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i"), globallyUniqueIds: decoder.decodeInt64ArrayForKey("u"))
            case SecretChatOutgoingOperationValue.deleteMessages.rawValue:
                self = .deleteMessages(layer: SecretChatLayer(rawValue: decoder.decodeInt32ForKey("l"))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i"), globallyUniqueIds: decoder.decodeInt64ArrayForKey("u"))
            case SecretChatOutgoingOperationValue.screenshotMessages.rawValue:
                self = .screenshotMessages(layer: SecretChatLayer(rawValue: decoder.decodeInt32ForKey("l"))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i"), globallyUniqueIds: decoder.decodeInt64ArrayForKey("u"))
            case SecretChatOutgoingOperationValue.clearHistory.rawValue:
                self = .clearHistory(layer: SecretChatLayer(rawValue: decoder.decodeInt32ForKey("l"))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i"))
            case SecretChatOutgoingOperationValue.resendOperations.rawValue:
                self = .resendOperations(layer: SecretChatSequenceBasedLayer(rawValue: decoder.decodeInt32ForKey("l"))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i"), fromSeqNo: decoder.decodeInt32ForKey("f"), toSeqNo: decoder.decodeInt32ForKey("t"))
            case SecretChatOutgoingOperationValue.reportLayerSupport.rawValue:
                self = .reportLayerSupport(layer: SecretChatLayer(rawValue: decoder.decodeInt32ForKey("l"))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i"), layerSupport: decoder.decodeInt32ForKey("l"))
            case SecretChatOutgoingOperationValue.pfsRequestKey.rawValue:
                self = .pfsRequestKey(layer: SecretChatSequenceBasedLayer(rawValue: decoder.decodeInt32ForKey("l"))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i"), rekeySessionId: decoder.decodeInt64ForKey("s"), a: decoder.decodeBytesForKey("a")!)
            case SecretChatOutgoingOperationValue.pfsAcceptKey.rawValue:
                self = .pfsAcceptKey(layer: SecretChatSequenceBasedLayer(rawValue: decoder.decodeInt32ForKey("l"))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i"), rekeySessionId: decoder.decodeInt64ForKey("s"), gA: decoder.decodeBytesForKey("g")!, b: decoder.decodeBytesForKey("b")!)
            case SecretChatOutgoingOperationValue.pfsAbortSession.rawValue:
                self = .pfsAbortSession(layer: SecretChatSequenceBasedLayer(rawValue: decoder.decodeInt32ForKey("l"))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i"), rekeySessionId: decoder.decodeInt64ForKey("s"))
            case SecretChatOutgoingOperationValue.pfsCommitKey.rawValue:
                self = .pfsCommitKey(layer: SecretChatSequenceBasedLayer(rawValue: decoder.decodeInt32ForKey("l"))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i"), rekeySessionId: decoder.decodeInt64ForKey("s"), keyFingerprint: decoder.decodeInt64ForKey("f"))
            case SecretChatOutgoingOperationValue.noop.rawValue:
                self = .noop(layer: SecretChatSequenceBasedLayer(rawValue: decoder.decodeInt32ForKey("l"))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i"))
            case SecretChatOutgoingOperationValue.setMessageAutoremoveTimeout.rawValue:
                self = .setMessageAutoremoveTimeout(layer: SecretChatLayer(rawValue: decoder.decodeInt32ForKey("l"))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i"), timeout: decoder.decodeInt32ForKey("t"))
            case SecretChatOutgoingOperationValue.terminate.rawValue:
                self = .terminate
            default:
                self = .noop(layer: SecretChatSequenceBasedLayer(rawValue: decoder.decodeInt32ForKey("l"))!, actionGloballyUniqueId: 0)
                assertionFailure()
        }
    }
    
    func encode(_ encoder: Encoder) {
        switch self {
            case let .initialHandshakeAccept(gA, accessHash, b):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.initialHandshakeAccept.rawValue, forKey: "r")
                encoder.encodeBytes(gA, forKey: "g")
                encoder.encodeInt64(accessHash, forKey: "h")
                encoder.encodeBytes(b, forKey: "b")
            case let .sendMessage(layer, id, file):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.sendMessage.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(id.peerId.toInt64(), forKey: "i.p")
                encoder.encodeInt32(id.namespace, forKey: "i.n")
                encoder.encodeInt32(id.id, forKey: "i.i")
                if let file = file {
                    encoder.encodeObject(file, forKey: "f")
                } else {
                    encoder.encodeNil(forKey: "f")
                }
            case let .readMessagesContent(layer, actionGloballyUniqueId, globallyUniqueIds):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.readMessagesContent.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt64Array(globallyUniqueIds, forKey: "u")
            case let .deleteMessages(layer, actionGloballyUniqueId, globallyUniqueIds):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.deleteMessages.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt64Array(globallyUniqueIds, forKey: "u")
            case let .screenshotMessages(layer, actionGloballyUniqueId, globallyUniqueIds):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.screenshotMessages.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt64Array(globallyUniqueIds, forKey: "u")
            case let .clearHistory(layer, actionGloballyUniqueId):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.clearHistory.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
            case let .resendOperations(layer, actionGloballyUniqueId, fromSeqNo, toSeqNo):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.resendOperations.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt32(fromSeqNo, forKey: "f")
                encoder.encodeInt32(toSeqNo, forKey: "t")
            case let .reportLayerSupport(layer, actionGloballyUniqueId, layerSupport):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.reportLayerSupport.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt32(layerSupport, forKey: "l")
            case let .pfsRequestKey(layer, actionGloballyUniqueId, rekeySessionId, a):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.pfsRequestKey.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt64(rekeySessionId, forKey: "s")
                encoder.encodeBytes(a, forKey: "a")
            case let .pfsAcceptKey(layer, actionGloballyUniqueId, rekeySessionId, gA, b):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.pfsAcceptKey.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt64(rekeySessionId, forKey: "s")
                encoder.encodeBytes(gA, forKey: "g")
                encoder.encodeBytes(b, forKey: "b")
            case let .pfsAbortSession(layer, actionGloballyUniqueId, rekeySessionId):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.pfsAbortSession.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt64(rekeySessionId, forKey: "s")
            case let .pfsCommitKey(layer, actionGloballyUniqueId, rekeySessionId, keyFingerprint):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.pfsCommitKey.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt64(rekeySessionId, forKey: "s")
                encoder.encodeInt64(keyFingerprint, forKey: "f")
            case let .noop(layer, actionGloballyUniqueId):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.noop.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
            case let .setMessageAutoremoveTimeout(layer, actionGloballyUniqueId, timeout):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.setMessageAutoremoveTimeout.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt32(timeout, forKey: "t")
            case .terminate:
                encoder.encodeInt32(SecretChatOutgoingOperationValue.terminate.rawValue, forKey: "r")
        }
    }
}

final class SecretChatOutgoingOperation: Coding {
    let contents: SecretChatOutgoingOperationContents
    let mutable: Bool
    let delivered: Bool
    
    init(contents: SecretChatOutgoingOperationContents, mutable: Bool, delivered: Bool) {
        self.contents = contents
        self.mutable = mutable
        self.delivered = delivered
    }
    
    init(decoder: Decoder) {
        self.contents = decoder.decodeObjectForKey("c", decoder: { SecretChatOutgoingOperationContents(decoder: $0) }) as! SecretChatOutgoingOperationContents
        self.mutable = (decoder.decodeInt32ForKey("m") as Int32) != 0
        self.delivered = (decoder.decodeInt32ForKey("d") as Int32) != 0
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeObject(self.contents, forKey: "c")
        encoder.encodeInt32(self.mutable ? 1 : 0, forKey: "m")
        encoder.encodeInt32(self.delivered ? 1 : 0, forKey: "r")
    }
    
    func withUpdatedDelivered(_ delivered: Bool) -> SecretChatOutgoingOperation {
        return SecretChatOutgoingOperation(contents: self.contents, mutable: self.mutable, delivered: delivered)
    }
}

extension SecretChatOutgoingFileReference {
    init?(_ apiFile: Api.InputEncryptedFile) {
        switch apiFile {
            case let .inputEncryptedFile(id, accessHash):
                self = .remote(id: id, accessHash: accessHash)
            case let .inputEncryptedFileBigUploaded(id, parts, keyFingerprint):
                self = .uploadedLarge(id: id, partCount: parts, keyFingerprint: keyFingerprint)
            case let .inputEncryptedFileUploaded(id, parts, md5Checksum, keyFingerprint):
                self = .uploadedRegular(id: id, partCount: parts, md5Digest: md5Checksum, keyFingerprint: keyFingerprint)
            case .inputEncryptedFileEmpty:
                return nil
        }
    }
    
    var apiInputFile: Api.InputEncryptedFile {
        switch self {
            case let .remote(id, accessHash):
                return .inputEncryptedFile(id: id, accessHash: accessHash)
            case let .uploadedRegular(id, partCount, md5Digest, keyFingerprint):
                return .inputEncryptedFileUploaded(id: id, parts: partCount, md5Checksum: md5Digest, keyFingerprint: keyFingerprint)
            case let .uploadedLarge(id, partCount, keyFingerprint):
                return .inputEncryptedFileBigUploaded(id: id, parts: partCount, keyFingerprint: keyFingerprint)
        }
    }
}
