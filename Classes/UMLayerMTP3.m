//
//  UMLayerMTP3.m
//  ulibmtp3
//
//  Created by Andreas Fink on 04/12/14.
//  Copyright (c) 2016 Andreas Fink
//
// This source is dual licensed either under the GNU GENERAL PUBLIC LICENSE
// Version 3 from 29 June 2007 and other commercial licenses available by
// the author.

#import "UMLayerMTP3.h"
#import "UMMTP3LinkSet.h"
#import "UMMTP3Link.h"
#import "UMMTP3PointCode.h"

#import "UMMTP3Task_m2paStatusIndication.h"
#import "UMMTP3Task_m2paSctpStatusIndication.h"
#import "UMMTP3Task_m2paDataIndication.h"
#import "UMMTP3Task_m2paCongestion.h"
#import "UMMTP3Task_m2paCongestionCleared.h"
#import "UMMTP3Task_m2paProcessorOutage.h"
#import "UMMTP3Task_m2paProcessorRestored.h"
#import "UMMTP3Task_m2paSpeedLimitReached.h"
#import "UMMTP3Task_m2paSpeedLimitReachedCleared.h"
#import "UMMTP3Task_adminAttachOrder.h"
#import "UMMTP3Task_adminCreateLinkset.h"
#import "UMMTP3Task_adminCreateLink.h"
#import "UMMTP3Label.h"
#import "UMMTP3HeadingCode.h"
#import "UMMTP3RoutingTable.h"
#import "UMMTP3Route.h"

#import "UMMTP3Task_start.h"
#import "UMMTP3Task_stop.h"
#import "UMLayerMTP3UserProtocol.h"

@implementation UMLayerMTP3

@synthesize networkIndicator;
@synthesize variant;
@synthesize opc;
@synthesize defaultRoute;
@synthesize ready;

#pragma mark -
#pragma mark Initializer

- (UMLayerMTP3 *)init
{
    self = [super init];
    if(self)
    {
        [self genericInitialisation];
    }
    return self;
}

- (UMLayerMTP3 *)initWithTaskQueueMulti:(UMTaskQueueMulti *)tq
{
    self = [super initWithTaskQueueMulti:tq];
    if(self)
    {
        [self genericInitialisation];
    }
    return self;
}


- (void)genericInitialisation
{
    linksets = [[NSMutableDictionary alloc]init];
    userPart = [[UMSynchronizedDictionary  alloc]init];
}


#pragma mark -
#pragma mark Linkset Handling

- (void)addLinkset:(UMMTP3LinkSet *)ls
{
    @synchronized(linksets)
    {
        ls.mtp3 = self;
        ls.variant = self.variant;
        ls.logFeed = [self.logFeed copy];
        ls.logFeed.subsection = @"mtp3_linkset";
        ls.logFeed.name = ls.name;
        ls.logLevel = self.logFeed.level;
        ls.localPointCode = self.opc;
        ls.networkIndicator = self.networkIndicator;
        linksets[ls.name]=ls;
    }
}

- (void)removeAllLinksets
{
    @synchronized(linksets)
    {
        linksets = NULL;
        linksets = [[NSMutableDictionary alloc]init];
    }
}


- (void)removeLinkset:(UMMTP3LinkSet *)ls
{
    @synchronized(linksets)
    {
        ls.mtp3 = NULL;
        [linksets removeObjectForKey:ls.name];
    }
}

- (void)removeLinksetByName:(NSString *)n
{
    @synchronized(linksets)
    {
        UMMTP3LinkSet *ls = linksets[n];
        ls.mtp3 = NULL;
        [linksets removeObjectForKey:n];
    }
}

- (UMMTP3LinkSet *)getLinksetByName:(NSString *)n
{
    @synchronized(linksets)
    {
        return linksets[n];
    }
}

- (UMMTP3Link *)getLinkByName:(id)userId
{
    NSString *ourName = (NSString *)userId;
    NSArray *a = [ourName componentsSeparatedByString:@":"];
    if(a==NULL)
    {
        return NULL;
    }
    if([a count]!=2)
    {
        return NULL;
    }
    NSString *linkSetName = a[0];
    NSString *linkName = a[1];
    UMMTP3LinkSet *linkset = [self getLinksetByName:linkSetName];
    UMMTP3Link *link = [linkset getLinkByName:linkName];
    return link;
}


