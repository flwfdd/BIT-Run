//
// Created by no3core on 2023/12/15.
//

#ifndef BIT_RUN_LIFECYCLE_H
#define BIT_RUN_LIFECYCLE_H

#include "image.h"

void _init();
void _init_buffer();
void _free_buffer();


void _init_image(pImage p_image);
void _free_image(pImage p_image);

void _init_images();
void _free_images();


void _close();

#endif //BIT_RUN_LIFECYCLE_H
