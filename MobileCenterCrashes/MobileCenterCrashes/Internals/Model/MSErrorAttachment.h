#import <Foundation/Foundation.h>

@class MSErrorBinaryAttachment;

/*
 * Attachment for error log.
 */
@interface MSErrorAttachment : NSObject

/**
 * Plain text attachment [optional].
 */
@property(nonatomic, copy) NSString *textAttachment;

/**
 * Binary attachment [optional].
 */
@property(nonatomic) MSErrorBinaryAttachment *binaryAttachment;

/**
 * Is equal to another error attachment
 *
 * @param attachment Error attachment
 *
 * @return Return YES if equal and NO if not equal
 */
- (BOOL)isEqual:(nullable MSErrorAttachment *)attachment;

+ (nonnull MSErrorAttachment *)attachmentWithText:(nonnull NSString *)text;

+ (nonnull MSErrorAttachment *)attachmentWithBinaryData:(nonnull NSData *)data
                                                filename:(nullable NSString *)filename
                                                mimeType:(nonnull NSString *)mimeType;

+ (nonnull MSErrorAttachment *)attachmentWithText:(nonnull NSString *)text
                                     andBinaryData:(nonnull NSData *)data
                                          filename:(nullable NSString *)filename
                                          mimeType:(nonnull NSString *)mimeType;

@end
