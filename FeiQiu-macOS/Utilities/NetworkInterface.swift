import Foundation

#if canImport(Darwin)
import Darwin
#endif

// MARK: - 网络接口工具

/// 获取本机网络接口信息
struct NetworkInterface {
    
    /// 获取本机所有 IP 地址
    static func getLocalIPAddresses() -> [String] {
        var addresses: [String] = []
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return addresses }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            
            let addrFamily = interface.ifa_addr.pointee.sa_family
            guard addrFamily == UInt8(AF_INET) else { continue }
            
            // 跳过 loopback
            let flags = Int32(interface.ifa_flags)
            guard (flags & IFF_LOOPBACK) == 0 else { continue }
            guard (flags & IFF_UP) != 0 else { continue }
            
            // 获取接口名
            let name = String(cString: interface.ifa_name)
            
            // 只获取主要接口 (en0, en1, pdp_ip0 等)
            guard name.hasPrefix("en") || name.hasPrefix("pdp_ip") || name.hasPrefix("bridge") else { continue }
            
            // 获取地址
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            
            if result == 0 {
                let address = String(cString: hostname)
                addresses.append(address)
            }
        }
        
        return addresses
    }
    
    /// 获取所有广播地址
    static func getBroadcastAddresses() -> [String] {
        var addresses: [String] = []
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return addresses }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            
            let addrFamily = interface.ifa_addr.pointee.sa_family
            guard addrFamily == UInt8(AF_INET) else { continue }
            
            let flags = Int32(interface.ifa_flags)
            guard (flags & IFF_LOOPBACK) == 0 else { continue }
            guard (flags & IFF_UP) != 0 else { continue }
            guard (flags & IFF_BROADCAST) != 0 else { continue }
            
            let name = String(cString: interface.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("pdp_ip") || name.hasPrefix("bridge") else { continue }
            
            // 计算广播地址 = IP & netmask | ~netmask
            guard let addrPtr = interface.ifa_addr,
                  let maskPtr = interface.ifa_netmask else { continue }
            
            let addr = addrPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
            let mask = maskPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
            
            let broadcast = (addr & mask) | ~mask
            
            var broadcastAddr = in_addr(s_addr: broadcast)
            if let cStr = inet_ntoa(broadcastAddr) {
                addresses.append(String(cString: cStr))
            }
        }
        
        return addresses
    }
    
    /// 获取主机名
    static func getHostName() -> String {
        var hostnameBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard gethostname(&hostnameBuffer, hostnameBuffer.count) == 0 else {
            return "iOS-Device"
        }
        return String(cString: hostnameBuffer)
    }
    
    /// 获取设备名（适合作为 IPMSG 显示名）
    static func getDeviceName() -> String {
        #if canImport(UIKit)
        return ProcessInfo.processInfo.hostName.components(separatedBy: ".").first ?? "iOS"
        #else
        return getHostName().components(separatedBy: ".").first ?? "iOS"
        #endif
    }
}
