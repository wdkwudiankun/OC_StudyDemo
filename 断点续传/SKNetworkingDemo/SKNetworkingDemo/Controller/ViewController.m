//
//  ViewController.m
//  SKNetworkingDemo
//
//  Created by wushangkun on 16/5/19.
//  Copyright © 2016年 wushangkun. All rights reserved.
//

#import "ViewController.h"
#import "SKDownloadCell.h"
#import "SKNetworking.h"
#import "SKDownloadModel.h"


@interface ViewController () <UITableViewDelegate,UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *dataArray;

@end

@implementation ViewController


#pragma mark -- Life circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initSubViews];
    
    [self loadListData];
    
    [SKNetworking enableInterfaceDebug:YES];
    [SKNetworking updateLocalAllTasks];
}



#pragma mark -- UITableViewDelegate & UITableViewDataSource

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 80;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.dataArray.count;
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {

    return @"删除";
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    // 左侧删除
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
         SKDownloadModel *model = self.dataArray[indexPath.row];
        
         [self cancelDownloadWithModel:model];
        
        [self.dataArray removeObjectAtIndex:indexPath.row];
    
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //SKDownloadCell *cell = [tableView dequeueReusableCellWithIdentifier:[SKDownloadCell description] forIndexPath:indexPath];
    SKDownloadCell *cell = [tableView dequeueReusableCellWithIdentifier:[SKDownloadCell description]];
    __weak typeof(self) weakSelf = self;
    if (!cell) {
        NSArray *nibArray = [[NSBundle mainBundle]loadNibNamed:[SKDownloadCell description] owner:nil options:nil];
        for (id obj in nibArray) {
            if ([obj isKindOfClass:SKDownloadCell.self]) {
                cell = obj;
                break;
            }
        }
    }
    SKDownloadModel *model = self.dataArray[indexPath.row];
    [model setTag:indexPath.row];
    [cell setModel:model];
    __weak typeof(cell) weakCell = cell;
    cell.startDownloadAciton = ^(SKDownloadModel *model) {
        
        switch (model.status) {
            case kSKDownloadStatusNotLoaded:
            {
                NSLog(@"开始缓存%ld",indexPath.row);
                [weakSelf downloadWithModel:model withTableViewCell:weakCell];
            }
                break;
            case kSKDownloadStatusIsLoading:
            {
                NSLog(@"暂定缓存%ld",indexPath.row);
                [weakSelf pauseDownloadWithModel:model];
            }
                break;
            case kSKDownloadStatusPausing:
            {
                NSLog(@"继续缓存%ld",indexPath.row);
                [weakSelf downloadWithModel:model withTableViewCell:weakCell];

            }
                break;
            case kSKDownloadStatusDone:
                NSLog(@"缓存完成%ld",indexPath.row);
                break;
            case kSKDownloadStatusError:
                NSLog(@"缓存出错！");
                break;
            default:
                break;
        }


    };
    return cell;
}


#pragma mark -- Private method

-(void)cancelDownloadWithModel:(SKDownloadModel *)model{

    [SKNetworking cancelDownloadWithUrl:model.linkUrl];
}

#pragma mark -- 下载
- (void)downloadWithModel:(SKDownloadModel *)model withTableViewCell:(SKDownloadCell *)cell {

    [SKNetworking downloadWithUrl:model.linkUrl
                             cachePath:model.destinationPath
                              progress:^(int64_t bytesRead, int64_t totalBytesRead,NSString *speed) {
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      model.status = kSKDownloadStatusIsLoading;
                                      model.bytesRead = bytesRead;
                                      model.totalBytesRead = totalBytesRead;
                                      model.speed = speed;
                                      [self _dispactchUpdateUIWith:model withTableViewCell:cell];
                                  });
                              }
                               success:^(id response) {
                                   NSLog(@"%@",response);
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       model.status = kSKDownloadStatusDone;
                                       [self _dispactchUpdateUIWith:model withTableViewCell:cell];
                                   });
                               }
                               failure:^(NSError *error, SKDownloadingStatus downloadStatus) {
                                   
                                   if (downloadStatus == kSKDownloadingStatusSuspended) {
                                          model.status = kSKDownloadStatusPausing;
                                   } else {
                                          model.status = kSKDownloadStatusError;
                                   }
                                   
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       [self _dispactchUpdateUIWith:model withTableViewCell:cell];
                                   });
                                   
                               }];}

/**
 *  继续下载
 */
