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