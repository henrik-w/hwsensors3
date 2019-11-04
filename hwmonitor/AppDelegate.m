//
//  AppDelegate.m
//  HWMonitor
//
//  Created by mozo,Navi on 20.10.11.
//  Copyright (c) 2011 mozo. All rights reserved.
//
//  Francesco Renga (vector sigma) 2017, read battery from common path
//

#import "AppDelegate.h"
#import "NSString+TruncateToWidth.h"
#import "IOBatteryStatus.h"
#include "../utils/definitions.h"


#define LOG_NULL_VALUES 0

#define SMART_UPDATE_INTERVAL 5*60


@implementation AppDelegate

- (id)init
{
    if (self = [super init]) {
        lastcall = [NSDate date];
    }
    return self;
}


- (void)updateTitles
{
    NSDictionary *pb = [IOBatteryStatus getIOPMPowerSource];
    NSEnumerator *enumerator = nil;
    HWMonitorSensor *sensor = nil;

    NSMutableString *statusString = [[NSMutableString alloc] init];
    int count = 0;

    NSMutableDictionary *values;

    values = [NSMutableDictionary dictionaryWithCapacity:0];

    if (smart) {
        if (fabs([lastcall timeIntervalSinceNow]) > SMART_UPDATE_INTERVAL) {
            lastcall = [NSDate date];
            [smartController update];
        }
        [values addEntriesFromDictionary:[smartController getSSDLife]];
        [values addEntriesFromDictionary:[smartController getDataSet /*:1*/]];
    }

    NSDictionary *temp = [IOBatteryStatus getAllBatteriesLevel];
    if ([temp count] >0) {
        [values addEntriesFromDictionary:temp];

        BOOL __block needFooter = YES;
        [temp enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            BOOL found = NO;
            NSEnumerator *sensorsEnumerator = [sensorsList objectEnumerator];
            HWMonitorSensor *localSensor;
            while (localSensor = (HWMonitorSensor *)[sensorsEnumerator nextObject]) {
                if ([key isEqualToString:[localSensor key]]) {
                    found = YES;
                    needFooter = NO;
                }
            }
            if (!found) {
                [self addSensorWithKey:key andType:@TYPE_FPE2 andCaption:key intoGroup:BatterySensorsGroup];
            }
        }];
        if (needFooter) {
            [self insertFooterAndTitle:NSLocalizedString(@"BATTERIES", nil)
                              andImageNamed:@"modern-battery-icon"];
        }
    }

    if (values) {
        enumerator = [sensorsList objectEnumerator];

        while (sensor = (HWMonitorSensor *)[enumerator nextObject]) {
            NSString *value = nil;
            if ([[sensor key] isEqualToString:@KEY_BAT0_VOLTAGE] || [[sensor key] isEqualToString:@KEY_BAT0_AMPERAGE]) {
                if (pb) {
                    int v = ([[sensor key] isEqualToString:@KEY_BAT0_VOLTAGE] ?
                             [IOBatteryStatus getBatteryVoltageFrom:pb] :
                             [IOBatteryStatus getBatteryAmperageFrom:pb]);

                    if (v > BAT0_NOT_FOUND) {
                        value = [NSString stringWithFormat:@"%d", v];
                    } else {
                        [[(NSMenuItem *)[sensor object] menu] removeItem:(NSMenuItem *)[sensor object]];
                    }
                } else {
                    // workaround for VoodooBatterySMC when no battery is present
                    value = nil;
                    [[(NSMenuItem *)[sensor object] menu] removeItem:(NSMenuItem *)[sensor object]];
                }
            } else {
                value = [sensor formatedValue:
                         [values objectForKey:[sensor key]] ?
                         [values objectForKey:[sensor key]] :
                         [HWMonitorSensor readValueForKey:[sensor key]]];
            }

            if ((value != nil) && ![value isEqualToString:@""]) {
                if (isMenuVisible) {
                    // Update menu item title
                    NSString *menuItemTitle = [sensor caption];
                    menuItemTitle = [NSString stringWithFormat:@"%@\t%@", menuItemTitle, value];

                    if (![[(NSMenuItem *)[sensor object] title] isEqualToString:menuItemTitle]) {
                        [(NSMenuItem *)[sensor object] setAttributedTitle:[[NSAttributedString alloc] initWithString:menuItemTitle attributes:statusMenuAttributes]];
                    }
                }

                if ([sensor favorite]) {
                    [statusString appendString:@" "];
                    [statusString appendString:value];
                    count++;
                }
            }
        }
    }

    //if (count > 0) { /* let update the title */
    // Update status bar title
