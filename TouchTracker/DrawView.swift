//
//  DrawView.swift
//  TouchTracker
//
//  Created by Adam Hogan on 7/24/17.
//  Copyright © 2017 Adam Hogan. All rights reserved.
//

import UIKit

class DrawView: UIView, UIGestureRecognizerDelegate {
    
    let view = UIView()
    var line = Line()
    var currentLines = [NSValue:Line]()
    var finishedLines = [Line]()
    var selectedLineIndex: Int? {
        didSet {
            if selectedLineIndex == nil {
                let menu = UIMenuController.shared
                menu.setMenuVisible(false, animated: true)
            }
        }
    }
    var moveRecognizer: UIPanGestureRecognizer!
    
    var currentCircle = Circle()
    var finishedCircles = [Circle]()
    
    var maxRecordedVelocity: CGFloat = CGFloat.leastNonzeroMagnitude
    var minRecordedVelocity: CGFloat = CGFloat.greatestFiniteMagnitude
    var currentVelocity: CGFloat = 0
    var currentLineWidth: CGFloat {
        let maxLineWidth: CGFloat = 10
        let minLineWidth: CGFloat = 1
        //thinner line for faster velocity
        let lineWidth = (maxRecordedVelocity - currentVelocity) / (maxRecordedVelocity - minRecordedVelocity) * (maxLineWidth - minLineWidth) + minLineWidth
        return lineWidth
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    @IBInspectable var finishedLineColor: UIColor = UIColor.black {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable var currentLineColor: UIColor = UIColor.red {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable var lineThickness: CGFloat = 10 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(DrawView.doubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.delaysTouchesBegan = true
        addGestureRecognizer(doubleTapRecognizer)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(DrawView.tap(_:)))
        tapRecognizer.delaysTouchesBegan = true
        tapRecognizer.require(toFail: doubleTapRecognizer)
        addGestureRecognizer(tapRecognizer)
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(DrawView.longPress(_:)))
        addGestureRecognizer(longPressRecognizer)
        
        moveRecognizer = UIPanGestureRecognizer(target: self, action: #selector(DrawView.moveLine(_:)))
        moveRecognizer.delegate = self
        moveRecognizer.cancelsTouchesInView = false
        addGestureRecognizer(moveRecognizer)
        
        let swipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(DrawView.swipeForColors(_:)))
        swipeRecognizer.numberOfTouchesRequired = 3
        swipeRecognizer.direction = .up
        addGestureRecognizer(swipeRecognizer)
        
        moveRecognizer = UIPanGestureRecognizer(target: self, action: #selector(DrawView.moveLine(_:)))
        moveRecognizer.delegate = self
        moveRecognizer.cancelsTouchesInView = false
        moveRecognizer.require(toFail: swipeRecognizer)
        addGestureRecognizer(moveRecognizer)
    }
    
    func tap(_ gestureRecognizer: UIGestureRecognizer) {
        print("Recognized a tap")
        
        let point = gestureRecognizer.location(in: self)
        selectedLineIndex = indexOfLine(at: point)
        
        //grab the menu controller
        let menu = UIMenuController.shared
        
        if selectedLineIndex != nil {
            //make DrawView the target of menu item action messages
            becomeFirstResponder()
            
            //create a new "Delete" UIMenuItem
            let deleteItem = UIMenuItem(title: "Delete", action: #selector(DrawView.deleteLine(_:)))
            menu.menuItems = [deleteItem]
            
            //tell the menu where it should come from and show it
            let targetRect = CGRect(x: point.x, y: point.y, width: 2, height: 2)
            menu.setTargetRect(targetRect, in: self)
            menu.setMenuVisible(true, animated: true)
        } else {
            //hide the menu if no line is selected
            menu.setMenuVisible(false, animated: true)
        }
        
        setNeedsDisplay()
    }
    
    func stroke(_ line: Line) {
        let path = UIBezierPath()
        path.lineWidth = line.lineWidth
        path.lineCapStyle = .round
        
        path.move(to: line.begin)
        path.addLine(to: line.end)
        path.stroke()
    }
    
    func doubleTap(_ gestureRecognizer: UIGestureRecognizer) {
        print("Recognize a double tap")
        
        selectedLineIndex = nil
        currentLines.removeAll()
        finishedLines.removeAll()
        setNeedsDisplay()
    }
    
    func longPress(_ gestureRecognizer: UIGestureRecognizer) {
        print("Recognized a long press")
        
        if gestureRecognizer.state == .began {
            let point = gestureRecognizer.location(in: self)
            selectedLineIndex = indexOfLine(at: point)
            
            if selectedLineIndex != nil {
                currentLines.removeAll()
            }
        } else if gestureRecognizer.state == .ended {
            selectedLineIndex = nil
        }
        
        setNeedsDisplay()
    }
    
    func moveLine(_ gestureRecognizer: UIPanGestureRecognizer) {
        print("Recognized a pan")
        let menu = UIMenuController.shared
        
        let velocityInXY = gestureRecognizer.velocity(in: self)
        currentVelocity = hypot(velocityInXY.x, velocityInXY.y)
        
        maxRecordedVelocity = max(maxRecordedVelocity, currentVelocity)
        minRecordedVelocity = min(minRecordedVelocity, currentVelocity)
        
        print("Current Drawing Velocity: \(currentVelocity) points per second")
        print("maxRecordedVelocity: \(maxRecordedVelocity) points per second")
        print("minRecordedVelocity: \(minRecordedVelocity) points per second")
        
        guard gestureRecognizer.state == .changed || gestureRecognizer.state == .ended else {
            return
        }
        
        //if a line is selected...
        if let index = selectedLineIndex {
            //when pan recognizer changes its position...
            if gestureRecognizer.state == .changed {
                //how far has the pan moved?
                let translation = gestureRecognizer.translation(in: self)
                menu.setMenuVisible(false, animated: true)
            
                //add the translation to the current beginning and end points of the line
                //make sure there are no copy and paste typos!
                finishedLines[index].begin.x += translation.x
                finishedLines[index].begin.y += translation.y
                finishedLines[index].end.x += translation.x
                finishedLines[index].end.y += translation.y
                
                gestureRecognizer.setTranslation(CGPoint.zero, in: self)
            
                //redraw the screen
                setNeedsDisplay()
        }
    } else {
        //if no line is selected, do not do anything
        return
        }
    }

    override func draw(_ rect: CGRect) {
        finishedLineColor.setStroke()
        for line in finishedLines {
            stroke(line)
        }
        
        //currentLineColor
        for (_, line) in currentLines {
            
            switch line.angle.value {
            case 0 ..< 90.0:
                UIColor.red.setStroke()
            case 90.0 ..< 180.0:
                UIColor.blue.setStroke()
            case -180.0 ..< -90.0:
                UIColor.yellow.setStroke()
            case -90.0 ..< 0:
                UIColor.green.setStroke()
            default:
                break
            }
            
            stroke(line)
        }
        
        if let index = selectedLineIndex {
            UIColor.green.setStroke()
            let selectedLine = finishedLines[index]
            stroke(selectedLine)
            
        }

        //draw circles
        finishedLineColor.setStroke()
        for circle in finishedCircles {
            let path = UIBezierPath(ovalIn: circle.rect)
            path.lineWidth = lineThickness
            path.stroke()
        }
        currentLineColor.setStroke()
        UIBezierPath(ovalIn: currentCircle.rect).stroke()
    
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func indexOfLine(at point: CGPoint) -> Int? {
        //find a line close to point
        for (index, line) in finishedLines.enumerated() {
            let begin = line.begin
            let end = line.end
            
            //check a few points on the line
            for t in stride(from: CGFloat(0), to: 1.0, by: 0.05) {
                let x = begin.x + ((end.x - begin.x) * t)
                let y = begin.y + ((end.y - begin.y) * t)
                
                //if the tapped point is within 20 points, let's return this line
                if hypot(x - point.x, y - point.y) < 20.0 {
                    return index
                }
            }
        }
        
        //if nothing is close enough to the tapped point, then we did not select a line
        return nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //log statement to see the order of events
        print(#function)
        
        if touches.count == 2 {
            let touchesArray = Array(touches)
            let location1 = touchesArray[0].location(in: self)
            let location2 = touchesArray[1].location(in: self)
            currentCircle = Circle(point1: location1, point2: location2)
        } else {
        
        for touch in touches {
            if selectedLineIndex == nil {
                let location = touch.location(in: self)
                
                let newLine = Line(begin: location, end: location, lineWidth: currentLineWidth, color: currentLineColor)
                
                let key = NSValue(nonretainedObject: touch)
                currentLines[key] = newLine
            }
     

            }
        
        setNeedsDisplay()
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        //log statement to see the order of events
        print(#function)
        
        if touches.count == 2 {
            let touchesArray = Array(touches)
            let location1 = touchesArray[0].location(in: self)
            let location2 = touchesArray[1].location(in: self)
            currentCircle = Circle(point1: location1, point2: location2)
        } else {
        for touch in touches {
            let key = NSValue(nonretainedObject: touch)
            currentLines[key]?.end = touch.location(in: self)
            }
        }
        
        setNeedsDisplay()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        //log statement to se the order of events
        print(#function)
        
        
        if touches.count == 2 {
            let touchesArray = Array(touches)
            let location1 = touchesArray[0].location(in: self)
            let location2 = touchesArray[1].location(in: self)
            currentCircle = Circle(point1: location1, point2: location2)
            finishedCircles.append(currentCircle)
            currentCircle = Circle()
        } else {
        
            for touch in touches {
                let key = NSValue(nonretainedObject: touch)
                if var line = currentLines[key] {
                
                    line.end = touch.location(in: self)
                    line.lineWidth = currentLineWidth
                    finishedLines.append(line)
                    currentLines.removeValue(forKey: key)
                    }
                }
            setNeedsDisplay()
            }
        line.color = currentLineColor
        finishedLines.append(line)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // log statement to see the order of events
        print(#function)
        
        currentLines.removeAll()
        currentCircle = Circle()
        
        setNeedsDisplay()
    }
    
    func deleteLine(_ sender: UIMenuController) {
        //remove the selected line from teh list of finishedLines
        if let index = selectedLineIndex {
            finishedLines.remove(at: index)
            selectedLineIndex = nil
            
            //redraw everything
            setNeedsDisplay()
        }
    }
    
    func swipeForColors(_ gestureRecognizer: UISwipeGestureRecognizer) {
        print("Recognized a swipe")
        currentLines.removeAll()
        
        // Grab the menu controller
        let menu = UIMenuController.shared
        
        // Make DrawView the target of menu item action messages
        becomeFirstResponder()
        
        let color0Item = UIMenuItem(title: "Black", action: #selector(DrawView.selectColor0(_:)))
        let color1Item = UIMenuItem(title: "Gray", action: #selector(DrawView.selectColor1(_:)))
        let color2Item = UIMenuItem(title: "Red", action: #selector(DrawView.selectColor2(_:)))
        let color3Item = UIMenuItem(title: "Yellow", action: #selector(DrawView.selectColor3(_:)))
        let color4Item = UIMenuItem(title: "Blue", action: #selector(DrawView.selectColor4(_:)))
        menu.menuItems = [color0Item, color1Item, color2Item, color3Item, color4Item]
        
        // Tell the menu where it should come from and show it
        let targetRect = CGRect(x: self.frame.midX, y: self.frame.midY, width: 2, height: 2)
        menu.setTargetRect(targetRect, in: self)
        menu.setMenuVisible(true, animated: true)
    }
    
    func selectColor0(_ sender: UIMenuController) {
        currentLineColor = .black
        UIMenuController.shared.setMenuVisible(false, animated: true)
    }
    
    func selectColor1(_ sender: UIMenuController) {
        currentLineColor = .gray
        UIMenuController.shared.setMenuVisible(false, animated: true)
    }
    
    func selectColor2(_ sender: UIMenuController) {
        currentLineColor = .red
        UIMenuController.shared.setMenuVisible(false, animated: true)
    }
    
    func selectColor3(_ sender: UIMenuController) {
        currentLineColor = .yellow
        UIMenuController.shared.setMenuVisible(false, animated: true)
    }
    
    func selectColor4(_ sender: UIMenuController) {
        currentLineColor = .blue
        UIMenuController.shared.setMenuVisible(false, animated: true)
    }
}

