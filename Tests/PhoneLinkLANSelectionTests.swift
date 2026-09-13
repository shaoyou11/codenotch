import XCTest
import Darwin
@testable import Codenotch

final class PhoneLinkLANSelectionTests: XCTestCase {
    private let active = Int32(IFF_UP | IFF_RUNNING)

    func testVPNDefaultRouteDoesNotHideEthernetOrWiFi() {
        let hosts = PhoneLinkNetwork.localHosts([
            ("utun6", "10.8.0.1", active | IFF_POINTOPOINT),
            ("en0", "10.118.0.228", active),
            ("en1", "10.118.98.90", active)
        ], primaryInterface: "utun6")
        XCTAssertEqual(hosts, ["10.118.0.228", "10.118.98.90"])
    }

    func testMissingDefaultRouteStillFindsLANAndDeduplicates() {
        XCTAssertEqual(PhoneLinkNetwork.localHosts([
            ("en0", "192.168.1.2", active), ("en0", "192.168.1.2", active)
        ], primaryInterface: nil), ["192.168.1.2"])
    }

    func testPrimaryLANComesFirst() {
        XCTAssertEqual(PhoneLinkNetwork.localHosts([
            ("en0", "192.168.1.2", active), ("en1", "10.1.1.2", active)
        ], primaryInterface: "en1"), ["10.1.1.2", "192.168.1.2"])
    }

    func testTunnelPeerLoopbackInactiveAndPublicAddressesAreExcluded() {
        XCTAssertEqual(PhoneLinkNetwork.localHosts([
            ("utun6", "10.8.0.1", active), ("awdl0", "169.254.1.2", active),
            ("lo0", "127.0.0.1", active | IFF_LOOPBACK),
            ("en0", "192.168.1.2", IFF_UP),
            ("en1", "203.0.113.2", active),
            ("en2", "10.1.1.2", active | IFF_POINTOPOINT)
        ], primaryInterface: "utun6"), [])
    }

    func testBridgeAndVLANAreSupported() {
        XCTAssertEqual(PhoneLinkNetwork.localHosts([
            ("bridge0", "192.168.2.2", active), ("vlan0", "10.2.2.2", active)
        ], primaryInterface: nil), ["192.168.2.2", "10.2.2.2"])
    }

    func testMalformedAddressesAreRejected() {
        for ip in ["10.1.2.999", "10..1.2", "10.a.1.2.3", "10.-1.2.3"] {
            XCTAssertFalse(PhoneLinkNetwork.isPrivateIPv4(ip), ip)
        }
    }
}
