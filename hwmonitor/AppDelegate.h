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


@interface AppDelegate : NSObject <NSApplicationDelegate> {
    NSStatusItem *statusItem;
#if !useSystemDefaultMenuStyles
    NSFont *statusItemFont;
#endif
    NSDictionary *statusItemAttributes;

    NSMutableArray *sensorsList;
    NSDictionary *DisksList;
    NSDictionary *SSDList;
    NSDictionary *BatteriesList;

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
    NSDictionary *statusMenuAttributes;
}

@property (assign) IBOutlet NSMenuItem *startAtLoginItem;

- (void)updateTitles;
- (HWMonitorSensor *)addSensorWithKey:(NSString *)key
                              andType:(NSString *)aType
                           andCaption:(NSString *)caption
                            intoGroup:(SensorGroup)group;

- (void)insertFooterAndTitle:(NSString *)title andImage:(NSImage *)img;
- (void)insertFooterAndTitle:(NSString *)title andImageNamed:(NSString *)imgName;

- (void)menuItemClicked:(id)sender;

@end