#if !useSystemDefaultMenuStyles
    NSMutableAttributedString * title = [[NSMutableAttributedString alloc] initWithString:statusString attributes:statusItemAttributes];
    [title addAttribute:NSFontAttributeName value:statusItemFont range:NSMakeRange(0, [title length])];
    [statusItem setAttributedTitle:title];
#else
    [statusItem setTitle:statusString];
#endif
    //}
}


- (HWMonitorSensor *)addSensorWithKey:(NSString *)key andType:(NSString *)aType andCaption:(NSString *)caption intoGroup:(SensorGroup)group
{
    if (group != HDSmartTempSensorGroup &&
        group != HDSmartLifeSensorGroup &&
        group != BatterySensorsGroup &&
        ![HWMonitorSensor readValueForKey:key]) {
        return nil;
    }

#if !useSystemDefaultMenuStyles
    caption = [caption stringByTruncatingToWidth:180.0f withFont:statusMenuFont];
#else
    caption = [caption stringByTruncatingToWidth:180.0f withFont:nil];
#endif
    HWMonitorSensor *sensor = [HWMonitorSensor monitorSensorWithKey:key andType:aType andGroup:group withCaption:caption];

    [sensor setFavorite:[[NSUserDefaults standardUserDefaults] boolForKey:key]];

    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:caption action:nil keyEquivalent:@""];

    [menuItem setRepresentedObject:sensor];
    [menuItem setAction:@selector(menuItemClicked:)];
    [menuItem setState:[sensor favorite]? YES : NO];

    [statusMenu insertItem:menuItem atIndex:menusCount++];

    [sensor setObject:menuItem];

    [sensorsList addObject:sensor];
    
    return sensor;
}


- (void)insertFooterAndTitle:(NSString *)title andImageNamed:(nonnull NSString *)imgName
{
    NSImage *img = [NSImage imageNamed:imgName];
    //img.template = YES;
    [self insertFooterAndTitle:title andImage:img];
}


- (void)insertFooterAndTitle:(NSString *)title andImage:(NSImage *)img
{
    if (lastMenusCount >= menusCount) {
        return;
    }

    NSMenuItem *titleItem = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    [titleItem setImage:img];
    [titleItem setEnabled:NO];
    //[titleItem setIndentationLevel:1];

    [statusMenu insertItem:titleItem atIndex:lastMenusCount];
    menusCount++;
    [statusMenu insertItem:[NSMenuItem separatorItem] atIndex:menusCount++];
    lastMenusCount = menusCount;
}


#pragma mark Events


- (void)menuWillOpen:(NSMenu *)menu
{
    isMenuVisible = YES;
    [self updateTitles];
}


- (void)menuDidClose:(NSMenu *)menu
{
    isMenuVisible = NO;
}


- (void)menuItemClicked:(id)sender
{
    NSMenuItem *menuItem = (NSMenuItem *)sender;

    [menuItem setState:![menuItem state]];
    HWMonitorSensor *sensor = (HWMonitorSensor *)[menuItem representedObject];
    [sensor setFavorite:[menuItem state]];

    [self updateTitles];

    [[NSUserDefaults standardUserDefaults] setBool:[menuItem state] forKey:[sensor key]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    if (![NSUserDefaults.standardUserDefaults objectForKey:@"runAtLoginWasSet"]) {
        [self toggleLaunchAtStartup:nil];
    }

    self.startAtLoginItem.state = [self isLaunchAtStartup] ? NSOnState : NSOffState;

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                [self methodSignatureForSelector:@selector(updateTitles)]];
    [invocation setTarget:self];
    [invocation setSelector:@selector(updateTitles)];
    [[NSRunLoop mainRunLoop] addTimer:[NSTimer timerWithTimeInterval:3 invocation:invocation repeats:YES] forMode:NSRunLoopCommonModes];

    [self updateTitles];
}


