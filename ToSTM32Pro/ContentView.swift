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
            Text("MCU 系统时间:\(coreControl.mcuSystemTime)")
            MCUControl(coreControl: coreControl)
            
        }
        .padding()
        
    }
    
}

// 连接控制模块
struct ConnectControl:View {
    @ObservedObject var coreControl:CoreControl
    @State var selected = 0
    var devs = [String]()
    init(coreControl: CoreControl, selected: Int = 0, devs: [String] = [String]()) {
        self.coreControl = coreControl
        self.selected = selected
        self.devs = self.coreControl.getUartDev()
    }
    var body: some View {
        Image(systemName: "globe")
            .imageScale(.large)
            .foregroundStyle(.tint)
        Picker("请选择端口", selection: $selected){
           
            ForEach(0 ..< devs.count,id:\.self  ){ index in
                Text(devs[index]).tag(index)
            }
            
        }.disabled(coreControl.isOpenDev)
        HStack{
            Button("连接"){
                if(coreControl.open(dev: devs[selected])){
                    coreControl.listen()
                }
            }.disabled(coreControl.isOpenDev)
            Button("断开"){
                coreControl.close()
            }.disabled(!coreControl.isOpenDev)
        }
    }
}
// MCU 控制模块
struct MCUControl:View {
    @ObservedObject var coreControl:CoreControl
    @State var angle:String
    @State var angleNum:Double
    init(coreControl: CoreControl) {
        self.coreControl = coreControl
        self.angleNum = Double(coreControl.steeringParameter.angle)
        self.angle = String(coreControl.steeringParameter.angle)
    }
    var body: some View {
        HStack{
            TextField("输入角度", text: $angle)
            Slider(value: $angleNum,in: 0...180) { change in
                    coreControl.steeringAngleSet(angle: UInt8(UInt(angleNum)))
                    angle = String(UInt(angleNum))
            }
            Button("执行"){
                coreControl.steeringAngleSet(angle: angle)
                angleNum = Double(coreControl.steeringParameter.angle)
            }
        }.disabled(!coreControl.isOpenDev)
    }
}

#Preview {
    ContentView()
}
