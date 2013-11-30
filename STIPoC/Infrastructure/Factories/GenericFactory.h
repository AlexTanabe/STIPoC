//
//  GenericFactory.h
//  STIPoC
//
//  Created by Alex Gutierrez on 11/29/13.
//  Copyright (c) 2013 Administrator. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GenericFactory : NSObject

+ (instancetype)sharedFactory;

@end