- (void)awakeFromNib
{
    menusCount = 0;
    lastcall = [NSDate date];
    smartController = [ISPSmartController new];
    if (nil != smartController) {
        smart = YES;
        [smartController getPartitions];
        [smartController update];
        DisksList = [smartController getDataSet /*:1*/];
        SSDList = [smartController getSSDLife];
    }

    BatteriesList = [IOBatteryStatus getAllBatteriesLevel];

    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];

    NSImage *statusImage = [NSImage imageNamed:@"temperature_small"];
    statusImage.template = YES;
    statusItem.image = statusImage;
    NSImage *statusImageAlternate = [NSImage imageNamed:@"temperature_small"];
    statusImageAlternate.template = YES;
    statusItem.alternateImage = statusImageAlternate;

    NSMutableParagraphStyle *style;
#if !useSystemDefaultMenuStyles
    statusItemFont = [NSFont fontWithName:@"Lucida Grande Bold" size:9.0];
    style = [NSMutableParagraphStyle new];
    [style setLineSpacing:0];
    statusItemAttributes = [NSDictionary dictionaryWithObject:style forKey:NSParagraphStyleAttributeName];
#else
    statusItemAttributes = [NSDictionary dictionaryWithObject:[NSParagraphStyle defaultParagraphStyle] forKey:NSParagraphStyleAttributeName];
#endif

#if !useSystemDefaultMenuStyles
    statusMenuFont = [NSFont fontWithName:@"Menlo" size:11.0];
    [statusMenu setFont:statusMenuFont];
