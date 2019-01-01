#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

typedef UInt64 OSSize;

#if __has_include("XKBitmapFontData.h")

#include "XKBitmapFontData.h"

void writeCharacter(uint32_t *buffer, NSInteger width, NSInteger height, NSInteger x, NSInteger y, NSInteger character)
{
    for (NSInteger iy = y; iy < y + kXKBitmapFontGlyphHeight; iy++)
    {
        UInt8 row = gXKBitmapFont8x16Data[character][iy - y];

        for (NSInteger ix = x; ix < x + kXKBitmapFontGlyphWidth; ix++)
        {
            BOOL active = (row >> (ix - x)) & 1;

            if (active) {
                buffer[(iy * width) + ix] = 0xFF00FF;
            } else {
                buffer[(iy * width) + ix] = 0xFFFFFF;
            }
        }
    }
}

void reverseTransform(uint32_t *buffer, NSInteger height, NSInteger width)
{
    for (NSInteger y = 0; y < height; y += kXKBitmapFontGlyphHeight)
    {
        for (NSInteger x = 0; x < width; x += kXKBitmapFontGlyphWidth)
        {
            NSInteger character = (y + (x / kXKBitmapFontGlyphWidth));

            writeCharacter(buffer, width, height, x, y, character);
        }
    }
}

void doReverse(NSURL *url, BOOL hasBorder)
{
    NSInteger totalSize = kXKBitmapFontGlyphCount * (kXKBitmapFontGlyphHeight * kXKBitmapFontGlyphWidth);
    NSInteger imageHeight = (kXKBitmapFontGlyphCount / kXKBitmapFontGlyphHeight) * kXKBitmapFontGlyphHeight;
    NSInteger imageWidth = totalSize / imageHeight;

    NSBitmapImageRep *bitmapImage = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
            pixelsWide:imageWidth pixelsHigh:imageHeight
            bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO
            isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace
            bytesPerRow:(imageWidth * 4) bitsPerPixel:32];

    reverseTransform((uint32_t *)[bitmapImage bitmapData], imageHeight, imageWidth);

    NSData *pngData = [bitmapImage representationUsingType:NSPNGFileType properties:@{}];
    [pngData writeToURL:url atomically:YES];
}

#else /* !__has_include("XKBitmapFontData.h") */

void doReverse(NSURL *url)
{
    printf("This binary hasn't been compiled with the proper header to recreate the font source image.\n");
    printf("Please run the program and then recompile.\n");
}

#endif /* __has_include("XKBitmapFontData.h") */
