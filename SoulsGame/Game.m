//
//  Game.m
//  SoulsGame
//
//  Created by Andrew Cummings on 5/27/16.
//  Copyright © 2016 Andrew Cummings. All rights reserved.
//

#import "Game.h"
#import "FireResist.h"
#import "Crystal.h"
#import "FireBuff.h"
#import "LifeBuff.h"
#import "WaterResist.h"
#import "WaterBuff.h"

#import "Fireball.h"
#import "QuickHeal.h"
#import "WaterShard.h"
#import "HealingPool.h"

#import "Spells.h"
#import "SoulsLibrary.h"

#import "SocketHandler.h"

@interface Game ()

@property (nonatomic, strong) UIViewController<UpdateableController>* _delegate;
@property (nonatomic) NSInteger userID;
@property (nonatomic) NSInteger awayID;

@property (nonatomic) BOOL shouldEndHome;
@property (nonatomic) BOOL shouldEndAway;

@property (nonatomic) BOOL started;

@end

@implementation Game

@synthesize messageIndex;
@synthesize currentBuffer;

static Game* gameInstance = nil;

-(instancetype)init{
    if (self = [super init]){
        self.time = 0;
        
        self.homePlayer = [[Player alloc]init];
        self.homePlayer.delegate = self;
        
        self.awayPlayer = [[Player alloc]init];
        
        self.homePlayer.mana = [Game crystalCreateCost];
        self.awayPlayer.mana = [Game crystalCreateCost];
        
        self.homeKnownResist = [SoulsLibrary resistSouls];
        self.homeKnownBuff = [SoulsLibrary buffSouls];
        self.homeKnownSpec = [SoulsLibrary specSouls];
        
        self.knownSpells = [Spells spells];
        
        self.canAttack = NO;
        
        self.shouldEndAway = NO;
        self.shouldEndHome = NO;
        
        self.started = NO;
        
        self.offline = NO;
        
        [SocketHandler getInstance].gameDelegate = self;
    }
    return self;
}

-(void)opponentNextTurn {
    if (self.offline) {
        self.canAttack = YES;
        [self._delegate updateGUI];
        return;
    }
    
    self.canAttack = YES;
    
    [self._delegate updateGUI];
}

-(BOOL)checkCrystalDeath {
    [self.homePlayer checkCrystalDeath];
    [self.awayPlayer checkCrystalDeath];
    
    if (self.shouldEndAway && self.shouldEndHome) {
        if ([self.homePlayer crystals].count == 0) {
            self.homeWonGame = NO;
            [[SocketHandler getInstance] endGame];
            return YES;
        } else if ([self.awayPlayer crystals].count == 0) {
            self.homeWonGame = YES;
            [[SocketHandler getInstance] endGame];
            return YES;
        }
    }
    
    return NO;
}

-(void)homeEndTurn {
    self.shouldEndHome = YES;
    
    if ([self checkCrystalDeath]) {
        return;
    }
    
    self.time++;
    [self.homePlayer nextTurn];
    
    if (self.offline) {
        Player* prevHome = self.homePlayer;
        self.homePlayer = self.awayPlayer;
        self.awayPlayer = prevHome;
        return;
    }
    
    self.canAttack = NO;
    [[SocketHandler getInstance] sendMessage:@"<e"];
}

-(void)awayEndTurn{
    if (self.started) {
        self.shouldEndAway = YES;
    } else {
        self.started = YES;
    }
    
    self.time++;
    [self opponentNextTurn];
}

-(void)setDelegate:(UIViewController<UpdateableController> *)delegate{
    self._delegate = delegate;
    self.userID = delegate.userID;
    self.awayID = delegate.awayID;
}

+(Game*)instance {
    @synchronized(self) {
        if (gameInstance == nil) {
            gameInstance = [[Game alloc] init];
        }
    }
    
    return gameInstance;
}

+(NSInteger)crystalCreateCost{
    return 9;
}

-(void)endGame {
    if (self.offline) {
        [self._delegate exitSegue];
        gameInstance = nil;
        return;
    }
    
    [self._delegate exitSegue];
    gameInstance = nil;
}

