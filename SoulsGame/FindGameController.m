//
//  FindGameController.m
//  SoulsGame
//
//  Created by Andrew Cummings on 8/4/16.
//  Copyright © 2016 Andrew Cummings. All rights reserved.
//

#import "FindGameController.h"
#import "BattlefieldController.h"
#import "Game.h"

@interface FindGameController ()

@property (weak, nonatomic) IBOutlet UILabel *usernameLabel;
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;
@property (weak, nonatomic) IBOutlet UIButton *findButton;
@property (weak, nonatomic) IBOutlet UILabel *findingLabel;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;

@property (nonatomic) NSInteger awayID;
@property (nonatomic) NSInteger rank;

@end

@implementation FindGameController

-(void)viewDidLoad{
    [super viewDidLoad];
    
    [self setUserInfo];
    self.cancelButton.hidden = YES;
    self.findButton.enabled = NO;
    [SocketHandler getInstance].queueDelegate = self;
}

- (IBAction)findMatch {
    if ([Game instance].offline) {
        [self performSegueWithIdentifier:@"matchFound" sender:self];
        return;
    }
    
    [[SocketHandler getInstance] addToQueueWithRank:self.rank andID:self.userID];

    self.findingLabel.hidden = NO;
    self.findButton.hidden = YES;
    self.cancelButton.hidden = NO;
    
}

-(void)updateLabel:(NSTimer*)timer {
    self.findingLabel.text = [NSString stringWithFormat:@"%@.", self.findingLabel.text];
    if ([self.findingLabel.text isEqualToString:@"Finding Match...."]){
        self.findingLabel.text = @"Finding Match";
    }
}

-(void)matchAcceptedWithID:(NSInteger)ID {
    self.awayID = ID;
    [self performSegueWithIdentifier:@"matchFound" sender:self];
}

-(void)matchRejected {
    [self cancelSearch];
}

-(void)queryAccepted {
    self.cancelButton.enabled = NO;
    self.findingLabel.text = @"Joining Match";
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if ([segue.destinationViewController isKindOfClass:[BattlefieldController class]]){
        BattlefieldController* dest = (BattlefieldController*)segue.destinationViewController;
        dest.userID = self.userID;
        dest.awayID = self.awayID;
        dest.username = self.usernameLabel.text;
    }
}

-(void)setUserInfo{
    if ([Game instance].offline) {
        self.usernameLabel.text = @"Offline";
        self.rankLabel.text = @"--";
        return;
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/ServerCode/playerdata.php", [Game serverIP]]];
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: nil delegateQueue: [NSOperationQueue mainQueue]];
    
    NSMutableURLRequest * urlRequest = [NSMutableURLRequest requestWithURL:url];
    NSString* params = [NSString stringWithFormat:@"id=%ld", (long)self.userID];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setHTTPBody:[params dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSError *error = nil;
    
    if (!error) {
        NSURLSessionDataTask *uploadTask = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data,NSURLResponse *response,NSError *error) {
            NSString *str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
            NSArray* items = [str componentsSeparatedByString:@","];
            
            self.usernameLabel.text = [items objectAtIndex:0];
            self.rankLabel.text = [NSString stringWithFormat:@"Rank: %@", [items objectAtIndex:1]];
            self.rank = [(NSString*)[items objectAtIndex:1] integerValue];
            self.findButton.enabled = YES;
        }];
        
        [uploadTask resume];
    }
}

- (IBAction)cancelSearch {
    if ([Game instance].offline) {
        [self performSegueWithIdentifier:@"return" sender:self];
        return;
    }
    
    [[SocketHandler getInstance] cancelQuery];
    [self performSegueWithIdentifier:@"return" sender:self];
}

@end