- (void)resumeDownloadWithModel:(SKDownloadModel *)model withTableViewCell:(SKDownloadCell *)cell {

    [SKNetworking resumeDownloadWithUrl:model.linkUrl
                               progress:^(int64_t bytesRead, int64_t totalBytesRead,NSString *speed) {
                                   
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       model.status = kSKDownloadStatusIsLoading;
                                       model.bytesRead = bytesRead;
                                       model.totalBytesRead = totalBytesRead;
                                       model.speed = speed;
                                       [self _dispactchUpdateUIWith:model withTableViewCell:cell];
                                   });
                               }
                                success:^(id response) {
                                    //
                                    NSLog(@"%@",response);
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        model.status = kSKDownloadStatusDone;
                                        [self _dispactchUpdateUIWith:model withTableViewCell:cell];
                                    });

                                }
                                failure:^(NSError *error , SKDownloadingStatus downloadStatus) {
                                    if(error.code == NSURLErrorCancelled) { //正在暂停
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            model.status = kSKDownloadStatusPausing;
                                            [self _dispactchUpdateUIWith:model withTableViewCell:cell];
                                        });
                                    }else {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            model.status = kSKDownloadStatusError;
                                            [self _dispactchUpdateUIWith:model withTableViewCell:cell];
                                        });
                                    }

                                }];
    
    
}




/**
 *  暂停下载
 */
- (void)pauseDownloadWithModel:(SKDownloadModel *)model {

    [SKNetworking pauseDownloadWithUrl:model.linkUrl];
}


/**
 *  开始下载
 */
- (void)startDownloadWithModel:(SKDownloadModel *)model withTableViewCell:(SKDownloadCell *)cell{

    [SKNetworking startDownloadWithUrl:model.linkUrl
                       cachePath:model.destinationPath
                        progress:^(int64_t bytesRead, int64_t totalBytesRead,NSString *speed) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                model.status = kSKDownloadStatusIsLoading;
                                model.bytesRead = bytesRead;
                                model.totalBytesRead = totalBytesRead;
                                model.speed = speed;
                                [self _dispactchUpdateUIWith:model withTableViewCell:cell];
                            });
                        }
                         success:^(id response) {
                             NSLog(@"%@",response);
                             dispatch_async(dispatch_get_main_queue(), ^{
                                 model.status = kSKDownloadStatusDone;
                                 [self _dispactchUpdateUIWith:model withTableViewCell:cell];
                             });
                         }
                         failure:^(NSError *error ,SKDownloadingStatus downloadStatus) {
                             
                             if(error.code == NSURLErrorCancelled) { //正在暂停
                                 
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     model.status = kSKDownloadStatusPausing;
                                     [self _dispactchUpdateUIWith:model withTableViewCell:cell];
                                 });
                             }
                         }];
}

-(void)_dispactchUpdateUIWith:(SKDownloadModel *)model  withTableViewCell:(SKDownloadCell *)cell {
    cell.model = model;
}


/**
 *  初始化视图
 */
-(void)initSubViews {
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.tableView];
}
/**
 *  加载默认数据
 */
-(void)loadListData {
    
    for (int i=1; i<5; i++) {
        SKDownloadModel *model = [[SKDownloadModel alloc]init];
        model.tag = i-1;
        model.bytesRead = 0;
        model.totalBytesRead = 1;
        model.name = [NSString stringWithFormat:@"速度与激情%d",i];
        switch (i) {
            case 1:
                  model.linkUrl = @"http://mw5.dwstatic.com/1/3/1528/133489-99-1436409822.mp4";
                break;
            case 2:
                model.linkUrl = @"http://android-mirror.bugly.qq.com:8080/eclipse_mirror/juno/content.jar";
                break;
            case 3:
                model.linkUrl = @"http://dlsw.baidu.com/sw-search-sp/soft/2a/25677/QQ_V4.1.1.1456905733.dmg";
                break;
            case 4:
                model.linkUrl = @"http://mw2.dwstatic.com/2/8/1528/133366-99-1436362095.mp4";
                break;
            default:
                break;
        }
        NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        model.destinationPath = [cacheDir stringByAppendingPathComponent:model.name];
        model.status = kSKDownloadStatusNotLoaded;
        [self.dataArray addObject:model];
    }
    [self.tableView reloadData];
}

-(UITableView *)tableView {
    if (!_tableView) {
        CGRect rect = self.view.bounds;
        rect.origin.y += 20;
        _tableView = [[UITableView alloc]initWithFrame:rect style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource =self;
        [_tableView setRowHeight:80];
        /**
         *  用 xib 创建的 cell, 给cell里的任一控件 添加 点击手势（非代码添加）时, 运行以下registerNib代码会报错！
         *  猜测原因: 添加的手势（object） 在nib里 和 该cell是同一级，而以下代码 要求 nib 里面必须只能 包含一个UITableViewCell对象
         */
        //[_tableView registerNib:[UINib nibWithNibName:@"SKDownloadCell" bundle:nil]forCellReuseIdentifier:@"SKDownloadCell"];
    }
    return _tableView;
}

-(NSMutableArray *)dataArray{
    if (!_dataArray) {
        _dataArray = [NSMutableArray array];
    }
    return _dataArray;
}

@end
