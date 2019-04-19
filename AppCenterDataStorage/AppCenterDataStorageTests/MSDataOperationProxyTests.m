// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "MSBaseOptions.h"
#import "MSDBDocumentStore.h"
#import "MSDataOperationProxy.h"
#import "MSDataSourceError.h"
#import "MSDataStorageConstants.h"
#import "MSDataStoreErrors.h"
#import "MSDictionaryDocument.h"
#import "MSDocumentWrapperInternal.h"
#import "MSTestFrameworks.h"
#import "MSTokenResult.h"

@interface MSDataOperationProxyTests : XCTestCase

@property(nonatomic) MSDataOperationProxy *sut;
@property(nonatomic) id documentStoreMock;
@property(nonatomic) id reachability;
@property(nonatomic) NSError *dummyError;

@end

@implementation MSDataOperationProxyTests

- (void)setUp {
  [super setUp];

  // Init properties.
  _documentStoreMock = OCMClassMock([MSDBDocumentStore class]);
  _reachability = OCMPartialMock([MS_Reachability reachabilityForInternetConnection]);
  _sut = [[MSDataOperationProxy alloc] initWithDocumentStore:_documentStoreMock reachability:self.reachability];
  _dummyError = [NSError errorWithDomain:kMSACDataStoreErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Some dummy error"}];
}

- (void)tearDown {
  [super tearDown];

  [self.documentStoreMock stopMocking];
  [self.reachability stopMocking];
}

- (void)testInvalidOperation {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completed with error for invalid operation."];
  __block MSDocumentWrapper *wrapper;

  // When
  [self.sut performOperation:@"badOperation"
      documentId:@"documentId"
      documentType:[NSString class]
      document:nil
      baseOptions:nil
      cachedTokenBlock:^(MSCachedTokenCompletionHandler _Nonnull __unused handler) {
      }
      remoteDocumentBlock:^(MSDocumentWrapperCompletionHandler _Nonnull __unused handler) {
      }
      completionHandler:^(MSDocumentWrapper *_Nonnull document) {
        wrapper = document;
        [expectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertEqual(wrapper.documentId, @"documentId");
                                 XCTAssertEqual(wrapper.deserializedValue, nil);
                                 XCTAssertNotNil(wrapper.error);
                                 XCTAssertEqual(wrapper.error.error.code, MSACDataStoreLocalStoreError);
                               }];
}

- (void)testInvalidToken {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completed with error retrieving token."];
  __block MSDocumentWrapper *wrapper;

  // When
  [self.sut performOperation:kMSPendingOperationRead
      documentId:@"documentId"
      documentType:[NSString class]
      document:nil
      baseOptions:nil
      cachedTokenBlock:^(MSCachedTokenCompletionHandler _Nonnull handler) {
        handler(nil, self.dummyError);
      }
      remoteDocumentBlock:^(MSDocumentWrapperCompletionHandler _Nonnull __unused handler) {
      }
      completionHandler:^(MSDocumentWrapper *_Nonnull document) {
        wrapper = document;
        [expectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertEqual(wrapper.documentId, @"documentId");
                                 XCTAssertEqual(wrapper.deserializedValue, nil);
                                 XCTAssertEqual(wrapper.error.error.code, MSACDataStoreLocalStoreError);
                               }];
}

- (void)testRemoteOperationWhenNoDocumentInStoreAndDefaultTTL {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completed with remote document (default TTL)."];
  __block MSDocumentWrapper *remoteDocumentWrapper = [MSDocumentWrapper alloc];
  __block MSDocumentWrapper *wrapper;
  OCMStub([self.documentStoreMock readWithToken:OCMOCK_ANY documentId:OCMOCK_ANY documentType:OCMOCK_ANY])
      .andReturn([[MSDocumentWrapper alloc] initWithError:self.dummyError documentId:@"documentId"]);
  MSTokenResult *token = [MSTokenResult alloc];
  __block MSTokensResponse *tokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ token ]];

  // When
  [self.sut performOperation:kMSPendingOperationRead
      documentId:@"documentId"
      documentType:[NSString class]
      document:nil
      baseOptions:nil
      cachedTokenBlock:^(MSCachedTokenCompletionHandler _Nonnull handler) {
        handler(tokensResponse, nil);
      }
      remoteDocumentBlock:^(MSDocumentWrapperCompletionHandler _Nonnull handler) {
        handler(remoteDocumentWrapper);
      }
      completionHandler:^(MSDocumentWrapper *_Nonnull document) {
        wrapper = document;
        [expectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertEqual(wrapper, remoteDocumentWrapper);
                                 OCMVerify([self.documentStoreMock upsertWithToken:token
                                                                   documentWrapper:remoteDocumentWrapper
                                                                         operation:kMSPendingOperationRead
                                                                  deviceTimeToLive:kMSDataStoreTimeToLiveDefault]);
                               }];
}

- (void)testRemoteOperationWhenNoDocumentInStoreAndNoCache {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completed with remote document (no cache)."];
  __block MSDocumentWrapper *remoteDocumentWrapper = [MSDocumentWrapper alloc];
  __block MSDocumentWrapper *wrapper;
  OCMStub([self.documentStoreMock readWithToken:OCMOCK_ANY documentId:OCMOCK_ANY documentType:OCMOCK_ANY])
      .andReturn([[MSDocumentWrapper alloc] initWithError:self.dummyError documentId:@"documentId"]);
  OCMReject([[self.documentStoreMock ignoringNonObjectArgs] upsertWithToken:OCMOCK_ANY
                                                            documentWrapper:OCMOCK_ANY
                                                                  operation:OCMOCK_ANY
                                                           deviceTimeToLive:0]);
  MSTokenResult *token = [MSTokenResult alloc];
  __block MSTokensResponse *tokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ token ]];

  // When
  MSBaseOptions *options = [[MSBaseOptions alloc] initWithDeviceTimeToLive:kMSDataStoreTimeToLiveNoCache];
  [self.sut performOperation:kMSPendingOperationRead
      documentId:@"documentId"
      documentType:[NSString class]
      document:nil
      baseOptions:options
      cachedTokenBlock:^(MSCachedTokenCompletionHandler _Nonnull handler) {
        handler(tokensResponse, nil);
      }
      remoteDocumentBlock:^(MSDocumentWrapperCompletionHandler _Nonnull handler) {
        handler(remoteDocumentWrapper);
      }
      completionHandler:^(MSDocumentWrapper *_Nonnull document) {
        wrapper = document;
        [expectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertEqual(wrapper, remoteDocumentWrapper);
                                 OCMVerify([self.documentStoreMock deleteWithToken:token documentId:@"documentId"]);
                               }];
}

- (void)testRemoteOperationWhenNoDocumentInStoreAndCustomTTL {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completed with remote document (custom TTL)."];
  __block MSDocumentWrapper *remoteDocumentWrapper = [MSDocumentWrapper alloc];
  __block MSDocumentWrapper *wrapper;
  OCMStub([self.documentStoreMock readWithToken:OCMOCK_ANY documentId:OCMOCK_ANY documentType:OCMOCK_ANY])
      .andReturn([[MSDocumentWrapper alloc] initWithError:self.dummyError documentId:@"documentId"]);
  MSTokenResult *token = [MSTokenResult alloc];
  __block MSTokensResponse *tokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ token ]];

  // When
  NSInteger deviceTimeToLive = 100000;
  [self.sut performOperation:kMSPendingOperationRead
      documentId:@"documentId"
      documentType:[NSString class]
      document:nil
      baseOptions:[[MSBaseOptions alloc] initWithDeviceTimeToLive:deviceTimeToLive]
      cachedTokenBlock:^(MSCachedTokenCompletionHandler _Nonnull handler) {
        handler(tokensResponse, nil);
      }
      remoteDocumentBlock:^(MSDocumentWrapperCompletionHandler _Nonnull handler) {
        handler(remoteDocumentWrapper);
      }
      completionHandler:^(MSDocumentWrapper *_Nonnull document) {
        wrapper = document;
        [expectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertEqual(wrapper, remoteDocumentWrapper);
                                 OCMVerify([self.documentStoreMock upsertWithToken:token
                                                                   documentWrapper:remoteDocumentWrapper
                                                                         operation:kMSPendingOperationRead
                                                                  deviceTimeToLive:deviceTimeToLive]);
                               }];
}

