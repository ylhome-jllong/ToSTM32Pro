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
    var MagneticSensorInformation = "磁传感器信息"
    
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
        // 磁传感器数据更新回调
        onMagneticSensorUpDate {
            if(self.magneticSensorParameter.isInCalibration == false){
                if(self.magneticSensorParameter.isPrecise){
                    self.MagneticSensorInformation = String(format: "x:%0.2f y:%0.2f z:%0.2f 磁偏角: %0.2f",self.magneticSensorParameter.x,self.magneticSensorParameter.y,self.magneticSensorParameter.z,self.magneticSensorParameter.angle)
                }
                else{
                    self.MagneticSensorInformation = "请校准传感器"
                }
            }
            else{
                self.MagneticSensorInformation = "传感器校准中……"
            }
            self.updateUI()
        }
        
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
