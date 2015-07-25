#import "HotKeys.h"

@implementation HotKeys

static OSStatus func(EventHandlerCallRef nextHandler, EventRef anEvent, void *userData) {
  void (^block)() = (__bridge void (^)())(userData);
  block();
  return noErr;
}

static NSMutableArray *handlers;

+ (void)registerHotKey:(UInt32)keyCode modifiers:(UInt32)modifiers block:(nonnull void (^)())block;
{
  EventHotKeyRef hotKey;
  EventHotKeyID hotKeyID = {.signature = 'hush', .id = 1};
  EventTypeSpec eventType = {.eventClass = kEventClassKeyboard, .eventKind = kEventHotKeyPressed};

  void (^__nonnull block2)() = (__bridge void (^__nonnull)())Block_copy((__bridge void *)block);
  [handlers addObject:block2];
  InstallEventHandler(GetApplicationEventTarget(), func, 1, &eventType, (__bridge void *)block2, NULL);
  RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), kNilOptions, &hotKey);
}

@end
