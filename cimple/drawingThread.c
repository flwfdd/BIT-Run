//
// Created by no3core on 2023/12/15.
//

#include <stdio.h>
#include "drawingThread.h"
#include "BIT_run.h"
#include "image.h"

extern
HWND      h_window_main;

// the drawing buffer
int buffer_index = 0;
HDC ha_buffer_dc[BUFFER_SIZE];
HBITMAP ha_buffer_bmp[BUFFER_SIZE];

// thread & event control
extern volatile int thread_live ;
extern HANDLE h_draw_buffer_event;
extern HANDLE h_draw_window_event;

// drawing
long long game_ms = 0;

//debug
extern Image image_demo;


DWORD _refresh_interval_thread(LPVOID lpParam) {
    while(thread_live==1){
        putchar('.');
        SetEvent(h_draw_buffer_event);
        Sleep(1000/FPS);
        game_ms+=1000/FPS;
    }
    return 0;
}


DWORD _draw_buffer_thread(LPVOID lpParam) {
    while(thread_live==1){
        WaitForSingleObject(h_draw_buffer_event,INFINITE);
        ResetEvent(h_draw_buffer_event);

        int indx = buffer_index;

        indx++;
        if(indx==BUFFER_SIZE)
            indx = 0;

        //DEBUG
        putchar(indx+'A');

        //DEBUG: Green square
        for (int i = 0; i < 30; ++i) {
            for (int j = 0; j < 30; ++j) {
                SetPixel(ha_buffer_dc[indx],i+indx,j,0x00FF00);
            }
        }

        //DEBUG: image
        //??
        TransparentBlt(
                ha_buffer_dc[indx],
                800-25,600-50,
                image_demo.w,image_demo.h,
                image_demo.h_dc,
                0,0,
                image_demo.w,image_demo.h,
        image_demo.mask_color);

        buffer_index = indx;
        SetEvent(h_draw_window_event);
    }
    return 0;
}

DWORD _draw_window_thread(LPVOID lpParam) {
    HDC h_dc;
    int buffer_index_l ;

    while(thread_live==1){
        WaitForSingleObject(h_draw_window_event,INFINITE);
        ResetEvent(h_draw_window_event);

        buffer_index_l = buffer_index;

        //DEBUG
        putchar('a'+buffer_index_l);

        //DEBUG
        h_dc = GetDC(h_window_main);
        BitBlt(h_dc,0,0,WINDOW_WIDTH,WINDOW_HEIGHT,
               ha_buffer_dc[buffer_index_l],
               0,0,
               SRCCOPY
               );
        ReleaseDC(h_window_main,h_dc);

    }

    return 0;
}