#pragma mark -
#pragma mark M2PA callbacks

- (void) adminCreateLinkset:(NSString *)linkset
{
    UMMTP3Task_adminCreateLinkset *task = [[UMMTP3Task_adminCreateLinkset alloc ]initWithReceiver:self
                                                                                       sender:(id)NULL
                                                                                      linkset:linkset];
    [self queueFromAdmin:task];
}
- (void) adminCreateLink:(NSString *)linkset
                     slc:(int)slc
                    link:(NSString *)link
{
    UMMTP3Task_adminCreateLink *task = [[UMMTP3Task_adminCreateLink alloc ]initWithReceiver:self
                                                                                       sender:(id)NULL
                                                                                          slc:(int)slc
                                                                                      linkset:linkset
                                                                                         link:link];
    [self queueFromAdmin:task];
}

- (void)adminAttachOrder:(UMLayerM2PA *)m2pa_layer
                     slc:(int)slc
                 linkset:(NSString *)linkset;
{
    UMMTP3Task_adminAttachOrder *task = [[UMMTP3Task_adminAttachOrder alloc ]initWithReceiver:self
                                                                                       sender:(id)NULL
                                                                                          slc:(int)slc
                                                                                         m2pa:m2pa_layer
                                                                                      linkset:linkset];
    [self queueFromAdmin:task];
}

- (void) adminAttachConfirm:(UMLayer *)attachedLayer
                        slc:(int)slc
                     userId:(id)uid
{
    UMMTP3LinkSet *linkSet;
    @synchronized(linksets)
    {
        linkSet = linksets[uid];
    }
    [linkSet attachmentConfirmed:slc];
}


- (void) adminAttachFail:(UMLayer *)attachedLayer
                     slc:(int)slc
                  userId:(id)uid
                  reason:(NSString *)r
{
    UMMTP3LinkSet *linkSet;
    @synchronized(linksets)
    {
        linkSet = linksets[uid];
    }
    [linkSet attachmentFailed:slc reason:r];
}

- (void) sentAckConfirmFrom:(UMLayer *)sender
                   userInfo:(NSDictionary *)userInfo
{
    NSLog(@"sentAckConfirmFrom Not yet implemented");
}
- (void) sentAckFailureFrom:(UMLayer *)sender
                   userInfo:(NSDictionary *)userInfo
                      error:(NSString *)err
                     reason:(NSString *)reason
                  errorInfo:(NSDictionary *)ei
{
    NSLog(@"sentAckFailureFrom Not yet implemented");
}


- (void) m2paStatusIndication:(UMLayer *)caller
                          slc:(int)xslc
                       userId:(id)uid
                       status:(M2PA_Status)s
{
    UMMTP3Task_m2paStatusIndication *task = [[UMMTP3Task_m2paStatusIndication alloc]initWithReceiver:self
                                                                                              sender:caller
                                                                                                 slc:xslc
                                                                                              userId:uid
                                                                                              status:s];
    if(0)
    {
        [self queueFromLowerWithPriority:task];
    }
    else
    {
        [task main];
    }
}

- (void) m2paSctpStatusIndication:(UMLayer *)caller
                              slc:(int)xslc
                           userId:(id)uid
                           status:(SCTP_Status)s
{
    
    UMMTP3Task_m2paSctpStatusIndication *task = [[UMMTP3Task_m2paSctpStatusIndication alloc]initWithReceiver:self
                                                                                              sender:caller
                                                                                                 slc:xslc
                                                                                              userId:uid
                                                                                              status:s];
    [self queueFromLowerWithPriority:task];
}

- (void) m2paDataIndication:(UMLayer *)caller
                        slc:(int)xslc
                     userId:(id)uid
                       data:(NSData *)d
{
    UMMTP3Task_m2paDataIndication *task = [[UMMTP3Task_m2paDataIndication alloc]initWithReceiver:self
                                                                                          sender:caller
                                                                                             slc:xslc
                                                                                          userId:uid
                                                                                            data:d];
    [self queueFromLower:task];
}


