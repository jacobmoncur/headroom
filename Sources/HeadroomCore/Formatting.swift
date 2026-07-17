import Foundation

public enum StorageFormatting {
    public static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
    public static func signedBytes(_ value: Int64) -> String {
        (value >= 0 ? "+" : "−") + bytes(abs(value))
    }
}
