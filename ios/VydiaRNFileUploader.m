#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>
#import <Photos/Photos.h>

@interface VydiaRNFileUploader : RCTEventEmitter <RCTBridgeModule, NSURLSessionTaskDelegate>
{
    NSMutableDictionary *_responsesData;
    NSMutableDictionary *downloadDictionary;
}
@end

@implementation VydiaRNFileUploader

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;
static int uploadId = 0;
static RCTEventEmitter* staticEventEmitter = nil;
static NSString *BACKGROUND_SESSION_ID = @"ReactNativeBackgroundUpload";

NSURLSession *_urlSession = nil;

+ (BOOL)requiresMainQueueSetup {
    return NO;
}

-(id) init {
  self = [super init];
  if (self) {
    staticEventEmitter = self;
    _responsesData = [NSMutableDictionary dictionary];
      downloadDictionary = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)_sendEventWithName:(NSString *)eventName body:(id)body {
  if (staticEventEmitter == nil)
    return;
  [staticEventEmitter sendEventWithName:eventName body:body];
}

- (NSArray<NSString *> *)supportedEvents {
    return @[
        @"RNFileUploader-progress",
        @"RNFileUploader-error",
        @"RNFileUploader-cancelled",
        @"RNFileUploader-completed",
        @"RNFileUploader-downloadCompleted",
        @"RNFileUploader-downloadProgress",
        @"RNFileUploader-downloadError"
    ];
}

/*
 Gets file information for the path specified.  Example valid path is: file:///var/mobile/Containers/Data/Application/3C8A0EFB-A316-45C0-A30A-761BF8CCF2F8/tmp/trim.A5F76017-14E9-4890-907E-36A045AF9436.MOV
 Returns an object such as: {mimeType: "video/quicktime", size: 2569900, exists: true, name: "trim.AF9A9225-FC37-416B-A25B-4EDB8275A625.MOV", extension: "MOV"}
 */
RCT_EXPORT_METHOD(getFileInfo:(NSString *)path resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    @try {
        // NSURL *fileUri = [NSURL URLWithString: path];
        NSURL *fileUri = nil;
        if([path containsString:@"://"]){
            fileUri = [NSURL URLWithString: path];
        }
        else{
            fileUri = [NSURL fileURLWithPath:path];
        }
        
        if([path containsString:@"ph://"] || [path containsString:@"assets-library://"]){
            
            NSString *assetId = [path substringFromIndex:@"ph://".length];
            PHAsset *asset = [[PHAsset fetchAssetsWithLocalIdentifiers:@[assetId] options:nil] firstObject];
            
            if(asset == nil){
                NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool:NO], @"exists", nil];
                resolve(params);
//                resolve(@{exists: [NSNumber numberWithBool:NO]});
                return;
            }
            // asset is a PHAsset object for which you want to get the information
            NSArray *resourceArray = [PHAssetResource assetResourcesForAsset:asset];
            BOOL bIsLocallayAvailable = [[resourceArray.firstObject valueForKey:@"locallyAvailable"] boolValue]; // If this returns NO, then the asset is in iCloud and not saved locally yet
//            NSString* name = [[resourceArray.firstObject valueForKey:@"filename"] stringValue];
            long long fileSize = [[resourceArray.firstObject valueForKey:@"fileSize"] longLongValue];
            NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys: @"name", @"name", nil];
            [params setObject:[NSNumber numberWithBool:bIsLocallayAvailable] forKey:@"locallyAvailable"];
            [params setObject:[NSNumber numberWithLongLong:fileSize] forKey:@"fileSize"];
            [params setObject:[NSNumber numberWithLongLong:fileSize] forKey:@"size"];
            resolve(params);
        }
        else{
            NSString *pathWithoutProtocol = [fileUri path];
            NSString *name = [fileUri lastPathComponent];
            NSString *extension = [name pathExtension];
            bool exists = [[NSFileManager defaultManager] fileExistsAtPath:pathWithoutProtocol];
            NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys: name, @"name", nil];
            [params setObject:extension forKey:@"extension"];
            [params setObject:[NSNumber numberWithBool:exists] forKey:@"exists"];
            
            if (exists)
            {
                [params setObject:[self guessMIMETypeFromFileName:name] forKey:@"mimeType"];
                NSError* error;
                NSDictionary<NSFileAttributeKey, id> *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:pathWithoutProtocol error:&error];
                if (error == nil)
                {
                    unsigned long long fileSize = [attributes fileSize];
                    [params setObject:[NSNumber numberWithLong:fileSize] forKey:@"size"];
                }
            }
            resolve(params);
        }
    }
    @catch (NSException *exception) {
        reject(@"RN Uploader", exception.name, nil);
    }
}

