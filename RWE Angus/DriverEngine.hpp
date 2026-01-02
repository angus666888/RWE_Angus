#ifndef DriverEngine_hpp
#define DriverEngine_hpp

#include <IOKit/IOKitLib.h>
#include "shared_types.h"

class DriverEngine {
private:
    io_connect_t connect;
public:
    DriverEngine() : connect(0) {}
    bool openConnection();
    uint8_t readByte(uint64_t address);
    void closeConnection();
    void writeByte(uint64_t address, uint8_t value);
};

#endif
