//
//  TestViewController.swift
//  atsios
//
//  Created by Caipture on 12/10/2020.
//  Copyright © 2020 CAIPTURE. All rights reserved.
//

import UIKit

class TestViewController: UIViewController {

    @IBOutlet private weak var windowsCoordinatesLabel: UILabel!
    @IBOutlet private weak var coordinatesLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        windowsCoordinatesLabel.text = "\(view.bounds)"
        
        // Do any additional setup after loading the view.
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        coordinatesLabel.text = "\(touches.first!.location(in: nil))"
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
