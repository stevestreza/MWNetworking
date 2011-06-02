//
//  MWURLOperation.m
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

#import "MWURLOperation.h"
#import "NSData+Base64.h"

#if TARGET_OS_IPHONE
#define kMWURLOperationRunLoopMode NSDefaultRunLoopMode
#else
#define kMWURLOperationRunLoopMode NSConnectionReplyMode
#endif


@interface MWURLOperation (Private)

+(NSMutableDictionary *)_allObjectParsers;
+(NSMutableDictionary *)_allDataParsers;
-(void)_startConnection;

@end


@implementation MWURLOperation

@synthesize 
userInfo=_userInfo, 

delegate=_delegate, 
didBeginHandler=_didBeginHandler,
didReceiveDataHandler=_didReceiveDataHandler,
didFinishHandler=_didFinishHandler,
shouldRedirectHandler=_shouldRedirectHandler,
didErrorHandler=_didErrorHandler,
respondOnMainThread=_respondOnMainThread,

// request
request=_request, 
requestURL=_requestURL, 
requestTimeoutInterval=_requestTimeoutInterval,
requestType=_requestType,  
requestData=_requestData,
requestBody=_requestBody, 
requestHeaders=_requestHeaders, 

// response
response=_response,  
responseData=_responseData,
responseBody=_responseBody,
responseError=_responseError,
responseExpectedSize=_responseExpectedSize,

// connection
connection=_connection,
connectionFinished=_connectionFinished,
connectionActive=_connectionActive, 
connectionStarted=_connectionStarted,
connectionIsSynchronous=_connectionIsSynchronous;

static NSThread *sBackgroundThread;
static NSRunLoop *sBackgroundRunLoop;
static NSUInteger sRunningOperationCount = 0;

#pragma mark NSObject methods

-(id)initWithRequest:(NSURLRequest *)request{
	if((self = [self initWithURL:[request URL]])){
		_request = [request copy];
	}
	return self;
}

- (id)initWithURL:(NSURL *)url{
    self = [super init];
    if (self) {
        _requestURL = [url copy];
        _request = nil;

        _connectionActive = _connectionStarted = _connectionFinished = NO;
        _respondOnMainThread = YES;
    }
    
    return self;
}

- (void)dealloc
{
#define MWRelease(_item) do{ [(NSObject *)(_item) release], _item = nil; }while(0)
    MWRelease(_userInfo);
    MWRelease(_delegate);
    MWRelease(_didBeginHandler);
    MWRelease(_didFinishHandler);
    MWRelease(_shouldRedirectHandler);
    MWRelease(_didErrorHandler);
    MWRelease(_request);
    MWRelease(_requestURL);
    MWRelease(_requestData);
    MWRelease(_requestBody);
    MWRelease(_requestHeaders);
    MWRelease(_response);
    MWRelease(_responseData);
    MWRelease(_responseBody);
    MWRelease(_responseError);
    MWRelease(_connection);
    
    [super dealloc];
}

#pragma mark NSURLOperation Methods

-(void)main{
    dispatch_sync(dispatch_get_main_queue(), ^{
        sRunningOperationCount++;
    });

    [super main];
    
    [self _startConnection];
}

-(void)_finish{
    [self willChangeValueForKey:@"isFinished"];
    _connectionFinished = YES;
    [self didChangeValueForKey:@"isFinished"];

    dispatch_sync(dispatch_get_main_queue(), ^{
        sRunningOperationCount--;
    });
}

-(void)cancel{
    [super cancel];
    
    if(self.connection){
        [self.connection cancel];
    }
    
    [self _finish];
}

-(BOOL)isConcurrent{
    return YES;
}

-(BOOL)isExecuting{
    return self.connectionStarted && self.connectionActive && !self.connectionFinished;
}

-(BOOL)isFinished{
    return self.connectionFinished;
}

#pragma mark Request Methods

-(void)setUsername:(NSString *)username password:(NSString *)password{
	if (username && password) {
		// Set header for HTTP Basic authentication explicitly, to avoid problems with proxies and other intermediaries
		NSString *authStr = [NSString stringWithFormat:@"%@:%@", username, password];
		NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
		NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodingWithLineLength:80]];
		[self setValue:authValue forHeader:@"Authorization"];
	}	
}

