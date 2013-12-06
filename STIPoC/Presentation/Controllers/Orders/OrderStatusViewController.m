//
//  OrderStatusViewController.m
//  STIPoC
//
//  Created by Administrator on 11/26/13.
//  Copyright (c) 2013 Administrator. All rights reserved.
//

#import "OrderStatusViewController.h"
#import "SessionsService.h"
#import "UIViewController+ECSlidingViewController.h"
#import "ECZoomAnimationController.h"
#import "OrderDetailViewController.h"
#import "AlertViewFactory.h"
#import "SelfService.h"
#import "OrderSummary.h"

#define ALERT_VIEW_CANCEL_INDEX 0
#define REJECTION_ALERT_VIEW_TAG 1
#define MODIFICATION_ALERT_VIEW_TAG 2
#define ORDERS_PAGE_SIZE 15

NSString *const kSTIPoCSegueEmbedOrdersTableViewController = @"OrdersTableViewControllerEmbedSegue";

static NSString *const kSTIPoCSegueModalOrderDetailViewController = @"OrderDetailViewControllerModalSegue";

@interface OrderStatusViewController ()

@property (nonatomic) NSInteger requestCounter;

@property (weak, nonatomic) OrdersTableViewController *ordersTableViewController;

@property (strong, nonatomic) ECZoomAnimationController *zoomTransitionController;

@property (strong, nonatomic) OrderSummary *selectedOrderSummary;
@property (strong, nonatomic) OrderSummary *rejectedOrderSummary;

- (void)requestOrderDetailsForOrders:(NSArray *)orders replace:(BOOL)replace;
- (void)showOverlayWithMessage:(NSString *)message;
- (void)dismissOverlay;

@end

@implementation OrderStatusViewController

#pragma mark -
#pragma mark View Lifecycle

- (void)viewDidLoad
{
    self.navigationItem.hidesBackButton = YES;
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.slidingViewController.delegate = self.zoomTransitionController;
    [self.navigationController.view addGestureRecognizer:self.slidingViewController.panGesture];
    self.slidingViewController.topViewAnchoredGesture = ECSlidingViewControllerAnchoredGestureTapping | ECSlidingViewControllerAnchoredGesturePanning;
}

#pragma mark -
#pragma mark Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:kSTIPoCSegueEmbedOrdersTableViewController]) {
        self.ordersTableViewController = (OrdersTableViewController *)segue.destinationViewController;
        self.ordersTableViewController.delegate = self;
    }
    else if ([segue.identifier isEqualToString:kSTIPoCSegueModalOrderDetailViewController]) {
        OrderDetailViewController *orderDetailViewController = (OrderDetailViewController *)segue.destinationViewController;
        orderDetailViewController.delegate = self;
        orderDetailViewController.selectedOrderSummary = self.selectedOrderSummary;
    }
}

#pragma mark -
#pragma mark Custom Accessors

- (ECZoomAnimationController *)zoomTransitionController
{
    if (!_zoomTransitionController) {
        _zoomTransitionController = [ECZoomAnimationController new];
    }
    return _zoomTransitionController;
}

#pragma mark -
#pragma mark Orders Table View Controller Protocols

- (void)ordersTableViewControllerRequestedFirstOrdersLoadFromServer
{
    [self showOverlayWithMessage:NSLocalizedString(@"Loading...", nil)];
    
    self.requestCounter++;
    [[SelfService sharedInstance] getOrdersWithPageSize:ORDERS_PAGE_SIZE
                                             pageNumber:1
                                        completionBlock:^(NSArray *orders) {
                                            self.requestCounter--;
                                            [self requestOrderDetailsForOrders:orders replace:YES];
                                
                                        } andFailureBlock:^(NSError *error) {
                                            [self dismissOverlay];
                                            [self.ordersTableViewController.refreshControl endRefreshing];
                                            
                                            self.requestCounter--;
                                            UIAlertView *alertView = [[AlertViewFactory sharedFactory] createAlertViewWithError:error];
                                            [alertView show];
                                        }];
}