#endif

    style = [NSMutableParagraphStyle new];
    style.tabStops = @[[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight location:190.0 options:@{}]];
    //style.defaultTabInterval = 390.0;
    statusMenuAttributes = [NSDictionary dictionaryWithObject:style forKey:NSParagraphStyleAttributeName];

    // Init sensors
    sensorsList = [NSMutableArray array];
    lastMenusCount = menusCount;

    //
    // Temperatures
    //
    NSString *type;
    for (int i = 0; i < 0xA; i++) {
        [self addSensorWithKey:[NSString stringWithFormat:@KEY_FORMAT_CPU_DIODE_TEMPERATURE, i]
                       andType:((type = [HWMonitorSensor getTypeOfKey:[NSString stringWithFormat:@KEY_FORMAT_CPU_DIODE_TEMPERATURE, i]]) ? type : @TYPE_SP78)
                    andCaption:[NSString stringWithFormat:@"CPU %X Diode", i]
                     intoGroup:TemperatureSensorGroup];
        //there was TC%XH, I change to TC%XC
        [self addSensorWithKey:[NSString stringWithFormat:@KEY_FORMAT_CPU_DIE_CORE_TEMPERATURE, i]
                       andType:((type = [HWMonitorSensor getTypeOfKey:[NSString stringWithFormat:@KEY_FORMAT_CPU_DIE_CORE_TEMPERATURE, i]]) ? type : @TYPE_SP78)
                    andCaption:[NSString stringWithFormat:@"CPU %X Core", i]
                     intoGroup:TemperatureSensorGroup];
    }
    [self addSensorWithKey:@KEY_CPU_PROXIMITY_TEMPERATURE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_CPU_PROXIMITY_TEMPERATURE]) ? type : @TYPE_SP78)
                andCaption:NSLocalizedString(@"CPU Proximity", nil)
                 intoGroup:TemperatureSensorGroup];
    [self addSensorWithKey:@KEY_CPU_HEATSINK_TEMPERATURE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_CPU_HEATSINK_TEMPERATURE]) ? type : @TYPE_SP78)
                andCaption:NSLocalizedString(@"CPU Heatsink", nil)
                 intoGroup:TemperatureSensorGroup];
    [self addSensorWithKey:@KEY_NORTHBRIDGE_TEMPERATURE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_NORTHBRIDGE_TEMPERATURE]) ? type : @TYPE_SP78)
                andCaption:NSLocalizedString(@"Motherboard", nil)
                 intoGroup:TemperatureSensorGroup];
    [self addSensorWithKey:@KEY_DIMM_TEMPERATURE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_DIMM_TEMPERATURE]) ? type : @TYPE_SP78)
                andCaption:NSLocalizedString(@"DIMM 0", nil)
                 intoGroup:TemperatureSensorGroup];
    [self addSensorWithKey:@KEY_DIMM2_TEMPERATURE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_DIMM2_TEMPERATURE]) ? type : @TYPE_SP78)
                andCaption:NSLocalizedString(@"DIMM 1", nil)
                 intoGroup:TemperatureSensorGroup];
    [self addSensorWithKey:@KEY_AMBIENT_TEMPERATURE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_AMBIENT_TEMPERATURE]) ? type : @TYPE_SP78)
                andCaption:NSLocalizedString(@"Ambient", nil)
                 intoGroup:TemperatureSensorGroup];

    for (int i = 0; i < 0xA; i++) {
        NSString *sensorKey = [NSString stringWithFormat:@KEY_FORMAT_GPU_DIODE_TEMPERATURE, i];
        [self addSensorWithKey:sensorKey
                       andType:((type = [HWMonitorSensor getTypeOfKey:sensorKey]) ? type : @TYPE_SP78)
                    andCaption:[NSString stringWithFormat:NSLocalizedString(@"GPU %X Core", nil), i]
                     intoGroup:TemperatureSensorGroup];
        sensorKey = [NSString stringWithFormat:@KEY_FORMAT_GPU_BOARD_TEMPERATURE, i];
        [self addSensorWithKey:sensorKey
                       andType:((type = [HWMonitorSensor getTypeOfKey:sensorKey]) ? type : @TYPE_SP78)
                    andCaption:[NSString stringWithFormat:NSLocalizedString(@"GPU %X Board", nil), i]
                     intoGroup:TemperatureSensorGroup];
        sensorKey = [NSString stringWithFormat:@KEY_FORMAT_GPU_PROXIMITY_TEMPERATURE, i];
        [self addSensorWithKey:sensorKey
                       andType:((type = [HWMonitorSensor getTypeOfKey:sensorKey]) ? type : @TYPE_SP78)
                    andCaption:[NSString stringWithFormat:NSLocalizedString(@"GPU %X Proximity", nil), i]
                     intoGroup:TemperatureSensorGroup];
    }

    [self insertFooterAndTitle:NSLocalizedString(@"TEMPERATURES", nil) andImageNamed:@"temp_alt_small"];

    //
    // Frequencies
    //
    for (int i = 0; i < 16; i++) {
        [self addSensorWithKey:[NSString stringWithFormat:@KEY_FORMAT_NON_APPLE_CPU_FREQUENCY, i]
                       andType:@TYPE_FREQ
                    andCaption:[NSString stringWithFormat:NSLocalizedString(@"CPU %X", nil), i]
                     intoGroup:FrequencySensorGroup];
    }

    for (int i = 0; i < 0xA; i++) {
        [self addSensorWithKey:[NSString stringWithFormat:@KEY_FAKESMC_FORMAT_GPU_FREQUENCY, i]
                       andType:@TYPE_FREQ
                    andCaption:[NSString stringWithFormat:NSLocalizedString(@"GPU %X Core", nil), i]
                     intoGroup:FrequencySensorGroup];
        [self addSensorWithKey:[NSString stringWithFormat:@KEY_FAKESMC_FORMAT_GPU_SHADER_FREQUENCY, i]
                       andType:@TYPE_FREQ
                    andCaption:[NSString stringWithFormat:NSLocalizedString(@"GPU %X Shaders", nil), i]
                     intoGroup:FrequencySensorGroup];

        // Temporary disable GPU ROP and Memory reporting
        [self addSensorWithKey:[NSString stringWithFormat:@KEY_FAKESMC_FORMAT_GPU_MEMORY_FREQUENCY, i]
                       andType:@TYPE_FREQ
                    andCaption:[NSString stringWithFormat:NSLocalizedString(@"GPU %X Memory", nil), i]
                     intoGroup:FrequencySensorGroup];
//        [self addSensorWithKey:[NSString stringWithFormat:@KEY_FAKESMC_FORMAT_GPU_ROP_FREQUENCY, i] andType:@TYPE_SP78 andCaption:[NSString stringWithFormat:NSLocalizedString(@"GPU %X ROP", nil), i] intoGroup:FrequencySensorGroup];
        //
        [self insertFooterAndTitle:NSLocalizedString(@"FREQUENCIES", nil) andImageNamed:@"freq_small"];
    }

    //
    // Multipliers
    //
    for (int i = 0; i < 0xA; i++) {
        [self addSensorWithKey:[NSString stringWithFormat:@KEY_FORMAT_NON_APPLE_CPU_MULTIPLIER, i]
                       andType:@TYPE_FP4C
                    andCaption:[NSString stringWithFormat:NSLocalizedString(@"CPU %X Multiplier", nil), i]
                     intoGroup:MultiplierSensorGroup];
    }
    [self addSensorWithKey:@KEY_NON_APPLE_PACKAGE_MULTIPLIER
                   andType:@TYPE_FP4C
                andCaption:NSLocalizedString(@"CPU Package Multiplier", nil)
                 intoGroup:MultiplierSensorGroup];
    [self insertFooterAndTitle:NSLocalizedString(@"MULTIPLIERS", nil) andImageNamed:@"multiply_small"];

    //
    // Voltages
    //
    [self addSensorWithKey:@KEY_CPU_VOLTAGE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_CPU_VOLTAGE]) ? type : @TYPE_FP2E)
                andCaption:NSLocalizedString(@"CPU Voltage", nil)
                 intoGroup:VoltageSensorGroup];
    [self addSensorWithKey:@KEY_CPU_VRM_SUPPLY0
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_CPU_VRM_SUPPLY0]) ? type : @TYPE_FP2E)
                andCaption:NSLocalizedString(@"CPU VRM Voltage", nil)
                 intoGroup:VoltageSensorGroup];
    [self addSensorWithKey:@KEY_MEMORY_VOLTAGE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_MEMORY_VOLTAGE]) ? type : @TYPE_FP2E)
                andCaption:NSLocalizedString(@"DIMM Voltage", nil)
                 intoGroup:VoltageSensorGroup];
    [self addSensorWithKey:@KEY_12V_VOLTAGE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_12V_VOLTAGE]) ? type : @TYPE_SP4B)
                andCaption:NSLocalizedString(@"+12V Bus Voltage", nil)
                 intoGroup:VoltageSensorGroup];
    [self addSensorWithKey:@KEY_5VC_VOLTAGE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_5VC_VOLTAGE]) ? type : @TYPE_SP4B)
                andCaption:NSLocalizedString(@"+5V Bus Voltage", nil)
                 intoGroup:VoltageSensorGroup];
    [self addSensorWithKey:@KEY_N12VC_VOLTAGE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_N12VC_VOLTAGE]) ? type : @TYPE_SP4B)
                andCaption:NSLocalizedString(@"-12V Bus Voltage", nil)
                 intoGroup:VoltageSensorGroup];
    [self addSensorWithKey:@KEY_5VSB_VOLTAGE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_5VSB_VOLTAGE]) ? type : @TYPE_SP4B)
                andCaption:NSLocalizedString(@"-5V Bus Voltage", nil)
                 intoGroup:VoltageSensorGroup];
    [self addSensorWithKey:@KEY_3VCC_VOLTAGE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_3VCC_VOLTAGE]) ? type : @TYPE_FP2E)
                andCaption:NSLocalizedString(@"3.3 VCC Voltage", nil)
                 intoGroup:VoltageSensorGroup];
    [self addSensorWithKey:@KEY_3VSB_VOLTAGE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_3VSB_VOLTAGE]) ? type : @TYPE_FP2E)
                andCaption:NSLocalizedString(@"3.3 VSB Voltage", nil)
                 intoGroup:VoltageSensorGroup];
    [self addSensorWithKey:@KEY_AVCC_VOLTAGE
                   andType:((type = [HWMonitorSensor getTypeOfKey:@KEY_AVCC_VOLTAGE]) ? type : @TYPE_FP2E)
                andCaption:NSLocalizedString(@"3.3 AVCC Voltage", nil)
                 intoGroup:VoltageSensorGroup];

    for (int i = 0; i < 0xA; i++) {
        NSString *key = [NSString stringWithFormat:@KEY_FORMAT_GPU_VOLTAGE, i];
        [self addSensorWithKey:key
                       andType:((type = [HWMonitorSensor getTypeOfKey:key]) ? type : @TYPE_FP2E)
                    andCaption:[NSString stringWithFormat:NSLocalizedString(@"GPU %X Voltage", nil), i]
                     intoGroup:VoltageSensorGroup];
    }

    [self insertFooterAndTitle:NSLocalizedString(@"VOLTAGES", nil) andImageNamed:@"voltage_small"];

    //
    // Fans
    //
    for (int i = 0; i < 10; i++) {
        FanTypeDescStruct *fds;
        NSString *caption = nil;

        NSData *keydata = [HWMonitorSensor readValueForKey:[NSString stringWithFormat:@KEY_FORMAT_FAN_ID, i]];
        if (nil != keydata) {
            fds = (FanTypeDescStruct*)[keydata bytes];
            caption = [[NSString alloc] initWithBytes:fds->strFunction
                                               length:DIAG_FUNCTION_STR_LEN
                                             encoding:NSUTF8StringEncoding];
            [caption stringByTrimmingCharactersInSet:[[NSCharacterSet letterCharacterSet] invertedSet]];
        }

        if (nil == caption || 0 >= caption.length) {
            caption = [NSString stringWithFormat:NSLocalizedString(@"Fan %d", nil), i];
        }
        NSString *key = [NSString stringWithFormat:@KEY_FORMAT_FAN_SPEED, i];
        [self addSensorWithKey:key
                       andType:((type = [HWMonitorSensor getTypeOfKey:key]) ? type : @TYPE_FPE2)
                    andCaption:caption
                     intoGroup:TachometerSensorGroup];
    }

    [self insertFooterAndTitle:NSLocalizedString(@"FANS", nil) andImageNamed:@"fan_small"];

    //
    // Disks
    //
    if (nil != DisksList && 0 != DisksList.count) {
        NSEnumerator<NSString *> *DisksEnumerator = [DisksList keyEnumerator];
        NSString *nextDiskKey;
        while (nextDiskKey = [DisksEnumerator nextObject]) {
            [self addSensorWithKey:nextDiskKey andType:@TYPE_FPE2 andCaption:nextDiskKey intoGroup:HDSmartTempSensorGroup];
        }
    }

    //
    // SSD Life
    //
    if (nil != SSDList && 0 != SSDList.count) {
        [self insertFooterAndTitle:NSLocalizedString(@"HARD DRIVES TEMPERATURES", nil) andImageNamed:@"hd_small"];

        NSEnumerator<NSString *> *SSDEnumerator = [SSDList keyEnumerator];
        NSString *nextSSDKey;
        while (nextSSDKey = [SSDEnumerator nextObject]) {
            [self addSensorWithKey:nextSSDKey andType:@TYPE_FPE2 andCaption:nextSSDKey intoGroup:HDSmartLifeSensorGroup];
        }

        [self insertFooterAndTitle:NSLocalizedString(@"SSD LIFE", nil) andImageNamed:@"ssd_small"];
    }

    //
    // Battery
    //
    if (nil != BatteriesList && 0 != BatteriesList.count) {
        [self addSensorWithKey:@KEY_BAT0_VOLTAGE andType: ((type = [HWMonitorSensor getTypeOfKey:@KEY_BAT0_VOLTAGE]) ? type : @TYPE_UI16) andCaption:NSLocalizedString(@"Battery Voltage, mV", nil) intoGroup:BatterySensorsGroup ];
        //KEY_BAT0_AMPERAGE
        [self addSensorWithKey:@KEY_BAT0_AMPERAGE andType: ((type = [HWMonitorSensor getTypeOfKey:@KEY_BAT0_AMPERAGE]) ? type : @TYPE_SI16) andCaption:NSLocalizedString(@"Battery Amperage, mA", nil) intoGroup:BatterySensorsGroup ];

        NSEnumerator<NSString *> *BatteryEnumerator = [BatteriesList keyEnumerator];
        NSString *nextBatteryKey;
        while (nextBatteryKey = [BatteryEnumerator nextObject]) {
            [self addSensorWithKey:nextBatteryKey andType:@TYPE_FPE2 andCaption:nextBatteryKey intoGroup:BatterySensorsGroup];
        }

        [self insertFooterAndTitle:NSLocalizedString(@"BATTERIES", nil) andImageNamed:@"modern-battery-icon"];
    }

    if (nil == sensorsList || 0 == sensorsList.count) {
        NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"No sensors found or FakeSMCDevice unavailable", nil) action:nil keyEquivalent:@""];

        [item setEnabled:NO];

        [statusMenu insertItem:item atIndex:0];
    }
}


