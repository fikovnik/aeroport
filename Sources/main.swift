import Foundation
import Security
import Commander
import CoreWLAN
import Darwin
import Stencil
import Regex

enum AeroportError: Error {
    case RuntimeError(message: String)
}

func findInterface(name: String) throws -> CWInterface {
    guard let interface = CWWiFiClient.shared().interface(withName: name) else {
        throw AeroportError.RuntimeError(message: "Unable to get \(name) interface")
    }

    return interface
}

func findNetworks(interface: CWInterface, predicate: (CWNetwork) -> Bool) throws -> [CWNetwork] {
    return try interface.scanForNetworks(withName: nil).filter(predicate)
}

func setNetwork(interface: CWInterface, network: CWNetwork) throws -> Void {
    print("Switching \(interface.interfaceName) to \(network.bssid!) (SSID: \(network.ssid ?? "N/A"))")

    let password = try network.ssid.flatMap{ try findWifiPassword(networkName: $0) }

    try interface.associate(to: network, password: password)
}

func findWifiPassword(networkName: String) throws -> String? {
    let networkNameData = (networkName as NSString).utf8String

    var passwordItem: SecKeychainItem? = nil
    var res: OSStatus = 0

    res = SecKeychainFindGenericPassword(
            nil,
            0,
            nil,
            UInt32(strlen(networkNameData)),
            networkNameData,
            nil,
            nil,
            &passwordItem)

    if res == errSecSuccess {
        var passwordLength: UInt32 = 0
        var passwordData: UnsafeMutableRawPointer? = nil

        res = SecKeychainItemCopyContent(passwordItem!, nil, nil, &passwordLength, &passwordData)

        if res == errSecSuccess {
            let data = Data(bytes: passwordData!, count: Int(passwordLength))
            let password = String(data: data, encoding: String.Encoding.utf8)

            return password
        } else {
            throw AeroportError.RuntimeError(message: "Getting password for \(networkName) failed: \(SecCopyErrorMessageString(res, nil)) (SecKeychainItemCopyContent)")
        }
    } else {
        throw AeroportError.RuntimeError(message: "Getting password for \(networkName) failed: \(SecCopyErrorMessageString(res, nil)) (SecKeychainFindGenericPassword)")
    }
}


let main = Group {
    $0.command("list",
            Argument<String>("interface", description: "Network interface"),
            Option<String>("ssid", "", description: "Filter by ssid"),
            description: "List available wireless networks") { (interfaceName, ssid) in

        let ssidRegex = ssid != "" ? try Regex(string: ssid) : nil
        let interface = try findInterface(name: interfaceName)
        let networks = try findNetworks(interface: interface, predicate: { network in
            if let regex = ssidRegex {
                if let name = network.ssid {
                    return regex.matches(name)
                } else {
                    return false
                }
            } else {
                return true
            }
        }).map {[
            "bssid": $0.bssid ?? "N/A",
            "ssid": $0.ssid ?? "N/A",
            "rssi​Value": $0.rssiValue,
            "noiseMeasurement": $0.noiseMeasurement,
            "channelNumber": $0.wlanChannel.channelNumber
        ]}

        let env = Environment(loader: FileSystemLoader(paths: ["Resources/"]))
        let output = try env.renderTemplate(
                name: "default.template",
                context: [
                        "interface": interface,
                        "nets": Array(networks),
                        "count": networks.count
                ])

        print(output)
    }

    $0.command("join",
            Argument<String>("interface", description: "Network interface"),
            Option<String>("bssid", "", description: "BSSID of the network"),
            description: "Join network") { (interfaceName, bssid) in

        let interface = try findInterface(name: interfaceName)
        let network = try findNetworks(interface: interface, predicate: { $0.bssid == bssid }).first

        if network != nil {
            try setNetwork(interface: interface, network: network!)
        } else {
            throw AeroportError.RuntimeError(message: "\(bssid): Unknown network")
        }
    }
}

main.run()