#include "Uart.hpp"



Uart::Uart()
{
}

Uart::~Uart()
{
}

//==========================================
// 功能：获得串口名称
// 返回：获得串口名字符串
//==========================================
uint8_t *Uart::getUartNames(){
    return getSerialNames();
}


//==========================================
// 功能：打开通信端口
// 参数：dev = 端口地址
// 返回：-1 打开失败 0 成功打开
//==========================================
int Uart::open(char *dev){
    rxBufferCount = 0;
    return serialOpen(dev, 115200);
}

//==========================================
// 功能：关闭通信端口
//==========================================
void Uart::close(){
    serialClose();
}

//==========================================
// 功能：发送数据
// 参数：pData = 要发送的数据 size = 发送数据长度
// 返回：发送的长度 <0 失败
//==========================================
long Uart::transmit(uint8_t *pData,uint8_t size){
    return frameTransmit(pData, size);
}

//==========================================
// 功能：接收数据
// 返回：接收到的数据 （目前长度固定 M_UART_DATA_SIZE  18个字节）
//==========================================
ReadFrameData Uart::receive(){
    int signal;
    ReadFrameData readFrameData;
    while (true) {
        signal =receiveToFrame(serialRead());
        if(signal == 0){}//继续
        else if(signal == 1){// 1帧数据接收完成
            readFrameData.isValid = true;
            readFrameData.pRxData = rxData;
            return readFrameData;
        }
        else if(signal == -1){// 无效数据
            readFrameData.isValid = false;
            return readFrameData;
        }
    }
}
//==========================================
// 功能：接收Uart一个字节拼合成桢
// 参数：aRxBuffer = 接收的一个字节 
// 返回：1.完成一帧数据接收 0.数据接收中 -1.底层端口已关闭
//==========================================
int Uart::receiveToFrame(ReadByteData aRxBuffer){
    if(!aRxBuffer.isValid){// 单字节数据无效，底层端口已关闭
        return -1;
    }
    rxBuffer[rxBufferCount] = aRxBuffer.data;
    rxBufferCount++;
    
    // 缓冲区已满
    if(rxBufferCount == M_UART_FRAME_SIZE){
        for(int i=0;i<M_UART_FRAME_SIZE; i++){
            if(rxBuffer[i]== 0xFE){
                if(i==0){//帧头在缓冲区头
                    if(rxBuffer[M_UART_FRAME_SIZE-1]==0xEF){//帧尾位置正常
                        completeFrame(rxBuffer);
                        rxBufferCount=0;
                        return 1;
                    }
                }
                else{ // 帧头位置不对
                    int z=0;
                    for(int j=i;j<M_UART_FRAME_SIZE;j++){
                        rxBuffer[z++] = rxBuffer[j];
                    }
                        
                    rxBufferCount=z;
                    break; // 继续接收
                }
            } 
 
        }
    }
    return 0;
}
//==========================================
// 功能：发送一个帧的数据
// 参数：pData= 发送数据 size= 数据大小
//==========================================
long Uart::frameTransmit(uint8_t *pData,uint8_t size){
    
    uint8_t txBuffer[M_UART_FRAME_SIZE]={0};

    txBuffer[0] = 0xFE;
    txBuffer[1] = 0x00;

    for(int i=0;i<size;i++){
        txBuffer[i+2]=pData[i];
    }

    txBuffer[M_UART_FRAME_SIZE-1] = 0xEF;
    
    
    return serialWrite(txBuffer, M_UART_FRAME_SIZE);

}
// 完成一个帧的接收
void Uart::completeFrame(uint8_t *pRxBuffer){
    // 脱帧壳
    uint8_t *pCom = &pRxBuffer[1];
    uint8_t *pData = &pRxBuffer[2];

    // 单帧数据
    if(*pCom==0x00){
        // 拷贝数据
        for(int i=0;i<M_UART_DATA_SIZE;i++)
            rxData[i]=pData[i];
    }
}
