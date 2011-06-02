//
//  MWURLOperation.h
//  A simple, self-contained class to download a thing.
//
//  Created by Steve Streza on 5/25/11.
//  Copyright 2011 Mustacheware. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MWURLOperation;

// callback-related APIs

#define kMWURLOperationDidBeginDownloadingNotification  @"kMWURLOperationDidBeginDownloadingNotification"
#define kMWURLOperationDidFinishDownloadingNotification @"kMWURLOperationDidFinishDownloadingNotification"

@protocol MWURLOperationDelegate <NSObject>

-(void)operationDidBegin:(MWURLOperation *)operation;
-(void)operationReceivedData:(MWURLOperation *)operation;
-(void)operationFinished:(MWURLOperation *)operation;
-(BOOL)operation:(MWURLOperation *)operation shouldRedirectToURL:(NSURL *)url;
-(void)operation:(MWURLOperation *)operation hadError:(NSError *)error;

@end

typedef void (^MWURLOperationHandler)(MWURLOperation *operation);
typedef BOOL (^MWURLOperationRedirectHandler)(MWURLOperation *operation, NSURL *url);
typedef void (^MWURLOperationErrorHandler)(MWURLOperation *operation, NSError *error);

// data types

typedef NSData* (^MWURLOperationObjectParser) (id object, NSString *contentType);
typedef id      (^MWURLOperationDataParser)(NSData *data, NSString *contentType);

typedef long long MWURLOperationSize;

typedef enum {
	MWURLOperationRequestTypeGET,
	MWURLOperationRequestTypePOST,
	MWURLOperationRequestTypePUT,
	MWURLOperationRequestTypeDELETE,
	MWURLOperationRequestTypeHEAD,
} MWURLOperationRequestType;

@interface MWURLOperation : NSOperation

@property (nonatomic, retain) id userInfo; // whatever you like, we don't touch it

// callback methods
@property (nonatomic, assign) id<MWURLOperationDelegate> delegate;
@property (nonatomic, retain) MWURLOperationHandler didBeginHandler;
@property (nonatomic, retain) MWURLOperationHandler didReceiveDataHandler;
@property (nonatomic, retain) MWURLOperationHandler didFinishHandler;
@property (nonatomic, retain) MWURLOperationRedirectHandler shouldRedirectHandler;
@property (nonatomic, retain) MWURLOperationErrorHandler didErrorHandler;
@property (nonatomic, assign) BOOL respondOnMainThread;

// request data
@property (nonatomic, retain) NSURLRequest *request;
@property (nonatomic, readonly) NSURL *requestURL;
@property (nonatomic, assign) MWURLOperationRequestType requestType;
@property (nonatomic, retain) NSData *requestData;
@property (nonatomic, retain) id requestBody;
@property (nonatomic, retain) NSDictionary *requestHeaders;
@property (nonatomic, assign) NSTimeInterval requestTimeoutInterval;

// response data
@property (nonatomic, readonly) NSHTTPURLResponse *response;
@property (nonatomic, readonly) NSData *responseData;
@property (nonatomic, readonly) NSString *responseString;
@property (nonatomic, readonly) id responseBody;
@property (nonatomic, readonly) NSDictionary *responseHeaders;
@property (nonatomic, readonly) NSError *responseError;
@property (nonatomic, readonly) MWURLOperationSize responseExpectedSize;
@property (nonatomic, readonly) double responsePercentComplete;

// connection data
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, readonly) BOOL connectionStarted;
@property (nonatomic, readonly) BOOL connectionActive;
@property (nonatomic, readonly) BOOL connectionFinished;
@property (nonatomic, readonly) BOOL connectionIsSynchronous;

// creating an MWURLOperation
-(id)initWithURL:(NSURL *)url;
-(id)initWithRequest:(NSURLRequest *)request;

// request methods
-(void)setUsername:(NSString *)username password:(NSString *)password;
-(void)setValue:(id)value forHeader:(NSString *)headerKey;

// data parsing
+(void)addObjectParserForContentType:(NSString *)contentType parser:(MWURLOperationObjectParser)parser;
+(void)  addDataParserForContentType:(NSString *)contentType parser:(MWURLOperationDataParser  )parser;
+(NSData *)dataForObject:(id)object     withContentType:(NSString *)contentType;
+(id)      objectForData:(NSData *)data withContentType:(NSString *)contentType;

-(NSData *)parseRequestBody;
-(id)      parseResponseData;

// misc
+(NSString *)HTTPMethodNameForRequestType:(MWURLOperationRequestType)requestType;
-(NSString *)HTTPMethodName;

+(NSThread  *)backgroundThread;
+(NSRunLoop *)backgroundRunLoop;

@end

@interface MWURLOperation (DelegateHandlers)

-(void)operationDidBegin;
-(void)operationReceivedData;
-(void)operationFinished;
-(BOOL)operationShouldRedirectToURL:(NSURL *)url;
-(void)operationHadError:(NSError *)error;

@end
