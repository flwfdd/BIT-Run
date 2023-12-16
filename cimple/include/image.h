//
// Created by no3core on 2023/12/15.
//

#ifndef BIT_RUN_IMAGE_H
#define BIT_RUN_IMAGE_H

#include "windows.h"

typedef struct Image {
//    DWORD id;
    const TCHAR*nameid;
    int w;
    int h;
    int mask_color;
    HANDLE h_dc;
    HANDLE h_bmp;
    int* a_mask;
} Image,*pImage;


#endif //BIT_RUN_IMAGE_H