- (void) m2paCongestion:(UMLayer *)caller
                    slc:(int)xslc
                 userId:(id)uid
{
    UMMTP3Task_m2paCongestion *task = [[UMMTP3Task_m2paCongestion alloc]initWithReceiver:self
                                                                                  sender:caller
                                                                                     slc:xslc
                                                                                  userId:uid];
    [self queueFromLowerWithPriority:task];
}

- (void) m2paCongestionCleared:(UMLayer *)caller
                           slc:(int)xslc
                        userId:(id)uid
{
    UMMTP3Task_m2paCongestionCleared *task = [[UMMTP3Task_m2paCongestionCleared alloc]initWithReceiver:self
                                                                                  sender:caller
                                                                                     slc:xslc
                                                                                  userId:uid];
    [self queueFromLowerWithPriority:task];
}


- (void) m2paProcessorOutage:(UMLayer *)caller
                         slc:(int)xslc
                      userId:(id)uid
{
    UMMTP3Task_m2paProcessorOutage *task = [[UMMTP3Task_m2paProcessorOutage alloc]initWithReceiver:self
                                                                                                 sender:caller
                                                                                                    slc:xslc
                                                                                                 userId:uid];
    [self queueFromLowerWithPriority:task];
}


- (void) m2paProcessorRestored:(UMLayer *)caller
                           slc:(int)xslc
                        userId:(id)uid
{
    UMMTP3Task_m2paProcessorRestored *task = [[UMMTP3Task_m2paProcessorRestored alloc]initWithReceiver:self
                                                                                            sender:caller
                                                                                               slc:xslc
                                                                                            userId:uid];
    [self queueFromLowerWithPriority:task];
}


- (void) m2paSpeedLimitReached:(UMLayer *)caller
                           slc:(int)xslc
                        userId:(id)uid
{
    UMMTP3Task_m2paSpeedLimitReached *task = [[UMMTP3Task_m2paSpeedLimitReached alloc]initWithReceiver:self
                                                                                            sender:caller
                                                                                               slc:xslc
                                                                                            userId:uid];
    [self queueFromLowerWithPriority:task];
}

- (void) m2paSpeedLimitReachedCleared:(UMLayer *)caller
                                  slc:(int)xslc
                               userId:(id)uid

{
    UMMTP3Task_m2paSpeedLimitReachedCleared *task = [[UMMTP3Task_m2paSpeedLimitReachedCleared alloc]initWithReceiver:self
                                                                                                sender:caller
                                                                                                   slc:xslc
                                                                                                userId:uid];
    [self queueFromLowerWithPriority:task];
}

#pragma mark -
#pragma mark Tasks

- (void) _adminCreateLinksetTask:(UMMTP3Task_adminCreateLinkset *)linkset
{
    if(logLevel <= UMLOG_DEBUG)
    {
        [self logDebug:@"_adminCreateLinksetTask"];
    }
    
    UMMTP3LinkSet *set = [[UMMTP3LinkSet alloc] init];
    set.name = [linkset linkset];
    linksets[set.name] = set;
}

- (void) _adminCreateLinkTask:(UMMTP3Task_adminCreateLink *)task
{
    if(logLevel <= UMLOG_DEBUG)
    {
        [self logDebug:@"_adminCreateLinkTask"];
    }
    
    NSString *linksetName = task.linkset;
    UMMTP3Link *link =[[UMMTP3Link alloc] init];
    link.slc = task.slc;
    link.name = task.link;
    UMMTP3LinkSet *linkset = linksets[linksetName];
    [linkset addLink:link];
}


- (void)_adminAttachOrderTask:(UMMTP3Task_adminAttachOrder *)task
{
    if(logLevel <= UMLOG_DEBUG)
    {
        [self logDebug:@"adminAttachOrder"];
    }
    UMLayerM2PA *m2pa = task.m2pa;
    UMLayerM2PAUserProfile *profile = [[UMLayerM2PAUserProfile alloc]initWithDefaultProfile];
    profile.allMessages = YES;
    profile.sctpLinkstateMessages = YES;
    profile.m2paLinkstateMessages = YES;
    profile.dataMessages = YES;
    profile.processorOutageMessages = YES;

    [m2pa adminAttachFor:self profile:profile userId:[NSString stringWithFormat:@"%@:%@",task.linkset,task.m2pa.layerName] ni:networkIndicator slc:task.slc];
}

