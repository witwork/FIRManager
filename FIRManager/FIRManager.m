//
//  FIRManager.m
//  FIRManager
//
//  Created by Thong Vo on 07/02/2023.
//

#import "FIRManager.h"
@import UIKit;
@import FirebaseCore;
@import GBDeviceInfo;
@import AuthenticationServices;
@import CommonCrypto;
@import FirebaseCrashlytics;
@import GoogleSignIn;

static NSString * const kPathAnonymous          =               @"anonymous";
static NSString * const kTraffic                =               @"traffic";
static NSString * const kDownload               =               @"download";
static NSString * const kUpload                 =               @"upload";
static NSString * const kUser                   =               @"users";
static NSString * const kLastLogin              =               @"lastLogin";
static NSString * const kConfigs                =               @"configs";
static NSString * const kDeviceInfo             =               @"deviceInfo";
static NSString * const kPremium                =               @"premium";
static NSString * const kAutoRenewing           =               @"autoRenewing";
static NSString * const kPackageName            =               @"packageName";
static NSString * const kProductId              =               @"productId";
static NSString * const kPurchaseTime           =               @"purchaseTime";
static NSString * const kServers                =               @"Servers";
static NSString * const kCreateAt               =               @"createAt";

@interface FIRManager() <ASAuthorizationControllerDelegate>
@property (nonatomic, strong) FIRFirestore *firestore;
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) GBDeviceInfo *gbDeviceInfo;
@property (nonatomic, strong) NSString *currentNonce;
@end

@implementation FIRManager

+(instancetype)shared {
    static dispatch_once_t once;
    static FIRManager* sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[FIRManager alloc] init];
    });
    return sharedInstance;
}

-(instancetype)init {
    if([super init]) {
        self.uuid = [UIDevice currentDevice].identifierForVendor.UUIDString;
        self.gbDeviceInfo = [GBDeviceInfo deviceInfo];
        self.firestore = [FIRFirestore firestore];
    }
    return self;
}

-(FIRUser *)user {
    return [FIRAuth auth].currentUser;
}
#pragma mark - FIRESTORE
-(void)updateBandwidth:(NSInteger)upload
              download:(NSInteger)download
            completion:(void(^)(NSError * _Nullable))completion {
    
    NSDictionary *data = @{
        kTraffic: @{kDownload   : @(download),
                    kUpload     : @(upload)
        },
        kLastLogin: [NSDate date]
    };
    [[self ref] updateData:data completion:completion];
}
-(void)fetchPackage:(void(^ _Nullable)(FIRQuerySnapshot * _Nullable,NSError * _Nullable))completion {
    [[self.firestore collectionWithPath:kConfigs] getDocumentsWithCompletion:completion];
}
-(void)fetchServers:(void(^ _Nullable)(FIRQuerySnapshot * _Nullable,NSError * _Nullable))completion {
    [[self.firestore collectionWithPath:kServers] getDocumentsWithCompletion:completion];
}
-(void)updatePremium:(NSString *)productId
          completion:(void(^)(NSError * _Nullable))completion {
    NSDictionary *data = @{
        kDeviceInfo: [self deviceInfo],
        kPremium: @{
            kAutoRenewing: @(true),
            kPackageName: [NSBundle mainBundle].bundleIdentifier,
            kProductId: productId,
            kPurchaseTime: [NSDate date]
        }
    };
    
    [[self ref] updateData:data completion:completion];
}

#pragma mark - AUTHEN
-(void)loginAnnonymous {
    FIRDocumentReference *ref = [[self.firestore collectionWithPath:kPathAnonymous] documentWithPath:self.uuid];
    __weak typeof(self) wSelf = self;
    [ref getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        NSMutableDictionary *data = @{
            kDeviceInfo: [wSelf deviceInfo],
            kLastLogin: [NSDate date]
        }.mutableCopy;
        if(snapshot.data) {
            [ref updateData:data completion:^(NSError * _Nullable error) {
                if(error) {
                    [wSelf loginFailed:error];
                }else {
                    [wSelf finishLogin];
                }
            }];
        }else {
            [data setValue:[NSDate date] forKey:kCreateAt];
            [ref setData:data completion:^(NSError * _Nullable error) {
                if(error) {
                    [wSelf loginFailed:error];
                }else {
                    [wSelf finishLogin];
                }
            }];
        }
    }];
}

