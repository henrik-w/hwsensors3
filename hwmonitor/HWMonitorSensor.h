//
//  NSSensor.h
//  HWSensors
//
//  Created by mozo,Navi on 22.10.11.
//  Copyright (c) 2011 mozo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ISPSmartController.h"

enum {
    TemperatureSensorGroup  = 1,
    VoltageSensorGroup      = 2,
    TachometerSensorGroup   = 3,
    FrequencySensorGroup    = 4,
    MultiplierSensorGroup   = 5,
    HDSmartTempSensorGroup  = 6,
    BatterySensorsGroup     = 7,
    HDSmartLifeSensorGroup  = 8,
};
typedef NSUInteger SensorGroup;

NS_ASSUME_NONNULL_BEGIN
@interface HWMonitorSensor : NSObject

@property (readonly, retain) NSString *key;
@property (readonly, retain) NSString *type;
@property (readonly, assign) SensorGroup group;
@property (readonly, retain) NSString *caption;
@property (readwrite, retain) id object;
@property (readwrite, assign, getter=isFavorite) BOOL favorite;


+ (nullable NSData *)readValueForKey:(NSString *)key;
+ (nullable NSString *)getTypeOfKey:(NSString *)key;

+ (instancetype)monitorSensorWithKey:(NSString *)aKey
                             andType:(NSString *)aType
                            andGroup:(NSUInteger)aGroup
                         withCaption:(NSString *)aCaption;
- (HWMonitorSensor *)initWithKey:(NSString *)aKey
                         andType:(NSString *)aType
                        andGroup:(NSUInteger)aGroup
                     withCaption:(NSString *)aCaption;

- (nonnull NSString *)formatedValue:(nullable NSData *)value;

@end

NS_ASSUME_NONNULL_END

