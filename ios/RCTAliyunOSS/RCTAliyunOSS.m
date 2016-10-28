//
//  RCTAliyunOSS.m
//  RCTAliyunOSS
//
//  Created by 李京生 on 2016/10/26.
//  Copyright © 2016年 lesonli. All rights reserved.
//

#import "RCTAliyunOSS.h"
#import "RCTLog.h"
#import "RCTEventDispatcher.h"
#import <AliyunOSSiOS/OSSService.h>


@implementation RCTAliyunOSS{
    
    OSSClient *client;
 
}

@synthesize bridge=_bridge;

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(enableOSSLog) {
    // 打开调试log
    [OSSLog enableLog];
    RCTLogInfo(@"OSSLog: 已开启");
}
// 由阿里云颁发的AccessKeyId/AccessKeySecret初始化客户端。
// 明文设置secret的方式建议只在测试时使用，
// 如果已经在bucket上绑定cname，将该cname直接设置到endPoint即可
RCT_EXPORT_METHOD(initWithKey:(NSString *)AccessKey
                  SecretKey:(NSString *)SecretKey
                  Endpoint:(NSString *)Endpoint){
    
    id<OSSCredentialProvider> credential = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:AccessKey secretKey:SecretKey];
    
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 3;
    conf.timeoutIntervalForRequest = 30;
    conf.timeoutIntervalForResource = 24 * 60 * 60;
    
    client = [[OSSClient alloc] initWithEndpoint:Endpoint credentialProvider:credential clientConfiguration:conf];
}

//通过签名方式初始化，需要服务端实现签名字符串，签名算法参考阿里云文档
RCT_EXPORT_METHOD(initWithSigner:(NSString *)AccessKey
                  Signature:(NSString *)Signature
                  Endpoint:(NSString *)Endpoint){
    
    // 自实现签名，可以用本地签名也可以远程加签
    id<OSSCredentialProvider> credential1 = [[OSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString *(NSString *contentToSign, NSError *__autoreleasing *error) {
        //NSString *signature = [OSSUtil calBase64Sha1WithData:contentToSign withSecret:@"<your secret key>"];
        if (Signature != nil) {
            *error = nil;
        } else {
            // construct error object
            *error = [NSError errorWithDomain:Endpoint code:OSSClientErrorCodeSignFailed userInfo:nil];
            return nil;
        }
        //return [NSString stringWithFormat:@"OSS %@:%@", @"<your access key>", signature];
        return [NSString stringWithFormat:@"OSS %@:%@", AccessKey, Signature];
    }];

    
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 1;
    conf.timeoutIntervalForRequest = 30;
    conf.timeoutIntervalForResource = 24 * 60 * 60;
    
    client = [[OSSClient alloc] initWithEndpoint:Endpoint credentialProvider:credential1 clientConfiguration:conf];
}

//异步下载
/*RCT_EXPORT_METHOD(downloadObjectAsync:(NSString *)BucketName
                  ObjectKey:(NSString *)ObjectKey){
    
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    // required
    request.bucketName = BucketName;
    request.objectKey = ObjectKey;
    
    //optional
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    // NSString * docDir = [self getDocumentDirectory];
    // request.downloadToFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"downloadfile"]];
    
    OSSTask * getTask = [client getObject:request];
    
    [getTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            NSLog(@"download object success!");
            OSSGetObjectResult * getResult = task.result;
            NSLog(@"download dota length: %lu", [getResult.downloadedData length]);
        } else {
            NSLog(@"download object failed, error: %@" ,task.error);
        }
        return nil;
    }];
}*/

//异步上传
RCT_EXPORT_METHOD(uploadObjectAsync:(NSString *)BucketName
                  SourceFile:(NSString *)SourceFile
                  OssFile:(NSString *)OssFile
                  UpdateDate:(NSString *)UpdateDate
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    
    // required fields
    put.bucketName = BucketName;
    put.objectKey = OssFile;
    //NSString * docDir = [self getDocumentDirectory];
    //put.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    put.uploadingFileURL = [NSURL fileURLWithPath:SourceFile];
    NSLog(@"uploadingFileURL: %@", put.uploadingFileURL);
    // optional fields
    put.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [self.bridge.eventDispatcher sendAppEventWithName:@"uploadProgress"
                                                     body:@{
                                                            @"bytesSent":[NSString stringWithFormat:@"%lld",bytesSent],
                                                            @"totalByteSent": [NSString stringWithFormat:@"%lld",totalByteSent],
                                                            @"totalBytesExpectedToSend": [NSString stringWithFormat:@"%lld",totalBytesExpectedToSend]}];
    };
    //put.contentType = @"";
    //put.contentMd5 = @"";
    //put.contentEncoding = @"";
    //put.contentDisposition = @"";
     put.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys: UpdateDate, @"Date", nil];
    
    OSSTask * putTask = [client putObject:put];
    
    [putTask continueWithBlock:^id(OSSTask *task) {
        NSLog(@"objectKey: %@", put.objectKey);
        if (!task.error) {
            NSLog(@"upload object success!");
            resolve(@YES);
        } else {
            NSLog(@"upload object failed, error: %@" , task.error);
            reject(@"-1", @"not respond this method", nil);
        }
        return nil;
    }];
}



@end