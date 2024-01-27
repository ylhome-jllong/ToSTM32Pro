#ifndef SERIAL_HPP
#define SERIAL_HPP

#pragma once
#include "stdint.h"
#include <dirent.h>
#include <stdlib.h>
#include <string>


// 读取一个字节返回类型
struct ReadByteData{
    bool isValid;
    uint8_t data;
};

class Serial
{
public:
    Serial();
    ~Serial();
    // 打开串口通信
    int serialOpen(const char *pFile,int speed,int  databit = 8,const char *stopbit = "1", char parity = 'n',int vtime = 0xFFFF,int vmin = 1);
    // 关闭串口通信
    void serialClose();
    // 读取一个字节
    ReadByteData serialRead(void);
    // 写数据到串口
    long serialWrite(uint8_t *buf,int nbyte);
    // 获得串口名
    uint8_t *getSerialNames();

private:
    // 设置波特率
    void set_baudrate (struct termios *opt, unsigned int baudrate);
    // 设置数据长度
    void set_data_bit (struct termios *opt, unsigned int databit);
    // 设置校验位
    void set_parity (struct termios *opt, char parity);
    // 设置停止位
    void set_stopbit (struct termios *opt, const char *stopbit);
    //串口设置
    int set_port_attr(int fd,int  baudrate, int  databit,const char *stopbit, char parity,int vtime,int vmin); 
    
    // 串口描述符
    int fd;

};

#endif