-(void)setValue:(id)value forHeader:(NSString *)headerKey{
    if(self.connectionStarted) return;
    
	if(!_requestHeaders){
		_requestHeaders = [[NSMutableDictionary alloc] init];
	}
    NSAssert(_requestHeaders != nil, @"MWURLOperation requestHeaders is nil");
	[self.requestHeaders setValue:value forKey:headerKey];
}

-(NSURLRequest *)request{
    if(!_request){
     	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.requestURL];
        [request setHTTPMethod:[self HTTPMethodName]];
        
        if(self.requestHeaders){
            NSArray *keys = [self.requestHeaders allKeys];
            for(NSString *key in keys){
                id value = [self.requestHeaders valueForKey:key];
                [request addValue:value forHTTPHeaderField:key];
            }
        }
        
        if(self.requestBody){
            [self parseRequestBody];
        }
        
        if(self.requestData){
            [request setHTTPBody:self.requestData];
        }
        
        if(self.requestTimeoutInterval){
            [request setTimeoutInterval:self.requestTimeoutInterval];
        }
        
        _request = request;
    }
    return _request;
}

-(NSURLConnection *)connection{
    if(!_connection){
        _connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
        [_connection scheduleInRunLoop:[[self class] backgroundRunLoop] forMode:kMWURLOperationRunLoopMode];
    }
    return _connection;
}

#pragma mark Response Methods

-(double)responsePercentComplete{
	return self.responseData.length / (double)self.responseExpectedSize;
}

