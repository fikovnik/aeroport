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

func setNetwork(interface: CWInterface, network: CWNetwork) throws -> Void {
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

func defaultInterfaceName() -> String? {
    return CWWiFiClient.interfaceNames()?.first
}

func interfaceNameValidator(name: String?) throws -> String? {
    return try findInterface(name: name!).interfaceName
}

func printNetworkList(interface: CWInterface, networks: [CWNetwork], template: String) throws -> Void {
    let networksProperties = networks.map {[
            "bssid": $0.bssid ?? "N/A",
            "ssid": $0.ssid ?? "N/A",
            "rssi​Value": $0.rssiValue,
            "noiseMeasurement": $0.noiseMeasurement,
            "channelNumber": $0.wlanChannel.channelNumber
    ]}
    let env = Environment(loader: FileSystemLoader(paths: ["Resources/"]))
    let output = try env.renderTemplate(
            name: template,
            context: [
                    "interface": interface,
                    "nets": networksProperties,
                    "count": networks.count
            ])

    print(output)
}

let main = Group {
    $0.command("scan",
            Option<String>("interface", default: defaultInterfaceName()!, description: "Network interface", validator: interfaceNameValidator),
            Option<String>("ssid", description: "Filter by ssid"),
            Flag("no-cache", description: "Do a full network scan", default: false),
            description: "List available wireless networks") { (interfaceName, ssid, nocache) in

        let interface = try findInterface(name: interfaceName!)

        if (nocache!) {
            print("Scanning \(interface.interfaceName!)...")
        }

        let ssidRegex = try ssid.map { try Regex(string: $0) }
        let networks = (nocache! ? try interface.scanForNetworks(withName: nil) : interface.cachedScanResults()) ?? []
        let filteredNetworks = networks.filter{ network in
            if let regex = ssidRegex {
                if let name = network.ssid {
                    return regex.matches(name)
                } else {
                    return false
                }
            } else {
                return true
            }
        }

        try printNetworkList(interface: interface, networks: filteredNetworks, template: "default.template")
    }

    $0.command("join",
            Option<String>("interface", default: defaultInterfaceName()!, description: "Network interface", validator: interfaceNameValidator),
            Option<String>("bssid", description: "BSSID of the network to join"),
            description: "Join a network"
    ) { interfaceName, bssid in

        if bssid == nil {
            throw AeroportError.RuntimeError(message: "Missing network name")
        }

        let interface = try findInterface(name: interfaceName!)

        if let network = try interface.scanForNetworks(withName: nil).filter({ $0.bssid == bssid }).first {
            print("Switching \(interface.interfaceName!) to \(network.bssid!) (SSID: \(network.ssid ?? "N/A"))")

            try setNetwork(interface: interface, network: network)
        } else {
            throw AeroportError.RuntimeError(message: "\(bssid): Unknown network")
        }
    }
}

main.run()