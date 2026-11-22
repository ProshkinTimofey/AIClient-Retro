//
//  AIProviderProtocol.m
//  AIClient
//

#import "AIProviderProtocol.h"
#import "AIOpenAIProvider.h"
#import "AIAnthropicProvider.h"
#import "AIGeminiProvider.h"
#import "AINVIDIAProvider.h"

static AIProviderFactory *_sharedFactory = nil;

@implementation AIProviderFactory

+ (instancetype)sharedFactory {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedFactory = [[self alloc] init];
    });
    return _sharedFactory;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _providerClasses = [NSMutableDictionary dictionary];
        // Register built-in providers
        [self registerProviderClass:[AIOpenAIProvider class] forType:AIProviderTypeOpenAI];
        [self registerProviderClass:[AIAnthropicProvider class] forType:AIProviderTypeAnthropic];
        [self registerProviderClass:[AIGeminiProvider class] forType:AIProviderTypeGemini];
        [self registerProviderClass:[AINVIDIAProvider class] forType:AIProviderTypeNVIDIA];
    }
    return self;
}

- (id<AIProviderProtocol>)createProviderOfType:(AIProviderType)type {
    Class providerClass = _providerClasses[@(type)];
    if (providerClass && [providerClass conformsToProtocol:@protocol(AIProviderProtocol)]) {
        return [[providerClass alloc] init];
    }
    return nil;
}

- (id<AIProviderProtocol>)createProviderWithIdentifier:(NSString *)identifier {
    for (NSNumber *typeNum in _providerClasses) {
        Class cls = _providerClasses[typeNum];
        id<AIProviderProtocol> instance = [[cls alloc] init];
        if ([instance.providerName isEqualToString:identifier]) {
            return instance;
        }
    }
    return nil;
}

- (void)registerProviderClass:(Class)providerClass forType:(AIProviderType)type {
    if ([providerClass conformsToProtocol:@protocol(AIProviderProtocol)]) {
        _providerClasses[@(type)] = providerClass;
    }
}

- (NSArray<AIProviderType>)registeredProviderTypes {
    return [_providerClasses.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
        return [a compare:b];
    }];
}

@end