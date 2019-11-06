//
//  ISPSmartController.m
//  iStatPro
//
//  Created by Buffy on 11/06/07.
//  Copyright 2007 . All rights reserved.
//

#import "ISPSmartController.h"
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOReturn.h>
#include <IOKit/storage/ata/ATASMARTLib.h>
#include <IOKit/storage/IOStorageDeviceCharacteristics.h>
#include <CoreFoundation/CoreFoundation.h>
#include <sys/param.h>
#include <sys/time.h>
#include <mach/mach.h>
#include <mach/mach_error.h>
#include <mach/mach_init.h>

#import "NSString+TruncateToWidth.h"

/*
static inline int convertTemperature(int format, int value) {
    if (format == 0) {
        return value;
    }

    if (format == 1) {
        return (value * 2) - ((value * 2) * 1 / 10) + 32;
    }

    if (format == 2) {
        return value + 273.15;
    }

    return value;
}
*/
void SwapASCIIString(UInt16 *buffer, UInt16 length);


@implementation ISPSmartController

#if defined(__BIG_ENDIAN__)
#define    SwapASCIIHostToBig(x,y)
#elif defined(__LITTLE_ENDIAN__)
#define    SwapASCIIHostToBig(x,y)        SwapASCIIString( ( UInt16 * ) x,y)
#else
#error Unknown endianness.
#endif

typedef struct IOATASmartAttribute {
    UInt8 attributeId;
    UInt16 flag;
    UInt8 current;
    UInt8 worst;
    UInt8 rawvalue[6];
    UInt8 reserv;
}  __attribute__ ((packed)) IOATASmartAttribute;


typedef struct IOATASmartVendorSpecificData {
    UInt16 revisonNumber;
    IOATASmartAttribute vendorAttributes[kSMARTAttributeCount];
} __attribute__ ((packed)) IOATASmartVendorSpecificData;


typedef struct IOATASmartThresholdAttribute {
    UInt8 attributeId;
    UInt8 ThresholdValue;
    UInt8 Reserved[10];
} __attribute__ ((packed)) IOATASmartThresholdAttribute;


typedef struct IOATASmartVendorSpecificDataThresholds {
    UInt16 revisonNumber;
    IOATASmartThresholdAttribute ThresholdEntries[kSMARTAttributeCount];
} __attribute__ ((packed)) IOATASmartVendorSpecificDataThresholds;


void SwapASCIIString(UInt16 *buffer, UInt16 length)
{
    for (int index = 0; index < length / 2; index ++) {
        buffer[index] = OSSwapInt16(buffer[index]);
    }
}


- (int)VerifyIdentifyData:(UInt16 *)buffer
{
    UInt8 checkSum = -1;

    if ((buffer[255] & 0x00FF) != kChecksumValidCookie) {
        return checkSum;
    }

    checkSum = 0;

    UInt8 *ptr = (UInt8 *)buffer;
    for (UInt32 index = 0; index < 512; index++) {
        checkSum += ptr[index];
    }

    return checkSum;
}


