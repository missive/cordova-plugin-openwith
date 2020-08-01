#import <UIKit/UIKit.h>
#import <Social/Social.h>
#import "ShareViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface ShareViewController : SLComposeServiceViewController <UIAlertViewDelegate> {
    NSFileManager *_fileManager;
    NSUserDefaults *_userDefaults;
    int _verbosityLevel;
}
@property (nonatomic,retain) NSFileManager *fileManager;
@property (nonatomic,retain) NSUserDefaults *userDefaults;
@property (nonatomic) int verbosityLevel;
@end

/*
 * Constants
 */

#define VERBOSITY_DEBUG  0
#define VERBOSITY_INFO  10
#define VERBOSITY_WARN  20
#define VERBOSITY_ERROR 30

@implementation ShareViewController

@synthesize fileManager = _fileManager;
@synthesize userDefaults = _userDefaults;
@synthesize verbosityLevel = _verbosityLevel;

- (void) log:(int)level message:(NSString*)message {
    if (level >= self.verbosityLevel) {
        NSLog(@"[ShareViewController.m]%@", message);
    }
}

- (void) debug:(NSString*)message { [self log:VERBOSITY_DEBUG message:message]; }
- (void) info:(NSString*)message { [self log:VERBOSITY_INFO message:message]; }
- (void) warn:(NSString*)message { [self log:VERBOSITY_WARN message:message]; }
- (void) error:(NSString*)message { [self log:VERBOSITY_ERROR message:message]; }

- (void) setup {
    [self debug:@"[setup]"];
    
    self.fileManager = [NSFileManager defaultManager];
    self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:SHAREEXT_GROUP_IDENTIFIER];
    self.verbosityLevel = [self.userDefaults integerForKey:@"verbosityLevel"];
}

- (BOOL) isContentValid {
    return YES;
}

