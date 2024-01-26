//
//  CoreControl.swift
//  ToSTM32Pro
//
//  Created by 江龙 on 2024/1/26.
//

import Foundation

class CoreControl: Core,ObservableObject {
    init(){
        super.init(isUI: true)
    }
    
    // 监听MCU
    func listen(){
        super.runListen(bocak: updateUI)
    }
    // 步机电机控制
    func steeringAngleSet(angle:String) {
        
        if let angleInt = Int(angle) {
            if angleInt >= 0 && angleInt <= 180 {
                super.steeringAngleSet(angle: UInt8(angleInt))
            }
            else{
                super.recordLogs("请输入0-180之间的数字")
            }
        }
        else{
            super.recordLogs("请输入有效数字")
        }
        
    }
    
    // UI更新方法
    private func updateUI(){
        DispatchQueue.main.async{
           self.objectWillChange.send()
        }
    }
}
