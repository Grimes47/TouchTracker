//
//  Line.swift
//  TouchTracker
//
//  Created by Adam Hogan on 7/24/17.
//  Copyright © 2017 Adam Hogan. All rights reserved.
//

import Foundation
import UIKit
import CoreGraphics

struct Line {
    var begin = CGPoint.zero
    var end = CGPoint.zero
    var lineWidth: CGFloat = 10
    var color: UIColor = .black
    
    var angle: Measurement<UnitAngle> {
        var angleInRads: Measurement<UnitAngle>
        angleInRads = Measurement(value: -atan2(Double(end.y - begin.y),Double(end.x - begin.x)), unit: .radians)
        
        return angleInRads.converted(to: .degrees)
    }
}
