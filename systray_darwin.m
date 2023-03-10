#import <Cocoa/Cocoa.h>
#include "systray.h"

#if __MAC_OS_X_VERSION_MIN_REQUIRED < 101400

    #ifndef NSControlStateValueOff
      #define NSControlStateValueOff NSOffState
    #endif

    #ifndef NSControlStateValueOn
      #define NSControlStateValueOn NSOnState
    #endif

#endif

@interface MenuItem : NSObject
{
  @public
    NSNumber* menuId;
    NSNumber* parentMenuId;
    NSString* title;
    NSString* tooltip;
    short disabled;
    short checked;
}
-(id) initWithId: (int)theMenuId
withParentMenuId: (int)theParentMenuId
       withTitle: (const char*)theTitle
     withTooltip: (const char*)theTooltip
    withDisabled: (short)theDisabled
     withChecked: (short)theChecked;
     @end
     @implementation MenuItem
     -(id) initWithId: (int)theMenuId
     withParentMenuId: (int)theParentMenuId
            withTitle: (const char*)theTitle
          withTooltip: (const char*)theTooltip
         withDisabled: (short)theDisabled
          withChecked: (short)theChecked
{
  menuId = [NSNumber numberWithInt:theMenuId];
  parentMenuId = [NSNumber numberWithInt:theParentMenuId];
  title = [[NSString alloc] initWithCString:theTitle
                                   encoding:NSUTF8StringEncoding];
  tooltip = [[NSString alloc] initWithCString:theTooltip
                                     encoding:NSUTF8StringEncoding];
  disabled = theDisabled;
  checked = theChecked;
  return self;
}
@end

@interface NotificationDelegate: NSObject <UNUserNotificationCenterDelegate>
@end
  @implementation NotificationDelegate
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    NSLog(@"NSLOG DID RECEIVE NOTIFICATION REQUEST");
    NSDictionary *userInfo = response.notification.request.content.userInfo;

    NSString *actionUri = userInfo[@"action_uri"];
    if ([actionUri length] != 0) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:actionUri]];
    }

    completionHandler();
}
@end

@interface AppDelegate: NSObject <NSApplicationDelegate>
  - (void) add_or_update_menu_item:(MenuItem*) item;
  - (IBAction)menuHandler:(id)sender;
  @property (assign) IBOutlet NSWindow *window;
  @end

  @implementation AppDelegate
{
  NSStatusItem *statusItem;
  NSMenu *menu;
  NSCondition* cond;
}

@synthesize window = _window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  self->statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
  self->menu = [[NSMenu alloc] init];
  [self->menu setAutoenablesItems: FALSE];
  [self->statusItem setMenu:self->menu];
  [self->statusItem addObserver:self forKeyPath:@"button.effectiveAppearance" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial context:nil];
  systray_ready();
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"button.effectiveAppearance"]) {
        NSStatusItem *item = object;
        NSAppearance *appearance = item.button.effectiveAppearance;
        NSString *appearanceName = (NSString*)(appearance.name);
        if ([[appearanceName lowercaseString] containsString:@"dark"]) {
          systray_appearance_changed(true);
        } else {
          systray_appearance_changed(false);
        }
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
  systray_on_exit();
}

- (void)setIcon:(NSImage *)image {
  statusItem.button.image = image;
  [self updateTitleButtonStyle];
}

- (void)setTitle:(NSString *)title {
  statusItem.button.title = title;
  [self updateTitleButtonStyle];
}

-(void)updateTitleButtonStyle {
  if (statusItem.button.image != nil) {
    if ([statusItem.button.title length] == 0) {
      statusItem.button.imagePosition = NSImageOnly;
    } else {
      statusItem.button.imagePosition = NSImageLeft;
    }
  } else {
    statusItem.button.imagePosition = NSNoImage;
  }
}


- (void)setTooltip:(NSString *)tooltip {
  statusItem.button.toolTip = tooltip;
}

- (IBAction)menuHandler:(id)sender
{
  NSNumber* menuId = [sender representedObject];
  systray_menu_item_selected(menuId.intValue);
}

- (void)add_or_update_menu_item:(MenuItem *)item {
  NSMenu *theMenu = self->menu;
  NSMenuItem *parentItem;
  if ([item->parentMenuId integerValue] > 0) {
    parentItem = find_menu_item(menu, item->parentMenuId);
    if (parentItem.hasSubmenu) {
      theMenu = parentItem.submenu;
    } else {
      theMenu = [[NSMenu alloc] init];
      [theMenu setAutoenablesItems:NO];
      [parentItem setSubmenu:theMenu];
    }
  }
  
  NSMenuItem *menuItem;
  menuItem = find_menu_item(theMenu, item->menuId);
  if (menuItem == NULL) {
    menuItem = [theMenu addItemWithTitle:item->title
                               action:@selector(menuHandler:)
                        keyEquivalent:@""];
    [menuItem setRepresentedObject:item->menuId];
  }
  [menuItem setTitle:item->title];
  [menuItem setTag:[item->menuId integerValue]];
  [menuItem setTarget:self];
  [menuItem setToolTip:item->tooltip];
  if (item->disabled == 1) {
    menuItem.enabled = FALSE;
  } else {
    menuItem.enabled = TRUE;
  }
  if (item->checked == 1) {
    menuItem.state = NSControlStateValueOn;
  } else {
    menuItem.state = NSControlStateValueOff;
  }
}