- (void) openURL:(nonnull NSURL *)url {
    SEL selector = NSSelectorFromString(@"openURL:options:completionHandler:");
    
    UIResponder* responder = self;
    while ((responder = [responder nextResponder]) != nil) {
        
        if([responder respondsToSelector:selector] == true) {
            NSMethodSignature *methodSignature = [responder methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
            
            void (^completion)(BOOL success) = ^void(BOOL success) {};
            
            if (@available(iOS 13.0, *)) {
                UISceneOpenExternalURLOptions * options = [[UISceneOpenExternalURLOptions alloc] init];
                options.universalLinksOnly = false;
                
                [invocation setTarget: responder];
                [invocation setSelector: selector];
                [invocation setArgument: &url atIndex: 2];
                [invocation setArgument: &options atIndex:3];
                [invocation setArgument: &completion atIndex: 4];
                [invocation invoke];
                break;
            } else {
                NSDictionary<NSString *, id> *options = [NSDictionary dictionary];
                
                [invocation setTarget: responder];
                [invocation setSelector: selector];
                [invocation setArgument: &url atIndex: 2];
                [invocation setArgument: &options atIndex:3];
                [invocation setArgument: &completion atIndex: 4];
                [invocation invoke];
                break;
            }
        }
    }
}

- (void) viewDidAppear:(BOOL)animated {
    [self.view endEditing:YES];
    
    [self setup];
    [self debug:@"[viewDidAppear]"];
    
    __block int remainingAttachments = ((NSExtensionItem*)self.extensionContext.inputItems[0]).attachments.count;
    __block NSMutableArray *items = [[NSMutableArray alloc] init];
    __block NSDictionary *results = @{
        @"text" : self.contentText,
        @"items": items,
    };
    
    NSString *lastDataType = @"";
    
    for (NSItemProvider* itemProvider in ((NSExtensionItem*)self.extensionContext.inputItems[0]).attachments) {
        [self debug:[NSString stringWithFormat:@"item provider registered indentifiers = %@", itemProvider.registeredTypeIdentifiers]];
        NSArray *registeredTypeIdentifiers = itemProvider.registeredTypeIdentifiers;
        
        // MOVIE
        if ([itemProvider hasItemConformingToTypeIdentifier:@"public.movie"]) {
            [self debug:[NSString stringWithFormat:@"item provider = %@", itemProvider]];
            
            
            lastDataType = [NSString stringWithFormat:@"FILE"];
            
            [itemProvider loadItemForTypeIdentifier:@"public.movie" options:nil completionHandler: ^(NSURL* item, NSError *error) {
                NSString *fileUrl = [self saveFileToAppGroupFolder:item];
                NSString *suggestedName = item.lastPathComponent;
                
                NSString *uti = @"public.movie";
                NSString *registeredType = nil;
                
                if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                    registeredType = itemProvider.registeredTypeIdentifiers[0];
                } else {
                    registeredType = uti;
                }
                
                NSString *mimeType =  [self mimeTypeFromUti:registeredType];
                NSDictionary *dict = @{
                    @"text" : self.contentText,
                    @"fileUrl" : fileUrl,
                    @"uti"  : uti,
                    @"utis" : itemProvider.registeredTypeIdentifiers,
                    @"name" : suggestedName,
                    @"type" : mimeType
                };
                
                [items addObject:dict];
                
                --remainingAttachments;
                if (remainingAttachments == 0) {
                    [self sendResults:results];
                }
            }];
        }
        
        // IMAGE
        else if ([itemProvider hasItemConformingToTypeIdentifier:@"public.image"]) {
            [self debug:[NSString stringWithFormat:@"item provider = %@", itemProvider]];
            
            
            lastDataType = [NSString stringWithFormat:@"FILE"];
            
            [itemProvider loadItemForTypeIdentifier:@"public.image" options:nil completionHandler: ^(id<NSSecureCoding> data, NSError *error) {
                NSLog(@"%@",data);
                if([(NSObject*)data isKindOfClass:[UIImage class]]) {
                    UIImage* image = (UIImage*) data;
                    if(image != nil) {
                        NSURL *targetUrl = [[self.fileManager containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER] URLByAppendingPathComponent:@"share.png"];
                        NSData * binaryImageData = UIImagePNGRepresentation(image);

                        BOOL done = [binaryImageData writeToFile:[targetUrl.absoluteString substringFromIndex:6] atomically:YES];
                        NSString *uti = @"public.image";
                        NSString *registeredType = nil;
                                        
                        if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                                registeredType = itemProvider.registeredTypeIdentifiers[0];
                        } else {
                                registeredType = uti;
                        }
                                        
                        NSString *mimeType =  @"image/png";
                        NSString* fileUrl = targetUrl.absoluteString;
                        NSDictionary *dict = @{
                                @"text" : self.contentText,
                                @"fileUrl" : fileUrl,
                                @"uti"  : uti,
                                @"utis" : itemProvider.registeredTypeIdentifiers,
                                @"name" : @"share.png",
                                @"type" : mimeType
                        };
                        [items addObject:dict];
                    }
                    --remainingAttachments;
                    if (remainingAttachments == 0) {
                        [self sendResults:results];
                    }
                    return;
                }
                if([(NSObject*)data isKindOfClass:[NSURL class]]) {
                    NSURL* item = (NSURL*) data;
                    if( item == nil || error != nil) {
                        --remainingAttachments;
                        if (remainingAttachments == 0) {
                            [self sendResults:results];
                        }
                        return;
                    }
                    NSString *fileUrl = [self saveFileToAppGroupFolder:item];
                    NSString *suggestedName = item.lastPathComponent;
                    
                    NSString *uti = @"public.image";
                    NSString *registeredType = nil;
                    
                    if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                        registeredType = itemProvider.registeredTypeIdentifiers[0];
                    } else {
                        registeredType = uti;
                    }
                    
                    NSString *mimeType =  [self mimeTypeFromUti:registeredType];
                    NSDictionary *dict = @{
                        @"text" : self.contentText,
                        @"fileUrl" : fileUrl,
                        @"uti"  : uti,
                        @"utis" : itemProvider.registeredTypeIdentifiers,
                        @"name" : suggestedName,
                        @"type" : mimeType
                    };
                    
                    [items addObject:dict];
                    
                    --remainingAttachments;
                    if (remainingAttachments == 0) {
                        [self sendResults:results];
                    }
                } else {
                    --remainingAttachments;
                    if (remainingAttachments == 0) {
                        [self sendResults:results];
                    }
                }
            }];
        }
        
        // FILE
        else if ([itemProvider hasItemConformingToTypeIdentifier:@"public.file-url"]) {
            [self debug:[NSString stringWithFormat:@"item provider = %@", itemProvider]];
        
            
            lastDataType = [NSString stringWithFormat:@"FILE"];
            
            [itemProvider loadItemForTypeIdentifier:@"public.file-url" options:nil completionHandler: ^(id<NSSecureCoding> data, NSError *error) {
                NSLog(@"%@",data);
                if([(NSObject*)data isKindOfClass:[NSURL class]]) {
                    NSURL* item = (NSURL*) data;
                    if( item == nil || error != nil) {
                        --remainingAttachments;
                        if (remainingAttachments == 0) {
                            [self sendResults:results];
                        }
                        return;
                    }
                    NSString *fileUrl = [self saveFileToAppGroupFolder:item];
                    NSString *suggestedName = item.lastPathComponent;
                    
                    NSString *uti = @"public.file-url";
                    NSString *registeredType = nil;
                    
                    if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                        registeredType = itemProvider.registeredTypeIdentifiers[0];
                    } else {
                        registeredType = uti;
                    }
                    
                    NSString *mimeType =  [self mimeTypeFromUti:registeredType];
                    NSDictionary *dict = @{
                        @"text" : self.contentText,
                        @"fileUrl" : fileUrl,
                        @"uti"  : uti,
                        @"utis" : itemProvider.registeredTypeIdentifiers,
                        @"name" : suggestedName,
                        @"type" : mimeType
                    };
                    
                    [items addObject:dict];
                    
                    --remainingAttachments;
                    if (remainingAttachments == 0) {
                        [self sendResults:results];
                    }
                } else {
                    --remainingAttachments;
                    if (remainingAttachments == 0) {
                        [self sendResults:results];
                    }
                }
            }];
        }
        
        // URL
        else if ([itemProvider hasItemConformingToTypeIdentifier:@"public.url"]) {
            [self debug:[NSString stringWithFormat:@"item provider = %@", itemProvider]];
            
          /*  if ([lastDataType length] > 0 && ![lastDataType isEqualToString:@"URL"]) {
                --remainingAttachments;
                continue;
            }*/
            
            lastDataType = [NSString stringWithFormat:@"URL"];
            
            [itemProvider loadItemForTypeIdentifier:@"public.url" options:nil completionHandler: ^(id<NSSecureCoding> data, NSError *error) {
                NSLog(@"%@",data);
                if( [(NSObject*)data isKindOfClass:[NSURL class]]) {
                    NSURL* item = (NSURL *) data;
                    if( item == nil || error != nil) {
                        --remainingAttachments;
                        if (remainingAttachments == 0) {
                            [self sendResults:results];
                        }
                        return;
                    }
                    [self debug:[NSString stringWithFormat:@"public.url = %@", item]];
                    
                    NSString *uti = @"public.url";
                    NSDictionary *dict = @{
                        @"data" : item.absoluteString,
                        @"uti": uti,
                        @"utis": itemProvider.registeredTypeIdentifiers,
                        @"name": @"",
                        @"type": [self mimeTypeFromUti:uti],
                    };
                    
                    [items addObject:dict];
                    
                    --remainingAttachments;
                    if (remainingAttachments == 0) {
                        [self sendResults:results];
                    } } else {
                        --remainingAttachments;
                        if (remainingAttachments == 0) {
                            [self sendResults:results];
                        }
                    }
            }];
        }
        
        // TEXT
        else if ([itemProvider hasItemConformingToTypeIdentifier:@"public.text"] ) {
            [self debug:[NSString stringWithFormat:@"item provider = %@", itemProvider]];
        
            
            lastDataType = [NSString stringWithFormat:@"TEXT"];
            
            [itemProvider loadItemForTypeIdentifier:@"public.text" options:nil completionHandler: ^(id<NSSecureCoding> data, NSError *error) {
                NSLog(@"%@",data);
                if( [(NSObject*)data isKindOfClass:[NSString class]]) {
                    NSString* item = (NSString *) data;
                    if( item == nil || error != nil) {
                        --remainingAttachments;
                        if (remainingAttachments == 0) {
                            [self sendResults:results];
                        }
                        return;
                    }
                    [self debug:[NSString stringWithFormat:@"public.text = %@", item]];
                    
                    NSString *uti = @"public.text";
                    NSDictionary *dict = @{
                        @"text" : self.contentText,
                        @"data" : item,
                        @"uti": uti,
                        @"utis": itemProvider.registeredTypeIdentifiers,
                        @"name": @"",
                        @"type": [self mimeTypeFromUti:uti],
                    };
                    
                    [items addObject:dict];
                    
                    --remainingAttachments;
                    if (remainingAttachments == 0) {
                        [self sendResults:results];
                    }
                }
            }];
        }
        else if([itemProvider hasItemConformingToTypeIdentifier:@"public.plain-text"]) {
            [self debug:[NSString stringWithFormat:@"item provider = %@", itemProvider]];
            [itemProvider loadItemForTypeIdentifier:@"public.plain-text" options:nil completionHandler: ^(id<NSSecureCoding> data, NSError *error) {
                NSLog(@"%@",data);
                if( [(NSObject*)data isKindOfClass:[NSString class]]) {
                    NSString* item = (NSString *) data;
                    if( item == nil || error != nil) {
                        --remainingAttachments;
                        if (remainingAttachments == 0) {
                            [self sendResults:results];
                        }
                        return;
                    }
                    [self debug:[NSString stringWithFormat:@"public.plain-text = %@", item]];
                    
                    NSString *uti = @"public.plain-text";
                    NSDictionary *dict = @{
                        @"text" : self.contentText,
                        @"data" : item,
                        @"uti": uti,
                        @"utis": itemProvider.registeredTypeIdentifiers,
                        @"name": @"",
                        @"type": [self mimeTypeFromUti:uti],
                    };
                    
                    [items addObject:dict];
                    
                    --remainingAttachments;
                    if (remainingAttachments == 0) {
                        [self sendResults:results];
                    }
                }
            }];
        }
        // Unhandled data type
        else {
            --remainingAttachments;
            if (remainingAttachments == 0) {
                [self sendResults:results];
            }
        }
    }
}

- (void) sendResults: (NSDictionary*)results {
    [self.userDefaults setObject:results forKey:@"shared"];
    [self.userDefaults synchronize];
    
    // Emit a URL that opens the cordova app
    NSString *url = [NSString stringWithFormat:@"%@://shared", SHAREEXT_URL_SCHEME];
    [self openURL:[NSURL URLWithString:url]];
    
    // Shut down the extension
    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
}

- (void) didSelectPost {
    [self debug:@"[didSelectPost]"];
}

- (NSArray*) configurationItems {
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    return @[];
}

- (NSString *) mimeTypeFromUti: (NSString*)uti {
    if (uti == nil) { return nil; }
    
    CFStringRef cret = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)uti, kUTTagClassMIMEType);
    NSString *ret = (__bridge_transfer NSString *)cret;
    
    return ret == nil ? uti : ret;
}

- (NSString *) saveFileToAppGroupFolder: (NSURL*)url {
    if( url == nil) {
        return @"";
    }
    NSURL *targetUrl = [[self.fileManager containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER] URLByAppendingPathComponent:url.lastPathComponent];
    [self.fileManager copyItemAtURL:url toURL:targetUrl error:nil];
    
    return targetUrl.absoluteString;
}

@end
