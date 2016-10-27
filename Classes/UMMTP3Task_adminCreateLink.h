//
//  UMMTP3Task_adminCreateLink.h
//  ulibmtp3
//
//  Created by Andreas Fink on 09.12.14.
//  Copyright (c) 2016 Andreas Fink
//
// This source is dual licensed either under the GNU GENERAL PUBLIC LICENSE
// Version 3 from 29 June 2007 and other commercial licenses available by
// the author.

#import <ulib/ulib.h>
#import <ulibm2pa/ulibm2pa.h>

@class UMLayerMTP3;

@interface UMMTP3Task_adminCreateLink : UMLayerTask
{
    int slc;
    NSString    *linkset;
    NSString    *link;
}
@property (readwrite,assign) int slc;
@property (readwrite,strong) NSString *linkset;
@property (readwrite,strong) NSString *link;

- (UMMTP3Task_adminCreateLink *)initWithReceiver:(UMLayerMTP3 *)rx
                                          sender:(id)tx
                                             slc:(int)xslc
                                         linkset:(NSString *)xlinkset
                                            link:link;
@end