NSMenuItem *find_menu_item(NSMenu *ourMenu, NSNumber *menuId) {
  NSMenuItem *foundItem = [ourMenu itemWithTag:[menuId integerValue]];
  if (foundItem != NULL) {
    return foundItem;
  }
  NSArray *menu_items = ourMenu.itemArray;
  int i;
  for (i = 0; i < [menu_items count]; i++) {
    NSMenuItem *i_item = [menu_items objectAtIndex:i];
    if (i_item.hasSubmenu) {
      foundItem = find_menu_item(i_item.submenu, menuId);
      if (foundItem != NULL) {
        return foundItem;
      }
    }
  }

  return NULL;
};

- (void) add_separator:(NSNumber*) menuId
{
  [menu addItem: [NSMenuItem separatorItem]];
}

- (void) hide_menu_item:(NSNumber*) menuId
{
  NSMenuItem* menuItem = find_menu_item(menu, menuId);
  if (menuItem != NULL) {
    [menuItem setHidden:TRUE];
  }
}

- (void) setMenuItemIcon:(NSArray*)imageAndMenuId {
  NSImage* image = [imageAndMenuId objectAtIndex:0];
  NSNumber* menuId = [imageAndMenuId objectAtIndex:1];

  NSMenuItem* menuItem;
  menuItem = find_menu_item(menu, menuId);
  if (menuItem == NULL) {
    return;
  }
  menuItem.image = image;
}

- (void) show_menu_item:(NSNumber*) menuId
{
  NSMenuItem* menuItem = find_menu_item(menu, menuId);
  if (menuItem != NULL) {
    [menuItem setHidden:FALSE];
  }
}

- (void) remove_menu_item:(NSNumber*) menuId
{
  NSMenuItem* menuItem = find_menu_item(menu, menuId);
  if (menuItem != NULL) {
    [menuItem.menu removeItem:menuItem];     
  }
}

- (void) reset_menu
{
  [self->menu removeAllItems];
}

- (void) quit
{
  [NSApp terminate:self];
}

@end

bool internalLoop = false;
AppDelegate *owner;
NotificationDelegate *notificationDelegate;

void setInternalLoop(bool i) {
	internalLoop = i;
}

void registerSystray(void) {
  if (!internalLoop) { // with an external loop we don't take ownership of the app
    return;
  }

  owner = [[AppDelegate alloc] init];
  [[NSApplication sharedApplication] setDelegate:owner];

  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

  // Define our custom notification category with actions we will want to use on notifications later
  UNNotificationAction *learnMoreAction = [UNNotificationAction actionWithIdentifier:@"LearnMoreAction"
      title:@"Learn More" options:UNNotificationActionOptionNone];

  UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:@"KolideNotificationCategory"
      actions:@[learnMoreAction] intentIdentifiers:@[]
      options:UNNotificationCategoryOptionNone];
  NSSet *categories = [NSSet setWithObject:category];
  [center setNotificationCategories:categories];

  notificationDelegate = [[NotificationDelegate alloc] init];
  [center setDelegate:notificationDelegate];

  // A workaround to avoid crashing on macOS versions before Catalina. Somehow
  // SIGSEGV would happen inside AppKit if [NSApp run] is called from a
  // different function, even if that function is called right after this.
  if (floor(NSAppKitVersionNumber) <= /*NSAppKitVersionNumber10_14*/ 1671){
    [NSApp run];
  }
}

void nativeEnd(void) {
  systray_on_exit();
}

int nativeLoop(void) {
  if (floor(NSAppKitVersionNumber) > /*NSAppKitVersionNumber10_14*/ 1671){
    [NSApp run];
  }
  return EXIT_SUCCESS;
}

void nativeStart(void) {
  owner = [[AppDelegate alloc] init];

  NSNotification *launched = [NSNotification notificationWithName:NSApplicationDidFinishLaunchingNotification
                                                        object:[NSApplication sharedApplication]];
  [owner applicationDidFinishLaunching:launched];
}

void runInMainThread(SEL method, id object) {
  [owner
    performSelectorOnMainThread:method
                     withObject:object
                  waitUntilDone: YES];
}

