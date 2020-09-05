//
//  ViewController.swift
//  Draw
//
//  Created by 邱云翔 on 2020/8/26.
//  Copyright © 2020 com.Qiuyunxiang.www. All rights reserved.
//

import UIKit

struct TouchPointStruct {
    var timeStamp : TimeInterval = 0
    var point : CGPoint = CGPoint.init()
}

extension TouchPointStruct {
    func isEqualToOtherTP(other:TouchPointStruct?) -> Bool {
        guard let other = other else {
            return false
        }
        return timeStamp == other.timeStamp && point == other.point
    }
}

class ViewController: UIViewController {
    var currentDrawLayer : CAShapeLayer?
    var pathArray : Array = Array<Array<TouchPointStruct>>()
    var currentArray : Array<TouchPointStruct>?
    var currentPath : UIBezierPath?
    var currentAnimationView : UIView?
    var currentAnimationIndex : Int = 0
    var currentPauseAnimation : CAAnimation? //只有当暂停时才会被赋值
    
    lazy var startAnimationBtn : UIButton = {
        let btn = UIButton.init(type: UIButton.ButtonType.custom)
        btn.setTitle("回放", for: UIControl.State.normal)
        btn.setTitle("暂停", for: UIControl.State.selected)
        btn.setTitleColor(UIColor.green, for: UIControl.State.normal)
        btn.setTitleColor(UIColor.green, for: UIControl.State.selected)
        btn.frame = CGRect.init(x: self.view.bounds.size.width - 120, y: 50, width: 60, height: 30)
        btn.addTarget(self, action: #selector(handleAnimationRecordingBtn(btn:)), for: UIControl.Event.touchUpInside)
        return btn
    }()
    lazy var cleanPathBtn : UIButton = {
        let btn = UIButton.init(type: UIButton.ButtonType.custom)
        btn.setTitle("清除", for: UIControl.State.normal)
        btn.setTitleColor(UIColor.blue, for: UIControl.State.normal)
        btn.frame = CGRect.init(x: 60, y: 50, width: 60, height: 30)
        btn.addTarget(self, action: #selector(handleCleanPathBtn), for: UIControl.Event.touchUpInside)
        return btn
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.addSubview(startAnimationBtn)
        self.view.addSubview(cleanPathBtn)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !startAnimationBtn.isEnabled {return}
        let t = touches.first
        startNewDraw()
        guard let point = t?.location(in: self.view) else { return }
        currentPath?.move(to: point)
        appendPath(touch: t)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !startAnimationBtn.isEnabled {return}
        appendPath(touch: touches.first)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !startAnimationBtn.isEnabled {return}
        endOnePath()
    }
    
    //开始绘制准备
    func startNewDraw() {
        currentDrawLayer = createNewLayer()
        currentArray = Array()
        currentPath = UIBezierPath.init()
    }
    
    //拼接画笔路径
    func appendPath(touch : UITouch?) {
        guard let point = touch?.location(in: self.view) else {
            return
        }
        guard let timestamp = touch?.timestamp else { return }
        currentPath?.addLine(to: point)
        currentDrawLayer?.path = currentPath?.cgPath
        let touchSut = TouchPointStruct.init(timeStamp: timestamp, point: point)
        guard let count = currentArray?.count else {
            return
        }
        if count > 0 {
            let lastTouchSut = currentArray?[count-1]
            if touchSut.point == lastTouchSut?.point {
                //去除前一个，减少内存压力
                currentArray?.remove(at: count-1)
            }
        }
        currentArray?.append(touchSut)
    }
    
    func endOnePath() {
        if let array = currentArray {
            pathArray.append(array)
        }
    }
    
    //获得一个CAShaperLayer对象
    func createNewLayer() -> CAShapeLayer {
        let layer = CAShapeLayer.init()
        layer.borderWidth = 0
        layer.strokeColor = UIColor.red.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 2
        self.view.layer.addSublayer(layer)
        return layer
    }
    
    func cleanAllDraw() {
        guard let layerArray = self.view.layer.sublayers else {
            return
        }
        
        for layer in layerArray {
            if layer.delegate != nil {continue}
            layer.removeFromSuperlayer()
        }
    }
    
    //回放动画
    func startNextAnimation() {
        //取出一组
        if currentAnimationIndex >= pathArray.count {
            //标志结束位
            print("所有的动画都结束了")
            startAnimationBtn.setTitle("回放", for: UIControl.State.normal)
            currentAnimationView = nil
            return
        }
        
        let animation = CAKeyframeAnimation.init(keyPath: "position")
        let count = pathArray[currentAnimationIndex].count
        let array = pathArray[currentAnimationIndex]
        guard let startTime = array.first?.timeStamp else {return}
        
        var timeArray = Array<NSNumber>()
        var pointArray = Array<CGPoint>()
        let duration = array.last!.timeStamp - startTime
        
        for i in 0...count-1 {
            let point = array[i].point
            let time = array[i].timeStamp - startTime
            //组装为一个关键帧数据
            timeArray.append(NSNumber.init(value: time / duration))
            pointArray.append(point)
        }
        animation.keyTimes = timeArray
        animation.values = pointArray
        animation.beginTime = CACurrentMediaTime()
        animation.duration = duration
        animation.fillMode = CAMediaTimingFillMode.forwards
        let view = UIView.init(frame: CGRect.init(origin: pointArray.first!, size: CGSize.init(width: 2, height: 2)))
        view.backgroundColor = UIColor.red
        view.layer.add(animation, forKey: "test")
        self.view.addSubview(view)
        currentAnimationView = view
        currentDrawLayer = createNewLayer()
        currentPath = UIBezierPath.init()
        currentPath?.move(to: pointArray[0])
        self.view.layer.addSublayer(currentDrawLayer!)
        let link = CADisplayLink.init(target: self, selector: #selector(startDrawRecording(link:)))
        link.add(to: RunLoop.current, forMode: RunLoop.Mode.common)
    }
    
    func endCurrentAnimation() {
        //这里可以获取path之间的获取时间差值，暂时未处理
        currentAnimationIndex += 1
        startNextAnimation()
    }
    
    func endAllAnimation() {
        //清空所有数组
        pathArray.removeAll()
        currentAnimationIndex = 0
        currentArray?.removeAll()
        currentAnimationView = nil
    }
    
    @objc func handleAnimationRecordingBtn(btn : UIButton) {
        if currentAnimationView != nil {
            animationAction()
        } else {
            cleanAllDraw()
            currentAnimationIndex = 0
            startNextAnimation()
        }
    }
    
    @objc func startDrawRecording(link:CADisplayLink) {
        guard let point = currentAnimationView?.layer.presentation()?.position else {
            return
        }
        if currentAnimationView?.layer.animation(forKey: "test") == nil {
            currentAnimationView?.removeFromSuperview()
            link.invalidate()
            link.remove(from: RunLoop.current, forMode: RunLoop.Mode.common)
            endCurrentAnimation()
            return
        }
        currentPath?.addLine(to: point)
        currentDrawLayer?.path = currentPath?.cgPath
    }
    
    //清除画板时触发
    @objc func handleCleanPathBtn() {
        endAllAnimation()
        cleanAllDraw()
    }
    
    //暂停动画
    func animationAction() {
        if currentAnimationView != nil {
            if currentAnimationView?.layer.speed == 0.0 {
                //启动动画
                continueAnimation()
            } else {
                //暂停动画
                pauseAnimation()
            }
        }
    }
    
    //暂停动画
    func pauseAnimation() {
        print("暂停动画")
        let frame = (currentAnimationView?.layer.presentation()?.frame)!
        let pauseT = currentAnimationView?.layer .convertTime(CACurrentMediaTime(), from: nil)
        currentAnimationView?.layer.speed = 0.0
        currentAnimationView?.layer.timeOffset = pauseT!
        currentAnimationView?.frame = frame
        startAnimationBtn.setTitle("播放", for: UIControl.State.normal)
    }
    
    //继续执行动画
    func continueAnimation() {
        print("继续动画")
        let pauseT = currentAnimationView?.layer.timeOffset
        currentAnimationView?.layer.speed = 1
        currentAnimationView?.layer.timeOffset = 0.0
        currentAnimationView?.layer.beginTime = 0.0
        let startT = (currentAnimationView?.layer.convertTime(CACurrentMediaTime(), from: nil))! - pauseT!
        currentAnimationView?.layer.beginTime = startT
        startAnimationBtn.setTitle("暂停", for: UIControl.State.normal)
    }
}