-(void)registerAddSoul:(NSString *)soulID toTarget:(NSInteger)target {
    NSString* cmd = [NSString stringWithFormat:@">s%ld%@", (long)target, soulID];
    [[SocketHandler getInstance] sendMessage:cmd];
}

-(void)registerCastSpell:(NSString *)spellID fromSource:(NSInteger)source toTarget:(Crystal *)target {
    NSInteger targetIndex;
    
    if (target == [self.awayPlayer crystal1]){
        targetIndex = 1;
    } else if (target == [self.awayPlayer crystal2]){
        targetIndex = 2;
    } else if (target == [self.awayPlayer crystal3]){
        targetIndex = 3;
    } else if (target == [self.awayPlayer crystal4]){
        targetIndex = 4;
    } else if (target == [self.awayPlayer crystal5]){
        targetIndex = 5;
    } else if (target == [self.homePlayer crystal1]){
        targetIndex = 6;
    } else if (target == [self.homePlayer crystal2]){
        targetIndex = 7;
    } else if (target == [self.homePlayer crystal3]){
        targetIndex = 8;
    } else if (target == [self.homePlayer crystal4]){
        targetIndex = 9;
    } else if (target == [self.homePlayer crystal5]){
        targetIndex = 10;
    } else {
        return;
    }
    
    NSString *cmd;
    if (targetIndex < 6) {
        cmd = [NSString stringWithFormat:@">h%ld%ld%@", (long)source, targetIndex, spellID];
    } else {
        cmd = [NSString stringWithFormat:@">a%ld%ld%@", (long)source, targetIndex-5, spellID];
    }
    
    [[SocketHandler getInstance] sendMessage:cmd];
}

-(void)registerAddCrystal:(Crystal *)crystal atIndex:(NSInteger)index {
    
    NSString* cmd = [NSString stringWithFormat:@">c%ld%lx%lx%lx", (long)index, (long)[crystal health]/2, (long)[crystal shield], (long)[crystal speed]];
    
    [[SocketHandler getInstance] sendMessage:cmd];
}



-(void)addCrytsalAtPosition:(NSInteger)target withHealth:(NSInteger)health speed:(NSInteger)speed andShield:(NSInteger)shield {
    Crystal* newCrystal = [[Crystal alloc]initWithHealth:health Speed:speed shield:shield];
    
    [self.awayPlayer setCrystalN:target toCrystal:newCrystal];
    [self._delegate updateGUI];
}

-(void)addSoulAtPosition:(NSInteger)target withID:(NSString *)soulID {
    Soul* soul = [SoulsLibrary soulWithID:soulID];
    Crystal* targetCrystal = [self.awayPlayer crystalN:target];
    [targetCrystal addSoulInEmptyIndex:soul];
    [self._delegate updateGUI];
}

-(void)castSpellAtHomePlayer:(NSInteger)target fromAwayPlayer:(NSInteger)caster andID:(NSString *)spellID {
    Spell* spell = [Spells spellWithID:spellID];
    if (spell == nil){
        NSLog(@"Unrecognized spell!");
        return;
    }
    
    Crystal* casterCrystal = [self.awayPlayer crystalN:caster];
    Crystal* targetCrystal = [self.homePlayer crystalN:target];
    
    [casterCrystal castSpell:spell onTarget:targetCrystal];
    [self._delegate updateGUI];
}

-(void)castSpellAtAwayPlayer:(NSInteger)target fromAwayPlayer:(NSInteger)caster andID:(NSString *)spellID {
    Spell* spell = [Spells spellWithID:spellID];
    if (spell == nil){
        NSLog(@"Unrecognized spell!");
        return;
    }
    
    Crystal* casterCrystal = [self.awayPlayer crystalN:caster];
    Crystal* targetCrystal = [self.awayPlayer crystalN:target];
    
    [casterCrystal castSpell:spell onTarget:targetCrystal];
    [self._delegate updateGUI];
}

+(NSString*)serverIP {
    return @"ec2-54-186-194-165.us-west-2.compute.amazonaws.com";
}

+(NSInteger)maxUsernameLength {
    return 20;
}

@end