RCT_EXPORT_METHOD(copyAssetToFile:(NSString *)assetUrl resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject){
    @try{
        
        NSString *sourcePath = @"...";
        NSString *destPath = @"...";
        NSFileManager *fm = [NSFileManager defaultManager];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        [@"abc def ghi abc def ghi" rangeOfString:@"abc" options:NSBackwardsSearch];
        NSString *fileName =[assetUrl substringFromIndex:[assetUrl rangeOfString:@"/" options:NSBackwardsSearch].location+1];
        NSLog(@"string  substring %@", [assetUrl substringFromIndex:[assetUrl rangeOfString:@"/" options:NSBackwardsSearch].location]);
        NSString *txtPath = [documentsDirectory stringByAppendingPathComponent:fileName];
        
        BOOL isDirectory;
        NSError *copyError = nil;
        
        if ([fm fileExistsAtPath:txtPath] == NO) {
//            NSString *resourcePath = [[NSBundle mainBundle] pathForResource:@"txtFile" ofType:@"txt"];
            [fm copyItemAtPath:assetUrl toPath:txtPath error:&copyError];
        }
//        if ([fm fileExistsAtPath:txtPath] == YES) {
//            [fm removeItemAtPath:txtPath error:&error];
//        }
        
//        NSString *resourcePath = [[NSBundle mainBundle] pathForResource:@"txtFile" ofType:@"txt"];
        [fm copyItemAtPath:assetUrl toPath:txtPath error:&copyError];
        
        NSError* error = nil;
        NSData* data = [NSData dataWithContentsOfFile:assetUrl  options:0 error:&error];
        NSLog(@"Data read from %@ with error: %@", assetUrl, error.debugDescription);
        
        NSURL *fileUri = [NSURL URLWithString: assetUrl];
        NSString *pathWithoutProtocol = [fileUri path];
        
        
        [fm createFileAtPath:txtPath contents:nil attributes:nil];
        NSData *data1 = [[NSFileManager defaultManager] contentsAtPath:pathWithoutProtocol];
        copyError = nil;
        [data1 writeToFile:txtPath atomically:true];
        
       [NSData dataWithContentsOfFile:assetUrl  options:0 error:&copyError];
        
        if([data1 writeToFile:txtPath atomically:true]){
            NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys: [NSURL fileURLWithPath:txtPath].path, @"path",[NSURL fileURLWithPath:txtPath].absoluteString , @"uri", nil];
//            [NSURL fileURLWithFileSystemRepresentation:txtPath isDirectory:FALSE relativeToURL:nil];
            resolve(params);
        }
        else{
            reject(@"RN Uploader", [NSString stringWithFormat: @"first error %@ url %@ assetUrl %@", copyError.debugDescription, txtPath, assetUrl],  nil);
        }
        

    }
    @catch(NSException *exception){
        
        reject(@"RN Uploader", exception.debugDescription, nil);
    }
}

/*
 Borrowed from http://stackoverflow.com/questions/2439020/wheres-the-iphone-mime-type-database
*/
- (NSString *)guessMIMETypeFromFileName: (NSString *)fileName {
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[fileName pathExtension], NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    if (!MIMEType) {
        return @"application/octet-stream";
    }
    return (__bridge NSString *)(MIMEType);
}

