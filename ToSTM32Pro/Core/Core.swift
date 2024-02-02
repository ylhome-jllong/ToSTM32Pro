//
//  Core.swift
//  ToSTM32
//
//  Created by 江龙 on 2024/1/17.
//

import Foundation
import SwiftUI

class Core{

    private var updateLogsCallback:(()->())?
    private var mcuPulseCallback:(()->())?
    private var steeringAngleCallback:(()->())?
    private var magneticSensorUpdate:(()->())?
    
    private var timer:Timer!
    // 串口类
    private var uart = Uart()
    // 返回的字符串
    private(set) var logs = ""
    // 标志串口是否打开
    private(set) var isOpenDev = false
    // 标志工作模式
    private var isUI = false
    // MCU系统时间
    private(set) var mcuSystemTime:UInt64 = 0
    // MCU时钟时间
    private(set) var mcuClockTime:UInt64 = 0
    
    // 舵机数据
    private(set) var steeringParameter = SteeringParameter(angle: 0)
    // 磁场传感器数据
    private(set) var magneticSensorParameter = MagneticSensorParameter()
    
    
    // 标志在线与否
    private var isOnLine = 1
    // 选择连接的dev
    private var devName = ""
    
    init(isUI:Bool = false){
        self.isUI = isUI
    }
    
    //=================================================
    // 功能：获取端口地址
    // 返回：串口地址
    //=================================================
    func getUartDev()->[String]{
        let str = String(cString:uart.getUartNames())
        var retStr = [String]()
        let subStr = str.split(separator: "\n")
        for sequence in subStr {
            retStr.append("\(sequence)")
        }
        return retStr
    }
    
    //=================================================
    // 功能：开启串口
    // 参数：dev = 串口地址
    //=================================================
    func open(dev:String)->Bool{
        devName = dev
        if (uart.open(toChar(str: dev)) == 0){
            isOpenDev = true
            return true
        }
        else{
            isOpenDev = false
            return false
        }
    }
    //=================================================
    // 功能：断开串口
    //=================================================
    func close(){
        timer.invalidate()
        uart.close()
        isOpenDev = false
        recordLogs("串口关闭")
    }
    //=================================================
    // 功能：监听单片机消息
    // 说明：异步监听单片机的消息，并处理
    // 将收获的消息加时间戳存于logs
    //=================================================
    func runListen(){
        if isOpenDev {
            Task{await listen()}
            recordLogs("开始监听单片机信号：")
            // 单片机脉搏监控
            mcuPulseControl()
            // 单片机初始化
            mcuInit()
        }
        else{
            recordLogs("串口未正确开启")
        }
    }
    //=================================================
    // 功能：监听单片机消息
    // 说明：异步监听单片机的消息，并处理
    // 将收获的消息加时间戳存于logs
    //=================================================
    private func listen() async {
        while(self.isOpenDev){
            let readFrameData = self.uart.receive()// 读取数据
            if(readFrameData.isValid){// 数据有效
                var pdata = [UInt8]()
                for j in 0 ..< M_UART_DATA_SIZE {
                    pdata.append(readFrameData.pRxData[Int(j)])
                }
                self.telematics(data:pdata)
            }
        }
    }
    
    // 单片机初始化
    private func mcuInit(){
        //询问值
        steeringAngleGet()
    }
    