#pragma mark launch at start up


- (BOOL)isLaunchAtStartup
{
    // See if the app is currently in LoginItems.
    LSSharedFileListItemRef itemRef = [self itemRefInLoginItems];
    // Store away that boolean.
    BOOL isInList = itemRef != nil;
    // Release the reference if it exists.
    if (itemRef != nil) CFRelease(itemRef);

    return isInList;
}


- (IBAction)toggleLaunchAtStartup:(NSMenuItem *)sender
{
    // Toggle the state.
    BOOL shouldBeToggled = ![self isLaunchAtStartup];
    // Get the LoginItems list.
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemsRef == nil) return;
    if (shouldBeToggled) {
        // Add the app to the LoginItems list.
        CFURLRef appUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, appUrl, NULL, NULL);
        if (itemRef) CFRelease(itemRef);
    }
    else {
        // Remove the app from the LoginItems list.
        LSSharedFileListItemRef itemRef = [self itemRefInLoginItems];
        LSSharedFileListItemRemove(loginItemsRef,itemRef);
        if (itemRef != nil) CFRelease(itemRef);
    }
    CFRelease(loginItemsRef);

    self.startAtLoginItem.state = [self isLaunchAtStartup] ? NSOnState : NSOffState;

    [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"runAtLoginWasSet"];
    [NSUserDefaults.standardUserDefaults synchronize];
}


- (LSSharedFileListItemRef)itemRefInLoginItems
{
    LSSharedFileListItemRef res = nil;

    // Get the app's URL.
    NSURL *bundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    // Get the LoginItems list.
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemsRef == nil) return nil;
    // Iterate over the LoginItems.
    NSArray *loginItems = (__bridge NSArray *)LSSharedFileListCopySnapshot(loginItemsRef, nil);
    for (id item in loginItems) {
        LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)(item);
        CFURLRef itemURLRef;
        if (LSSharedFileListItemResolve(itemRef, 0, &itemURLRef, NULL) == noErr) {
            // Again, use toll-free bridging.
            NSURL *itemURL = (__bridge NSURL *)itemURLRef;
            if ([itemURL isEqual:bundleURL]) {
                res = itemRef;
                break;
            }
        }
    }
    // Retain the LoginItem reference.
    if (res != nil) CFRetain(res);
    CFRelease(loginItemsRef);
    CFRelease((__bridge CFTypeRef)(loginItems));

    return res;
}

@end

