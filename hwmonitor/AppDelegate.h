//
//  AppDelegate.h
//  HWMonitor
//
//  Created by mozo,Navi on 20.10.11.
//  Copyright (c) 2011 mozodojo. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ISPSmartController.h"
#include "HWMonitorSensor.h"

#define useSystemDefaultMenuStyles 1


NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    NSStatusItem *statusItem;
#if !useSystemDefaultMenuStyles
    NSFont *statusItemFont;
#endif
    NSDictionary<NSAttributedStringKey, id> *statusItemAttributes;

    NSMutableArray<HWMonitorSensor *> *sensorsList;
    NSDictionary<NSString *, id> *DisksList;
    NSDictionary<NSString *, id> *SSDList;
    NSDictionary<NSString *, id> *BatteriesList;

    ISPSmartController *smartController;

    BOOL isMenuVisible;
    BOOL smart;
    int menusCount;
    int lastMenusCount;

    NSDate *lastcall;

    IBOutlet NSMenu *statusMenu;
#if !useSystemDefaultMenuStyles
    NSFont *statusMenuFont;
#endif
    NSDictionary<NSAttributedStringKey, id> *statusMenuAttributes;
}

@property (assign) IBOutlet NSMenuItem *startAtLoginItem;

- (void)updateTitles;
- (nullable HWMonitorSensor *)addSensorWithKey:(NSString *)key
                                       andType:(NSString *)aType
                                    andCaption:(NSString *)caption
                                     intoGroup:(SensorGroup)group;

- (void)insertFooterAndTitle:(NSString *)title andImageNamed:(NSString *)imgName;
- (void)insertFooterAndTitle:(NSString *)title andImage:(nullable NSImage *)img;

- (void)menuItemClicked:(id)sender;

@end

NS_ASSUME_NONNULL_END