/*
 Utility method to copy a PHAsset file into a local temp file, which can then be uploaded.
 */
- (void)copyAssetToFile: (NSString *)assetUrl completionHandler: (void(^)(NSString *__nullable tempFileUrl, NSError *__nullable error))completionHandler {
    NSURL *url = [NSURL URLWithString:assetUrl];
    PHAsset *asset = [PHAsset fetchAssetsWithALAssetURLs:@[url] options:nil].lastObject;
    if (!asset) {
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:@"Asset could not be fetched.  Are you missing permissions?" forKey:NSLocalizedDescriptionKey];
        completionHandler(nil,  [NSError errorWithDomain:@"RNUploader" code:5 userInfo:details]);
        return;
    }
    PHAssetResource *assetResource = [[PHAssetResource assetResourcesForAsset:asset] firstObject];
    NSString *pathToWrite = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSURL *pathUrl = [NSURL fileURLWithPath:pathToWrite];
    NSString *fileURI = pathUrl.absoluteString;

    PHAssetResourceRequestOptions *options = [PHAssetResourceRequestOptions new];
    options.networkAccessAllowed = YES;

    [[PHAssetResourceManager defaultManager] writeDataForAssetResource:assetResource toFile:pathUrl options:options completionHandler:^(NSError * _Nullable e) {
        if (e == nil) {
            completionHandler(fileURI, nil);
        }
        else {
            completionHandler(nil, e);
        }
    }];
}

/*
 * Starts a file upload.
 * Options are passed in as the first argument as a js hash:
 * {
 *   url: string.  url to post to.
 *   path: string.  path to the file on the device
 *   headers: hash of name/value header pairs
 * }
 *
 * Returns a promise with the string ID of the upload.
 */
