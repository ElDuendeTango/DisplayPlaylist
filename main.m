//
//  main.m
//  DisplayPlaylist
//
//  Created by Christian Seyb on 30.01.14.
//  Copyright (c) 2014 Christian Seyb. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <AppleScriptObjC/AppleScriptObjC.h>

int main(int argc, const char * argv[])
{
    [[NSBundle mainBundle] loadAppleScriptObjectiveCScripts];
    return NSApplicationMain(argc, argv);
}
