//
//  AIAttachmentPickerViewController.m
//  AIClient
//

#import "AIAttachmentPickerViewController.h"
#import "AIAttachment.h"
#import <Photos/Photos.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface AIAttachmentPickerViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate, PHPickerViewControllerDelegate>

@property (nonatomic, strong) NSMutableArray<AIAttachment *> *selectedAttachments;

@end

@implementation AIAttachmentPickerViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInscribedGrouped];
    if (self) {
        self.title = @"Attach Files";
        _selectedAttachments = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelTapped)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(doneTapped)];
    self.navigationItem.rightBarButtonItem.enabled = NO;

    self.tableView.registerClass:[UITableViewCell class] forCellReuseIdentifier:@"OptionCell"];
    self.tableView.registerClass:[UITableViewCell class] forCellReuseIdentifier:@"AttachmentCell"];
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)doneTapped {
    if ([self.delegate respondsToSelector:@selector(attachmentPicker:didPickAttachments:)]) {
        [self.delegate attachmentPicker:self didPickAttachments:self.selectedAttachments];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Add Files" : @"Selected Attachments";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 4; // Photo Library, Camera, Files, Pasteboard
    return MAX(self.selectedAttachments.count, 1);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OptionCell" forIndexPath:indexPath];
        var content = cell.defaultContentConfiguration;

        switch (indexPath.row) {
            case 0:
                content.text = @"Photo Library";
                content.image = [UIImage systemImageNamed:@"photo.on.rectangle"];
                content.imageProperties.tintColor = [UIColor systemBlueColor];
                break;
            case 1:
                content.text = @"Camera";
                content.image = [UIImage systemImageNamed:@"camera"];
                content.imageProperties.tintColor = [UIColor systemGreenColor];
                break;
            case 2:
                content.text = @"Files";
                content.image = [UIImage systemImageNamed:@"folder"];
                content.imageProperties.tintColor = [UIColor systemOrangeColor];
                break;
            case 3:
                content.text = @"Paste from Clipboard";
                content.image = [UIImage systemImageNamed:@"doc.on.clipboard"];
                content.imageProperties.tintColor = [UIColor systemPurpleColor];
                break;
        }

        content.imageProperties.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
        cell.contentConfiguration = content;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AttachmentCell" forIndexPath:indexPath];

        if (self.selectedAttachments.count == 0) {
            var content = cell.defaultContentConfiguration;
            content.text = @"No attachments selected";
            content.textProperties.color = [UIColor tertiaryLabel];
            content.image = [UIImage systemImageNamed:@"paperclip"];
            content.imageProperties.tintColor = [UIColor quaternaryLabel];
            cell.contentConfiguration = content;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }

        AIAttachment *attachment = self.selectedAttachments[indexPath.row];
        var content = cell.defaultContentConfiguration;

        if (attachment.type == AIAttachmentTypeImage) {
            content.text = attachment.fileName;
            content.secondaryText = [NSString stringWithFormat:@"Image • %@", [self formattedFileSize:attachment.fileSize]];
            content.image = attachment.thumbnail ?: [UIImage systemImageNamed:@"photo"];
        } else {
            content.text = attachment.fileName;
            content.secondaryText = [NSString stringWithFormat:@"Document • %@", [self formattedFileSize:attachment.fileSize]];
            content.image = [UIImage systemImageNamed:@"doc"];
        }

        content.imageProperties.tintColor = [UIColor systemBlueColor];
        content.imageProperties.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
        cell.contentConfiguration = content;

        // Remove button
        UIButton *removeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        removeButton.setImage:[UIImage systemImageNamed:@"xmark.circle.fill"], forState:UIControlStateNormal];
        removeButton.tintColor = [UIColor systemRedColor];
        removeButton.frame = CGRectMake(0, 0, 30, 30);
        [removeButton addTarget:self action:@selector(removeAttachment:) forControlEvents:UIControlEventTouchUpInside];
        removeButton.tag = indexPath.row;
        cell.accessoryView = removeButton;

        return cell;
    }
}