- (void) _m2paStatusIndicationTask:(UMMTP3Task_m2paStatusIndication *)task;
{
    if(logLevel <=UMLOG_DEBUG)
    {
        [self logDebug:@"_m2paStatusIndicationTask"];
        [self logDebug:[NSString stringWithFormat:@" slc: %d",task.slc]];
        [self logDebug:[NSString stringWithFormat:@" userId: %@",task.userId]];
        
        switch(task.status)
        {
            case M2PA_STATUS_UNUSED:
                [self logDebug:[NSString stringWithFormat:@" status: UNUSED (%d)",task.status]];
                break;
            case M2PA_STATUS_OFF:
                [self logDebug:[NSString stringWithFormat:@" status: OFF (%d)",task.status]];
                break;
            case M2PA_STATUS_OOS:
                [self logDebug:[NSString stringWithFormat:@" status: OOS (%d)",task.status]];
                break;
            case M2PA_STATUS_INITIAL_ALIGNMENT:
                [self logDebug:[NSString stringWithFormat:@" status: INITIAL_ALIGNMENT (%d)",task.status]];
                break;
            case M2PA_STATUS_ALIGNED_NOT_READY:
                [self logDebug:[NSString stringWithFormat:@" status: ALIGNED_NOT_READY (%d)",task.status]];
                break;
            case M2PA_STATUS_ALIGNED_READY:
                [self logDebug:[NSString stringWithFormat:@" status: ALIGNED_READY (%d)",task.status]];
                break;
            case M2PA_STATUS_IS:
                [self logDebug:[NSString stringWithFormat:@" status: IS (%d)",task.status]];
                break;
            default:
                [self logDebug:[NSString stringWithFormat:@" status: UNKNOWN(%d)",task.status]];
                break;
        }
        [self logDebug:[NSString stringWithFormat:@" status: %d",task.status]];
    }

    
    UMMTP3LinkSet *linkset = [self getLinksetByName: task.userId];
    [linkset m2paStatusUpdate:task.status slc:task.slc];
}


- (void) _m2paSctpStatusIndicationTask:(UMMTP3Task_m2paSctpStatusIndication *)task;
{
    if(logLevel <=UMLOG_DEBUG)
    {
        [self logDebug:@"_m2paSctpStatusIndicationTask"];
        [self logDebug:[NSString stringWithFormat:@" slc: %d",task.slc]];
        [self logDebug:[NSString stringWithFormat:@" userId: %@",task.userId]];
        switch(task.status)
        {
                
            case SCTP_STATUS_M_FOOS:
                [self logDebug:[NSString stringWithFormat:@" status: M_FOOS (%d)",task.status]];
                break;
            case SCTP_STATUS_OFF:
                [self logDebug:[NSString stringWithFormat:@" status: OFF (%d)",task.status]];
                break;
            case SCTP_STATUS_OOS:
                [self logDebug:[NSString stringWithFormat:@" status: OOS (%d)",task.status]];
                break;
            case SCTP_STATUS_IS:
                [self logDebug:[NSString stringWithFormat:@" status: IS (%d)",task.status]];
                break;
            default:
                [self logDebug:[NSString stringWithFormat:@" status: UNKNOWN(%d)",task.status]];
                break;
        }
    }
    
    UMMTP3LinkSet *linkset = [self getLinksetByName:task.userId];
    [linkset sctpStatusUpdate:task.status slc:task.slc];
}


- (void) _m2paDataIndicationTask:(UMMTP3Task_m2paDataIndication *)task
{
    if(logLevel <=UMLOG_DEBUG)
    {
        [self logDebug:@"_m2paDataIndicationTask"];
        [self logDebug:[NSString stringWithFormat:@" slc: %d",task.slc]];
        [self logDebug:[NSString stringWithFormat:@" userId: %@",task.userId]];
        [self logDebug:[NSString stringWithFormat:@" data: %@",task.data.description]];
    }

    UMMTP3LinkSet *linkset = [self getLinksetByName:task.userId];
    [linkset dataIndication:task.data slc:task.slc];
}


