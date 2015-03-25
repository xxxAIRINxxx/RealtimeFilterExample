//
//  OpenCVSampleFilter.m
//  RealtimeFilterExample
//
//  Created by xxxAIRINxxx on 2015/03/17.
//  Copyright (c) 2015年 xxxAIRINxxx. All rights reserved.
//

#import "OpenCVSampleFilter-Bridging-Header.h"

#import <opencv2/opencv.hpp>

@implementation OpenCVSampleFilter

+ (UIImage *)mangaImageFromUIImage:(UIImage *)image
{
    CGImageRef monocrhomeCGImage = [[self class] reflectMonochromeFilter:image.CGImage];
    UIImage *monocrhomeImage = [UIImage imageWithCGImage:monocrhomeCGImage];
    CGImageRelease(monocrhomeCGImage);
    
    CGImageRef lineCGImage = [[self class] reflectLineFilter:image.CGImage];
    UIImage *lineImage = [UIImage imageWithCGImage:lineCGImage];
    CGImageRelease(lineCGImage);
    
    UIImage *margedImage;
    CGRect imageRect = CGRectMake(0, 0, image.size.width, image.size.height);
    
    UIGraphicsBeginImageContext(imageRect.size);
    
    [monocrhomeImage drawInRect:imageRect];
    [lineImage drawInRect:imageRect];
    margedImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    if (margedImage) {
        return margedImage;
    }
    return [UIImage new];
}

// @see : http://dev.classmethod.jp/smartphone/opencv-manga-2/

+ (IplImage *)iplImageFromCGImage:(CGImageRef)image
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    IplImage *tempIplImage = cvCreateImage(cvSize((int)CGImageGetWidth(image), (int)CGImageGetHeight(image)), IPL_DEPTH_8U, 4);
    
    CGContextRef context = CGBitmapContextCreate(tempIplImage->imageData,
                                                 tempIplImage->width,
                                                 tempIplImage->height,
                                                 tempIplImage->depth,
                                                 tempIplImage->widthStep,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, CGImageGetWidth(image), CGImageGetHeight(image)), image);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    IplImage *iplImage = cvCreateImage(cvGetSize(tempIplImage), IPL_DEPTH_8U, 3);
    cvCvtColor(tempIplImage, iplImage, CV_RGBA2RGB);
    
    cvReleaseImage(&tempIplImage);
    
    return iplImage;
}

+ (CGImageRef)cgImageFromIplImage:(IplImage *)image
{
    NSData *data = [NSData dataWithBytes:image->imageData length:image->imageSize];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(image->width,
                                       image->height,
                                       image->depth,
                                       image->depth * image->nChannels,
                                       image->widthStep,
                                       colorSpace,
                                       kCGImageAlphaNone | kCGBitmapByteOrderDefault,
                                       provider,
                                       NULL,
                                       false,
                                       kCGRenderingIntentDefault);
    
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    
    return cgImage;
}

+ (CGImageRef)reflectLineFilter:(CGImageRef)image
{
    IplImage *srcImage = [[self class] iplImageFromCGImage:image];
    
    IplImage *grayscaleImage = cvCreateImage(cvGetSize(srcImage), IPL_DEPTH_8U, 1);
    IplImage *edgeImage = cvCreateImage(cvGetSize(srcImage), IPL_DEPTH_8U, 1);
    IplImage *dstImage = cvCreateImage(cvGetSize(srcImage), IPL_DEPTH_8U, 3);
    
    cvCvtColor(srcImage, grayscaleImage, CV_BGR2GRAY);
    cvSmooth(grayscaleImage, grayscaleImage, CV_GAUSSIAN, 3, 0, 0);
    cvCanny(grayscaleImage, edgeImage, 20, 120);
    cvNot(edgeImage, edgeImage);
    cvCvtColor(edgeImage, dstImage, CV_GRAY2BGR);
    
    CGImageRef effectedImage = [self cgImageFromIplImage:dstImage];
    
    cvReleaseImage(&srcImage);
    cvReleaseImage(&grayscaleImage);
    cvReleaseImage(&edgeImage);
    cvReleaseImage(&dstImage);
    
    const CGFloat colorMasking[6] = {255, 255, 255, 255, 255, 255};
    effectedImage = CGImageCreateWithMaskingColors(effectedImage, colorMasking);
    
    return effectedImage;
}

+ (CGImageRef)reflectMonochromeFilter:(CGImageRef)image
{
    IplImage *srcImage = [[self class] iplImageFromCGImage:image];
    
    IplImage *grayscaleImage = cvCreateImage(cvGetSize(srcImage), IPL_DEPTH_8U, 1);
    IplImage *dstImage = cvCreateImage(cvGetSize(srcImage), IPL_DEPTH_8U, 3);
    
    cvCvtColor(srcImage, grayscaleImage, CV_BGR2GRAY);
    
    for (int y = 0; y < grayscaleImage->height; y++) {
        for (int x = 0; x < grayscaleImage->width; x++) {
            int a = grayscaleImage->widthStep * y + x;
            uchar p = grayscaleImage->imageData[a];
            
            if (p < 70) {
                // black color
                grayscaleImage->imageData[a] = 0;
            } else if (70 <= p && p < 120) {
                // gray color
                grayscaleImage->imageData[a] = 100;
            } else {
                // white color
                grayscaleImage->imageData[a] = 255;
            }
        }
    }
    
    cvCvtColor(grayscaleImage, dstImage, CV_GRAY2BGR);
    
    CGImageRef effectedImage = [self cgImageFromIplImage:dstImage];
    
    cvReleaseImage(&srcImage);
    cvReleaseImage(&grayscaleImage);
    cvReleaseImage(&dstImage);
    
    const CGFloat colorMasking[6] = {100, 100, 100, 100, 100, 100};
    effectedImage = CGImageCreateWithMaskingColors(effectedImage, colorMasking);
    
    return effectedImage;
}

@end
