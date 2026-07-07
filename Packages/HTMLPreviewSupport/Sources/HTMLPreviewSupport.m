#import "HTMLPreviewSupport.h"
#import <WebKit/WebKit.h>

@interface MRHTMLPreviewView ()

@property(nonatomic, strong) WKWebView *webView;

- (void)setupWebView;

@end


@implementation MRHTMLPreviewView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupWebView];
    }
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupWebView];
    }
    return self;
}

- (void)setupWebView {
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
    configuration.defaultWebpagePreferences.allowsContentJavaScript = YES;

    self.webView = [[WKWebView alloc] initWithFrame:self.bounds configuration:configuration];
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.webView];

    [NSLayoutConstraint activateConstraints:@[
        [self.webView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.webView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
}

- (void)loadHTMLString:(NSString *)html baseURL:(nullable NSURL *)baseURL {
    [self.webView loadHTMLString:html baseURL:baseURL];
}

@end
