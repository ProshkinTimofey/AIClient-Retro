//
//  AIJSONParser.h
//  AIClient
//

#import <Foundation/Foundation.h>

@interface AIJSONParser : NSObject

+ (NSDictionary *)parseJSON:(NSString *)string error:(NSError **)error;
+ (NSString *)stringifyJSON:(id)object pretty:(BOOL)pretty error:(NSError **)error;
+ (BOOL)isValidJSON:(NSString *)string;
+ (id)parseJSONData:(NSData *)data error:(NSError **)error;

@end