- (void) _m2paCongestionTask:(UMMTP3Task_m2paCongestion*)task
{
    if(logLevel <=UMLOG_DEBUG)
    {
        [self logDebug:@"_m2paCongestionTask"];
        [self logDebug:[NSString stringWithFormat:@" slc: %d",task.slc]];
        [self logDebug:[NSString stringWithFormat:@" userId: %@",task.userId]];
    }
    UMMTP3Link *link = [self getLinkByName:task.userId];
    [link congestionIndication];
}



- (void) _m2paCongestionClearedTask:(UMMTP3Task_m2paCongestionCleared *)task
{
    if(logLevel <=UMLOG_DEBUG)
    {
        [self logDebug:@"_m2paCongestionClearedTask"];
        [self logDebug:[NSString stringWithFormat:@" slc: %d",task.slc]];
        [self logDebug:[NSString stringWithFormat:@" userId: %@",task.userId]];
    }
    UMMTP3Link *link = [self getLinkByName:task.userId];
    [link congestionClearedIndication];
}


- (void) _m2paProcessorOutageTask:(UMMTP3Task_m2paProcessorOutage *)task
{
    if(logLevel <=UMLOG_DEBUG)
    {
        [self logDebug:@"_m2paProcessorOutageTask"];
        [self logDebug:[NSString stringWithFormat:@" slc: %d",task.slc]];
        [self logDebug:[NSString stringWithFormat:@" userId: %@",task.userId]];
    }
    UMMTP3Link *link = [self getLinkByName:task.userId];
    [link processorOutageIndication];
}


- (void) _m2paProcessorRestoredTask:(UMMTP3Task_m2paProcessorRestored *)task
{
    if(logLevel <=UMLOG_DEBUG)
    {
        [self logDebug:@"_m2paProcessorRestoredTask"];
        [self logDebug:[NSString stringWithFormat:@" slc: %d",task.slc]];
        [self logDebug:[NSString stringWithFormat:@" userId: %@",task.userId]];
    }
    UMMTP3Link *link = [self getLinkByName:task.userId];
    [link processorRestoredIndication];
}


- (void) _m2paSpeedLimitReachedTask:(UMMTP3Task_m2paSpeedLimitReached *)task
{
    if(logLevel <=UMLOG_DEBUG)
    {
        [self logDebug:@"_m2paSpeedLimitReachedTask"];
        [self logDebug:[NSString stringWithFormat:@" slc: %d",task.slc]];
        [self logDebug:[NSString stringWithFormat:@" userId: %@",task.userId]];
    }
    UMMTP3Link *link = [self getLinkByName:task.userId];
    [link speedLimitReachedIndication];
}

- (void) _m2paSpeedLimitReachedClearedTask:(UMMTP3Task_m2paSpeedLimitReachedCleared *)task
{
    if(logLevel <=UMLOG_DEBUG)
    {
        [self logDebug:@"_m2paSpeedLimitReachedClearedTask"];
        [self logDebug:[NSString stringWithFormat:@" slc: %d",task.slc]];
        [self logDebug:[NSString stringWithFormat:@" userId: %@",task.userId]];
    }
    UMMTP3Link *link = [self getLinkByName:task.userId];
    [link speedLimitReachedClearedIndication];
}



#pragma mark -
#pragma mark Config Management

- (NSDictionary *)config
{
    NSMutableDictionary *config = [[NSMutableDictionary alloc]init];
    [self addLayerConfig:config];
    switch(variant)
    {
        case UMMTP3Variant_ITU:
            config[@"variant"]=@"itu";
            break;
        case UMMTP3Variant_ANSI:
            config[@"variant"]=@"ansi";
            break;
        case UMMTP3Variant_China:
            config[@"variant"]=@"china";
            break;
        default:
            break;
    }
    config[@"opc"] = [opc stringValue];
    config[@"ni"] = @(networkIndicator);
    NSMutableDictionary *linksetsConfig = [[NSMutableDictionary alloc]init];
    @synchronized(linksets)
    {
        for(NSString *linksetName in linksets)
        {
            UMMTP3LinkSet *linkset = linksets[linksetName];
            linksetsConfig[linksetName] = [linkset config];
        }
    }
    config[@"linksets"] = linksetsConfig;
    return config;
}

