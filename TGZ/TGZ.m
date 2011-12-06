//
//  Tar.m
//  Tar
//
//  Created by Eelco Lempsink on 07-05-09.
//  Copyright 2009 Tupil. All rights reserved.
//

#import "TGZ.h"
#import <sys/fcntl.h>
#import <sys/param.h>
#import "libtar.h"

@interface TGZ ()
@property (nonatomic, retain) NSString* tarFile;
@property (nonatomic, retain) NSString* targetDir;
@property (nonatomic, retain) NSArray* fileList;

- (BOOL)processFileWithCallback:(SEL)callback;
- (BOOL)listCallback:(TAR*)t :(char*)filename;
- (BOOL)extractCallback:(TAR*)t :(char*)filename;
@end

int
gzopen_frontend(char *pathname, int oflags, int mode)
{
	char *gzoflags;
	gzFile gzf;
	int fd;
	
	switch (oflags & O_ACCMODE)
	{
		case O_WRONLY:
			gzoflags = "wb";
			break;
		case O_RDONLY:
			gzoflags = "rb";
			break;
		default:
		case O_RDWR:
			errno = EINVAL;
			return -1;
	}
	
	fd = open(pathname, oflags, mode);
	if (fd == -1)
		return -1;
	
	if ((oflags & O_CREAT) && fchmod(fd, mode))
		return -1;
	
	gzf = gzdopen(fd, gzoflags);
	if (!gzf)
	{
		errno = ENOMEM;
		return -1;
	}
	
	return (int)gzf;
}

tartype_t gztype = { (openfunc_t) gzopen_frontend, (closefunc_t) gzclose, (readfunc_t) gzread, (writefunc_t) gzwrite };

@implementation TGZ

@synthesize tarFile = tarFile_;
@synthesize targetDir = targetDir_;
@synthesize fileList = fileList_;
@synthesize delegate = delegate_;

- (id)initWithFile:(NSString*)tarFile {
    self = [super init];
    if (self) {
        self.tarFile = tarFile;
    }
    return self;
}

- (BOOL)extractToDir:(NSString*)targetDir {
    self.targetDir = targetDir;
    if ([self.delegate respondsToSelector:@selector(willExtractFiles:)]) {
        self.fileList = nil;
        if ([self processFileWithCallback:@selector(listCallback::)]) {
            [self.delegate willExtractFiles:self.fileList];
        } else {
            return NO;
        }
    }
    
    return [self processFileWithCallback:@selector(extractCallback::)];
}


- (void)dealloc {
    self.targetDir = nil;
    self.fileList = nil;
    [super dealloc];
}

- (BOOL)listCallback:(TAR*)t :(char*)filename {
    if (TH_ISREG(t) && tar_skip_regfile(t) != 0) {
        self.fileList = nil;
        return NO;
    } // else
    
    if (self.fileList == nil) {
        self.fileList = [NSArray array];
    }
    
    self.fileList = [self.fileList arrayByAddingObject:[NSString stringWithCString:filename encoding:NSASCIIStringEncoding]];
    return YES;
}

- (BOOL)extractCallback:(TAR*)t :(char*)filename {
    if (tar_extract_file(t, filename) != 0) {
        return NO;
    } else {
        if ([self.delegate respondsToSelector:@selector(didExtractFile:)]) {
            [self.delegate didExtractFile:[NSString stringWithCString:filename encoding:NSASCIIStringEncoding]];
        }
        return YES;
    }
}

- (BOOL) processFileWithCallback:(SEL)callback {
	TAR *t;
	
	char *tarfile = strdup([self.tarFile cStringUsingEncoding:NSASCIIStringEncoding]);
	char *prefix = strdup([self.targetDir cStringUsingEncoding:NSASCIIStringEncoding]);
    
	if (tarfile == NULL || prefix == NULL) { // Memory problems!
		if (tarfile != NULL) free(tarfile);
		if (prefix != NULL) free(prefix);
		return NO;		
	}
	
    @try {
        if (tar_open(&t, tarfile, &gztype, O_RDONLY, 0, TAR_GNU) == -1) {
            free(tarfile); free(prefix);
            return NO;
        }
		
        // Code below is copied from libtar's wrapper.c and adapted for use here
        char *filename;
        char buf[MAXPATHLEN];
        int i;
        
        while ((i = th_read(t)) == 0) {
            filename = th_get_pathname(t);
            if (prefix != NULL) {
                snprintf(buf, sizeof(buf), "%s/%s", prefix, filename);
            } else {
                strlcpy(buf, filename, sizeof(buf));
            }
            
            if (![self performSelector:callback withObject:(id)t withObject:(id)buf]) {
                free(tarfile); free(prefix);
                return NO;
            }
        }
        
        if (i != 1) {
            free(tarfile); free(prefix);
            return NO;            
        }
		
        if (tar_close(t) != 0) {
            free(tarfile); free(prefix);
            return NO;
        }
    }
    
    @catch (id anything) {
        if (tarfile != NULL) free(tarfile);
		if (prefix != NULL) free(prefix);
		return NO;        
    }
    
	free(tarfile); free(prefix);
	return YES;    
}

@end