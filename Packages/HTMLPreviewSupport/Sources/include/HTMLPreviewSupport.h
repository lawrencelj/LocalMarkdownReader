#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#define MRPlatformView NSView
#else
#import <UIKit/UIKit.h>
#define MRPlatformView UIView
#endif

NS_ASSUME_NONNULL_BEGIN

@interface MRHTMLPreviewView : MRPlatformView

- (void)loadHTMLString:(NSString *)html baseURL:(nullable NSURL *)baseURL;

@end

NS_ASSUME_NONNULL_END