RCT_EXPORT_METHOD(startUpload:(NSDictionary *)options resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    int thisUploadId;
    @synchronized(self.class)
    {
        thisUploadId = uploadId++;
    }
    
    NSLog(@"upload 1");

    NSString *uploadUrl = options[@"url"];
    __block NSString *fileURI = options[@"path"];
    NSString *method = options[@"method"] ?: @"POST";
    NSString *uploadType = options[@"type"] ?: @"raw";
    NSString *fieldName = options[@"field"];
    NSString *customUploadId = options[@"customUploadId"];
    NSDictionary *headers = options[@"headers"];
    NSDictionary *parameters = options[@"parameters"];
    
    NSLog(@"upload 2");

    @try {
        NSURL *requestUrl = [NSURL URLWithString: uploadUrl];
        if (requestUrl == nil) {
            @throw @"Request cannot be nil";
        }
        NSLog(@"upload 3");

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestUrl];
        [request setHTTPMethod: method];
        NSLog(@"upload 4");

        [headers enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull val, BOOL * _Nonnull stop) {
            if ([val respondsToSelector:@selector(stringValue)]) {
                val = [val stringValue];
            }
            if ([val isKindOfClass:[NSString class]]) {
                [request setValue:val forHTTPHeaderField:key];
            }
        }];
        NSLog(@"upload 5");


        // asset library files have to be copied over to a temp file.  they can't be uploaded directly
        if ([fileURI hasPrefix:@"assets-library"]) {
            dispatch_group_t group = dispatch_group_create();
            dispatch_group_enter(group);
            NSLog(@"upload 6");
            [self copyAssetToFile:fileURI completionHandler:^(NSString * _Nullable tempFileUrl, NSError * _Nullable error) {
                if (error) {
                    dispatch_group_leave(group);
                    reject(@"RN Uploader", @"Asset could not be copied to temp file.", nil);
                    return;
                }
                NSLog(@"upload 7");
                fileURI = tempFileUrl;
                dispatch_group_leave(group);
                NSLog(@"upload 8");
            }];
            NSLog(@"upload 9");
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        }

        NSURLSessionDataTask *uploadTask;

        if ([uploadType isEqualToString:@"multipart"]) {
            NSString *uuidStr = [[NSUUID UUID] UUIDString];
            [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", uuidStr] forHTTPHeaderField:@"Content-Type"];

            NSData *httpBody = [self createBodyWithBoundary:uuidStr path:fileURI parameters: parameters fieldName:fieldName];
            [request setHTTPBody: httpBody];

            uploadTask = [[self urlSession] uploadTaskWithStreamedRequest:request];
        } else {
            NSLog(@"upload 10");
            if (parameters.count > 0) {
                reject(@"RN Uploader", @"Parameters supported only in multipart type", nil);
                return;
            }
            
//            NSString *assetId = [@"" substringFromIndex:@"ph://".length];
//            PHAsset *asset = [[PHAsset fetchAssetsWithLocalIdentifiers:@[assetId] options:nil] firstObject];
//            [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:nil resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
//                [AVPlayerItem playerItemWithAsset:asset];
//            }];
            
            if([fileURI containsString:@"ph://"]){
                dispatch_group_t group = dispatch_group_create();
                dispatch_group_enter(group);
                    NSString *assetId = [fileURI substringFromIndex:@"ph://".length];
                    PHAsset *asset = [[PHAsset fetchAssetsWithLocalIdentifiers:@[assetId] options:nil] firstObject];
                    [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:nil resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
                        NSLog(@"upload = %@", info);
                        if ([info objectForKey:@"PHImageFileURLKey"]) {
                            
                            NSURL *path = [info objectForKey:@"PHImageFileURLKey"];
                            // if you want to save image in document see this.
//                            [self saveimageindocument:imageData withimagename:[NSString stringWithFormat:@"DEMO"]];
                        }
                        dispatch_group_leave(group);
                    }];
                dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
            }

            NSURL * nsUrl = nil;
            if([fileURI containsString:@"://"]){
                nsUrl = [NSURL URLWithString:fileURI];
                NSLog(@"upload 11");
            }
            else{
                nsUrl = [NSURL fileURLWithPath:fileURI];
                NSLog(@"upload 12");
            }

            uploadTask = [[self urlSession] uploadTaskWithRequest:request fromFile:nsUrl];
            NSLog(@"upload 13");
        }

        uploadTask.taskDescription = customUploadId ? customUploadId : [NSString stringWithFormat:@"%i", thisUploadId];
        NSLog(@"upload 14");

        [uploadTask resume];
        NSLog(@"upload 15");
        resolve(uploadTask.taskDescription);
    }
    @catch (NSException *exception) {
        reject(@"RN Uploader", exception.name, nil);
    }
}



RCT_EXPORT_METHOD(isLocallyAvailable: (NSString *)uri resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    
    if(![uri containsString:@"ph://"]){
        resolve([NSNumber numberWithBool:YES]);
        return;
    }
    
    NSString *assetId = [uri substringFromIndex:@"ph://".length];
    PHAsset *asset = [[PHAsset fetchAssetsWithLocalIdentifiers:@[assetId] options:nil] firstObject];
    
    if(asset == nil){
        resolve([NSNumber numberWithBool:YES]);
        return;
    }
    // asset is a PHAsset object for which you want to get the information
    NSArray *resourceArray = [PHAssetResource assetResourcesForAsset:asset];
    BOOL bIsLocallayAvailable = [[resourceArray.firstObject valueForKey:@"locallyAvailable"] boolValue]; // If this returns NO, then the asset is in iCloud and not saved locally yet
    resolve([NSNumber numberWithBool:bIsLocallayAvailable]);
}