    //=====================================
    // 功能：发送消息到单片机
    // 参数：com = 命令 data = 命令附件信息
    //=====================================
    func send(com:UInt8,data:[UInt8]){
        let pData = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(M_UART_DATA_SIZE))
        pData[0] = com
        for i in 0 ..< data.count {
            pData[i+1] = data[i]
        }
        uart.transmit(pData, UInt8(M_UART_DATA_SIZE))
    }
    
    // 远程信息处理
    private func telematics(data:[UInt8]){
        switch(Int32(data[0])){
        // case M_REMOTE_COM_PRINT:remotePrint(data: data)
        case M_REMOTE_COM_INFO:remoteInfo(data: data)
        case M_REMOTE_COM_ASK_TIME:remoteAskTime(data:data)
        case M_REMOTE_COM_PULSE:remotePulse(data:data)
        case M_REMOTE_COM_ENGINE:remoteEngine(data:data)
        case M_REMOTE_COM_SENSOR:remoteSensor(data:data)
        default:
            recordLogs("接收到未知命令！")
        }
    }
    // 远程预置信息处理
    private func remoteInfo(data:[UInt8]){
        let tempData:UInt16 = UInt16(data[2])<<8 + UInt16(data[1])
        var str:String
        switch(tempData){
        case 0x0001:str = "系统初始化完成。"
        case 0x0002:str = "进程初始化完成。"
        case 0x0003:str = "单片机待命中……"
        case 0x0004:str = "测试回复"
        case 0x0100:str = "0号空闲进程初始化完成"
        case 0x0101:str = "1号主进程初始化完成"
        case 0x0102:str = "2号按键扫描进程初始化完成"
        case 0x0103:str = "3号时钟进程初始化完成"
        case 0x0104:str = "4号引擎进程初始化完成"
        case 0x0105:str = "5号传感器进程初始化完成"
        default:
            str = "未知预置消息"
        }
        recordLogs(str)
        
    }
    // 远程Print处理
    private func remotePrint(data:[UInt8]){
        let tempData:[UInt8] = Array(data[1 ..< Int(M_UART_DATA_SIZE)])
        recordLogs(String(cString:tempData))
    }
    // 远程询时处理
    private func remoteAskTime(data:[UInt8]! = nil){
        var outData = [UInt8]()
        var tData:UInt64 = getSystemTime()
        for _ in 0 ..< 8{
            outData.append(UInt8(tData & 0xFF ))
            tData >>= 8;
        }
        send(com: UInt8(M_REMOTE_COM_SET_CLOCK), data:outData)
    }
    // 远程脉搏
    private func remotePulse(data:[UInt8]){
        if(isOnLine < -2){
            recordLogs("重新捕获单片机")
        }
        isOnLine = 1
        // 获得MCU的系统时间
        let r1 = 1 ... 8
        for i in r1.reversed(){
            mcuSystemTime <<= 8
            mcuSystemTime += UInt64(data[i])
        }
        
        // 单片机新启动
        if(mcuSystemTime < 2000){
            // 单片机初始化
            mcuInit()
        }
        
        
        // 获得MCU的时钟时间
        let r2 = 9 ... 16
        for i in r2.reversed(){
            mcuClockTime <<= 8
            mcuClockTime += UInt64(data[i])
        }
        
        // 信息回调
        if let mcuPulseCallback = self.mcuPulseCallback {
            mcuPulseCallback()
        }
        if(abs(Double(getSystemTime()) - Double(mcuClockTime)) > 5){
            remoteAskTime()
        }
    }
    // 远程引擎
    private func remoteEngine(data:[UInt8]){
        switch(data[1]){
        case UInt8(M_REMOTE_COM_ENGINE_STEERING_ANGLE):// 舵机角度
            steeringParameter.angle = data[2]
            // 信息回调
            if let steeringAngleCallback = self.steeringAngleCallback {
                steeringAngleCallback()
            }
        default:
            recordLogs("引擎：未知信息")
        }
    }
    // 远程传感器
    private func remoteSensor(data:[UInt8]){
        switch(data[1]){
        case UInt8(M_REMOTE_COM_SENSOR_MAGNETIC_UPDATE):
            let fx:[UInt8] = [data[2],data[3],data[4],data[5]]
            memcpy(&magneticSensorParameter.rawX,fx, 4)
            let fy:[UInt8] = [data[6],data[7],data[8],data[9]]
            memcpy(&magneticSensorParameter.rawY, fy, 4)
            let fz:[UInt8] = [data[10],data[11],data[12],data[13]]
            memcpy(&magneticSensorParameter.rawZ, fz, 4)
            var uAHigh = data[17]
            if((uAHigh & 0x80) != 0){
                magneticSensorParameter.isPrecise = false
                uAHigh &= 0x7F
            }
            
            let fa:[UInt8] = [data[14],data[15],data[16],uAHigh]
            memcpy(&magneticSensorParameter.compassAngle,fa, 4)
            
            // 信息回调
            if let magneticSensorUpdate = self.magneticSensorUpdate {
                magneticSensorUpdate()
            }
            
        case UInt8(M_REMOTE_COM_SENSOT_MAGNETIC_CALIBRATION_COMPLETE):
            magneticSensorParameter.isPrecise = true  // 数据有效
            magneticSensorParameter.isInCalibration = false // 不在校准中
        default:
            recordLogs("传感器：未知信息")
        }
        
    }
    
    ///------------------------------------------------------------------------------------------------
    // 将String转为char字符串指针
    private func toChar(str:String)->UnsafeMutablePointer<UInt8>{
        let pChar = UnsafeMutablePointer<UInt8>.allocate(capacity: str.count)
        let data = str.data(using: .utf8)!
        for i in 0..<str.count{
            pChar[i] = data[i]
        }
        return pChar
    }
    // 获取系统时间毫秒
    private func getSystemTime()->UInt64{
        return UInt64(Date().timeIntervalSince1970)  + 8 * 3600
    }
    
    // 获取当前时间毫秒
    private func getTimeNow()->String{
        let now = Date()
        let dformatter = DateFormatter()
        dformatter.dateFormat = "HH:mm:ss.SSS"
        return "[" + dformatter.string(from: now) + "]"
    }
    
    // 记录日志
    func recordLogs(_ log:String){
        // 加入时间戳
        let timePlusLog = getTimeNow() + log
        // 刷新UI
        if (isUI){
            logs = timePlusLog + "\n" + logs
            // 刷新UI
            if let updateLogsCallback = self.updateLogsCallback {
                updateLogsCallback()
            }
        }
        else{
            print(timePlusLog)
        }
    }
    // 单片机脉搏
    func mcuPulseControl(){
        // 脉搏测试 (逻辑还是有问题)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true){timer in
            self.isOnLine -= 1;
            if(self.isOnLine < -5){
                timer.invalidate()
                self.isOnLine = 1
                self.recordLogs("单片机掉线,重新连接")
                self.uart.close()
                _ = self.open(dev: self.devName)
                self.runListen()
            }
        }
        // 非UI界面
        if(isUI == false ){
            RunLoop.current.add(timer, forMode: .default)
            RunLoop.current.run();
        }
    }
    
    // 舵机角度设置
    func steeringAngleSet(angle:UInt8){
        steeringParameter.angle = angle
        var outData = [UInt8]()
        outData.append(UInt8(M_REMOTE_COM_ENGINE_STEERING_ANGLE_SET))
        outData.append(angle)
        send(com: UInt8(M_REMOTE_COM_ENGINE), data:outData)
    }
    // 舵机角度获取
    func steeringAngleGet(){
        var outData = [UInt8]()
        outData.append(UInt8(M_REMOTE_COM_ENGINE_STEERING_ANGLE_GET))
        send(com: UInt8(M_REMOTE_COM_ENGINE), data:outData)
    }
    
    // 磁传感器校准
    func magneticCalibration(){
        magneticSensorParameter.isInCalibration = true
        var outData = [UInt8]()
        outData.append(UInt8(M_REMOTE_COM_SENSOT_MAGNETIC_CALIBRATION))
        send(com: UInt8(M_REMOTE_COM_SENSOR), data:outData)
    }
    
    // 磁传感器开关
    func magneticSensorOnOff(isEnable:Bool){
        magneticSensorParameter.isEnable = isEnable
        var outData = [UInt8]()
        if(isEnable){ // 开机
            outData.append(UInt8(M_REMOTE_COM_SENSOT_MAGNETIC_ON))
        }
        else{// 关机
            outData.append(UInt8(M_REMOTE_COM_SENSOT_MAGNETIC_OFF))
        }
        send(com:UInt8(M_REMOTE_COM_SENSOR), data:outData)
        
    }
        
    
    
    
    
    // 更新UI回调
    func onUpdateLogsCallback(block:@escaping ()->()){
        self.updateLogsCallback = block
    }
    // MCU脉搏回调
    func onMCUPulseCallback(block:@escaping()->()){
        self.mcuPulseCallback = block
    }
    // 舵机角度获取回调
    func onSteeringAngleCallback(block:@escaping()->()){
        self.steeringAngleCallback = block
    }
    // 磁传感器数据更新回调
    func onMagneticSensorUpdate(block:@escaping()->()){
        self.magneticSensorUpdate = block
    }
    
}



// 步机电机相关参数
struct SteeringParameter{
    var angle:UInt8
}
// 磁传感器相关参数
struct MagneticSensorParameter{
    var compassAngle:Float32 = 0
    var rawX:Float32 = 0
    var rawY:Float32 = 0
    var rawZ:Float32 = 0
    var isPrecise:Bool = false // 数据是否有效
    var isInCalibration:Bool = false // 校准中
    var isEnable = false // 是否开启
}
