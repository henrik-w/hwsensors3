//
//  NSSensor.m
//  HWSensors
//
//  Created by mozo on 22.10.11.
//  Copyright (c) 2011 mozo. All rights reserved.
//

#import "HWMonitorSensor.h"

#include "../utils/definitions.h"
#include "smc.h"

//#define SMC_ACCESS
#define BIT(x) (1 << (x))
#define bit_get(x, y) ((x) & (y))
#define bit_clear(x, y) ((x) &= (~y))


@interface HWMonitorSensor ()

+ (unsigned int)swapBytes:(unsigned int)value;
+ (int)getIndexOfHexChar:(char)c;
- (float)decodeNumericValue:(NSData *)data;

@end


@implementation HWMonitorSensor

+ (unsigned int)swapBytes:(unsigned int)value
{
    return ((value & 0xff00) >> 8) | ((value & 0xff) << 8);
}


+ (int)getIndexOfHexChar:(char)c
{
    return c > 96 && c < 103 ? c - 87 : c > 47 && c < 58 ? c - 48 : 0;
}


- (float)decodeNumericValue:(NSData *)data
{
    if (_type && data && [_type length] >= 3) {
        if (([_type characterAtIndex:0] == 'u' ||
             [_type characterAtIndex:0] == 's')
            && [_type characterAtIndex:1] == 'i') {
            BOOL signd = [_type characterAtIndex:0] == 's';

            switch ([_type characterAtIndex:2]) {
                case '8':
                    if ([data length] == 1) {
                        UInt8 encoded = 0;

                        bcopy([data bytes], &encoded, 1);

                        if (signd && bit_get(encoded, BIT(7))) {
                            bit_clear(encoded, BIT(7));
                            return -encoded;
                        }

                        return encoded;
                    }
                    break;

                case '1':
                    if ([_type characterAtIndex:3] == '6' && [data length] == 2) {
                        UInt16 encoded = 0;

                        bcopy([data bytes], &encoded, 2);

                        encoded = OSSwapBigToHostInt16(encoded);

                        if (signd && bit_get(encoded, BIT(15))) {
                            bit_clear(encoded, BIT(15));
                            return -encoded;
                        }

                        return encoded;
                    }
                    break;

                case '3':
                    if ([_type characterAtIndex:3] == '2' && [data length] == 4) {
                        UInt32 encoded = 0;

                        bcopy([data bytes], &encoded, 4);

                        encoded = OSSwapBigToHostInt32(encoded);

                        if (signd && bit_get(encoded, BIT(31))) {
                            bit_clear(encoded, BIT(31));
                            return -encoded;
                        }

                        return encoded;
                    }
                    break;
            }
        }
        else if (([_type characterAtIndex:0] == 'f' ||
                  [_type characterAtIndex:0] == 's') &&
                  [_type characterAtIndex:1] == 'p' && [data length] == 2) {
            UInt16 encoded = 0;

            bcopy([data bytes], &encoded, 2);

            UInt8 i = [HWMonitorSensor getIndexOfHexChar:[_type characterAtIndex:2]];
            UInt8 f = [HWMonitorSensor getIndexOfHexChar:[_type characterAtIndex:3]];

            if ((i + f) != (([_type characterAtIndex:0] == 's') ? 15 : 16))
                return 0;

            UInt16 swapped = OSSwapBigToHostInt16(encoded);

            BOOL signd = [_type characterAtIndex:0] == 's';
            BOOL minus = !!(bit_get(swapped, BIT(15)));

            if (signd && minus) bit_clear(swapped, BIT(15));

            return ((float)swapped / (float)BIT(f)) * (signd && minus ? -1 : 1);
        }
    }

    return 0;
}


+ (NSData *)readValueForKey:(NSString *)key
{
    SMCOpen(&conn);

    UInt32Char_t readkey = "\0";
    const char *cKey = [key cStringUsingEncoding:NSASCIIStringEncoding];
    strncpy(readkey, (NULL == cKey) ? "" : cKey, 4);
    readkey[4] = 0;

    SMCVal_t val;
    kern_return_t result = SMCReadKey(readkey, &val);
    if (result == kIOReturnSuccess) {
        SMCClose(conn);
        if (val.dataSize > 0) {
            return [NSData dataWithBytes:val.bytes length:val.dataSize];
        }
    }
    return nil;
}


+ (NSString *)getTypeOfKey:(NSString *)key
{
    SMCOpen(&conn);

    UInt32Char_t  readkey = "\0";
    const char *cKey = [key cStringUsingEncoding:NSASCIIStringEncoding];
    strncpy(readkey, (NULL == cKey) ? "" : cKey, 4);
    readkey[4] = 0;

    SMCVal_t val;
    kern_return_t result = SMCReadKey(readkey, &val);
    if (result == kIOReturnSuccess) {
        SMCClose(conn);
        if (val.dataSize > 0)
            return [NSString stringWithFormat:@"%.4s", val.dataType];
    }
    return nil;
}


+ (instancetype)monitorSensorWithKey:(NSString *)aKey andType:(NSString *)aType andGroup:(NSUInteger)aGroup withCaption:(NSString *)aCaption
{
    return [[self alloc] initWithKey:aKey andType:aType andGroup:aGroup withCaption:aCaption];
}


- (HWMonitorSensor *)initWithKey:(NSString *)aKey
                         andType:(NSString *)aType
                        andGroup:(NSUInteger)aGroup
                     withCaption:(NSString *)aCaption
{
    self = [super init];
    if (nil == self) {
        return nil;
    }

    _type = aType;
    _key = aKey;
    _group = aGroup;
    _caption = aCaption;

    return self;
}


- (NSString *)formatedValue:(NSData *)value
{
    if (value == nil) {
        return @"-";
    }

    float v = [self decodeNumericValue:value];
    switch (self.group) {
        case TemperatureSensorGroup: {
            return [NSString stringWithFormat:@"%2d°", (int)v];
        }

        case HDSmartTempSensorGroup: {
            unsigned int t = 0;
            bcopy([value bytes], &t, 2);
            //t = [NSSensor swapBytes:t] >> 8;
            return [NSString stringWithFormat:@"%d°", t];
        }

        case BatterySensorsGroup: {
            NSInteger *t = (NSInteger *)[value bytes];
            return [NSString stringWithFormat:@"%ld", *t];
        }

        case HDSmartLifeSensorGroup: {
            NSInteger *l = (NSInteger *)[value bytes];
            return [NSString stringWithFormat:@"%ld%%", *l];
        }

        case VoltageSensorGroup:
            return [NSString stringWithFormat:@"%2.3fV", v];

        case TachometerSensorGroup:
            return [NSString stringWithFormat:@"%d rpm", (int)v];

        case FrequencySensorGroup: {
            unsigned int MHZ = 0;
            bcopy([value bytes], &MHZ, 2);
            MHZ = [HWMonitorSensor swapBytes:MHZ];
            return [NSString stringWithFormat:@"%d MHz", MHZ];
        }

        case MultiplierSensorGroup: {
            unsigned int mlt = 0;
            bcopy([value bytes], &mlt, 2);
            return [NSString stringWithFormat:@" x %1.1f", (float)mlt / 10.0];
        }

        default:
            return @"-";
    }
}

@end

