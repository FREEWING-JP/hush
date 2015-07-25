#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>

@interface HotKeys : NSObject

+ (void)registerHotKey:(UInt32)keyCode modifiers:(UInt32)modifiers block:(void (^)())block;

@end
