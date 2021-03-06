#import "ABI35_0_0RNGestureHandlerModule.h"

#import <ReactABI35_0_0/ABI35_0_0RCTLog.h>
#import <ReactABI35_0_0/ABI35_0_0RCTViewManager.h>
#import <ReactABI35_0_0/ABI35_0_0RCTComponent.h>
#import <ReactABI35_0_0/ABI35_0_0RCTUIManager.h>
#import <ReactABI35_0_0/ABI35_0_0RCTUIManagerUtils.h>
#import <ReactABI35_0_0/ABI35_0_0RCTUIManagerObserverCoordinator.h>

#import "ABI35_0_0RNGestureHandlerState.h"
#import "ABI35_0_0RNGestureHandlerDirection.h"
#import "ABI35_0_0RNGestureHandler.h"
#import "ABI35_0_0RNGestureHandlerManager.h"

#import "ABI35_0_0RNGestureHandlerButton.h"

@interface ABI35_0_0RNGestureHandlerModule () <ABI35_0_0RCTUIManagerObserver>

@end

@interface ABI35_0_0RNGestureHandlerButtonManager : ABI35_0_0RCTViewManager
@end

@implementation ABI35_0_0RNGestureHandlerButtonManager

ABI35_0_0RCT_EXPORT_MODULE(ABI35_0_0RNGestureHandlerButton)

ABI35_0_0RCT_EXPORT_VIEW_PROPERTY(enabled, BOOL)
#if !TARGET_OS_TV
ABI35_0_0RCT_CUSTOM_VIEW_PROPERTY(exclusive, BOOL, ABI35_0_0RNGestureHandlerButton)
{
  [view setExclusiveTouch: json == nil ? YES : [ABI35_0_0RCTConvert BOOL: json]];
}
#endif
ABI35_0_0RCT_CUSTOM_VIEW_PROPERTY(hitSlop, UIEdgeInsets, ABI35_0_0RNGestureHandlerButton)
{
  if (json) {
    UIEdgeInsets hitSlopInsets = [ABI35_0_0RCTConvert UIEdgeInsets:json];
    view.hitTestEdgeInsets = UIEdgeInsetsMake(-hitSlopInsets.top, -hitSlopInsets.left, -hitSlopInsets.bottom, -hitSlopInsets.right);
  } else {
    view.hitTestEdgeInsets = defaultView.hitTestEdgeInsets;
  }
}

- (UIView *)view
{
    return [ABI35_0_0RNGestureHandlerButton new];
}

@end


typedef void (^GestureHandlerOperation)(ABI35_0_0RNGestureHandlerManager *manager);

@implementation ABI35_0_0RNGestureHandlerModule
{
    ABI35_0_0RNGestureHandlerManager *_manager;

    // Oparations called after views have been updated.
    NSMutableArray<GestureHandlerOperation> *_operations;
}

ABI35_0_0RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

- (void)invalidate
{
    _manager = nil;
    [self.bridge.uiManager.observerCoordinator removeObserver:self];
}

- (dispatch_queue_t)methodQueue
{
    // This module needs to be on the same queue as the UIManager to avoid
    // having to lock `_operations` and `_preOperations` since `uiManagerWillFlushUIBlocks`
    // will be called from that queue.

    // This is required as this module rely on having all the view nodes created before
    // gesture handlers can be associated with them
    return ABI35_0_0RCTGetUIManagerQueue();
}

- (void)setBridge:(ABI35_0_0RCTBridge *)bridge
{
    [super setBridge:bridge];

    _manager = [[ABI35_0_0RNGestureHandlerManager alloc]
                initWithUIManager:bridge.uiManager
                eventDispatcher:bridge.eventDispatcher];
    _operations = [NSMutableArray new];
    [bridge.uiManager.observerCoordinator addObserver:self];
}

