#import <Foundation/Foundation.h>

@interface PhysMemBridge : NSObject

- (BOOL)connect;
- (uint8_t)readAt:(unsigned long long)addr;
- (void)writeAt:(unsigned long long)addr value:(unsigned char)val;
@end
