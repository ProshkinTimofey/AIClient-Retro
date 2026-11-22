//
//  AIJSONParser.m
//  AIClient
//

#import "AIJSONParser.h"

@implementation AIJSONParser

+ (NSDictionary *)parseJSON:(NSString *)string error:(NSError **)error {
    if (!string) {
        if (error) *error = [NSError errorWithDomain:@"AIJSONParser" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Empty string"}];
        return nil;
    }
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [self parseJSONData:data error:error];
}

+ (NSString *)stringifyJSON:(id)object pretty:(BOOL)pretty error:(NSError **)error {
    if (![NSJSONSerialization isValidJSONObject:object]) {
        if (error) *error = [NSError errorWithDomain:@"AIJSONParser" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid JSON object"}];
        return nil;
    }
    NSJSONWritingOptions options = pretty ? NSJSONWritingPrettyPrinted : 0;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:options error:error];
    if (!data) return nil;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (BOOL)isValidJSON:(NSString *)string {
    if (!string) return NO;
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [NSJSONSerialization isValidJSONObject:[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]];
}

+ (id)parseJSONData:(NSData *)data error:(NSError **)error {
    if (!data) {
        if (error) *error = [NSError errorWithDomain:@"AIJSONParser" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Empty data"}];
        return nil;
    }
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
}

@end