-(NSString *)responseString{
    return [[[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding] autorelease];
}

-(NSDictionary *)responseHeaders{
    return [[self response] allHeaderFields];
}

#pragma mark Data Parser Methods

// data parsing
+(void)addObjectParserForContentType:(NSString *)contentType parser:(MWURLOperationObjectParser)parser{
    NSMutableDictionary *allObjectParsers = [[self class] _allObjectParsers];
    [allObjectParsers setObject:parser forKey:contentType];
}

+(void)addDataParserForContentType:(NSString *)contentType parser:(MWURLOperationDataParser  )parser{
    NSMutableDictionary *allDataParsers = [[self class] _allDataParsers];
    [allDataParsers setObject:parser forKey:contentType];
}

+(NSData *)dataForObject:(id)object withContentType:(NSString *)contentType{
    if(!object || !contentType) return nil;
    NSData *data = nil;
    
    MWURLOperationObjectParser parser = [[[self class] _allObjectParsers] objectForKey:contentType];
    if(parser){
        data = parser(object, contentType);
    }
    
    return data;
}

+(id)objectForData:(NSData *)data withContentType:(NSString *)contentType{
    if(!data || !contentType) return nil;
    
    id object = data;
    
    MWURLOperationDataParser parser = [[[self class] _allDataParsers] objectForKey:contentType];
    if(parser){
        object = parser(object, contentType);
    }
    
    return object;
}

-(NSData *)parseRequestBody{
    NSString *contentType = [[self responseHeaders] objectForKey:@"Content-Type"];
    NSData *data = [[self class] dataForObject:self.requestBody withContentType:contentType];
    
    [self willChangeValueForKey:@"requestData"];
    _requestData = [data retain];
    [self  didChangeValueForKey:@"requestData"];
    
    return data;
}

-(id)parseResponseData{
    NSString *contentType = [[self responseHeaders] objectForKey:@"Content-Type"];
    NSData *data = [self responseData];
    id object = [[self class] objectForData:data withContentType:contentType];
    
    [self willChangeValueForKey:@"responseBody"];
    _responseBody = [object retain];
    [self  didChangeValueForKey:@"responseBody"];
    
    return object;
}

#pragma mark Misc

-(id)retain{
    return [super retain];
}

-(void)release{
    [super release];
}

+(NSString *)HTTPMethodNameForRequestType:(MWURLOperationRequestType)requestType{
	switch (requestType) {
		case MWURLOperationRequestTypeGET:
			return @"GET";
			break;
		case MWURLOperationRequestTypePOST:
			return @"POST";
			break;
		case MWURLOperationRequestTypePUT:
			return @"PUT";
			break;
		case MWURLOperationRequestTypeDELETE:
			return @"DELETE";
			break;
		case MWURLOperationRequestTypeHEAD:
			return @"HEAD";
			break;
		default:
			break;
	}
	return @"GET";
}

-(NSString *)HTTPMethodName{
    return [[self class] HTTPMethodNameForRequestType:self.requestType];
}

+(NSThread  *)backgroundThread{
    if(!sBackgroundThread){
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
        sBackgroundThread = [[NSThread alloc] initWithTarget:self selector:@selector(beginBackgroundThread) object:nil];
        [sBackgroundThread start];
//    });
    }
    return sBackgroundThread;
}

+(void)beginBackgroundThread{
    NSAutoreleasePool *outerPool = [NSAutoreleasePool new];

    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    sBackgroundRunLoop = [runLoop retain];
    
    NSThread *currentThread = [NSThread currentThread];
    while(![currentThread isCancelled] && sRunningOperationCount){
        NSAutoreleasePool *innerPool = [NSAutoreleasePool new];
        [runLoop runMode:kMWURLOperationRunLoopMode beforeDate:[NSDate distantFuture]];   
        [innerPool release];
    }
    
    [outerPool release];
    
    [sBackgroundRunLoop release], sBackgroundRunLoop = nil;
    [sBackgroundThread release], sBackgroundThread = nil;
}

+(NSRunLoop *)backgroundRunLoop{
    [self backgroundThread];
    while(!sBackgroundRunLoop){
        usleep(1000);
    }
    return sBackgroundRunLoop;
}

@end

@implementation MWURLOperation (NSURLConnectionDelegate)

-(NSURLRequest *)connection:(NSURLConnection *)connection
            willSendRequest:(NSURLRequest *)request
           redirectResponse:(NSURLResponse *)redirectResponse{
	BOOL shouldReturn = [self operationShouldRedirectToURL:[request URL]];
	[self operationDidBegin];
	return (shouldReturn ? request : nil);
}


-(void)connection:(NSURLConnection *)conn didReceiveResponse:(NSHTTPURLResponse *)response{
	_response = [response retain];
	
	if([response statusCode] == 303 && [[response allHeaderFields] valueForKey:@"Location"]){
		return;
	}
	_responseExpectedSize = [response expectedContentLength];
	if(!_responseData){
		if(_responseExpectedSize == -1){
			_responseData = [[NSMutableData alloc] init];
		}else{
			_responseData = [[NSMutableData alloc] initWithCapacity:(NSUInteger)_responseExpectedSize];	
		}
	}
	
	[self willChangeValueForKey:@"connectionActive"];
	_connectionActive = YES;
	[self  didChangeValueForKey:@"connectionActive"];
}

- (void)connection:(NSURLConnection*)connection
  didFailWithError:(NSError*)deadError{
	_responseError = [deadError copy];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:kMWURLOperationDidFinishDownloadingNotification object:self];
    
	NSLog(@"MWURLOperation Error: %@",self.responseError);
	[self operationHadError:self.responseError];
    
	[self willChangeValueForKey:@"isExecuting"];
	[self willChangeValueForKey:@"connectionFinished"];
	_connectionActive = YES;
	[self  didChangeValueForKey:@"connectionFinished"];
	[self  didChangeValueForKey:@"isExecuting"];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)theData{
	NSMutableData *objectData = (NSMutableData *)self.responseData;
	
	[self willChangeValueForKey:@"responsePercentComplete"];
	[self willChangeValueForKey:@"responseData"];
	[objectData appendData:theData];
	[self  didChangeValueForKey:@"responseData"];
	[self  didChangeValueForKey:@"responsePercentComplete"];
    
//    NSLog(@"Received %i/%i bytes: %0.1f%% complete", [theData length], [objectData length],(100 * [objectData length]) / (double)self.responseExpectedSize);
	[self operationReceivedData];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection{
	[self parseResponseData];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kMWURLOperationDidFinishDownloadingNotification object:self];
    
    //	NSLog(@"Calling delegate that we're done: %@",mDelegate);
	[self operationFinished];
	
	[self willChangeValueForKey:@"isExecuting"];
	[self willChangeValueForKey:@"isFinished"];
	[self willChangeValueForKey:@"connectionFinished"];
	[self willChangeValueForKey:@"connectionActive"];
	_connectionActive = NO;
	[self  didChangeValueForKey:@"connectionActive"];
	[self  didChangeValueForKey:@"connectionFinished"];
	[self  didChangeValueForKey:@"isFinished"];
	[self  didChangeValueForKey:@"isExecuting"];
    
    [self _finish];
}