void setIcon(const char* iconBytes, int length, bool template) {
  NSData* buffer = [NSData dataWithBytes: iconBytes length:length];
  @autoreleasepool {
    NSImage *image = [[NSImage alloc] initWithData:buffer];
    [image setSize:NSMakeSize(16, 16)];
    image.template = template;
    runInMainThread(@selector(setIcon:), (id)image);
  }
}

void setMenuItemIcon(const char* iconBytes, int length, int menuId, bool template) {
  NSData* buffer = [NSData dataWithBytes: iconBytes length:length];
  @autoreleasepool {
    NSImage *image = [[NSImage alloc] initWithData:buffer];
    [image setSize:NSMakeSize(16, 16)];
    image.template = template;
    NSNumber *mId = [NSNumber numberWithInt:menuId];
    runInMainThread(@selector(setMenuItemIcon:), @[image, (id)mId]);
  }
}

void setTitle(char* ctitle) {
  NSString* title = [[NSString alloc] initWithCString:ctitle
                                             encoding:NSUTF8StringEncoding];
  free(ctitle);
  runInMainThread(@selector(setTitle:), (id)title);
}

void setTooltip(char* ctooltip) {
  NSString* tooltip = [[NSString alloc] initWithCString:ctooltip
                                               encoding:NSUTF8StringEncoding];
  free(ctooltip);
  runInMainThread(@selector(setTooltip:), (id)tooltip);
}

void add_or_update_menu_item(int menuId, int parentMenuId, char* title, char* tooltip, short disabled, short checked, short isCheckable) {
  MenuItem* item = [[MenuItem alloc] initWithId: menuId withParentMenuId: parentMenuId withTitle: title withTooltip: tooltip withDisabled: disabled withChecked: checked];
  free(title);
  free(tooltip);
  runInMainThread(@selector(add_or_update_menu_item:), (id)item);
}

void add_separator(int menuId) {
  NSNumber *mId = [NSNumber numberWithInt:menuId];
  runInMainThread(@selector(add_separator:), (id)mId);
}

void hide_menu_item(int menuId) {
  NSNumber *mId = [NSNumber numberWithInt:menuId];
  runInMainThread(@selector(hide_menu_item:), (id)mId);
}

void remove_menu_item(int menuId) {
  NSNumber *mId = [NSNumber numberWithInt:menuId];
  runInMainThread(@selector(remove_menu_item:), (id)mId);
}

void show_menu_item(int menuId) {
  NSNumber *mId = [NSNumber numberWithInt:menuId];
  runInMainThread(@selector(show_menu_item:), (id)mId);
}

void reset_menu() {
  runInMainThread(@selector(reset_menu), nil);
}

void quit() {
  runInMainThread(@selector(quit), nil);
}

BOOL doSendNotification(UNUserNotificationCenter *center, NSString *title, NSString *body, NSString *actionUri) {
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = title;
    content.body = body;
    content.categoryIdentifier = @"KolideNotificationCategory";
    content.userInfo = @{@"action_uri": actionUri};

    NSString *uuid = [[NSUUID UUID] UUIDString];
    NSString *identifier = [NSString stringWithFormat:@"kolide-notify-%@", uuid];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
        content:content trigger:nil];

    __block BOOL success = NO;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if (error != nil) {
                NSLog(@"Could not send notification: %@", error);
            } else {
                success = YES;
            }
            dispatch_semaphore_signal(semaphore);
        }];
    });

    // Wait for completion handler to complete so that we get a correct value for `success`
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC);
    intptr_t err = dispatch_semaphore_wait(semaphore, timeout);
    if (err != 0) {
        // Timed out, remove the pending request
        [center removePendingNotificationRequestsWithIdentifiers:@[identifier]];
    }

    return success;
}

BOOL sendNotification(char *cTitle, char *cBody, char *cActionUri) {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

    NSString *title = [NSString stringWithUTF8String:cTitle];
    NSString *body = [NSString stringWithUTF8String:cBody];
    NSString *actionUri = [NSString stringWithUTF8String:cActionUri];

    __block BOOL canSendNotification = NO;
    UNAuthorizationOptions options = (UNAuthorizationOptionAlert | UNAuthorizationStatusProvisional);
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [center requestAuthorizationWithOptions:options
        completionHandler:^(BOOL granted, NSError *_Nullable error) {
            if (!granted) {
                if (error != NULL) {
                    NSLog(@"Error asking for permission to send notifications %@", error);
                } else {
                    NSLog(@"Unable to get permission to send notifications");
                }
            } else {
                canSendNotification = YES;
            }
            dispatch_semaphore_signal(semaphore);
        }];
    });

    // Wait for completion handler to complete so that we get a correct value for `canSendNotification`
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC);
    dispatch_semaphore_wait(semaphore, timeout);

    if (canSendNotification) {
        return doSendNotification(center, title, body, actionUri);
    }

    return NO;
}