- (void)setConfig:(NSDictionary *)cfg
{
    [self readLayerConfig:cfg];
    
    NSString *var = cfg[@"variant"];
    if([var isEqualToString:@"itu"])
    {
        variant = UMMTP3Variant_ITU;
    }
    else if([var isEqualToString:@"ansi"])
    {
        variant = UMMTP3Variant_ANSI;
    }
    else if([var isEqualToString:@"china"])
    {
        variant = UMMTP3Variant_China;
    }

    NSString *pcStr = cfg[@"opc"];
    self.opc = [[UMMTP3PointCode alloc]initWithString:pcStr variant:variant];
    NSDictionary *linksetsConfig = cfg[@"linksets"];
    networkIndicator = [cfg[@"ni"]intValue];

    [self removeAllLinksets];
    for(NSString *linksetName in linksetsConfig)
    {
        NSDictionary *linksetConfig = linksetsConfig[linksetName];
        
        UMMTP3LinkSet  *linkset = [[UMMTP3LinkSet alloc]init];
        linkset.name = linksetName;
        linkset.variant = self.variant;
        linkset.config = linksetConfig;
        [self addLinkset:linkset];
    }
}

- (UMMTP3Route *)findRouteForDestination:(UMMTP3PointCode *)search_dpc
{
    UMMTP3Route *re =[routingTable findRouteForDestination:search_dpc];
    if(re==NULL)
    {
        return defaultRoute;
    }
    return re;
}

- (UMMTP3_Error)sendPDU:(NSData *)pdu
                    opc:(UMMTP3PointCode *)fopc
                    dpc:(UMMTP3PointCode *)fdpc
                     si:(int)si
                     mp:(int)mp
{
    if(fopc==NULL)
    {
        fopc = opc;
    }
    UMMTP3Route *route = [self findRouteForDestination:fdpc];
    return [self forwardPDU:pdu
                        opc:fopc
                        dpc:fdpc
                         si:si
                         mp:mp
                      route:route];
}


- (UMMTP3_Error)forwardPDU:(NSData *)pdu
                       opc:(UMMTP3PointCode *)fopc
                       dpc:(UMMTP3PointCode *)fdpc
                        si:(int)si
                        mp:(int)mp
                     route:(UMMTP3Route *)route
{
    UMMTP3LinkSet *linkset = route.linkset;
    
    UMMTP3Label *label = [[UMMTP3Label alloc]init];
    label.opc = fopc;
    label.dpc = fdpc;
        
    [linkset sendPdu:pdu
               label:label
             heading:-1
                  ni:linkset.mtp3.networkIndicator
                  mp:(int)mp
                  si:si
          ackRequest:NULL];
     
    return UMMTP3_no_error;
}

- (void)start
{
    UMMTP3Task_start *task = [[UMMTP3Task_start alloc]initWithReceiver:self];
    [self queueFromAdmin:task];
}

- (void)stop
{
    UMMTP3Task_stop *task = [[UMMTP3Task_stop alloc]initWithReceiver:self];
    [self queueFromAdmin:task];
}

- (void)_start
{
    @synchronized(linksets)
    {
        for(NSString *linksetName in linksets)
        {
            UMMTP3LinkSet *ls = linksets[linksetName];
            [ls powerOn];
        }
    }
}

- (void)_stop
{
    @synchronized(linksets)
    {
        for(NSString *linksetName in linksets)
        {
            UMMTP3LinkSet *ls = linksets[linksetName];
            [ls powerOff];
        }
    }
}


- (id<UMLayerMTP3UserProtocol>)findUserPart:(int)upid
{
    return userPart[@(upid)];
}

- (void)setUserPart:(int)upid user:(id<UMLayerMTP3UserProtocol>)user
{
    userPart[@(upid)] = user;
}

- (void)processUserPart:(UMMTP3Label *)label
                   data:(NSData *)data
             userpartId:(int)upid
                     ni:(int)ni
                     mp:(int)mp
                    slc:(int)slc
                   link:(UMMTP3Link *)link
{
    id<UMLayerMTP3UserProtocol> inst = [self findUserPart:upid];
    
    [inst mtpTransfer:data
         callingLayer:self
                  opc:label.opc
                  dpc:label.dpc
                   si:upid
                   ni:ni
              options:@{}];
    /* FIXME: reply something if not reachable? */
}


- (int)maxPduSize
{
    return 273;
}
@end
