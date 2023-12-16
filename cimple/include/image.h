//
// Created by no3core on 2023/12/15.
//

#ifndef BIT_RUN_IMAGE_H
#define BIT_RUN_IMAGE_H

#include "windows.h"

typedef struct Image {
//    DWORD id;
    const TCHAR*nameid;
    DWORD w;
    DWORD h;
    DWORD mask_color;
    HANDLE h_dc;
    HANDLE h_bmp;
    DWORD* a_mask;
} Image,*pImage;


#endif //BIT_RUN_IMAGE_H
