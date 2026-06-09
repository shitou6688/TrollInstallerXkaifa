//
//  appledb.m
//  libgrabkernel2
//
//  Created by Dhinak G on 3/4/24.
//  Modified: ApiDB 查询 + 超时保护 + 重试 + 本地缓存
//

#import <Foundation/Foundation.h>
#import <sys/utsname.h>
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#endif
#import <sys/sysctl.h>
#import "appledb.h"
#import "utils.h"

#define APPLEDB_BASE @"https://api.appledb.dev/ios/"

// 超时与重试配置
static const NSTimeInterval kApiRequestTimeout = 20;   // 单次请求超时(秒)
static const NSTimeInterval kApiResourceTimeout = 30;  // 整体资源超时(秒)
static const int kApiMaxRetries = 2;                    // 重试次数

// appledb 结果本地缓存（同一次 App 运行期内有效）
static NSDictionary *_cachedApiDBResult = nil;
static NSString *_cachedApiDBKey = nil;

// 复用 Session，避免每次请求重新 TCP 握手 + TLS 协商
static NSURLSession *_sharedApiSession = nil;
static dispatch_once_t _sharedApiSessionOnce;

static NSURLSession *_getSharedApiSession(void) {
    dispatch_once(&_sharedApiSessionOnce, ^{
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = kApiRequestTimeout;
        config.timeoutIntervalForResource = kApiResourceTimeout;
        config.waitsForConnectivity = YES;
        _sharedApiSession = [NSURLSession sessionWithConfiguration:config];
    });
    return _sharedApiSession;
}

static NSData *makeSynchronousRequest(NSString *url, NSError **error) {
    LOG("[api] >>> GET %s\n", url.UTF8String);

    __block NSError *lastError = nil;

    for (int attempt = 0; attempt <= kApiMaxRetries; attempt++) {
        if (attempt > 0) {
            LOG("[api] 重试 %d/%d\n", attempt, kApiMaxRetries);
            [NSThread sleepForTimeInterval:1.0 * attempt]; // 递增退避
        }

        NSDate *startTime = [NSDate date];
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block NSData *data = nil;
        __block NSHTTPURLResponse *httpResp = nil;
        __block NSError *taskError = nil;

        // 复用共享 Session（TCP 连接复用 + TLS 会话复用）
        NSURLSession *session = _getSharedApiSession();

        NSURLSessionDataTask *task = [session dataTaskWithURL:[NSURL URLWithString:url]
                                            completionHandler:^(NSData *taskData, NSURLResponse *response, NSError *err) {
                                                data = taskData;
                                                httpResp = (NSHTTPURLResponse *)response;
                                                taskError = err;
                                                dispatch_semaphore_signal(semaphore);
                                            }];
        [task resume];

        // 带超时的等待（替代 DISPATCH_TIME_FOREVER，防止线程永久卡死）
        dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW,
            (int64_t)(kApiResourceTimeout + 5) * NSEC_PER_SEC);
        long result = dispatch_semaphore_wait(semaphore, deadline);

        // 注意：共享 Session 不在此处 invalidate，避免后续请求无法复用连接

        if (result != 0) {
            // 超时
            [task cancel];
            NSTimeInterval elapsed = -[startTime timeIntervalSinceNow];
            LOG("[api] <<< TIMEOUT (%.1fs)\n", elapsed);
            taskError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut
                                       userInfo:@{NSLocalizedDescriptionKey: @"API 请求超时"}];
            continue; // 重试
        }

        NSTimeInterval elapsed = -[startTime timeIntervalSinceNow];
        int httpStatus = (int)(httpResp ? httpResp.statusCode : 0);

        if (taskError) {
            LOG("[api] <<< ERROR (%.1fs): HTTP %d — %s\n",
                elapsed, httpStatus, taskError.localizedDescription.UTF8String);
            NSError *underlying = taskError.userInfo[NSUnderlyingErrorKey];
            if (underlying) {
                if (underlying.code == -1009) {
                    ERRLOG("网络不可达！请检查手机是否连接网络\n");
                } else if (underlying.code == -1001) {
                    ERRLOG("请求超时！服务器 %.1f 秒内无响应\n", elapsed);
                } else if (underlying.code == -1003 || underlying.code == -1004) {
                    ERRLOG("DNS 解析失败！域名 %s 无法解析\n",
                           [NSURL URLWithString:url].host.UTF8String);
                }
            }
            // 网络不可达/超时/DNS — 值得重试
            if (underlying && (underlying.code == -1009 || underlying.code == -1001 ||
                               underlying.code == -1003 || underlying.code == -1004)) {
                continue;
            }
            lastError = taskError;
            if (error) *error = taskError;
            return nil;
        }

        LOG("[api] <<< HTTP %d (%.1fs, %lu bytes)\n",
            httpStatus, elapsed, (unsigned long)(data ? data.length : 0));

        if (httpStatus >= 400) {
            ERRLOG("服务器返回错误 HTTP %d\n", httpStatus);
            lastError = [NSError errorWithDomain:@"appledb" code:httpStatus
                                               userInfo:@{NSLocalizedDescriptionKey:
                                                   [NSString stringWithFormat:@"HTTP %d", httpStatus]}];
            if (httpStatus >= 500) continue; // 服务器错误，重试
            if (error) *error = lastError;
            return nil;
        }

        // 成功
        lastError = nil;
        if (error) *error = nil;
        return data;
    }

    // 所有重试都失败
    if (error) *error = lastError;
    return nil;
}

