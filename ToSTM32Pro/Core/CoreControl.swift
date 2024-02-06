//
//  CoreControl.swift
//  ToSTM32Pro
//
//  Created by 江龙 on 2024/1/26.
//

import Foundation

class CoreControl: Core,ObservableObject {
    
    // 舵机角度
    var steeringAngle = 0.0
    // mcu时钟时间
    var mcuClockTimeString = "--:--:--"
    // 磁传感器信息
    var magneticSensorInformation = "磁传感器信息"
    // 罗盘信息
    var compassInformation = "罗盘信息"
    
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
        // 罗盘数据更新回调
        onMagneticSensorUpdate {
            if(self.magneticSensorParameter.isEnable){
                self.magneticSensorInformation = String(format: "x:%0.2f y:%0.2f z:%0.2f",self.magneticSensorParameter.rawX,self.magneticSensorParameter.rawY,self.magneticSensorParameter.rawZ)
                if(self.magneticSensorParameter.isInCalibration == false){
                    if(self.magneticSensorParameter.isPrecise){
                        self.compassInformation = String(format: "罗盘角: %0.0f",self.magneticSensorParameter.compassAngle)
                    }
                    else{
                        self.compassInformation = "请校准传感器"
                    }
                }
                else{
                    self.compassInformation = "传感器校准中……"
                }
            }
            self.updateUI()
        }
        // 磁感器开机回调
        onMageneticSensorOn {
            self.updateUI()
        }
        // 磁传感器关键回调
        onMageneticSensorOff {
            self.magneticSensorInformation = "磁传感器信息"
            self.compassInformation = "罗盘信息"
            self.updateUI()
        }
        
        // 开始监听
        runListen()
    }
    // 步机电机控制
    func steeringAngleSet() {
        steeringAngleSet(angle: UInt8(steeringAngle))
    }
    
    // UI更新方法
    func updateUI(){
        DispatchQueue.main.async{
           self.objectWillChange.send()
        }
    }
}