RCT_EXPORT_METHOD(downloadIcloudFile: (NSDictionary *)options resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    NSString *uri = options[@"url"];
    NSString *uploadId = options[@"downloadId"];
    NSString *downloadId = options[@"downloadId"];
    
    NSString *assetId = [uri substringFromIndex:@"ph://".length];
    PHAsset *asset = [[PHAsset fetchAssetsWithLocalIdentifiers:@[assetId] options:nil] firstObject];
    
    PHImageManager* requestManager = [PHImageManager defaultManager];
    PHImageRequestID* requestId = nil;
    
    if (asset.mediaType == PHAssetMediaTypeImage && (asset.mediaSubtypes & PHAssetMediaSubtypePhotoLive)){
        PHLivePhotoRequestOptions *imageOptions = [PHLivePhotoRequestOptions new];
        imageOptions.networkAccessAllowed = YES;
        imageOptions.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
            NSLog(@"downloaded progress %f",progress);
            
            if(error == nil){
                //downloadCompleted
                [self _sendEventWithName:@"RNFileUploader-downloadProgress" body: @{ @"uploadId":uploadId, @"id":uploadId, @"progress" : [NSNumber numberWithDouble:progress]}];
            }
            else{
                [self _sendEventWithName:@"RNFileUploader-downloadError" body: @{@"uploadId":uploadId, @"id":uploadId}];
            }
        };
        requestId = [requestManager requestLivePhotoForAsset:asset targetSize:CGSizeZero contentMode:PHImageContentModeAspectFill options:imageOptions resultHandler:^(PHLivePhoto * _Nullable livePhoto, NSDictionary * _Nullable info) {
            for (NSString* key in info) {
                id value = info[key];
                NSLog(@"downloaded %@ %@",key, value);
                // do stuff
            }
            if ([info objectForKey:PHImageErrorKey] == nil && ![info objectForKey:PHImageResultIsDegradedKey] && livePhoto != nil)
            {
                NSLog(@"downloaded live photo:%@", uri);
                NSArray *resourceArray = [PHAssetResource assetResourcesForAsset:asset];
                BOOL bIsLocallayAvailable = [[resourceArray.firstObject valueForKey:@"locallyAvailable"] boolValue];
                [self _sendEventWithName:@"RNFileUploader-downloadCompleted" body: @{@"uploadId":uploadId, @"id":uploadId, @"completed" : @true}];
                //            NSData *livePhotoData = [NSKeyedArchiver archivedDataWithRootObject:livePhoto];
                //            if ([[NSFileManager defaultManager] createFileAtPath:uri contents:livePhotoData attributes:nil])
                //            {
                //                NSLog(@"downloaded live photo:%@", uri);
                //
                //            }
            }
            else if([info objectForKey:PHImageErrorKey] != nil){
                [self _sendEventWithName:@"RNFileUploader-downloadError" body: @{@"uploadId":uploadId, @"id":uploadId}];
            }
        }];
    }
    else if(asset.mediaType == PHAssetMediaTypeImage){
        PHImageRequestOptions *imageOptions = [PHImageRequestOptions new];
        imageOptions.networkAccessAllowed = YES;
        imageOptions.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
            NSLog(@"downloaded progress %f",progress);
            
            if(error == nil){
                [self _sendEventWithName:@"RNFileUploader-downloadProgress" body: @{ @"uploadId":uploadId, @"id":uploadId, @"progress" : [NSNumber numberWithDouble:progress]}];
            }
            else{
                [self _sendEventWithName:@"RNFileUploader-downloadError" body: @{@"uploadId":uploadId, @"id":uploadId}];
            }
            
        };
        requestId = [requestManager requestImageDataForAsset:asset options:imageOptions resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
            for (NSString* key in info) {
                id value = info[key];
                NSLog(@"downloaded %@ %@",key, value);
                // do stuff
            }
            if([info objectForKey:PHImageErrorKey] == nil && imageData != nil){
                NSArray *resourceArray = [PHAssetResource assetResourcesForAsset:asset];
                BOOL bIsLocallayAvailable = [[resourceArray.firstObject valueForKey:@"locallyAvailable"] boolValue];
                [self _sendEventWithName:@"RNFileUploader-downloadCompleted" body: @{@"uploadId":uploadId, @"id":uploadId, @"completed" : @true}];
            }
            else if([info objectForKey:PHImageErrorKey] != nil){
                [self _sendEventWithName:@"RNFileUploader-downloadError" body: @{@"uploadId":uploadId, @"id":uploadId}];
            }
            //            if ([info objectForKey:PHImageErrorKey] == nil
            //                && [[NSFileManager defaultManager] createFileAtPath:url.path contents:imageData attributes:nil])
            //            {
            //                NSLog(@"downloaded photo:%@", url.path);
            //                completion();
            //            }
        }];
    }
    else if (asset.mediaType == PHAssetMediaTypeVideo)
    {
        PHVideoRequestOptions *imageOptions = [PHVideoRequestOptions new];
        imageOptions.networkAccessAllowed = YES;
        imageOptions.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
            NSLog(@"downloaded progress %f %s",progress, stop);
            for (NSString* key in info) {
                id value = info[key];
                NSLog(@"downloaded %@ %@",key, value);
                // do stuff
            }
            
            if(error == nil){
                [self _sendEventWithName:@"RNFileUploader-downloadProgress" body: @{ @"uploadId":uploadId, @"id":uploadId, @"progress" : [NSNumber numberWithDouble:progress]}];
            }
            else{
                [self _sendEventWithName:@"RNFileUploader-downloadError" body: @{@"uploadId":uploadId, @"id":uploadId}];
            }
            
        };
        
        requestId = [requestManager requestExportSessionForVideo:asset options:imageOptions exportPreset:AVAssetExportPresetHighestQuality resultHandler:^(AVAssetExportSession * _Nullable exportSession, NSDictionary * _Nullable info) {
            for (NSString* key in info) {
                id value = info[key];
                NSLog(@"downloaded resultHandler %@ %@",key, value);
                // do stuff
            }
            if ([info objectForKey:PHImageErrorKey] == nil)
            {
                exportSession.outputURL = [NSURL URLWithString:uri];
                [self _sendEventWithName:@"RNFileUploader-downloadCompleted" body: @{@"uploadId":uploadId, @"id":uploadId, @"completed" : @true}];
                
                NSArray<PHAssetResource *> *resources = [PHAssetResource assetResourcesForAsset:asset];
                for (PHAssetResource *resource in resources)
                {
                    exportSession.outputFileType = resource.uniformTypeIdentifier;
                    if (exportSession.outputFileType != nil)
                        break;
                }
                
                [exportSession exportAsynchronouslyWithCompletionHandler:^{
                    if (exportSession.status == AVAssetExportSessionStatusCompleted)
                    {
                        NSLog(@"downloaded video:%@", uri);
                        //                        completion();
                        NSLog(@"downloaded resultHandler completed");
                        
                    }
                }];
            }
            else if([info objectForKey:PHImageErrorKey] != nil){
                [self _sendEventWithName:@"RNFileUploader-downloadError" body: @{@"uploadId":uploadId, @"id":uploadId}];
            }
            else{
                [self _sendEventWithName:@"RNFileUploader-downloadCompleted" body: @{@"uploadId":uploadId, @"id":uploadId, @"completed" : @true}];
            }
        }];
    }
    
    int32_t* temp = requestId;
    NSValue *myValue = [NSValue value:&temp withObjCType:@encode(int32_t)];

    
    [downloadDictionary setObject:@{@"id": myValue, @"manager": requestManager} forKey:downloadId];
    
    resolve([NSNumber numberWithBool:YES]);
}

