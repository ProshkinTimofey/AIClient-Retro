//
//  AITerminalAttachmentPickerViewController.m
//  AIClient
//
//  Theme-aware attachment picker
//

#import "AITerminalAttachmentPickerViewController.h"
#import "AIAttachment.h"
#import <Photos/Photos.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "AITheme.h"

@implementation AITerminalAttachmentPickerViewController {
    id<AITheme> _theme;
}

- (instancetype)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Attach Files";
        _selected = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _theme = [[AIThemeManager sharedManager] currentTheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(themeDidChange:)
                                                 name:@"AIThemeDidChangeNotification"
                                               object:nil];

    [self applyTheme];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"[Cancel]" style:UIBarButtonItemStylePlain target:self action:@selector(cancelTapped)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"[Done]" style:UIBarButtonItemStyleDone target:self action:@selector(doneTapped)];
    self.navigationItem.rightBarButtonItem.enabled = NO;

    [_theme styleBarButton:self.navigationItem.leftBarButtonItem withTheme:_theme];
    [_theme styleBarButton:self.navigationItem.rightBarButtonItem withTheme:_theme];

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)themeDidChange:(NSNotification *)note {
    _theme = [[AIThemeManager sharedManager] currentTheme];
    [self applyTheme];
    [self.tableView reloadData];
}

- (void)applyTheme {
    _theme = [[AIThemeManager sharedManager] currentTheme];

    self.view.backgroundColor = _theme.backgroundColor;
    self.tableView.backgroundColor = _theme.backgroundColor;
    self.tableView.separatorColor = _theme.separatorColor;

    [_theme styleNavigationBar:self.navigationController.navigationBar];
}

- (void)cancelTapped {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)doneTapped {
    if ([self.delegate respondsToSelector:@selector(attachmentPicker:didPickAttachments:)]) {
        [self.delegate attachmentPicker:self didPickAttachments:self.selected];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    return s == 0 ? [NSString stringWithFormat:@"  %@", [self addArrows:@"ADD FILES"]] : [NSString stringWithFormat:@"  %@", [self addArrows:@"SELECTED"]];
}

- (NSString *)addArrows:(NSString *)text {
    return [NSString stringWithFormat:@">> %@ <<", text];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return s == 0 ? 4 : MAX(self.selected.count, 1);
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:ip];

    [_theme styleTableViewCell:cell];
    cell.textLabel.font = _theme.fontMonospace;
    cell.detailTextLabel.font = _theme.fontCaption;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.accessoryView = nil;

    if (ip.section == 0) {
        switch (ip.row) {
            case 0: cell.textLabel.text = @"> photo_library"; cell.detailTextLabel.text = @"Photos.app"; break;
            case 1: cell.textLabel.text = @"> camera"; cell.detailTextLabel.text = @"Take photo"; break;
            case 2: cell.textLabel.text = @"> files"; cell.detailTextLabel.text = @"Documents/Cloud"; break;
            case 3: cell.textLabel.text = @"> clipboard"; cell.detailTextLabel.text = @"Paste image/file"; break;
        }
    } else {
        if (self.selected.count == 0) {
            cell.textLabel.text = @"  [Empty]";
            cell.textLabel.textColor = _theme.textMutedColor;
            cell.detailTextLabel.text = @"";
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else {
            AIAttachment *a = self.selected[ip.row];
            cell.textLabel.text = [NSString stringWithFormat:@"  %@ %@", a.type == AIAttachmentTypeImage ? @"[IMG]" : @"[FILE]", a.fileName];
            cell.detailTextLabel.text = [self fmtSize:a.fileSize];
            cell.accessoryType = UITableViewCellAccessoryNone;

            UIButton *rm = [UIButton buttonWithType:UIButtonTypeCustom];
            rm.frame = CGRectMake(0, 0, 30, 30);
            [_theme styleButton:rm forState:UIControlStateNormal];
            [rm setTitle:@"x" forState:UIControlStateNormal];
            rm.titleLabel.font = _theme.fontCaption;
            [rm setTitleColor:_theme.errorColor forState:UIControlStateNormal];
            rm.tag = ip.row;
            [rm addTarget:self action:@selector(remove:) forControlEvents:UIControlEventTouchUpInside];
            cell.accessoryView = rm;
        }
    }
    return cell;
}

- (NSString *)fmtSize:(unsigned long long)b {
    if (b < 1024) return [NSString stringWithFormat:@"%llu B", b];
    if (b < 1024*1024) return [NSString stringWithFormat:@"%.1f KB", (double)b/1024];
    return [NSString stringWithFormat:@"%.1f MB", (double)b/(1024*1024)];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 0) {
        switch (ip.row) {
            case 0: [self pickPhotos]; break;
            case 1: [self pickCamera]; break;
            case 2: [self pickFiles]; break;
            case 3: [self pickClipboard]; break;
        }
    }
}