- (void)ordersTableViewControllerRequestedOrdersRefreshFromServer
{
    NSInteger pageSize = (self.ordersTableViewController.orders.count > 0)? self.ordersTableViewController.orders.count : ORDERS_PAGE_SIZE;

    self.requestCounter++;
    [[SelfService sharedInstance] getOrdersWithPageSize:pageSize
                                             pageNumber:1
                                        completionBlock:^(NSArray *orders) {
                                            self.requestCounter--;
                                            [self requestOrderDetailsForOrders:orders replace:YES];
                                            
                                        } andFailureBlock:^(NSError *error) {
                                            [self dismissOverlay];
                                            
                                            [self.ordersTableViewController.refreshControl endRefreshing];
                                            
                                            self.requestCounter--;
                                            UIAlertView *alertView = [[AlertViewFactory sharedFactory] createAlertViewWithError:error];
                                            [alertView show];
                                        }];
}

- (void)ordersTableViewControllerRequestedMoreOrdersFromServer
{
    NSInteger pageNumber = self.ordersTableViewController.lastPageLoaded + 1;
    self.requestCounter++;
    [[SelfService sharedInstance] getOrdersWithPageSize:ORDERS_PAGE_SIZE
                                             pageNumber:pageNumber
                                        completionBlock:^(NSArray *orders) {
                                            self.requestCounter--;
                                            [self requestOrderDetailsForOrders:orders replace:NO];
                                            
                                        } andFailureBlock:^(NSError *error) {
                                            [self dismissOverlay];
                                            
                                            [self.ordersTableViewController.refreshControl endRefreshing];
                                            
                                            self.requestCounter--;
                                            UIAlertView *alertView = [[AlertViewFactory sharedFactory] createAlertViewWithError:error];
                                            [alertView show];
                                        }];
}

- (void)ordersTableViewControllerDidSelectOrder:(OrderSummary *)orderSummary
{
    self.selectedOrderSummary = orderSummary;
    [self performSegueWithIdentifier:kSTIPoCSegueModalOrderDetailViewController sender:self];
}

- (void)ordersTableViewControllerRequestedRejectionForOrder:(OrderSummary *)orderSummary
{
    self.rejectedOrderSummary = orderSummary;
    UIAlertView *alertView = [[AlertViewFactory sharedFactory] createOrderRejectionAlertViewWithDelegate:self];
    alertView.tag = REJECTION_ALERT_VIEW_TAG;
    [alertView show];
}

#pragma mark -
#pragma mark Order Detail View Controller Protocols

- (void)orderDetailViewControllerModifiedOrder:(OrderSummary *)orderSummary
{
    self.selectedOrderSummary = orderSummary;
    UIAlertView *alertView = [[AlertViewFactory sharedFactory] createConfirmationAlertViewWithTitle:NSLocalizedString(@"Orders update", nil)
                                                                                            message:NSLocalizedString(@"Your order is about to be updated. Please tap OK to proceed.", nil)
                                                                                        andDelegate:self];
    alertView.tag = MODIFICATION_ALERT_VIEW_TAG;
    [alertView show];
}

- (void)orderDetailViewControllerRejectedOrder:(OrderSummary *)orderSummary
{
    self.rejectedOrderSummary = orderSummary;
    UIAlertView *alertView = [[AlertViewFactory sharedFactory] createOrderRejectionAlertViewWithDelegate:self];
    alertView.tag = REJECTION_ALERT_VIEW_TAG;
    [alertView show];
}

#pragma mark -
#pragma mark Alert View Protocols

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == ALERT_VIEW_CANCEL_INDEX) {
        if (self.selectedOrderSummary) {
            [self performSegueWithIdentifier:kSTIPoCSegueModalOrderDetailViewController sender:self];
        }
    }
    else {
        self.requestCounter++;
        [self.ordersTableViewController hideSearchDisplayController];
        
        if (alertView.tag == REJECTION_ALERT_VIEW_TAG) {
            [self showOverlayWithMessage:NSLocalizedString(@"Rejecting...", nil)];
            
            NSString *comments = [alertView textFieldAtIndex:0].text;
            
            [[SelfService sharedInstance] rejectOrderWithOrderSummary:self.rejectedOrderSummary
                                                             comments:comments
                                                      completionBlock:^{
                                                          self.requestCounter--;
                                                          [self dismissOverlay];
                                                          [self showOverlayWithMessage:NSLocalizedString(@"Refreshing...", nil)];
                                                          [self ordersTableViewControllerRequestedOrdersRefreshFromServer];
                                                      } andFailureBlock:^(NSError *error) {
                                                          self.requestCounter--;
                                                          [self dismissOverlay];
                                                          UIAlertView *alertView = [[AlertViewFactory sharedFactory] createAlertViewWithError:error];
                                                          [alertView show];
                                                      }];
        }
        else {
            [self showOverlayWithMessage:NSLocalizedString(@"Updating...", nil)];
            
            [[SelfService sharedInstance] updateOrderDetailsOnServerWithOrders:self.selectedOrderSummary
                                                               completionBlock:^{
                                                                   self.requestCounter--;
                                                                   [self dismissOverlay];
                                                                   [self showOverlayWithMessage:NSLocalizedString(@"Refreshing...", nil)];
                                                                   [self ordersTableViewControllerRequestedOrdersRefreshFromServer];
                                                               }
                                                               andFailureBlock:^(NSError *error) {
                                                                   self.requestCounter--;
                                                                   [self dismissOverlay];
                                                                   UIAlertView *alertView = [[AlertViewFactory sharedFactory] createAlertViewWithError:error];
                                                                   [alertView show];
                                                               }];
        }
    }
}