- (void)testDeleteWhenUnsyncedCreateOperation {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completed with discarded create operation."];
  __block MSDocumentWrapper *cachedDocumentWrapper = [[MSDocumentWrapper alloc] initWithDeserializedValue:[MSDictionaryDocument alloc]
                                                                                                jsonValue:@""
                                                                                                partition:@"user"
                                                                                               documentId:@"documentId"
                                                                                                     eTag:nil
                                                                                          lastUpdatedDate:nil
                                                                                         pendingOperation:kMSPendingOperationCreate
                                                                                                    error:nil];
  __block MSDocumentWrapper *wrapper;
  OCMStub([self.documentStoreMock readWithToken:OCMOCK_ANY documentId:OCMOCK_ANY documentType:OCMOCK_ANY]).andReturn(cachedDocumentWrapper);
  OCMReject([[self.documentStoreMock ignoringNonObjectArgs] upsertWithToken:OCMOCK_ANY
                                                            documentWrapper:OCMOCK_ANY
                                                                  operation:OCMOCK_ANY
                                                           deviceTimeToLive:0]);
  MSTokenResult *token = [MSTokenResult alloc];
  __block MSTokensResponse *tokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ token ]];

  // When
  [self.sut performOperation:kMSPendingOperationDelete
      documentId:@"documentId"
      documentType:[NSString class]
      document:nil
      baseOptions:nil
      cachedTokenBlock:^(MSCachedTokenCompletionHandler _Nonnull handler) {
        handler(tokensResponse, nil);
      }
      remoteDocumentBlock:^(MSDocumentWrapperCompletionHandler _Nonnull __unused handler) {
      }
      completionHandler:^(MSDocumentWrapper *_Nonnull document) {
        wrapper = document;
        [expectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertNotEqual(wrapper, cachedDocumentWrapper);
                                 XCTAssertEqual(wrapper.documentId, cachedDocumentWrapper.documentId);
                                 XCTAssertEqual(wrapper.pendingOperation, kMSPendingOperationDelete);
                                 OCMVerify([self.documentStoreMock deleteWithToken:token documentId:@"documentId"]);
                               }];
}

