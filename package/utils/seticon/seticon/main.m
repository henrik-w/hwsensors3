//
//  main.m
//  seticon
//
//  Created by vector sigma on 22/03/18.
//  Copyright © 2018 vector sigma. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
int main(int argc, const char * argv[]) {
  @autoreleasepool {
    if (argc != 3) {
      printf("seticon require two arguments: [path to image] [path to file]\n");
      exit(1);
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%s", argv[2]]]) {
      printf("'%s' doesn't exist!\n",
             [NSString stringWithFormat:@"%s", argv[2]].UTF8String);
      exit(1);
    }
    
    NSImage *image = [[NSImage alloc] initByReferencingFile:[NSString stringWithFormat:@"%s", argv[1]]];
    if (image == nil) {
      printf("'%s' is not a supported image or doesn't exist!\n",
             [NSString stringWithFormat:@"%s", argv[1]].UTF8String);
      exit(1);
    }
    
    if (![[NSWorkspace sharedWorkspace] setIcon:image forFile:[NSString stringWithFormat:@"%s", argv[2]] options:0]) {
      printf("Error: unable to set the image for the requested file!\n");
      exit(1);
    }
    
  }
  return 0;
}
