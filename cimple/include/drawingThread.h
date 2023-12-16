//
// Created by no3core on 2023/12/15.
//

#ifndef BIT_RUN_DRAWINGTHREAD_H
#define BIT_RUN_DRAWINGTHREAD_H

#include "windows.h"
#include "image.h"

DWORD _refresh_interval_thread(LPVOID lpParam);
DWORD _render_window_thread(LPVOID lpParam);
DWORD _render_buffer_thread(LPVOID lpParam);

void _render_buffer();
void _render_window();

 typedef struct RenderObject{
     int x;
     int y;
     int z;
     Image* p_image;
 } RenderObject ;

#endif //BIT_RUN_DRAWINGTHREAD_H
