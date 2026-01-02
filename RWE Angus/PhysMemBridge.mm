#import "PhysMemBridge.h"
#include "DriverEngine.hpp"

@implementation PhysMemBridge {
    DriverEngine *engine;
}

- (instancetype)init {
    self = [super init];
    if (self) { engine = new DriverEngine(); }
    return self;
}

- (BOOL)connect {
    return engine->openConnection();
}

- (uint8_t)readAt:(unsigned long long)addr {
    return engine->readByte(addr);
}
- (void)writeAt:(unsigned long long)addr value:(unsigned char)val {
    if (engine) {
        engine->writeByte(addr, val);
    }
}
@end
