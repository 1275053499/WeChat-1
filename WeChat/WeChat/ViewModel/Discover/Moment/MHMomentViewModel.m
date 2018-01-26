//
//  MHMomentViewModel.m
//  WeChat
//
//  Created by senba on 2017/12/20.
//  Copyright © 2017年 CoderMikeHe. All rights reserved.
//

#import "MHMomentViewModel.h"
@interface MHMomentViewModel ()
/// 个人信息头部视图模型
@property (nonatomic, readwrite, strong) MHMomentProfileViewModel *profileViewModel;

/// 刷新某一个section的 事件回调
@property (nonatomic, readwrite, strong) RACSubject *reloadSectionSubject;

/// 评论回调
@property (nonatomic, readwrite, strong) RACSubject *commentSubject;
/// 发送评论内容
@property (nonatomic, readwrite, strong) RACCommand *commentCommand;
/// 删除当前用户的评论
@property (nonatomic, readwrite, strong) RACCommand *delCommentCommand;
/// 删除当前用户的发的说说
@property (nonatomic, readwrite, strong) RACCommand *delMomentCommand;
@end


@implementation MHMomentViewModel

- (void)initialize{
    [super initialize];
    
    @weakify(self);
    
    /// 设置tableView的样式
    self.style = UITableViewStyleGrouped;
    /// 隐藏导航栏的细线
    self.prefersNavigationBarBottomLineHidden = YES;
    
    /// 允许下拉刷新+上拉加载
    self.shouldPullDownToRefresh = NO;
    self.shouldPullUpToLoadMore = YES;
    
    /// 显示的数据是每页八条说说
    self.perPage = 8;
    
    /// 允许多段显示
    self.shouldMultiSections = YES;
    self.shouldEndRefreshingWithNoMoreData = YES;
    
    /// 个人信息头部视图
    self.profileViewModel = [[MHMomentProfileViewModel alloc] initWithUser:self.services.client.currentUser];
    
    /// 事件操作
    //// 初始化一系列subject
    self.reloadSectionSubject = [RACSubject subject];
    self.commentSubject = [RACSubject subject];
    
    /// 评论
    self.commentCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(MHMomentReplyItemViewModel * itemViewModel) {
        @strongify(self);
        
        /// 配置评论内容
        MHComment *comment = [[MHComment alloc] init];
        comment.text = itemViewModel.text;
        /// 搞个随机字符串
        comment.idstr = [NSString stringWithFormat:@"%ld",[NSObject mh_randomNumberWithFrom:10000000 to:99999999]];
        comment.momentIdstr = itemViewModel.momentIdstr;
        comment.createdAt = [NSDate date];
        comment.fromUser = self.services.client.currentUser;
        comment.toUser = itemViewModel.toUser;
        
        /// 根据 comment 获取到 commentItemViewModel
        MHMomentCommentItemViewModel *commentItemViewModel = [[MHMomentCommentItemViewModel alloc] initWithComment:comment];
        
        /// 根据section 获取到 momentItemViewModel
        MHMomentItemViewModel *momentItemViewModel = self.dataSource[itemViewModel.section];
        
        /// 插入数据
        [momentItemViewModel.dataSource addObject:commentItemViewModel];
        [momentItemViewModel.moment.commentsList addObject:comment];
        momentItemViewModel.moment.commentsCount +=1;
        
        /// 更新headerView的upArrow
        [momentItemViewModel updateUpArrow];
        
        /// 刷新数据源
        [self.reloadSectionSubject sendNext:@(itemViewModel.section)];
        
        
        return [RACSignal empty];
    }];
    
    /// 删除评论
    self.delCommentCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(NSIndexPath * indexPath) {
        @strongify(self);
        /// 根据indexPath.section 获取到 momentItemViewModel
        MHMomentItemViewModel *momentItemViewModel = self.dataSource[indexPath.section];
        MHMomentCommentItemViewModel *commentItemViewModel = momentItemViewModel.dataSource[indexPath.row];
        /// 删除数据
        [momentItemViewModel.dataSource removeObjectAtIndex:indexPath.row];
        /// 这个数据源 这里使用 removeObject来删除，一次来避免索引引起的Bug
        [momentItemViewModel.moment.commentsList removeObject:commentItemViewModel.comment];
        momentItemViewModel.moment.commentsCount -= 1;
        
        /// 更新headerView的upArrow
        [momentItemViewModel updateUpArrow];
        /// 刷新数据源
        [self.reloadSectionSubject sendNext:@(indexPath.section)];
        
        return [RACSignal empty];
    }];
}

/// 请求指定页的网络数据
- (RACSignal *)requestRemoteDataSignalWithPage:(NSUInteger)page{
    @weakify(self);
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self);
        /// config param
        NSMutableDictionary *param = [NSMutableDictionary dictionary];
        [param setValue:@(page) forKey:@"page"];
        /// 请求商品数据
        /// 请求商品数据 模拟网络请求
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            /// 获取数据
            NSData *data = [NSData dataNamed:[NSString stringWithFormat:@"WeChat_Moments_%zd.json",page]];
            MHMoments *momentsData = [MHMoments modelWithJSON:data];
            /// config data
            
            
            NSLog(@"----已经加载第%zd页的数据----",self.page);
            NSArray *viewModels = @[];
            /// 转化数据
            if (momentsData && momentsData.moments.count) { ///做个判断
                viewModels = [momentsData.moments.rac_sequence map:^MHMomentItemViewModel *(MHMoment * momment) {
                    @strongify(self);
                    MHMomentItemViewModel *itemViewModel = [[MHMomentItemViewModel alloc] initWithMoment:momment];
                    itemViewModel.reloadSectionSubject = self.reloadSectionSubject;
                    itemViewModel.commentSubject = self.commentSubject;
                    return itemViewModel;
                }].array;
            }
            
            
            if (page==1) {
                self.dataSource = viewModels ?:@[];
            }else{
                //// 类似于拼接
                self.dataSource = @[ (self.dataSource ?:@[]).rac_sequence , viewModels.rac_sequence].rac_sequence.flatten.array;
            }
            [subscriber sendNext:nil];
            [subscriber sendCompleted];
        });
        return nil;
    }];
}
@end