// ============================================================
// ApiDB 固件查找
// ============================================================
NSArray *hostsNeedingAuth = @[@"adcdownload.apple.com", @"download.developer.apple.com", @"developer.apple.com"];

static NSString *bestLinkFromSources(NSArray<NSDictionary<NSString *, id> *> *sources, NSString *modelIdentifier, bool *isOTA) {
    for (NSDictionary<NSString *, id> *source in sources) {
        if (![source[@"deviceMap"] containsObject:modelIdentifier]) continue;
        if (![@[@"ota", @"ipsw"] containsObject:source[@"type"]]) continue;
        if ([source[@"type"] isEqualToString:@"ota"] && source[@"prerequisiteBuild"]) continue;

        for (NSDictionary<NSString *, id> *link in source[@"links"]) {
            NSURL *url = [NSURL URLWithString:link[@"url"]];
            if ([hostsNeedingAuth containsObject:url.host]) continue;
            if (!link[@"active"]) continue;

            if (isOTA) *isOTA = [source[@"type"] isEqualToString:@"ota"];
            LOG("[firmware] 找到固件 (OTA: %s)\n", *isOTA ? "yes" : "no");
            return link[@"url"];
        }
    }
    return nil;
}

static NSString *getFirmwareURLFromApiDB(NSString *osStr, NSString *build, NSString *modelIdentifier, bool *isOTA) {
    // 检查本地缓存（同一 App 运行期内不重复查询 appledb）
    NSString *cacheKey = [NSString stringWithFormat:@"%@_%@_%@", osStr, build, modelIdentifier];
    if (_cachedApiDBResult && [_cachedApiDBKey isEqualToString:cacheKey]) {
        NSString *url = _cachedApiDBResult[@"url"];
        if (url) {
            LOG("[firmware] 命中本地缓存: %s\n", url.UTF8String);
            if (isOTA) *isOTA = [_cachedApiDBResult[@"isOTA"] boolValue];
            return url;
        }
    }

    // 检查 NSUserDefaults 持久缓存（上次成功下载后保存，跨 App 重启有效）
    {
        NSString *persistKey = [NSString stringWithFormat:@"cached_fw_url_%@", cacheKey];
        NSString *persistOTAKey = [NSString stringWithFormat:@"cached_fw_isOTA_%@", cacheKey];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *cachedURL = [defaults objectForKey:persistKey];
        if (cachedURL) {
            LOG("[firmware] 命中持久缓存: %s\n", cachedURL.UTF8String);
            if (isOTA) *isOTA = [defaults boolForKey:persistOTAKey];
            _cachedApiDBResult = @{@"url": cachedURL, @"isOTA": @([defaults boolForKey:persistOTAKey])};
            _cachedApiDBKey = cacheKey;
            return cachedURL;
        }
    }

    // 精确查询
    NSString *apiURL = [NSString stringWithFormat:@"%@%@;%@.json", APPLEDB_BASE, osStr, build];
    LOG("[firmware] 查询 ApiDB: %s (build %s)\n", modelIdentifier.UTF8String, build.UTF8String);

    NSError *error = nil;
    NSData *data = makeSynchronousRequest(apiURL, &error);
    if (error || !data) {
        ERRLOG("ApiDB 精确查询失败，尝试全量查询...\n");

        NSData *compressed = makeSynchronousRequest(APPLEDB_BASE @"main.json.xz", &error);
        if (error || !compressed) {
            ERRLOG("ApiDB 全量数据下载失败！%s\n",
                   error ? error.localizedDescription.UTF8String : "nil");
            return nil;
        }

        NSData *decompressed = [compressed decompressedDataUsingAlgorithm:NSDataCompressionAlgorithmLZMA error:&error];
        if (error || !decompressed) {
            ERRLOG("全量数据解压失败！\n");
            return nil;
        }

        NSArray *json = [NSJSONSerialization JSONObjectWithData:decompressed options:0 error:&error];
        if (error || ![json isKindOfClass:[NSArray class]]) {
            ERRLOG("全量数据 JSON 解析失败！\n");
            return nil;
        }

        for (NSDictionary<NSString *, id> *firmware in json) {
            if ([firmware[@"osStr"] isEqualToString:osStr] && [firmware[@"build"] isEqualToString:build]) {
                NSString *url = bestLinkFromSources(firmware[@"sources"], modelIdentifier, isOTA);
                if (url) {
                    _cachedApiDBResult = @{@"url": url, @"isOTA": @(*isOTA)};
                    _cachedApiDBKey = cacheKey;
                    // 持久缓存到 NSUserDefaults，下次启动跳过 appledb 查询
                    {
                        NSString *persistKey = [NSString stringWithFormat:@"cached_fw_url_%@", cacheKey];
                        NSString *persistOTAKey = [NSString stringWithFormat:@"cached_fw_isOTA_%@", cacheKey];
                        [[NSUserDefaults standardUserDefaults] setObject:url forKey:persistKey];
                        [[NSUserDefaults standardUserDefaults] setBool:*isOTA forKey:persistOTAKey];
                    }
                    return url;
                }
            }
        }

        ERRLOG("全量数据中也未找到 build %s 的固件\n", build.UTF8String);
        return nil;
    }

    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![json isKindOfClass:[NSDictionary class]]) {
        ERRLOG("ApiDB JSON 解析失败！\n");
        return nil;
    }

    NSString *url = bestLinkFromSources(json[@"sources"], modelIdentifier, isOTA);
    if (url) {
        LOG("[firmware] 固件 URL: %s\n", url.UTF8String);
        _cachedApiDBResult = @{@"url": url, @"isOTA": @(*isOTA)};
        _cachedApiDBKey = cacheKey;
        // 持久缓存到 NSUserDefaults，下次启动跳过 appledb 查询
        {
            NSString *persistKey = [NSString stringWithFormat:@"cached_fw_url_%@", cacheKey];
            NSString *persistOTAKey = [NSString stringWithFormat:@"cached_fw_isOTA_%@", cacheKey];
            [[NSUserDefaults standardUserDefaults] setObject:url forKey:persistKey];
            [[NSUserDefaults standardUserDefaults] setBool:*isOTA forKey:persistOTAKey];
        }
        return url;
    }

    ERRLOG("ApiDB 中未找到该设备/版本的固件\n");
    return nil;
}

// ============================================================
// 对外接口
// ============================================================
NSString *getFirmwareURLFor(NSString *osStr, NSString *build, NSString *modelIdentifier, bool *isOTA) {
    if (!modelIdentifier || !build) return nil;
    return getFirmwareURLFromApiDB(osStr, build, modelIdentifier, isOTA);
}

NSString *getFirmwareURL(bool *isOTA) {
    NSString *osStr = getOsStr();
    NSString *build = getBuild();
    NSString *modelIdentifier = getModelIdentifier();

    if (!osStr || !build || !modelIdentifier) return nil;

    return getFirmwareURLFor(osStr, build, modelIdentifier, isOTA);
}
