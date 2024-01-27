//
//  CoreControl.swift
//  ToSTM32Pro
//
//  Created by 江龙 on 2024/1/26.
//

import Foundation

class CoreControl: Core,ObservableObject {
    
    var steeringAngle = 0.0
    var mcuClockTimeString = "--:--:--"
    
    init(){
        super.init(isUI: true)
    }
    
    // 监听MCU
    func listen(){
        // 设置回调
        // 日志更新回调
        onUpdateLogsCallback {
            self.updateUI()
        }
        // MCU脉搏回调
        onMCUPulseCallback {
            let s = self.mcuClockTime % 60
            let m = (self.mcuClockTime / 60) % 60
            let h = (self.mcuClockTime / 3600) % 24
            self.mcuClockTimeString = "\(String(format: "%02d", h)):\(String(format: "%02d", m)):\(String(format: "%02d", s))"
            self.updateUI()
        }
        // 舵机角度回调
        onSteeringAngleCallback {
            self.steeringAngle = Double(self.steeringParameter.angle)
            self.updateUI()
        }
        runListen()
    }
    // 步机电机控制
    func steeringAngleSet() {
        steeringAngleSet(angle: UInt8(steeringAngle))
    }
    
    // UI更新方法
    private func updateUI(){
        DispatchQueue.main.async{
           self.objectWillChange.send()
        }
    }
}