- (NSString *)formattedFileSize:(unsigned long long)bytes {
    if (bytes < 1024) return [NSString stringWithFormat:@"%llu B", bytes];
    if (bytes < 1024 * 1024) return [NSString stringWithFormat:@"%.1f KB", (double)bytes / 1024];
    return [NSString stringWithFormat:@"%.1f MB", (double)bytes / (1024 * 1024)];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0: [self pickFromPhotoLibrary]; break;
            case 1: [self pickFromCamera]; break;
            case 2: [self pickFromFiles]; break;
            case 3: [self pasteFromClipboard]; break;
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1 && self.selectedAttachments.count > 0;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && indexPath.section == 1) {
        [self.selectedAttachments removeObjectAtIndex:indexPath.row];
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
        self.navigationItem.rightBarButtonItem.enabled = self.selectedAttachments.count > 0;
    }
}

#pragma mark - Attachment Picking

- (void)pickFromPhotoLibrary {
    if (@available(iOS 14, *)) {
        var config = PHPickerConfiguration();
        config.filter = PHPickerFilter.images;
        config.selectionLimit = 10;
        config.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCurrent;

        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.mediaTypes = @[(NSString *)kUTTypeImage];
        picker.allowsEditing = NO;
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)pickFromCamera {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Camera Unavailable" message:@"This device does not have a camera." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.mediaTypes = @[(NSString *)kUTTypeImage];
    picker.allowsEditing = NO;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)pickFromFiles {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[(NSString *)UTTypeItemIdentifier] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)pasteFromClipboard {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];

    // Check for image
    if ([pasteboard hasImages]) {
        UIImage *image = pasteboard.image;
        if (image) {
            AIAttachment *attachment = [AIAttachment attachmentWithImage:image fileName:[NSString stringWithFormat:@"pasted_image_%llu.png", (unsigned long long)[[NSDate date] timeIntervalSince1970]]];
            [self.selectedAttachments addObject:attachment];
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
            self.navigationItem.rightBarButtonItem.enabled = YES;
        }
    }
    // Check for URLs (could be file URLs)
    else if ([pasteboard hasURLs]) {
        for (NSURL *url in pasteboard.URLs) {
            if ([url isFileURL]) {
                AIAttachment *attachment = [[AIAttachment alloc] initWithLocalPath:url.path];
                [self.selectedAttachments addObject:attachment];
            }
        }
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
        self.navigationItem.rightBarButtonItem.enabled = self.selectedAttachments.count > 0;
    }
}

- (void)removeAttachment:(UIButton *)sender {
    NSInteger index = sender.tag;
    if (index < self.selectedAttachments.count) {
        [self.selectedAttachments removeObjectAtIndex:index];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
        self.navigationItem.rightBarButtonItem.enabled = self.selectedAttachments.count > 0;
    }
}

#pragma mark - PHPickerViewControllerDelegate (iOS 14+)

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];

    for (PHPickerResult *result in results) {
        if ([result.itemProvider canLoadObjectOfClass:[UIImage class]]) {
            [result.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(UIImage *image, NSError *error) {
                if (image) {
                    AIAttachment *attachment = [AIAttachment attachmentWithImage:image fileName:[NSString stringWithFormat:@"photo_%llu.jpg", (unsigned long long)[[NSDate date] timeIntervalSince1970]]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.selectedAttachments addObject:attachment];
                        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
                        self.navigationItem.rightBarButtonItem.enabled = YES;
                    });
                }
            }];
        }
    }
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];

    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) {
        AIAttachment *attachment = [AIAttachment attachmentWithImage:image fileName:[NSString stringWithFormat:@"photo_%llu.jpg", (unsigned long long)[[NSDate date] timeIntervalSince1970]]];
        [self.selectedAttachments addObject:attachment];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    for (NSURL *url in urls) {
        // Start accessing security-scoped resource
        BOOL success = [url startAccessingSecurityScopedResource];
        if (success) {
            AIAttachment *attachment = [[AIAttachment alloc] initWithLocalPath:url.path];
            [self.selectedAttachments addObject:attachment];
            [url stopAccessingSecurityScopedResource];
        }
    }
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
    self.navigationItem.rightBarButtonItem.enabled = self.selectedAttachments.count > 0;
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    // Cancelled
}

@end