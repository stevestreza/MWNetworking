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
        NSLog(@"Waiting for a run loop");
    }
    NSLog(@"We have a run loop");
    return sBackgroundRunLoop;
}

@end

@implementation MWURLOperation (NSURLConnectionDelegate)

-(NSURLRequest *)connection:(NSURLConnection *)connection
            willSendRequest:(NSURLRequest *)request
           redirectResponse:(NSURLResponse *)redirectResponse{
    NSLog(@"Beginning operation for %@",[request URL]);
	BOOL shouldReturn = [self operationShouldRedirectToURL:[request URL]];
	[self operationDidBegin];
	return (shouldReturn ? request : nil);
}


-(void)connection:(NSURLConnection *)conn didReceiveResponse:(NSHTTPURLResponse *)response{
	_response = [response retain];
    NSLog(@"Connection received response %i", (int)[response statusCode]);
	
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
    
    NSLog(@"Calling delegate that we're done: %@",self.delegate);
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

#pragma mark Base64 Support

static char encodingTable[64] = {
    'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
    'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
    'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
    'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/' };

@implementation NSData (Base64)

+ (NSData *) dataWithBase64EncodedString:(NSString *) string {
	NSData *result = [[NSData alloc] initWithBase64EncodedString:string];
	return [result autorelease];
}

- (id) initWithBase64EncodedString:(NSString *) string {
	NSMutableData *mutableData = nil;
    
	if( string ) {
		unsigned long ixtext = 0;
		unsigned long lentext = 0;
		unsigned char ch = 0;
		unsigned char inbuf[3], outbuf[4];
		short i = 0, ixinbuf = 0;
		BOOL flignore = NO;
		BOOL flendtext = NO;
		NSData *base64Data = nil;
		const unsigned char *base64Bytes = nil;
        
		// Convert the string to ASCII data.
		base64Data = [string dataUsingEncoding:NSASCIIStringEncoding];
		base64Bytes = [base64Data bytes];
		mutableData = [NSMutableData dataWithCapacity:[base64Data length]];
		lentext = [base64Data length];
        
		while( YES ) {
			if( ixtext >= lentext ) break;
			ch = base64Bytes[ixtext++];
			flignore = NO;
            
			if( ( ch >= 'A' ) && ( ch <= 'Z' ) ) ch = ch - 'A';
			else if( ( ch >= 'a' ) && ( ch <= 'z' ) ) ch = ch - 'a' + 26;
			else if( ( ch >= '0' ) && ( ch <= '9' ) ) ch = ch - '0' + 52;
			else if( ch == '+' ) ch = 62;
			else if( ch == '=' ) flendtext = YES;
			else if( ch == '/' ) ch = 63;
			else flignore = YES; 
            
			if( ! flignore ) {
				short ctcharsinbuf = 3;
				BOOL flbreak = NO;
                
				if( flendtext ) {
					if( ! ixinbuf ) break;
					if( ( ixinbuf == 1 ) || ( ixinbuf == 2 ) ) ctcharsinbuf = 1;
					else ctcharsinbuf = 2;
					ixinbuf = 3;
					flbreak = YES;
				}
                
				inbuf [ixinbuf++] = ch;
                
				if( ixinbuf == 4 ) {
					ixinbuf = 0;
					outbuf [0] = ( inbuf[0] << 2 ) | ( ( inbuf[1] & 0x30) >> 4 );
					outbuf [1] = ( ( inbuf[1] & 0x0F ) << 4 ) | ( ( inbuf[2] & 0x3C ) >> 2 );
					outbuf [2] = ( ( inbuf[2] & 0x03 ) << 6 ) | ( inbuf[3] & 0x3F );
                    
					for( i = 0; i < ctcharsinbuf; i++ ) 
						[mutableData appendBytes:&outbuf[i] length:1];
				}
                
				if( flbreak )  break;
			}
		}
	}
    
	self = [self initWithData:mutableData];
	return self;
}

- (NSString *) base64EncodingWithLineLength:(unsigned int) lineLength {
	const unsigned char	*bytes = [self bytes];
	NSMutableString *result = [NSMutableString stringWithCapacity:[self length]];
	unsigned long ixtext = 0;
	unsigned long lentext = [self length];
	long ctremaining = 0;
	unsigned char inbuf[3], outbuf[4];
	short i = 0;
	short charsonline = 0, ctcopy = 0;
	unsigned long ix = 0;
    
	while( YES ) {
		ctremaining = lentext - ixtext;
		if( ctremaining <= 0 ) break;
        
		for( i = 0; i < 3; i++ ) {
			ix = ixtext + i;
			if( ix < lentext ) inbuf[i] = bytes[ix];
			else inbuf [i] = 0;
		}
        
		outbuf [0] = (inbuf [0] & 0xFC) >> 2;
		outbuf [1] = ((inbuf [0] & 0x03) << 4) | ((inbuf [1] & 0xF0) >> 4);
		outbuf [2] = ((inbuf [1] & 0x0F) << 2) | ((inbuf [2] & 0xC0) >> 6);
		outbuf [3] = inbuf [2] & 0x3F;
		ctcopy = 4;
        
		switch( ctremaining ) {
            case 1: 
                ctcopy = 2; 
                break;
            case 2: 
                ctcopy = 3; 
                break;
		}
        
		for( i = 0; i < ctcopy; i++ )
			[result appendFormat:@"%c", encodingTable[outbuf[i]]];
        
		for( i = ctcopy; i < 4; i++ )
			[result appendFormat:@"%c",'='];
        
		ixtext += 3;
		charsonline += 4;
        
		if( lineLength > 0 ) {
			if (charsonline >= lineLength) {
				charsonline = 0;
				[result appendString:@"\n"];
			}
		}
	}
    
	return result;
}

@end