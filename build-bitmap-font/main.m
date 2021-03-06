#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#define kGlyphCount  0x80
#define kGlyphHeight 0x10

NSString *fileHeader = @"/********************************************************************************************/\n"
                        "/* +-+ WARNING: Autogenerated header file! Make changes to 'build-bitmap-font' instead. +-+ */\n"
                        "/********************************************************************************************/\n";

NSString *sectionAttribute = @"__attribute__((section(\"__DATA,__bootlogo\"))) ";
NSMutableString *header;

extern void doReverse(NSURL *url, BOOL hasBorder);

void write_data(NSData *data, NSURL *location)
{
    NSError *error;
    BOOL created = [data writeToURL:location options:NSDataWritingAtomic error:&error];

    if (!created)
    {
        printf("Error: Could not write to '%s'. (Error: %s)\n", [[location absoluteString] UTF8String], [[error localizedDescription] UTF8String]);
        exit(EXIT_FAILURE);
    }
}

void process_character(NSBitmapImageRep *image, NSInteger x, NSInteger y, uint8_t out_buffer[16], BOOL isInverted)
{
    for (NSInteger iy = y; iy < y + 16; iy++)
    {
        uint8_t row = 0;

        for (NSInteger ix = x; ix < x + 8; ix++)
        {
            NSUInteger pixelData[4];
            [image getPixel:pixelData atX:ix y:iy];

            CGFloat average = pixelData[0] + pixelData[1] + pixelData[2];
            average *= (pixelData[3] / 255.0F) / (255.0F * 3.0F);

            BOOL on = isInverted ? (average > 0.5F) : (average < 0.5F);
            row |= on << (ix - x);
        }

        out_buffer[iy - y] = row;
    }
}

NSString *encode_charset(uint8_t glyph_buffer[kGlyphCount][kGlyphHeight])
{
    NSString *variableName = @"const static UInt8 gXKBitmapFont8x16Data";
    NSMutableString *encodedString = [[NSMutableString alloc] init];

    [encodedString appendString:[NSString stringWithFormat:@"%@[0x%X][0x%X] = {", variableName, kGlyphCount, kGlyphHeight]];
    [encodedString appendString:@"\n"];

    for (NSInteger i = 0; i < kGlyphCount; i++)
    {
        char c = isprint((int)i) ? (char)i : ' ';

        [encodedString appendFormat:@"    /* %c */ {", c];

        for (NSInteger j = 0; j < kGlyphHeight; j++)
        {
            [encodedString appendString:[NSString stringWithFormat:@"0x%02X", glyph_buffer[i][j]]];

            if (j == 0xF)   [encodedString appendString:@"}"];
            else            [encodedString appendString:@", "];
        }

        if (i == (kGlyphCount - 1)) [encodedString appendString:@"\n};\n\n"];
        else                        [encodedString appendString:@",\n"];
    }

    return [encodedString copy];
}

void process_image(NSData *data, NSURL *outputURL, BOOL hasBorder, BOOL isInverted)
{
    NSBitmapImageRep *image = [[NSBitmapImageRep alloc] initWithData:data];
    NSInteger imageHeight = [image pixelsHigh];
    NSInteger imageWidth  = [image pixelsWide];
    NSInteger charHeight = 16;
    NSInteger charWidth = 8;
    NSInteger height;
    NSInteger width;
    NSInteger y = 0;
    NSInteger x;

    if (hasBorder) {
        height = imageHeight - 1;
        width = imageWidth - 1;

        charHeight++;
        charWidth++;

        y++;
    } else {
        height = imageHeight;
        width = imageWidth;
    }

    if ((height % charHeight) || (width % charWidth))
    {
        printf("Error: Image must have a proper height and width (multiple of %zux%zu)! (Found %zux%zu)\n", charWidth, charHeight, width, height);
        exit(EXIT_FAILURE);
    }

    height /= charHeight;
    width /= charWidth;

    if ((width * height) < kGlyphCount)
    {
        printf("Error: Font image provided does not contain enough character for the full ASCII text encoding. Only found %zu glyphs. (of 128 needed)\n", width * height);
        exit(EXIT_FAILURE);
    }

    // We can do it here (just encode first 128 glyphs)
    uint8_t glyph_buffer[kGlyphCount][kGlyphHeight];

    for ( ; y < imageHeight; y += charHeight)
    {
        x = (hasBorder ? 1 : 0);

        for ( ; x < imageWidth; x += charWidth)
        {
            NSInteger character = ((y / charHeight) * width) + (x / charWidth);

            if (character > kGlyphCount)
                break;

            process_character(image, x, y, glyph_buffer[character], isInverted);
        }
    }

    [header appendFormat:@"const static UInt16 kXKBitmapFontGlyphCount = 0x%X;\n", kGlyphCount];
    [header appendFormat:@"const static UInt16 kXKBitmapFontGlyphHeight = 0x%X;\n", kGlyphHeight];
    [header appendFormat:@"const static UInt16 kXKBitmapFontGlyphWidth = 0x8;\n\n"];
    [header appendString:encode_charset(glyph_buffer)];

    write_data([NSData dataWithBytes:[header UTF8String] length:[header length]], outputURL);
}

int main(int argc, const char *const *argv)
{
    @autoreleasepool
    {
        NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity:argc];
        header = [NSMutableString string];

        [header appendString:fileHeader];
        [header appendString:@"\n"];

        for (NSInteger i = 0; i < argc; i++)
            [args addObject:[NSString stringWithUTF8String:argv[i]]];

        BOOL hasBorder = [args containsObject:@"-withBorder"];
        [args removeObject:@"-withBorder"];

        BOOL isInverted = [args containsObject:@"-isInverted"];
        [args removeObject:@"-isInverted"];

        if ([args count] < 3)
        {
            printf("Error: Not enough arguments!\n");
            exit(EXIT_FAILURE);
        }

        NSString *output = [args objectAtIndex:2];
        NSString *input = [args objectAtIndex:1];

        if ([[NSFileManager defaultManager] fileExistsAtPath:output])
            printf("Warning: Output file '%s' already exists!\n", [output UTF8String]);

        NSData *imageData = [NSData dataWithContentsOfFile:input];

        if (!imageData)
        {
            printf("Error: Input image '%s' does not exist!\n", [input UTF8String]);
            exit(EXIT_FAILURE);
        }

        process_image(imageData, [NSURL fileURLWithPath:output], hasBorder, isInverted);

        if ([args count] > 3)
            doReverse([NSURL fileURLWithPath:[args objectAtIndex:3]], hasBorder);
    }

    return EXIT_SUCCESS;
}