- (void)testDeleteWhenUnsyncedReplaceOperation {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completed with discarded replace operation."];
  __block MSDocumentWrapper *cachedDocumentWrapper = [[MSDocumentWrapper alloc] initWithDeserializedValue:[MSDictionaryDocument alloc]
                                                                                                jsonValue:@""
                                                                                                partition:@"partition"
                                                                                               documentId:@"documentId"
                                                                                                     eTag:nil
                                                                                          lastUpdatedDate:nil
                                                                                         pendingOperation:kMSPendingOperationReplace
                                                                                                    error:nil];
  __block MSDocumentWrapper *wrapper;
  OCMStub([self.documentStoreMock readWithToken:OCMOCK_ANY documentId:OCMOCK_ANY documentType:OCMOCK_ANY]).andReturn(cachedDocumentWrapper);
  OCMReject([[self.documentStoreMock ignoringNonObjectArgs] upsertWithToken:OCMOCK_ANY
                                                            documentWrapper:OCMOCK_ANY
                                                                  operation:OCMOCK_ANY
                                                           deviceTimeToLive:0]);
  MSTokenResult *token = [MSTokenResult alloc];
  __block MSTokensResponse *tokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ token ]];

  // When
  [self.sut performOperation:kMSPendingOperationDelete
      documentId:@"documentId"
      documentType:[NSString class]
      document:nil
      baseOptions:nil
      cachedTokenBlock:^(MSCachedTokenCompletionHandler _Nonnull handler) {
        handler(tokensResponse, nil);
      }
      remoteDocumentBlock:^(MSDocumentWrapperCompletionHandler _Nonnull __unused handler) {
      }
      completionHandler:^(MSDocumentWrapper *_Nonnull document) {
        wrapper = document;
        [expectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertNotEqual(wrapper, cachedDocumentWrapper);
                                 XCTAssertEqual(wrapper.documentId, cachedDocumentWrapper.documentId);
                                 XCTAssertEqual(wrapper.pendingOperation, kMSPendingOperationDelete);
                                 OCMVerify([self.documentStoreMock deleteWithToken:token documentId:@"documentId"]);
                               }];
}