-(void)reauthen {
    NSString *email = self.user.email;
    if(email) {
        __weak typeof(self)wSelf = self;
        FIRDocumentReference *ref = [[self.firestore collectionWithPath:kUser] documentWithPath:email];
        [ref getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
            FIRUserProfileChangeRequest *request = [[FIRAuth auth].currentUser profileChangeRequest];
            request.displayName = self.uuid;
            [request commitChangesWithCompletion:^(NSError * _Nullable error) {
                if(error) {
                    NSDictionary *errorInfo = error.userInfo;
                    NSString *key = [errorInfo valueForKey:FIRAuthErrorUserInfoNameKey];
                    if(key && [key isEqualToString:@"ERROR_USER_NOT_FOUND"] && [self.delegate respondsToSelector:@selector(firManagerDidDelete)]) {
                        [wSelf.delegate firManagerDidDelete];
                        [wSelf logOut];
                    }else {
                        [wSelf loginFailed:error];
                    }
                }else {
                    [ref updateData:@{
                        kDeviceInfo: [wSelf deviceInfo],
                        kLastLogin: [NSDate date]
                    } completion:^(NSError * _Nullable error) {
                        if(error && [wSelf.delegate respondsToSelector:@selector(firManagerLoginFailed:)]) {
                            [wSelf.delegate firManagerLoginFailed:error];
                        }else {
                            [wSelf finishLogin];
                        }
                    }];
                }
            }];
        }];
    }else {
        [self loginAnnonymous];
    }
}

-(void)loginGoogle:(UIViewController *)fromController {
    if([self.delegate respondsToSelector:@selector(firManagerStartLogin)]) {
        [self.delegate firManagerStartLogin];
    }
    __weak typeof(self)wSelf = self;
    [[GIDSignIn sharedInstance] signInWithPresentingViewController:fromController
                                                        completion:^(GIDSignInResult * _Nullable auth, NSError * _Nullable error) {
        if(error) {
            [wSelf loginFailed:error];
        }else {
            NSString *idTokenString = auth.user.idToken.tokenString;
            NSString *accessToken = auth.user.accessToken.tokenString;
            FIRAuthCredential * authen = [FIRGoogleAuthProvider credentialWithIDToken:idTokenString accessToken:accessToken];
            __weak typeof(self)wSelf = self;
            [[FIRAuth auth] signInWithCredential:authen completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
                [wSelf update:authResult error:error];
            }];
        }
    }];
}

-(void)loginApple {
    if([self.delegate respondsToSelector:@selector(firManagerStartLogin)]) {
        [self.delegate firManagerStartLogin];
    }
    NSString *nonce = [self randomNonce:32];
    self.currentNonce = nonce;
    ASAuthorizationAppleIDProvider *appleIDProvider = [[ASAuthorizationAppleIDProvider alloc] init];
    ASAuthorizationAppleIDRequest *request = [appleIDProvider createRequest];
    request.requestedScopes = @[ASAuthorizationScopeFullName, ASAuthorizationScopeEmail];
    request.nonce = [self stringBySha256HashingString:nonce];
    
    ASAuthorizationController *authorizationController =
    [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
    authorizationController.delegate = self;
    [authorizationController performRequests];
}

-(void)finishLogin {
    if([self.delegate respondsToSelector:@selector(firManagerDidLogin)]) {
        [self.delegate firManagerDidLogin];
        [[FIRCrashlytics crashlytics] setUserID:self.user.uid];
    }
}

-(void)loginFailed:(NSError*)error {
    if([self.delegate respondsToSelector:@selector(firManagerLoginFailed:)]) {
        [self.delegate firManagerLoginFailed:error];
    }
    [self logOut];
}

-(void)logOut {
    [[FIRAuth auth] signOut:nil];
    self.user = nil;
}

-(void)update:(FIRAuthDataResult*)authData error:(NSError*)error {
    if(error && [self.delegate respondsToSelector:@selector(firManagerLoginFailed:)]) {
        [self.delegate firManagerLoginFailed:error];
        return;
    }
    NSString *email = authData.user.email;
    FIRDocumentReference *ref = [[self.firestore collectionWithPath:kUser] documentWithPath:email];
    
    __weak typeof(self) wSelf = self;
    [ref getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if(error && [wSelf.delegate respondsToSelector:@selector(firManagerLoginFailed:)]) {
            [wSelf.delegate firManagerLoginFailed:error];
            return;
        }
        NSMutableDictionary *data = @{
            kDeviceInfo: [wSelf deviceInfo],
            kLastLogin: [NSDate date]
        }.mutableCopy;
        
        if(snapshot.data) { // account is exist
            [ref updateData:data completion:^(NSError * _Nullable error) {
                if(error && [wSelf.delegate respondsToSelector:@selector(firManagerLoginFailed:)]) {
                    [wSelf.delegate firManagerLoginFailed:error];
                }else {
                    [wSelf finishLogin];
                }
            }];
        }else {
            [data setValue:[NSDate date] forKey:kCreateAt];
            [ref setData:data  completion:^(NSError * _Nullable error) {
                if(error && [wSelf.delegate respondsToSelector:@selector(firManagerLoginFailed:)]) {
                    [wSelf.delegate firManagerLoginFailed:error];
                }else {
                    [wSelf finishLogin];
                }
            }];
        }
    }];
}

