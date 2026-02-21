import Foundation

/// Percent-encode values for `application/x-www-form-urlencoded` bodies.
enum URLFormEncoding {
    static func encode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove("+")
        allowed.remove("&")
        allowed.remove("=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