- (void)testReadOperationFailsWhenPendingDelete {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completed with failure pending local delete."];
  __block MSDocumentWrapper *cachedDocumentWrapper = [[MSDocumentWrapper alloc] initWithDeserializedValue:[MSDictionaryDocument alloc]
                                                                                                jsonValue:@""
                                                                                                partition:@"partition"
                                                                                               documentId:@"documentId"
                                                                                                     eTag:@""
                                                                                          lastUpdatedDate:nil
                                                                                         pendingOperation:kMSPendingOperationDelete
                                                                                                    error:nil];
  __block MSDocumentWrapper *wrapper;
  OCMStub([self.documentStoreMock readWithToken:OCMOCK_ANY documentId:OCMOCK_ANY documentType:OCMOCK_ANY]).andReturn(cachedDocumentWrapper);
  OCMReject([[self.documentStoreMock ignoringNonObjectArgs] upsertWithToken:OCMOCK_ANY
                                                            documentWrapper:OCMOCK_ANY
                                                                  operation:OCMOCK_ANY
                                                           deviceTimeToLive:0]);
  MSTokenResult *token = [MSTokenResult alloc];
  __block MSTokensResponse *tokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ token ]];

  // When
  [self.sut performOperation:kMSPendingOperationRead
      documentId:@"documentId"
      documentType:[NSString class]
      document:nil
      baseOptions:nil
      cachedTokenBlock:^(MSCachedTokenCompletionHandler _Nonnull handler) {
        handler(tokensResponse, nil);
      }
      remoteDocumentBlock:^(MSDocumentWrapperCompletionHandler _Nonnull __unused handler) {
      }
      completionHandler:^(MSDocumentWrapper *_Nonnull document) {
        wrapper = document;
        [expectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertNotNil(wrapper.error);
                                 XCTAssertEqual(wrapper.error.error.code, MSACDataStoreErrorDocumentNotFound);
                               }];
}

- (void)testLocalDeleteWhenCachedDocumentPresent {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completed with delete and local cached document."];
  __block MSDocumentWrapper *cachedDocumentWrapper = [[MSDocumentWrapper alloc] initWithDeserializedValue:[MSDictionaryDocument alloc]
                                                                                                jsonValue:@""
                                                                                                partition:@"partition"
                                                                                               documentId:@"documentId"
                                                                                                     eTag:@""
                                                                                          lastUpdatedDate:nil
                                                                                         pendingOperation:kMSPendingOperationRead
                                                                                                    error:nil];
  __block MSDocumentWrapper *wrapper;
  OCMStub([self.documentStoreMock readWithToken:OCMOCK_ANY documentId:OCMOCK_ANY documentType:OCMOCK_ANY]).andReturn(cachedDocumentWrapper);
  MSTokenResult *token = [MSTokenResult alloc];
  __block MSTokensResponse *tokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ token ]];

  // Simulate being offline.
  OCMStub([self.reachability currentReachabilityStatus]).andReturn(NotReachable);

  // When
  [self.sut performOperation:kMSPendingOperationDelete
      documentId:@"documentId"
      documentType:[NSString class]
      document:nil
      baseOptions:nil
      cachedTokenBlock:^(MSCachedTokenCompletionHandler _Nonnull handler) {
        handler(tokensResponse, nil);
      }
      remoteDocumentBlock:^(MSDocumentWrapperCompletionHandler _Nonnull __unused handler) {
      }
      completionHandler:^(MSDocumentWrapper *_Nonnull document) {
        wrapper = document;
        [expectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertNotEqual(wrapper, cachedDocumentWrapper);
                                 XCTAssertEqual(wrapper.documentId, cachedDocumentWrapper.documentId);
                                 XCTAssertEqual(wrapper.pendingOperation, kMSPendingOperationDelete);
                                 OCMVerify([self.documentStoreMock upsertWithToken:token
                                                                   documentWrapper:wrapper
                                                                         operation:kMSPendingOperationDelete
                                                                  deviceTimeToLive:kMSDataStoreTimeToLiveDefault]);
                               }];
}

