#ifndef UART_HPP
#define UART_HPP


#pragma once
#include "stdint.h"
#include "Serial.hpp"
#include "string"

#define M_UART_FRAME_SIZE 21 // 通信帧大小
#define M_UART_DATA_SIZE  18 // 通信数据大小

struct ReadFrameData{
    bool isValid;
    uint8_t *pRxData;
};

class Uart:public Serial
{
public:
    Uart();
    ~Uart();
    
    // 获得串口名
    uint8_t * getUartNames();
    
    // 打开通信端口
    int open(char *dev);
    // 关闭通信端口
    void close();

    // 发送
    long transmit(uint8_t *pData,uint8_t size);
    // 接收
    ReadFrameData receive();
    
    
private:
    
    // 接收Uart一个字节拼合成桢
    int receiveToFrame(ReadByteData aRxBuffer);
    // 发送一个帧的数据
    long frameTransmit(uint8_t *pData,uint8_t size);
    
    // Uart通信接收缓冲区
    uint8_t rxBuffer[M_UART_FRAME_SIZE];
    // 接收缓冲区使用量
    uint8_t rxBufferCount;
    uint8_t rxData[M_UART_DATA_SIZE];
    // 完成一个帧的接收
    void completeFrame(uint8_t *pRxBuffer);
};

#endif