- (void)connection:(NSURLConnection *)connection
   didSendBodyData:(NSInteger)bytesWritten
 totalBytesWritten:(NSInteger)totalBytesWritten
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite{
	printf("Upload %0.2f%% complete\n",(100.*totalBytesWritten/(double)totalBytesExpectedToWrite));
}

@end

@implementation MWURLOperation (DelegateHandlers)

-(void)operationDidBegin{
    if(self.respondOnMainThread && ![NSThread isMainThread]){
        [self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone: NO];
        return;
    }
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(operationDidBegin:)]){
		[self.delegate operationDidBegin:self];
	}	
	
	if(self.didBeginHandler){
		self.didBeginHandler(self);
	}
}

-(void)operationReceivedData{
    if(self.respondOnMainThread && ![NSThread isMainThread]){
        [self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone: NO];
        return;
    }

    if(self.delegate && [self.delegate respondsToSelector:@selector(operationReceivedData:)]){
		[self.delegate operationReceivedData:self];
	}	
    
	if(self.didReceiveDataHandler){
		self.didReceiveDataHandler(self);
	}
}

-(void)operationFinished{
    if(self.respondOnMainThread && ![NSThread isMainThread]){
        [self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone: NO];
        return;
    }

    if(self.delegate && [self.delegate respondsToSelector:@selector(operationFinished:)]){
		[self.delegate operationFinished:self];
	}	
    
	if(self.didFinishHandler){
		self.didFinishHandler(self);
	}
}

-(BOOL)operationShouldRedirectToURL:(NSURL *)aURL{
    __block MWURLOperation *this = self;
	__block BOOL shouldReturn = YES;
    dispatch_sync(dispatch_get_main_queue(), ^{
        if(this.delegate && [this.delegate respondsToSelector:@selector(operation:shouldRedirectToURL:)]){
            shouldReturn = [this.delegate operation:this shouldRedirectToURL:aURL];
        }	
        
        if(this.shouldRedirectHandler){
            shouldReturn = this.shouldRedirectHandler(this, aURL);
        }
    });
	return shouldReturn;
}

-(void)operationHadError:(NSError *)error{
    if(self.respondOnMainThread && ![NSThread isMainThread]){
        [self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone: NO];
        return;
    }
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(operation:hadError:)]){
		[self.delegate operation:self hadError:error];
	}
    
	if(self.didErrorHandler){
		self.didErrorHandler(self, error);
	}
}

@end

@implementation MWURLOperation (Private)

+(NSMutableDictionary *)_allObjectParsers{
    static NSMutableDictionary *sAllObjectParsers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sAllObjectParsers = [[NSMutableDictionary alloc] init];
    });
    return sAllObjectParsers;
}

+(NSMutableDictionary *)_allDataParsers{
    static NSMutableDictionary *sAllDataParsers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sAllDataParsers = [[NSMutableDictionary alloc] init];
    });
    return sAllDataParsers;
}

-(void)_startConnection{
    if(self.connectionStarted || self.connectionActive || self.connectionFinished) return;
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"connectionStarted"];
    _connectionStarted = YES;
    [self  didChangeValueForKey:@"connectionStarted"];
    [self  didChangeValueForKey:@"isExecuting"];
    
    [[self connection] start];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMWURLOperationDidBeginDownloadingNotification object:self];
}

@end