- (void)remove:(UIButton *)b {
    [self.selected removeObjectAtIndex:b.tag];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
    self.navigationItem.rightBarButtonItem.enabled = self.selected.count > 0;
}

#pragma mark - Pickers

- (void)pickPhotos {
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *c = [[PHPickerConfiguration alloc] init];
        c.filter = PHPickerFilter.images;
        c.selectionLimit = 10;
        PHPickerViewController *p = [[PHPickerViewController alloc] initWithConfiguration:c];
        p.delegate = self;
        [self presentViewController:p animated:YES completion:nil];
    } else {
        UIImagePickerController *p = [[UIImagePickerController alloc] init];
        p.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        p.mediaTypes = @[(NSString *)kUTTypeImage];
        p.delegate = self;
        [self presentViewController:p animated:YES completion:nil];
    }
}

- (void)pickCamera {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"> no camera" message:@"Device has no camera" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [_theme styleAlertView:a];
        [a show];
        return;
    }
    UIImagePickerController *p = [[UIImagePickerController alloc] init];
    p.sourceType = UIImagePickerControllerSourceTypeCamera;
    p.mediaTypes = @[(NSString *)kUTTypeImage];
    p.delegate = self;
    [self presentViewController:p animated:YES completion:nil];
}

- (void)pickFiles {
    UIDocumentPickerViewController *p = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[(NSString *)UTTypeItemIdentifier] asCopy:YES];
    p.delegate = self;
    p.allowsMultipleSelection = YES;
    [self presentViewController:p animated:YES completion:nil];
}

- (void)pickClipboard {
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    if (pb.hasImages) {
        UIImage *img = pb.image;
        if (img) {
            AIAttachment *a = [AIAttachment attachmentWithImage:img fileName:[NSString stringWithFormat:@"clipboard_%llu.png", (unsigned long long)[[NSDate date] timeIntervalSince1970]]];
            [self.selected addObject:a];
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
            self.navigationItem.rightBarButtonItem.enabled = YES;
        }
    } else if (pb.URLs.count > 0) {
        for (NSURL *u in pb.URLs) {
            if ([u isFileURL]) {
                BOOL ok = [u startAccessingSecurityScopedResource];
                if (ok) {
                    AIAttachment *a = [[AIAttachment alloc] initWithLocalPath:u.path];
                    [self.selected addObject:a];
                    [u stopAccessingSecurityScopedResource];
                }
            }
        }
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
        self.navigationItem.rightBarButtonItem.enabled = self.selected.count > 0;
    }
}

#pragma mark - PHPickerViewControllerDelegate

- (void)picker:(PHPickerViewController *)p didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [p dismissViewControllerAnimated:YES completion:nil];
    for (PHPickerResult *r in results) {
        if ([r.itemProvider canLoadObjectOfClass:[UIImage class]]) {
            [r.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(UIImage *img, NSError *err) {
                if (img) {
                    AIAttachment *a = [AIAttachment attachmentWithImage:img fileName:[NSString stringWithFormat:@"photo_%llu.jpg", (unsigned long long)[[NSDate date] timeIntervalSince1970]]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.selected addObject:a];
                        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
                        self.navigationItem.rightBarButtonItem.enabled = YES;
                    });
                }
            }];
        }
    }
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)p didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [p dismissViewControllerAnimated:YES completion:nil];
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    if (img) {
        AIAttachment *a = [AIAttachment attachmentWithImage:img fileName:[NSString stringWithFormat:@"photo_%llu.jpg", (unsigned long long)[[NSDate date] timeIntervalSince1970]]];
        [self.selected addObject:a];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)p {
    [p dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)c didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    for (NSURL *u in urls) {
        BOOL ok = [u startAccessingSecurityScopedResource];
        if (ok) {
            AIAttachment *a = [[AIAttachment alloc] initWithLocalPath:u.path];
            [self.selected addObject:a];
            [u stopAccessingSecurityScopedResource];
        }
    }
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
    self.navigationItem.rightBarButtonItem.enabled = self.selected.count > 0;
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)c { }

@end