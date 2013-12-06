//
//  OrderDetailViewController.h
//  STIPoC
//
//  Created by Administrator on 11/26/13.
//  Copyright (c) 2013 Administrator. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GenericViewController.h"
#import "OrderDetailTableViewController.h"

@class OrderSummary;

@protocol OrderDetailViewControllerDelegate <NSObject>

- (void)orderDetailViewControllerWasDismissed;
- (void)orderDetailViewControllerModifiedOrder:(OrderSummary *)orderSummary;
- (void)orderDetailViewControllerRejectedOrder:(OrderSummary *)orderSummary;

@end

@interface OrderDetailViewController : GenericViewController<OrderDetailTableViewControllerDelegate>

@property (weak, nonatomic) id<OrderDetailViewControllerDelegate> delegate;

@property (strong, nonatomic) OrderSummary *selectedOrderSummary;

@property (weak, nonatomic) IBOutlet UISegmentedControl *priceTypeSegmentedControl;
@property (weak, nonatomic) IBOutlet UILabel *projectNumberLabel;
@property (weak, nonatomic) IBOutlet UILabel *orderStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalLabel;
@property (weak, nonatomic) IBOutlet UINavigationItem *customNavigationItem;
@property (weak, nonatomic) IBOutlet UIView *purchaseItemsView;
@property (weak, nonatomic) IBOutlet UIButton *rejectOrderButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *purchaseItemsVerticalSpaceConstraint;

- (IBAction)priceTypeFilterChanged:(UISegmentedControl *)sender;
- (IBAction)dismissModal:(UIBarButtonItem *)sender;
- (IBAction)saveOrder:(UIBarButtonItem *)sender;
- (IBAction)rejectOrder:(UIButton *)sender;

@end
