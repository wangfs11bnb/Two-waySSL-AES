//
//  WZURLRequest.m
//  Pods
//
//  Created by Wenqi Zhou on 12/29/15.
//
//

#import "WZURLRequest.h"
#import <CommonCrypto/CommonCryptor.h>

#define TIME_OUT 8.0f

static NSString *baseURLString = @"";
static NSString *AESKey = @"0123456789abcdef";

@implementation WZURLRequest

+ (void)setAPIBaseURL:(NSString *)urlString{
    baseURLString = urlString;
}

+ (void)setAESKey:(NSString *)key{
    AESKey = key;
}

+ (NSMutableURLRequest *)createRequestWithURLString:(NSString *)urlString body:(NSDictionary *)body method:(WZHTTPRequestMethodType)method
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", baseURLString, urlString]] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:TIME_OUT];
    switch (method) {
        case WZHTTPRequestMethodTypeSkip:
            break;
        default:
        case WZHTTPRequestMethodGet:
            [request setHTTPMethod:@"GET"];
            break;
        case WZHTTPRequestMethodPost:
            [request setHTTPMethod:@"POST"];
            break;
        case WZHTTPRequestMethodPut:
            [request setHTTPMethod:@"PUT"];
            break;
        case WZHTTPRequestMethodDelete:
            [request setHTTPMethod:@"DELETE"];
            break;
    }
//    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
//    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    NSData *jsonData = [WZURLRequest dictionaryToJSONData:body];
    if (jsonData) {
        [request setHTTPBody:jsonData];
    }
    NSLog(@"%@", [NSString stringWithFormat:@"Request:%@\nHeader:%@\n",request, [request allHTTPHeaderFields]]);
    return request;
}

+ (NSString *)dictionaryToJSONString:(NSDictionary *)body
{
    if (body) {
        NSString *jsonString = nil;
        // convert request dictionary to JSON data
        NSData *data = nil;
        NSError *error = nil;
        data = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
        if (error) {
            NSLog(@"ERROR: Caught %@ while create JSON data (%@)", error.localizedDescription, body);
            return nil;
        } else {
            jsonString = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
            
            NSLog(@"%@", [NSString stringWithFormat:@"body:%@\n",jsonString]);
            return jsonString;
        }
    }
    return nil;
}

+ (NSData *)dictionaryToJSONData:(NSDictionary *)body
{
    NSString *jsonString = [WZURLRequest dictionaryToJSONString:body];
    if (jsonString) {
        return [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    } else {
        return nil;
    }
}

+ (NSMutableData *)AESEncrypt:(NSDictionary *)body
{
    NSString *jsonString = [WZURLRequest dictionaryToJSONString:body];
    NSString *bodyString = [NSString stringWithFormat:@"~1Ba%@\n",jsonString];
    NSMutableData *data = [[NSMutableData alloc]initWithData:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    uint32_t crc32 = [WZURLRequest crc32:[bodyString dataUsingEncoding:NSASCIIStringEncoding]];
    NSData *crcData = [[NSData alloc]initWithBytes:&crc32 length:sizeof(crc32)];
    [data appendData:crcData];
    //NSData *result = [WZURLRequest AES128WithData:data];
    
    //Key to Data
    NSData *key = [AESKey dataUsingEncoding:NSUTF8StringEncoding];
    //NSLog(@"%@",key.bytes);
    // Init cryptor
    CCCryptorRef cryptor = NULL;
    
    
    // Alloc Data Out
    NSMutableData *cipherData = [NSMutableData dataWithLength:data.length + kCCBlockSizeAES128];
    
    //Empty IV: initialization vector
    NSData *iv =  [AESKey dataUsingEncoding:NSUTF8StringEncoding];
    
    //Create Cryptor
    CCCryptorStatus  create = CCCryptorCreateWithMode(kCCEncrypt,
                                                      kCCModeCFB8,
                                                      kCCAlgorithmAES128,
                                                      ccNoPadding,
                                                      iv.bytes, // can be NULL, because null is full of zeros
                                                      key.bytes,
                                                      key.length,
                                                      NULL,
                                                      0,
                                                      0,
                                                      kCCModeOptionCTR_BE,
                                                      &cryptor);
    
    if (create == kCCSuccess)
    {
        //alloc number of bytes written to data Out
        size_t outLength;
        
        //Update Cryptor
        CCCryptorStatus  update = CCCryptorUpdate(cryptor,
                                                  data.bytes,
                                                  data.length,
                                                  cipherData.mutableBytes,
                                                  cipherData.length,
                                                  &outLength);
        if (update == kCCSuccess)
        {
            //Cut Data Out with nedded length
            cipherData.length = outLength;
            
            //Final Cryptor
            CCCryptorStatus final = CCCryptorFinal(cryptor, //CCCryptorRef cryptorRef,
                                                   cipherData.mutableBytes, //void *dataOut,
                                                   cipherData.length, // size_t dataOutAvailable,
                                                   &outLength); // size_t *dataOutMoved)
            
            if (final == kCCSuccess)
            {
                //Release Cryptor
                //CCCryptorStatus release =
                CCCryptorRelease(cryptor ); //CCCryptorRef cryptorRef
            }
            return cipherData;
            
        }
        
    }
    else
    {
        //error
        
    }
    
    return nil;
}

+(uint32_t)crc32:(NSData *)input
{
    uint32_t seed = 0xFFFFFFFFL;
    uint32_t poly = 0xEDB88320L;
    uint32_t *pTable = malloc(sizeof(uint32_t) * 256);
    generateCRC32Table(pTable, poly);
    
    uint32_t crc    = seed;
    uint8_t *pBytes = (uint8_t *)[input bytes];
    NSUInteger length = [input length];
    
    while (length--)
    {
        crc = (crc>>8) ^ pTable[(crc & 0xFF) ^ *pBytes++];
    }
    
    free(pTable);
    return crc ^ 0xFFFFFFFFL;
}

void generateCRC32Table(uint32_t *pTable, uint32_t poly)
{
    for (uint32_t i = 0; i <= 255; i++)
    {
        uint32_t crc = i;
        
        for (uint32_t j = 8; j > 0; j--)
        {
            if ((crc & 1) == 1)
                crc = (crc >> 1) ^ poly;
            else
                crc >>= 1;
        }
        pTable[i] = crc;
    }
}

@end