#pragma mark -
#pragma mark IBActions

- (IBAction)menuButtonTapped:(UIBarButtonItem *)sender
{
    if (self.slidingViewController.currentTopViewPosition == ECSlidingViewControllerTopViewPositionAnchoredRight) {
        [self.slidingViewController resetTopViewAnimated:YES];
    }
    else {
        [self.slidingViewController anchorTopViewToRightAnimated:YES];
    }
}

- (IBAction)priceTypeFilterChanged:(UISegmentedControl *)sender
{
    [self.ordersTableViewController changeFilterWithPriceType:(PriceType)[self.priceTypeSegmentedControl selectedSegmentIndex]];
}

#pragma mark -
#pragma mark Private Methods

- (void)requestOrderDetailsForOrders:(NSArray *)orders replace:(BOOL)replace
{
    for (OrderSummary *orderSummary in orders) {
        self.requestCounter++;
        [[SelfService sharedInstance] getOrderDetailWithOrderSummary:orderSummary
                                                     completionBlock:^(OrderSummary *detailedOrderSummary) {
                                                         self.requestCounter--;
                                                         [orderSummary setAttributesWithOrderSummary:detailedOrderSummary];
                                                         if (self.requestCounter <= 0) {
                                                             
                                                             [self.ordersTableViewController.refreshControl endRefreshing];
                                                             [self dismissOverlay];
                                                             
                                                             if (replace) {
                                                                 self.ordersTableViewController.orders = [orders mutableCopy];
                                                                 [self.ordersTableViewController reloadTableViews];
                                                             }
                                                             else {
                                                                 NSMutableArray *currentOrders = self.ordersTableViewController.orders;
                                                                 NSMutableArray *indexPaths = [NSMutableArray array];
                                                                 for (int row = currentOrders.count; row < currentOrders.count + orders.count; row++) {
                                                                     [indexPaths addObject:[NSIndexPath indexPathForRow:row inSection:0]];
                                                                 }
                                                                 
                                                                 [currentOrders addObjectsFromArray:orders];
                                                                 [self.ordersTableViewController.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
                                                                 [self.ordersTableViewController.tableView.pullToRefreshView stopAnimating];
                                                             }
                                                             
                                                             self.ordersTableViewController.lastPageLoaded = ((self.ordersTableViewController.orders.count * 1.0) / ORDERS_PAGE_SIZE);
                                                         }
                                                     }
                                                     andFailureBlock:^(NSError *error) {
                                                         if (self.requestCounter > 0) {
                                                             
                                                             if (replace) {
                                                                 [self.ordersTableViewController.refreshControl endRefreshing];
                                                             }
                                                             else {
                                                                 [self.ordersTableViewController.tableView.pullToRefreshView stopAnimating];
                                                             }
                                                             
                                                             [[SelfService sharedInstance] stopAllOperations];
                                                             self.requestCounter = 0;
                                                             [self dismissOverlay];
                                                             UIAlertView *alertView = [[AlertViewFactory sharedFactory] createAlertViewWithError:error];
                                                             [alertView show];
                                                         }
                                                     }];
    }
}

- (void)showOverlayWithMessage:(NSString *)message
{
    [MRProgressOverlayView showOverlayAddedTo:self.navigationController.view
                                        title:message
                                         mode:MRProgressOverlayViewModeIndeterminateSmall
                                     animated:YES];
}

- (void)dismissOverlay
{
    [MRProgressOverlayView dismissAllOverlaysForView:self.navigationController.view animated:YES];
}

@end
