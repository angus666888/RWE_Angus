#include "DriverEngine.hpp"
#include <iostream>

bool DriverEngine::openConnection() {
    if (connect != 0) return true;
    
    // 兼容 10.13+ 的端口获取
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("PhysMemRW"));
    if (!service) return false;

    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &connect);
    IOObjectRelease(service);
    
    return (kr == kIOReturnSuccess);
}
void DriverEngine::writeByte(uint64_t address, uint8_t value) {
    if (connect == 0) return;

    mmio_request_t req;
    req.phys_addr = address;
    req.data = value;
    req.size = 1;
    req.is_write = true; // 告诉驱动这是写入操作

    size_t outSize = sizeof(req);
    // 调用驱动方法（假设 Index 0 是读写通用入口）
    IOConnectCallMethod(connect, 0, NULL, 0, &req, sizeof(req), NULL, NULL, &req, &outSize);
}
uint8_t DriverEngine::readByte(uint64_t address) {
    if (connect == 0) return 0xFF;

    mmio_request_t req;
    req.phys_addr = address;
    req.size = 1;
    req.is_write = false;

    size_t outSize = sizeof(req);
    kern_return_t kr = IOConnectCallMethod(connect, 0, NULL, 0, &req, sizeof(req), NULL, NULL, &req, &outSize);

    return (kr == kIOReturnSuccess) ? (uint8_t)req.data : 0xFF;
}

void DriverEngine::closeConnection() {
    if (connect != 0) {
        IOServiceClose(connect);
        connect = 0;
    }
}
