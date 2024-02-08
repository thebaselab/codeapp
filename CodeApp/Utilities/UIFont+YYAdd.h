//
//  UIFont+YYAdd.h
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 14/5/11.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Provides extensions for `UIFont`.
 */
@interface UIFont (YYAdd) <NSCoding>
#pragma mark - Dump font data
///=============================================================================
/// @name Dump font data
///=============================================================================

/**
 Serialize and return the font data.
 
 @param font The font.
 
 @return data in TTF, or nil if an error occurs.
 */
+ (nullable NSData *)dataFromFont:(UIFont *)font;

/**
 Serialize and return the font data.
 
 @param cgFont The font.
 
 @return data in TTF, or nil if an error occurs.
 */
+ (nullable NSData *)dataFromCGFont:(CGFontRef)cgFont;

@end

NS_ASSUME_NONNULL_END