- (NSMutableDictionary *)getDiskInfo:(IOATASMARTInterface **)smartInterface
{
    IOReturn error = kIOReturnSuccess;
    UInt8 *buffer = NULL;
    UInt32 length = kATADefaultSectorSize;
    UInt16 *words = NULL;
    int checksum = 0;
    BOOL isSMARTSupported = NO;

    buffer = (UInt8 *)malloc(kATADefaultSectorSize);
    if (buffer == NULL) {
        return nil;
    }

    bzero(buffer, kATADefaultSectorSize);
    error = (*smartInterface)->GetATAIdentifyData(smartInterface,buffer,kATADefaultSectorSize,&length);
    if (error != kIOReturnSuccess) {
        if (NULL != buffer) {
            free(buffer);
        }
        return nil;
    }

    checksum = [self VerifyIdentifyData:(UInt16 *)buffer];

    if (checksum != 0) {
        if (NULL != buffer) {
            free(buffer);
        }
        return nil;
    }

    buffer[94] = 0;
    buffer[40] = 0;
    SwapASCIIHostToBig(&buffer[54], 40);

    NSString *model = nil;
    NSString *serial = nil;

    model = [[NSString stringWithCString:(char *)&buffer[54] encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    serial = [NSString stringWithCString:(char *)&buffer[20] encoding:NSUTF8StringEncoding];

    if (model == nil || serial == nil) {
        if (NULL != buffer) {
            free(buffer);
        }
        return nil;
    }

    words = (UInt16 *)buffer;

    isSMARTSupported = words[kATAIdentifyCommandSetSupported] & kATASupportsSMARTMask;
    if (isSMARTSupported) {
        NSMutableDictionary *data = [NSMutableDictionary dictionaryWithCapacity:2];
        if (model != nil) {
            [data setObject:model forKey:@"model"];
        }

        if (serial != nil) {
            [data setObject:serial forKey:@"serial"];
        }

        if (NULL != buffer) {
            free(buffer);
        }

        return data;
    }

    if (NULL != buffer) {
        free(buffer);
    }

    return nil;
}


- (NSNumber *)getSMARTLifeForInterface:(IOATASMARTInterface **)smartInterface
{
    IOReturn error = kIOReturnSuccess;
    Boolean conditionExceeded = false;
    ATASMARTData smartData;
    IOATASmartVendorSpecificData smartDataVendorSpecifics;
    ATASMARTDataThresholds smartThresholds;
    IOATASmartVendorSpecificDataThresholds smartThresholdVendorSpecifics;
    ATASMARTLogDirectory smartLogDirectory;

    bzero(&smartData, sizeof(smartData));
    bzero(&smartDataVendorSpecifics, sizeof(smartDataVendorSpecifics));
    bzero(&smartThresholds, sizeof(smartThresholds));
    bzero(&smartThresholdVendorSpecifics, sizeof(smartThresholdVendorSpecifics));
    bzero(&smartLogDirectory, sizeof(smartLogDirectory));

    BOOL foundLife = NO;
    //  NSNumber *life = nil;

    error = (*smartInterface)->SMARTEnableDisableOperations(smartInterface, true);
    if (error != kIOReturnSuccess) {
        (*smartInterface)->SMARTEnableDisableAutosave(smartInterface, false);
        (*smartInterface)->SMARTEnableDisableOperations(smartInterface, false);
        return [NSNumber numberWithInt:0];
    }

    error = (*smartInterface)->SMARTEnableDisableAutosave(smartInterface, true);
    if (error != kIOReturnSuccess) {
        (*smartInterface)->SMARTEnableDisableAutosave(smartInterface, false);
        (*smartInterface)->SMARTEnableDisableOperations(smartInterface, false);
        return [NSNumber numberWithInt:0];
    }

    error = (*smartInterface)->SMARTReturnStatus(smartInterface, &conditionExceeded);
    if (error != kIOReturnSuccess) {
        (*smartInterface)->SMARTEnableDisableAutosave(smartInterface, false);
        (*smartInterface)->SMARTEnableDisableOperations(smartInterface, false);
        return [NSNumber numberWithInt:0];
    }

    error = (*smartInterface)->SMARTReadData(smartInterface, &smartData);
    if (error == kIOReturnSuccess) {
        error = (*smartInterface)->SMARTValidateReadData(smartInterface, &smartData);
        if (error == kIOReturnSuccess) {
            smartDataVendorSpecifics = *((IOATASmartVendorSpecificData *)&(smartData.vendorSpecific1));
            for (int currentAttributeIndex = 0; currentAttributeIndex < kSMARTAttributeCount; currentAttributeIndex++) {
                IOATASmartAttribute currentAttribute = smartDataVendorSpecifics.vendorAttributes[currentAttributeIndex];
                if (currentAttribute.attributeId == kSMARTsDriveWearLevelingCount) {
                    UInt8 raw = currentAttribute.current;
                    life = [NSNumber numberWithUnsignedInt:raw];
                    foundLife = YES;
                    break;
                }
            }
        }
    }

    (*smartInterface)->SMARTEnableDisableAutosave(smartInterface, false);
    (*smartInterface)->SMARTEnableDisableOperations(smartInterface, false);

    if (foundLife && life != nil && [life intValue] > 0) {
        return life;
    }
    return nil;
}


- (NSNumber *)getSMARTTempForInterface:(IOATASMARTInterface **)smartInterface
{
    IOReturn error = kIOReturnSuccess;
    Boolean conditionExceeded = false;
    ATASMARTData smartData;
    IOATASmartVendorSpecificData smartDataVendorSpecifics;
    ATASMARTDataThresholds smartThresholds;
    IOATASmartVendorSpecificDataThresholds smartThresholdVendorSpecifics;
    ATASMARTLogDirectory smartLogDirectory;

    bzero(&smartData, sizeof(smartData));
    bzero(&smartDataVendorSpecifics, sizeof(smartDataVendorSpecifics));
    bzero(&smartThresholds, sizeof(smartThresholds));
    bzero(&smartThresholdVendorSpecifics, sizeof(smartThresholdVendorSpecifics));
    bzero(&smartLogDirectory, sizeof(smartLogDirectory));

    BOOL foundTemperature = NO;
    //  NSNumber *temperature = nil;

    //  [smartResultsDict setObject:[NSNumber numberWithBool:NO] forKey:kWindowSMARTsDeviceOkKeyString];

    error = (*smartInterface)->SMARTEnableDisableOperations(smartInterface, true);
    if (error != kIOReturnSuccess) {
        (*smartInterface)->SMARTEnableDisableAutosave(smartInterface, false);
        (*smartInterface)->SMARTEnableDisableOperations(smartInterface, false);
        return [NSNumber numberWithInt:0];
    }

    error = (*smartInterface)->SMARTEnableDisableAutosave(smartInterface, true);
    if (error != kIOReturnSuccess) {
        (*smartInterface)->SMARTEnableDisableAutosave(smartInterface, false);
        (*smartInterface)->SMARTEnableDisableOperations(smartInterface, false);
        return [NSNumber numberWithInt:0];
    }

    error = (*smartInterface)->SMARTReturnStatus(smartInterface, &conditionExceeded);
    if (error != kIOReturnSuccess) {
        (*smartInterface)->SMARTEnableDisableAutosave(smartInterface, false);
        (*smartInterface)->SMARTEnableDisableOperations(smartInterface, false);
        return [NSNumber numberWithInt:0];
    }

    //  if (!conditionExceeded)
    //    [smartResultsDict setObject:[NSNumber numberWithBool:YES] forKey:kWindowSMARTsDeviceOkKeyString];

    error = (*smartInterface)->SMARTReadData(smartInterface, &smartData);
    if (error == kIOReturnSuccess) {
        error = (*smartInterface)->SMARTValidateReadData(smartInterface, &smartData);
        if (error == kIOReturnSuccess) {
            smartDataVendorSpecifics = *((IOATASmartVendorSpecificData *)&(smartData.vendorSpecific1));
            for (int currentAttributeIndex = 0; currentAttributeIndex < kSMARTAttributeCount; currentAttributeIndex++) {
                IOATASmartAttribute currentAttribute = smartDataVendorSpecifics.vendorAttributes[currentAttributeIndex];
                if (currentAttribute.attributeId == kWindowSMARTsDriveTempAttribute ||
                    currentAttribute.attributeId == kWindowSMARTsDriveTempAttribute2) {
                    UInt8 raw = currentAttribute.rawvalue[0];
                    temp = [NSNumber numberWithUnsignedInt:raw];
                    foundTemperature = YES;
                    break;
                }
                if (currentAttribute.attributeId == kSMARTsDriveWearLevelingCount) {
                    UInt8 raw = currentAttribute.current;
                    life = [NSNumber numberWithUnsignedInt:raw];
                    //          foundLife = YES;
                    break;
                }
            }
        }
    }

    (*smartInterface)->SMARTEnableDisableAutosave(smartInterface, false);
    (*smartInterface)->SMARTEnableDisableOperations(smartInterface, false);

    if (foundTemperature && temp != nil && [temp intValue] > 0) {
        return temp;
    }
    return nil;
}


- (void)getSMARTData:(io_service_t)object
{
    IOCFPlugInInterface **cfPlugInInterface = NULL;
    IOATASMARTInterface **smartInterface = NULL;
    SInt32 score = 0;
    HRESULT herr = S_OK;
    IOReturn err = kIOReturnSuccess;

    err = IOCreatePlugInInterfaceForService(object,
                                            kIOATASMARTUserClientTypeID,
                                            kIOCFPlugInInterfaceID,
                                            &cfPlugInInterface,
                                            &score);

    if (err != kIOReturnSuccess) {
        return;
    }

    herr = ( *cfPlugInInterface )->QueryInterface(cfPlugInInterface,
                                                  CFUUIDGetUUIDBytes(kIOATASMARTInterfaceID),
                                                  (LPVOID)&smartInterface);
    if (herr != S_OK ) {
        IODestroyPlugInInterface(cfPlugInInterface);
        cfPlugInInterface = NULL;
        return;
    }

    NSMutableDictionary *diskInfo = [self getDiskInfo:smartInterface];
    if (diskInfo != nil) {
        [self getSMARTTempForInterface:smartInterface];

        CFTypeRef cfName = IORegistryEntrySearchCFProperty(object, kIOServicePlane, CFSTR("BSD Name"), kCFAllocatorDefault, kIORegistryIterateRecursively);
        NSString *bsdName = CFBridgingRelease(cfName);

        if (bsdName) {
            if ([partitionData objectForKey:bsdName]) {
                [diskInfo setObject:[partitionData objectForKey:bsdName] forKey:@"partitions"];
            }
//            CFRelease(bsdName);
        }
        if (temp != nil) {
            [diskInfo setObject:temp forKey:@"temp"];
            [diskData addObject:diskInfo];
        }
        //[diskInfo release];
        /* NSNumber *life = [self getSMARTLifeForInterface:smartInterface]; */
        if (life != nil) {
            [diskInfo setObject:life forKey:@"life"];
            [diskData addObject:diskInfo];
        }
    }

    (*smartInterface)->Release(smartInterface);
    smartInterface = NULL;

    IODestroyPlugInInterface(cfPlugInInterface);
    cfPlugInInterface = NULL;
}


- (void)update
{
    diskData = [NSMutableArray array];
    IOReturn error = kIOReturnSuccess;
    NSMutableDictionary *matchingDict = [NSMutableDictionary dictionaryWithCapacity:8];
    NSMutableDictionary *subDict = [NSMutableDictionary dictionaryWithCapacity:8];
    io_iterator_t iter = IO_OBJECT_NULL;
    io_object_t obj = IO_OBJECT_NULL;

    [subDict setObject:[NSNumber numberWithBool:YES] forKey:@kIOPropertySMARTCapableKey];
    [matchingDict setObject:subDict forKey:@kIOPropertyMatchKey];

    error = IOServiceGetMatchingServices(kIOMasterPortDefault, CFBridgingRetain(matchingDict), &iter);
    if (error == kIOReturnSuccess) {
        while ((obj = IOIteratorNext(iter)) != IO_OBJECT_NULL) {
            [self getSMARTData:obj];
            IOObjectRelease(obj);
        }
    }

    if (0 == diskData.count) {
        iter = IO_OBJECT_NULL;
        matchingDict = CFBridgingRelease(IOServiceMatching("IOATABlockStorageDevice"));

        error = IOServiceGetMatchingServices(kIOMasterPortDefault, CFBridgingRetain(matchingDict), &iter);
        if (error == kIOReturnSuccess) {
            while ((obj = IOIteratorNext(iter)) != IO_OBJECT_NULL) {
                [self getSMARTData:obj];
                IOObjectRelease(obj);
            }
        }
    }

    IOObjectRelease(iter);
    iter = IO_OBJECT_NULL;
    latestData = diskData;
}


- (NSDictionary *)getDataSet /*:(int)degrees*/
{
/*
    NSString *degreesSuffix = @"°";
    if (degrees == 2) {
        degreesSuffix = @"K";
    }
 */

    NSMutableDictionary *formattedTemps = [NSMutableDictionary dictionary];
    [latestData enumerateObjectsUsingBlock:^(NSMutableDictionary<NSString *, id> *diskInfo, NSUInteger idx, BOOL *stop) {
        NSNumber *tempInfo = [diskInfo objectForKey:@"temp"];
        if (nil == tempInfo) {
            return;
        }

        unsigned long value = [tempInfo intValue];
        //value = convertTemperature(degrees, value);

        NSString *name;
        if (nil != [diskInfo objectForKey:@"partitions"]) {
            name = [NSString stringWithFormat:@"%@", [[diskInfo objectForKey:@"partitions"] componentsJoinedByString:@", "]];
        } else {
            name = [NSString stringWithFormat:@"%@ s/n %@", [[diskInfo objectForKey:@"model"] stringByTrimmingLeadingWhitespace], [[diskInfo objectForKey:@"serial"] stringByTrimmingLeadingWhitespace]];
        }

        [formattedTemps setObject:[NSData dataWithBytes:&value length:sizeof(value)] forKey:name];
//        [diskInfo setObject:life forKey:@"life"];
//        [diskData addObject:diskInfo];
    }];

    return formattedTemps;
}


- (NSDictionary<NSString *, NSData *> *)getSSDLife
{
    NSMutableDictionary<NSString *, NSData *> *formattedLife = [NSMutableDictionary dictionaryWithCapacity:latestData.count];

    [latestData enumerateObjectsUsingBlock:^(NSMutableDictionary<NSString *, id> *diskInfo, NSUInteger idx, BOOL *stop) {
        NSNumber *lifeInfo = [diskInfo objectForKey:@"life"];
        if (nil == lifeInfo) {
            return;
        }

        unsigned long value = [lifeInfo intValue];
        NSString *name;
        if (nil != [diskInfo objectForKey:@"partitions"]) {
            name = [NSString stringWithFormat:@"_%@", [[diskInfo objectForKey:@"partitions"] componentsJoinedByString:@"_"]];
        } else {
            name = [NSString stringWithFormat:@"%@ s/n:%@", [[diskInfo objectForKey:@"model"] stringByTrimmingLeadingWhitespace], [[diskInfo objectForKey:@"serial"] stringByTrimmingLeadingWhitespace]];
        }

        [formattedLife setObject:[NSData dataWithBytes:&value length:sizeof(value)] forKey:name];
    }];

    return formattedLife;
}


- (void)getPartitions
{
    if (nil != partitionData) {
        [partitionData removeAllObjects];
    } else {
        partitionData = [NSMutableDictionary dictionary];
    }

    [[[NSWorkspace sharedWorkspace] mountedLocalVolumePaths] enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
        struct statfs buffer;
        int returnnewCode = statfs([path fileSystemRepresentation], &buffer);
        if (0 != returnnewCode) {
            return;
        }

        NSRange start = [path rangeOfString:@"/Volumes/"];
        if (0 != idx && start.length == 0) {
            return;
        }

        NSString *name = [[NSString stringWithFormat:@"%s", buffer.f_mntfromname] lastPathComponent];
        if (4 < name.length && [name hasPrefix:@"disk"]) {
            NSString *newName = [name substringFromIndex:4];
            NSRange paritionLocation = [newName rangeOfString:@"s"];
            if (paritionLocation.length != 0) {
                name = [NSString stringWithFormat:@"disk%@", [newName substringToIndex: paritionLocation.location]];
            }
        }

        NSMutableArray *partitions = [partitionData objectForKey:name];
        if (nil != partitions) {
            [partitions addObject:[[NSFileManager defaultManager] displayNameAtPath:path]];
        } else {
            partitions = [NSMutableArray arrayWithObject:[[NSFileManager defaultManager] displayNameAtPath:path]];
            [partitionData setObject:partitions forKey:name];
        }
    }];
}

@end