ABI35_0_0RCT_EXPORT_METHOD(createGestureHandler:(nonnull NSString *)handlerName tag:(nonnull NSNumber *)handlerTag config:(NSDictionary *)config)
{
    [self addOperationBlock:^(ABI35_0_0RNGestureHandlerManager *manager) {
        [manager createGestureHandler:handlerName tag:handlerTag config:config];
    }];
}

ABI35_0_0RCT_EXPORT_METHOD(attachGestureHandler:(nonnull NSNumber *)handlerTag toViewWithTag:(nonnull NSNumber *)viewTag)
{
    [self addOperationBlock:^(ABI35_0_0RNGestureHandlerManager *manager) {
        [manager attachGestureHandler:handlerTag toViewWithTag:viewTag];
    }];
}

ABI35_0_0RCT_EXPORT_METHOD(updateGestureHandler:(nonnull NSNumber *)handlerTag config:(NSDictionary *)config)
{
    [self addOperationBlock:^(ABI35_0_0RNGestureHandlerManager *manager) {
        [manager updateGestureHandler:handlerTag config:config];
    }];
}

ABI35_0_0RCT_EXPORT_METHOD(dropGestureHandler:(nonnull NSNumber *)handlerTag)
{
    [self addOperationBlock:^(ABI35_0_0RNGestureHandlerManager *manager) {
        [manager dropGestureHandler:handlerTag];
    }];
}

ABI35_0_0RCT_EXPORT_METHOD(handleSetJSResponder:(nonnull NSNumber *)viewTag blockNativeResponder:(nonnull NSNumber *)blockNativeResponder)
{
    [self addOperationBlock:^(ABI35_0_0RNGestureHandlerManager *manager) {
        [manager handleSetJSResponder:viewTag blockNativeResponder:blockNativeResponder];
    }];
}

ABI35_0_0RCT_EXPORT_METHOD(handleClearJSResponder)
{
    [self addOperationBlock:^(ABI35_0_0RNGestureHandlerManager *manager) {
        [manager handleClearJSResponder];
    }];
}

#pragma mark -- Batch handling

- (void)addOperationBlock:(GestureHandlerOperation)operation
{
    [_operations addObject:operation];
}

#pragma mark - ABI35_0_0RCTUIManagerObserver

- (void)uiManagerWillFlushUIBlocks:(ABI35_0_0RCTUIManager *)uiManager
{
  [self uiManagerWillPerformMounting:uiManager];
}

- (void)uiManagerWillPerformMounting:(ABI35_0_0RCTUIManager *)uiManager
{
    if (_operations.count == 0) {
        return;
    }

    NSArray<GestureHandlerOperation> *operations = _operations;
    _operations = [NSMutableArray new];

    [uiManager addUIBlock:^(__unused ABI35_0_0RCTUIManager *manager, __unused NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        for (GestureHandlerOperation operation in operations) {
            operation(self->_manager);
        }
    }];
}

#pragma mark Events

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"onGestureHandlerEvent", @"onGestureHandlerStateChange"];
}

#pragma mark Module Constants

- (NSDictionary *)constantsToExport
{
    return @{ @"State": @{
                      @"UNDETERMINED": @(ABI35_0_0RNGestureHandlerStateUndetermined),
                      @"BEGAN": @(ABI35_0_0RNGestureHandlerStateBegan),
                      @"ACTIVE": @(ABI35_0_0RNGestureHandlerStateActive),
                      @"CANCELLED": @(ABI35_0_0RNGestureHandlerStateCancelled),
                      @"FAILED": @(ABI35_0_0RNGestureHandlerStateFailed),
                      @"END": @(ABI35_0_0RNGestureHandlerStateEnd)
                      },
              @"Direction": @{
                      @"RIGHT": @(ABI35_0_0RNGestureHandlerDirectionRight),
                      @"LEFT": @(ABI35_0_0RNGestureHandlerDirectionLeft),
                      @"UP": @(ABI35_0_0RNGestureHandlerDirectionUp),
                      @"DOWN": @(ABI35_0_0RNGestureHandlerDirectionDown)
                      }
              };
}



@end
