//
//  ViewController.swift
//  HeraldTest
//
//  Created by Andres Colubri on 8/25/21.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var status: UILabel!    
    @IBOutlet weak var peers: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        TestService.shared.start()
        
        EventHelper.delegate = self
    }

}

extension ViewController: EventHelperDelegate {
    
    func updateStatus() {
        DispatchQueue.main.async {
            let service = TestService.shared
            self.status.text = (String(AppDelegate.instance?.payloadDataSupplier?.getIdentifier() ?? 0)) + ":" +
                               (AppDelegate.instance?.payloadDataSupplier?.getStatus().toString() ?? "")
        }
    }
        
    func updatePeers() {
        DispatchQueue.main.async {
            self.peers.text = ""
            let cpeers = AppDelegate.instance?.currentPeers
            cpeers?.forEach({ (id: Int, value: PeerInfo) in
                let txt = "-> \(id): \(value.status): \(value.getRSSI()) \n"
                print(txt)
                self.peers.text.append(txt)
            })
        }
    }
}