RCT_EXPORT_METHOD(cancelDownload: (NSString *)downloadId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    NSLog(@"Cancelling download");
    NSDictionary *obj = [downloadDictionary objectForKey:downloadId];
    NSLog(@"Cancelling download %@",obj);
    if(obj != nil){
        NSValue *myValue = obj[@"id"];
        PHImageManager* manager = obj[@"manager"];
        if(myValue != nil && myValue != nil){
            int32_t* requestId;
            [myValue getValue:&requestId];
            

            [manager cancelImageRequest:requestId];
        }

    }
    resolve([NSNumber numberWithBool:YES]);
}


/*
 * Cancels file upload
 * Accepts upload ID as a first argument, this upload will be cancelled
 * Event "cancelled" will be fired when upload is cancelled.
 */
RCT_EXPORT_METHOD(cancelUpload: (NSString *)cancelUploadId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [_urlSession getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        for (NSURLSessionTask *uploadTask in uploadTasks) {
            if ([uploadTask.taskDescription isEqualToString:cancelUploadId]){
                // == checks if references are equal, while isEqualToString checks the string value
                [uploadTask cancel];
            }
        }
    }];
    resolve([NSNumber numberWithBool:YES]);
}

- (NSData *)createBodyWithBoundary:(NSString *)boundary
                         path:(NSString *)path
                         parameters:(NSDictionary *)parameters
                         fieldName:(NSString *)fieldName {

    NSMutableData *httpBody = [NSMutableData data];

    // resolve path
    NSURL *fileUri = nil;
    if([path containsString:@"://"]){
        fileUri = [NSURL URLWithString: path];
    }
    else{
        fileUri = [NSURL fileURLWithPath:path];
    }
    NSString *pathWithoutProtocol = [fileUri path];

    NSData *data = [[NSFileManager defaultManager] contentsAtPath:pathWithoutProtocol];
    NSString *filename  = [path lastPathComponent];
    NSString *mimetype  = [self guessMIMETypeFromFileName:path];

    [parameters enumerateKeysAndObjectsUsingBlock:^(NSString *parameterKey, NSString *parameterValue, BOOL *stop) {
        [httpBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", parameterKey] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"%@\r\n", parameterValue] dataUsingEncoding:NSUTF8StringEncoding]];
    }];

    [httpBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", fieldName, filename] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBody appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", mimetype] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBody appendData:data];
    [httpBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];

    [httpBody appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

    return httpBody;
}

- (NSURLSession *)urlSession {
    if (_urlSession == nil) {
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:BACKGROUND_SESSION_ID];
        _urlSession = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
    }

    return _urlSession;
}

