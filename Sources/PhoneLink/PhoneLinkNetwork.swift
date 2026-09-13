import Foundation
import SystemConfiguration
import Darwin

enum PhoneLinkNetwork {
    static func getHosts() -> [String] {
        let global = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString) as? [String: Any]
        let primaryInterface = global?["PrimaryInterface"] as? String
        var candidates: [(name: String, ip: String, flags: Int32)] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            guard let interface = ptr?.pointee,
                  let address = interface.ifa_addr else { continue }

            let flags = Int32(interface.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0 else { continue }
            let addrFamily = interface.ifa_addr.pointee.sa_family
            guard addrFamily == UInt8(AF_INET) else { continue }
            let name = String(cString: interface.ifa_name)

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, 0, NI_NUMERICHOST) == 0 else { continue }

            let ip = String(cString: hostname)
            candidates.append((name, ip, flags))
        }

        return localHosts(candidates, primaryInterface: primaryInterface)
    }

    /// A VPN can own the default route without replacing the LAN. Prefer the
    /// primary interface only when it is a LAN interface; keep the other LANs.
    static func localHosts(_ candidates: [(name: String, ip: String, flags: Int32)],
                           primaryInterface: String?) -> [String] {
        let eligible = candidates.filter { item in
            let isLAN = ["en", "bridge", "vlan", "bond"].contains { prefix in
                let suffix = item.name.dropFirst(prefix.count)
                return item.name.hasPrefix(prefix) && !suffix.isEmpty
                    && suffix.allSatisfy { $0.isASCII && $0.isNumber }
            }
            return isLAN && item.flags & IFF_UP != 0 && item.flags & IFF_RUNNING != 0
                && item.flags & (IFF_LOOPBACK | IFF_POINTOPOINT) == 0
                && isPrivateIPv4(item.ip)
        }
        let ordered = eligible.filter { $0.name == primaryInterface }
            + eligible.filter { $0.name != primaryInterface }
        var seen = Set<String>()
        return ordered.compactMap { seen.insert($0.ip).inserted ? $0.ip : nil }
    }

    static func getComputerName() -> String {
        if let name = SCDynamicStoreCopyComputerName(nil, nil) as String? {
            return name
        }
        return Host.current().localizedName ?? "Mac"
    }

    static func isPrivateIPv4(_ ip: String) -> Bool {
        let octets = ip.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4, octets.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }) else { return false }
        let parts = octets.compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else { return false }

        if parts[0] == 10 { return true }
        if parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31 { return true }
        if parts[0] == 192 && parts[1] == 168 { return true }
        if parts[0] == 169 && parts[1] == 254 { return true } // link-local
        return false
    }

    static func isPrivateIP(_ ip: String) -> Bool {
        if isPrivateIPv4(ip) { return true }
        if ip == "127.0.0.1" || ip == "::1" { return true }

        // IPv6 ULA (fc00::/7) or link-local (fe80::/10)
        let lower = ip.lowercased()
        if lower.hasPrefix("fc") || lower.hasPrefix("fd") || lower.hasPrefix("fe8") || lower.hasPrefix("fe9") || lower.hasPrefix("fea") || lower.hasPrefix("feb") {
            return true
        }
        return false
    }
}
