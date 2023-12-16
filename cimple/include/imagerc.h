//
// Created by no3core on 2023/12/16.
//

#ifndef BIT_RUN_IMAGERC_H
#define BIT_RUN_IMAGERC_H

char * IMAGES_START;

char *IMAGE_GOOSE_STAND_ID = "./image/goose_stand.bmp";
int IMAGE_GOOSE_STAND_MASK_COLOR = 0x00FF00;
char *IMAGE_GOOSE_RUN0_ID  = "./image/goose_run0.bmp" ;
int IMAGE_GOOSE_RUN0_MASK_COLOR  = 0x00FF00;
char *IMAGE_GOOSE_RUN1_ID  = "./image/goose_run1.bmp" ;
int IMAGE_GOOSE_RUN1_MASK_COLOR  = 0x00FF00;
char *IMAGE_GOOSE_JUMP_ID  = "./image/goose_jump.bmp" ;
int IMAGE_GOOSE_JUMP_MASK_COLOR  = 0x00FF00;

char *IMAGE_BIT_BADGE_ID   = "./image/bit_badge.bmp";
int IMAGE_BIT_BADGE_MASK_COLOR   = 0x000000;

char *IMAGES_END;

size_t IMAGES_SIZE  ;

typedef struct {
    const char* id;
    int mask_color;
} ImageRes,*pImageRes;

const ImageRes imagesResource[] = {
        { "./image/goose_stand.bmp", 0x00FF00 },
        { "./image/goose_run0.bmp", 0x00FF00 },
        { "./image/goose_run1.bmp", 0x00FF00 },
        { "./image/goose_jump.bmp", 0x00FF00 },
        { "./image/bit_badge.bmp", 0x000000 },
        { NULL, 0 }  // 结束标识符，用于遍历时判断资源的结束位置
};

#endif //BIT_RUN_IMAGERC_H
