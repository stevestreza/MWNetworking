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