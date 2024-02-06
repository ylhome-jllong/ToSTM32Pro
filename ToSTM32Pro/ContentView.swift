//
//  ContentView.swift
//  ToSTM32Pro
//
//  Created by 江龙 on 2024/1/21.
//

import SwiftUI
struct ContentView: View {
    
    @ObservedObject var coreControl = CoreControl()


    var body: some View {
        HStack{
            // 左侧控制面板
            Left(coreControl: self.coreControl)
            // 右侧工作日志
            TextEditor(text:.constant(coreControl.logs))
            .padding()
        }
    }
}


// 左侧控制面板模块
struct Left:View{
    @ObservedObject var coreControl:CoreControl
    
    var body: some View {
        VStack {
            ConnectControl(coreControl: coreControl)
            HStack{
                Text("MCU 系统时间:\(coreControl.mcuSystemTime)")
                Text("MCU 时钟时间:\(coreControl.mcuClockTimeString)")
            }
            MCUControl(coreControl: coreControl)
        }
        .padding()
        
    }
    
}

// 连接控制模块
struct ConnectControl:View {
    @ObservedObject var coreControl:CoreControl
    @State var selected = 0
    @State var devs:[String]
    init(coreControl: CoreControl, selected: Int = 0, devs: [String] = [String]()) {
        self.coreControl = coreControl
        self.selected = selected
        self.devs = coreControl.getUartDev()
    }
    var body: some View {
        Image(systemName: "globe")
            .imageScale(.large)
            .foregroundStyle(.tint)
        HStack{
            Picker("请选择端口", selection: $selected){
                
                ForEach(0 ..< devs.count,id:\.self  ){ index in
                    Text(devs[index]).tag(index)
                }
            }
            Button("刷新") {
                devs.removeAll()
                devs.append(contentsOf: self.coreControl.getUartDev())
            }
        }.disabled(coreControl.isOpenDev)
        HStack{
            Button("连接"){
                if(coreControl.open(dev: devs[selected])){
                    coreControl.listen()
                }
            }.disabled(coreControl.isOpenDev || devs.count == 0)
            Button("断开"){
                coreControl.close()
            }.disabled(!coreControl.isOpenDev)
        }
    }
}
// MCU 控制模块
struct MCUControl:View {
    @ObservedObject var coreControl:CoreControl
    var body: some View {
        VStack(alignment: .leading){
            SteeringControl(coreControl: coreControl)
            MagneticSensorControl(coreControl: coreControl)
        }.disabled(!coreControl.isOpenDev)
    }
}

// 舵机控制模块
struct SteeringControl:View {
    @ObservedObject var coreControl:CoreControl
    let numberFormatter = NumberFormatter()
    @State var isContinuous = false
    init(coreControl: CoreControl) {
        self.coreControl = coreControl
        self.numberFormatter.numberStyle = .none
        self.numberFormatter.maximum = 180
        self.numberFormatter.minimum = 0
    }
    
    var body: some View {
        HStack{
            Text("舵机控制：")
            TextField("输入角度", value: $coreControl.steeringAngle, formatter:numberFormatter) { _ in
                coreControl.steeringAngleSet()
                coreControl.objectWillChange.send()
            }
            
            Slider(value: Binding(get:{coreControl.steeringAngle}, set: { newValue in
                // 拖动变化时刷新界面，如果要求电机同步变化就发指令
                coreControl.steeringAngle = newValue
                coreControl.objectWillChange.send()
                if(isContinuous){
                    coreControl.steeringAngleSet()
                }
                
            }),in: 0...180) { _ in
                // 不需要同步变化时，松开按键发指令
                if !isContinuous{
                    coreControl.steeringAngleSet()
                }
                    
            }
            
            Toggle(isOn: $isContinuous) {
                Text("连续变化")
            }
        }
    }
    
}
// 磁传感器控制
struct MagneticSensorControl:View {
    @ObservedObject var coreControl:CoreControl
    var body: some View {
        HStack{
            Toggle(isOn: Binding(get: {
                coreControl.magneticSensorParameter.isEnable
            }, set: { _ in
                coreControl.magneticSensorOnOff(isOn:!coreControl.magneticSensorParameter.isEnable)
            })) {
                Text("开启")
            }
            VStack(alignment: .leading){
                HStack(){
                    Text("磁传感器:")
                    Text(coreControl.magneticSensorInformation).frame(width: 250, alignment: .center)
                    
                }
                HStack(){
                    Text("罗盘:")
                    Text(coreControl.compassInformation).frame(width: 250, alignment: .center)
                    Button("校准") {
                        coreControl.magneticCalibration()
                    }.disabled(coreControl.magneticSensorParameter.isInCalibration)
                }.disabled(!coreControl.magneticSensorParameter.isEnable)
            }
        }
    }
}


#Preview {
    ContentView()
}
