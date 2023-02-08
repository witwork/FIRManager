//
//  FIRManager.h
//  FIRManager
//
//  Created by Thong Vo on 07/02/2023.
//

#import <Foundation/Foundation.h>
@import FirebaseFirestore;
@import FirebaseAuth;
@protocol FIRManagerDelegate <NSObject>
// authen
-(void)firManagerDidLogin;
-(void)firManagerDidLogOut;
-(void)firManagerDidDelete;
-(void)firManagerStartLogin;
-(void)firManagerLoginFailed:(NSError * _Nonnull)error;

// firestore
-(void)firManagerUpdateBandwidth:(FIRDocumentSnapshot * _Nullable)snapshot;
@end

@interface FIRManager : NSObject
@property (nonatomic, assign) id<FIRManagerDelegate> _Nullable delegate;
@property (nonatomic, strong) FIRUser *_Nullable user;

+(instancetype _Nonnull)shared;

///FIRESTORE
-(void)updatePremium:(NSString *_Nonnull)productId completion:(void(^_Nullable)(NSError * _Nullable))completion;
-(void)fetchPackage:(void(^_Nullable)(FIRQuerySnapshot * _Nullable,NSError * _Nullable))completion;
-(void)fetchServers:(void(^_Nullable)(FIRQuerySnapshot * _Nullable,NSError * _Nullable))completion;
-(void)updateBandwidth:(NSInteger)upload download:(NSInteger)download completion:(void(^ _Nullable)(NSError * _Nullable))completion;

///AUTH
-(void)loginApple;
-(void)loginGoogle:(UIViewController* _Nonnull)fromController;
-(void)reauthen;
@end
