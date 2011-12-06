//
//  Tar.h
//  Tar
//
//  Created by Eelco Lempsink on 07-05-09.
//  Copyright 2009 Tupil. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <zlib.h>

@protocol TGZDelegate;

@interface TGZ : NSObject {
    NSString* tarFile_;
    NSString* targetDir_;
    NSArray* fileList_;
    id<TGZDelegate> delegate_;
}

@property (nonatomic,assign) id<TGZDelegate> delegate;

- (id)initWithFile:(NSString*)tarFile;
- (BOOL)extractToDir:(NSString*)targetDir;

@end

// Delegate

@protocol TGZDelegate <NSObject>
@optional
- (void)willExtractFiles:(NSArray*)filenames;
- (void)didExtractFile:(NSString*)filename;
@end