- (void)testLocalCreateWhenCachedDocumentPresent {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completed with create and local cached document."];
  __block MSDocumentWrapper *cachedDocumentWrapper = [[MSDocumentWrapper alloc] initWithDeserializedValue:[MSDictionaryDocument alloc]
                                                                                                jsonValue:@""
                                                                                                partition:@"partition"
                                                                                               documentId:@"documentId"
                                                                                                     eTag:@""
                                                                                          lastUpdatedDate:nil
                                                                                         pendingOperation:kMSPendingOperationRead
                                                                                                    error:nil];
  __block MSDocumentWrapper *wrapper;
  OCMStub([self.documentStoreMock readWithToken:OCMOCK_ANY documentId:OCMOCK_ANY documentType:OCMOCK_ANY]).andReturn(cachedDocumentWrapper);
  MSTokenResult *token = [MSTokenResult alloc];
  __block MSTokensResponse *tokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ token ]];

  // Simulate being offline.
  OCMStub([self.reachability currentReachabilityStatus]).andReturn(NotReachable);

  // When
  NSMutableDictionary *dict = [NSMutableDictionary new];
  dict[@"key"] = @"value";
  [self.sut performOperation:kMSPendingOperationCreate
      documentId:@"documentId"
      documentType:[NSString class]
      document:[[MSDictionaryDocument alloc] initFromDictionary:dict]
      baseOptions:nil
      cachedTokenBlock:^(MSCachedTokenCompletionHandler _Nonnull handler) {
        handler(tokensResponse, nil);
      }
      remoteDocumentBlock:^(MSDocumentWrapperCompletionHandler _Nonnull __unused handler) {
      }
      completionHandler:^(MSDocumentWrapper *_Nonnull document) {
        wrapper = document;
        [expectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertNotEqual(wrapper, cachedDocumentWrapper);
                                 XCTAssertEqual(wrapper.documentId, cachedDocumentWrapper.documentId);
                                 XCTAssertEqual(wrapper.pendingOperation, kMSPendingOperationCreate);
                                 NSDictionary *actualDict = [wrapper.deserializedValue serializeToDictionary];
                                 XCTAssertEqual(actualDict[@"key"], @"value");
                                 OCMVerify([self.documentStoreMock upsertWithToken:token
                                                                   documentWrapper:wrapper
                                                                         operation:kMSPendingOperationCreate
                                                                  deviceTimeToLive:kMSDataStoreTimeToLiveDefault]);
                               }];
}

- (void)testLocalReplaceWhenCachedDocumentPresent {

  // If
  XCTestExpectation *expectation = [self expectationWithDescription:@"Completed with replace and local cached document."];
  __block MSDocumentWrapper *cachedDocumentWrapper = [[MSDocumentWrapper alloc] initWithDeserializedValue:[MSDictionaryDocument alloc]
                                                                                                jsonValue:@""
                                                                                                partition:@"partition"
                                                                                               documentId:@"documentId"
                                                                                                     eTag:@""
                                                                                          lastUpdatedDate:nil
                                                                                         pendingOperation:kMSPendingOperationRead
                                                                                                    error:nil];
  __block MSDocumentWrapper *wrapper;
  OCMStub([self.documentStoreMock readWithToken:OCMOCK_ANY documentId:OCMOCK_ANY documentType:OCMOCK_ANY]).andReturn(cachedDocumentWrapper);
  MSTokenResult *token = [MSTokenResult alloc];
  __block MSTokensResponse *tokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ token ]];

  // Simulate being offline.
  OCMStub([self.reachability currentReachabilityStatus]).andReturn(NotReachable);

  // When
  NSMutableDictionary *dict = [NSMutableDictionary new];
  dict[@"key"] = @"value";
  [self.sut performOperation:kMSPendingOperationReplace
      documentId:@"documentId"
      documentType:[NSString class]
      document:[[MSDictionaryDocument alloc] initFromDictionary:dict]
      baseOptions:nil
      cachedTokenBlock:^(MSCachedTokenCompletionHandler _Nonnull handler) {
        handler(tokensResponse, nil);
      }
      remoteDocumentBlock:^(MSDocumentWrapperCompletionHandler _Nonnull __unused handler) {
      }
      completionHandler:^(MSDocumentWrapper *_Nonnull document) {
        wrapper = document;
        [expectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                                 XCTAssertNotEqual(wrapper, cachedDocumentWrapper);
                                 XCTAssertEqual(wrapper.documentId, cachedDocumentWrapper.documentId);
                                 XCTAssertEqual(wrapper.pendingOperation, kMSPendingOperationReplace);
                                 NSDictionary *actualDict = [wrapper.deserializedValue serializeToDictionary];
                                 XCTAssertEqual(actualDict[@"key"], @"value");
                                 OCMVerify([self.documentStoreMock upsertWithToken:token
                                                                   documentWrapper:wrapper
                                                                         operation:kMSPendingOperationReplace
                                                                  deviceTimeToLive:kMSDataStoreTimeToLiveDefault]);
                               }];
}

@end
