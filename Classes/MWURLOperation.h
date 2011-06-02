//
//  MWURLOperation.h
//  A simple, self-contained class to download a thing.
//
//  Copyright (c) 2011, Mustacheware
//  All rights reserved.
//  
//  Redistribution and use in source and binary forms, with or without 
//  modification, are permitted provided that the following conditions  
//  are met:
//  
//  Redistributions of source code must retain the above copyright  
//  notice, this list of conditions and the following disclaimer. 
//  
//  Redistributions in binary form must reproduce the above copyright  
//  notice, this list of conditions and the following disclaimer in  
//  the documentation and/or other materials provided with the distribution. 
//  
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS  
//  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT  
//  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS  
//  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT  
//  HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,  
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED  
//  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR  
//  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  
//  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING  
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS  
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <Foundation/Foundation.h>
#import "MWTypes.h"

@interface MWURLOperation : NSOperation

@property (nonatomic, retain) id userInfo; // whatever you like, we don't touch it

// callback methods, all optional
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
@property (nonatomic, assign) MWURLOperationRequestType requestType; // defaults to GET
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

// connection state
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

// background threads
+(NSThread  *)backgroundThread;
+(NSRunLoop *)backgroundRunLoop;

@end

// These methods call through to the delegate and block callback APIs. You should
// not call them directly, but you can override them in subclasses.

@interface MWURLOperation (DelegateHandlers)

-(void)operationDidBegin;
-(void)operationReceivedData;
-(void)operationFinished;
-(BOOL)operationShouldRedirectToURL:(NSURL *)url;
-(void)operationHadError:(NSError *)error;

@end
