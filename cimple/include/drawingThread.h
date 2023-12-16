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

#define OBJ_GOOSE 0
#define OBJ_DEBUG1 1
#define OBJ_DEBUG2 2
#define OBJ_DEBUG3 3
#define OBJ_NONE 42

 typedef struct RenderObject{
     Image* p_image;
     int    obj_id;
     int x;
     int y;
     int z;

     float vx; // relative to goose Reference System
     float vy;
     float phsx; //physical x
     float phsy;
     int   lasttstp; // last update time stamp


 } RenderObject ;

#endif //BIT_RUN_DRAWINGTHREAD_H
