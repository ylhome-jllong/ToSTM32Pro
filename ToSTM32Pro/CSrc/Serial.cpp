#include "Serial.hpp"
#include <stdio.h>
#include <termios.h>
#include <fcntl.h>
#include <unistd.h>



Serial::Serial()
{


}

Serial::~Serial()
{

}
// 获得串口名
uint8_t *Serial::getSerialNames(){
    static char serialNames[1024];
    DIR *pDir;
    dirent *ptr;
    if(!(pDir = opendir("/dev"))){
        return NULL;
    }
    for(int i=0;i<1024;i++)
        serialNames[i]='\0';
    while((ptr = readdir(pDir))!=0){
        if(strstr(ptr->d_name,"tty.usb")!=NULL){
            strcat(serialNames, "/dev/");
            strcat(serialNames, ptr->d_name);
            strcat(serialNames, "\n");
        }
    }
    closedir(pDir);
    return (uint8_t*)serialNames;
}


//=====================================
//功能：打开串口通信
//参数：pFile = 路径字符串 speed = 传输速度 databit = 数据位数 stopbit = 停止位长度 “1”，“1.5”，“2“
//     parity = 校验位 N(o), O(dd), E(ven) vtime = 超时时间 vmin = 最小接收位
//返回：-1:打开失败 0：正确打开
//=====================================
int Serial::serialOpen(const char *pFile,int  speed,int  databit,const char *stopbit, char parity,int vtime,int vmin){
    fd = open(pFile,O_RDWR|O_NOCTTY|O_NONBLOCK); 
    if(fd<0)return -1;

    set_port_attr(fd, speed ,8,"1", 'N',0XFFFFF,1);
    return 0;
}
//=====================================
//功能：读取一个字节
//参数：无
//返回：ReadByteData 
//     包含.data一个字节数据  .isValid 是否有效
//
//=====================================
ReadByteData Serial::serialRead(void){
    ReadByteData buf;
    long len;
    while(fd>0){
        len=read(fd,&buf.data,1);
        if (len==1)
        {
            buf.isValid = true;
            return buf;
        }   
        usleep(1000);
    }
    buf.isValid = false;
    return buf;
}
//=====================================
//功能：写数据到串口
//参数：buf = 数据串指针 nbyte = 字节数
//返回：写入的字节数
//=====================================
long Serial::serialWrite(uint8_t *buf,int nbyte){
    return write(fd, buf, nbyte);
}
//=====================================
//功能：关闭串口通信
//=====================================
void Serial::serialClose(){
    close(fd);
    fd = -1;
}


// 设置波特率
void Serial::set_baudrate (struct termios *opt, unsigned int baudrate)
{
    cfsetispeed(opt, baudrate);
    cfsetospeed(opt, baudrate);
}

// 设置数据长度
void Serial::set_data_bit (struct termios *opt, unsigned int databit)
{
    opt->c_cflag &= ~CSIZE;
    switch (databit) {
    case 8:
        opt->c_cflag |= CS8;
        break;
    case 7:
        opt->c_cflag |= CS7;
        break;
    case 6:
        opt->c_cflag |= CS6;
        break;
    case 5:
        opt->c_cflag |= CS5;
        break;
    default:
        opt->c_cflag |= CS8;
        break;
    }
}

// 设置校验位
void Serial::set_parity (struct termios *opt, char parity)
{
    switch (parity) {
    case 'N':                  /* no parity check */
        opt->c_cflag &= ~PARENB;
        break;
    case 'E':                  /* even */
        opt->c_cflag |= PARENB;
        opt->c_cflag &= ~PARODD;
        break;
    case 'O':                  /* odd */
        opt->c_cflag |= PARENB;
        opt->c_cflag |= ~PARODD;
        break;
    default:                   /* no parity check */
        opt->c_cflag &= ~PARENB;
        break;
    }
}

// 设置停止位
void Serial::set_stopbit (struct termios *opt, const char *stopbit)
{
    if (0 == strcmp (stopbit, "1")) {
        opt->c_cflag &= ~CSTOPB; /* 1 stop bit */
    }    else if (0 == strcmp (stopbit, "1")) {
        opt->c_cflag &= ~CSTOPB; /* 1.5 stop bit */
    }   else if (0 == strcmp (stopbit, "2")) {
        opt->c_cflag |= CSTOPB;  /* 2 stop bits */
    } else {
        opt->c_cflag &= ~CSTOPB; /* 1 stop bit */
    }
}
//串口设置
int Serial::set_port_attr (
              int fd,
              int  baudrate,          // B1200 B2400 B4800 B9600 .. B115200
              int  databit,           // 5, 6, 7, 8
              const char *stopbit,    //  "1", "1.5", "2"
              char parity,            // N(o), O(dd), E(ven)
              int vtime,              // 接收超时时间
              int vmin )              // 一次接收字节数
{
     struct termios opt;
     tcgetattr(fd, &opt);
     //设置波特率
     set_baudrate(&opt, baudrate);
     opt.c_cflag          |= CLOCAL | CREAD;      /* | CRTSCTS */
     //设置数据位
     set_data_bit(&opt, databit);
     //设置校验位
     set_parity(&opt, parity);
     //设置停止位
     set_stopbit(&opt, stopbit);
     //其它设置
     opt.c_oflag          = 0;
     opt.c_lflag                |= 0;
     opt.c_oflag              &= ~OPOST;
     opt.c_cc[VTIME]          = vtime;
     opt.c_cc[VMIN]              = vmin;
     tcflush (fd, TCIFLUSH);
     return (tcsetattr (fd, TCSANOW, &opt));
}