#pragma NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:task.taskDescription, @"id", nil];
    NSURLSessionDataTask *uploadTask = (NSURLSessionDataTask *)task;
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)uploadTask.response;
    if (response != nil)
    {
        [data setObject:[NSNumber numberWithInteger:response.statusCode] forKey:@"responseCode"];
    }
    //Add data that was collected earlier by the didReceiveData method
    NSMutableData *responseData = _responsesData[@(task.taskIdentifier)];
    if (responseData) {
        [_responsesData removeObjectForKey:@(task.taskIdentifier)];
        NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        [data setObject:response forKey:@"responseBody"];
    } else {
        [data setObject:[NSNull null] forKey:@"responseBody"];
    }

    if (error == nil)
    {
        [self _sendEventWithName:@"RNFileUploader-completed" body:data];
    }
    else
    {
        [data setObject:error.localizedDescription forKey:@"error"];
        if (error.code == NSURLErrorCancelled) {
            [self _sendEventWithName:@"RNFileUploader-cancelled" body:data];
        } else {
            [self _sendEventWithName:@"RNFileUploader-error" body:data];
        }
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    float progress = -1;
    if (totalBytesExpectedToSend > 0) //see documentation.  For unknown size it's -1 (NSURLSessionTransferSizeUnknown)
    {
        progress = 100.0 * (float)totalBytesSent / (float)totalBytesExpectedToSend;
    }
    [self _sendEventWithName:@"RNFileUploader-progress" body:@{ @"id": task.taskDescription, @"totalBytes": [NSNumber numberWithLongLong:totalBytesExpectedToSend], @"bytesSent": [NSNumber numberWithLongLong:totalBytesSent], @"progress": [NSNumber numberWithFloat:progress] }];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (!data.length) {
        return;
    }
    //Hold returned data so it can be picked up by the didCompleteWithError method later
    NSMutableData *responseData = _responsesData[@(dataTask.taskIdentifier)];
    if (!responseData) {
        responseData = [NSMutableData dataWithData:data];
        _responsesData[@(dataTask.taskIdentifier)] = responseData;
    } else {
        [responseData appendData:data];
    }
}

@end