#pragma mark - PRIVATE
-(NSDictionary *)deviceInfo {
    return @{
        @"model": self.gbDeviceInfo.modelString,
        @"family": @(self.gbDeviceInfo.family),
        @"physicalMemory": @(self.gbDeviceInfo.physicalMemory),
        @"rawSystemInfoString": self.gbDeviceInfo.rawSystemInfoString,
        @"display": @(self.gbDeviceInfo.displayInfo.display),
        @"pixelsPerInch": @(self.gbDeviceInfo.displayInfo.pixelsPerInch),
        @"uuid": self.uuid
    };
}

-(FIRDocumentReference*)ref {
    FIRDocumentReference *ref = [[self.firestore collectionWithPath:kPathAnonymous] documentWithPath:self.uuid];
    NSString *email = self.user.email;
    if(email && email.length > 0) {
        ref = [[self.firestore collectionWithPath:kUser] documentWithPath:email];
    }
    return ref;
}

#pragma mark - HELPER
- (NSString *)randomNonce:(NSInteger)length {
    NSAssert(length > 0, @"Expected nonce to have positive length");
    NSString *characterSet = @"0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._";
    NSMutableString *result = [NSMutableString string];
    NSInteger remainingLength = length;
    
    while (remainingLength > 0) {
        NSMutableArray *randoms = [NSMutableArray arrayWithCapacity:16];
        for (NSInteger i = 0; i < 16; i++) {
            uint8_t random = 0;
            int errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random);
            NSAssert(errorCode == errSecSuccess, @"Unable to generate nonce: OSStatus %i", errorCode);
            
            [randoms addObject:@(random)];
        }
        
        for (NSNumber *random in randoms) {
            if (remainingLength == 0) {
                break;
            }
            
            if (random.unsignedIntValue < characterSet.length) {
                unichar character = [characterSet characterAtIndex:random.unsignedIntValue];
                [result appendFormat:@"%C", character];
                remainingLength--;
            }
        }
    }
    
    return [result copy];
}
- (NSString *)stringBySha256HashingString:(NSString *)input {
    const char *string = [input UTF8String];
    unsigned char result[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(string, (CC_LONG)strlen(string), result);
    
    NSMutableString *hashed = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hashed appendFormat:@"%02x", result[i]];
    }
    return hashed;
}

#pragma mark - ASAuthorizationControllerDelegate
-(void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error {
    if([self.delegate respondsToSelector:@selector(firManagerLoginFailed:)]) {
        [self.delegate firManagerLoginFailed:error];
    }
}

-(void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization {
    if ([authorization.credential isKindOfClass:[ASAuthorizationAppleIDCredential class]]) {
        ASAuthorizationAppleIDCredential *appleIDCredential = authorization.credential;
        NSString *rawNonce = self.currentNonce;
        NSAssert(rawNonce != nil, @"Invalid state: A login callback was received, but no login request was sent.");
        
        if (appleIDCredential.identityToken == nil) {
            NSLog(@"Unable to fetch identity token.");
            return;
        }
        
        NSString *idToken = [[NSString alloc] initWithData:appleIDCredential.identityToken
                                                  encoding:NSUTF8StringEncoding];
        if (idToken == nil) {
            NSLog(@"Unable to serialize id token from data: %@", appleIDCredential.identityToken);
        }
        
        // Initialize a Firebase credential.
        FIROAuthCredential *credential = [FIROAuthProvider credentialWithProviderID:@"apple.com"
                                                                            IDToken:idToken
                                                                           rawNonce:rawNonce];
        
        // Sign in with Firebase.
        [[FIRAuth auth] signInWithCredential:credential
                                  completion:^(FIRAuthDataResult * _Nullable authResult,
                                               NSError * _Nullable error) {
            [self update:authResult error:error];
        }];
    }
}
@end
