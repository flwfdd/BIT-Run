//
// Created by no3core on 2023/12/15.
//

#include <stdio.h>
#include "drawingThread.h"
#include "BIT_run.h"
#include "image.h"
#include "spirits.h"

extern
HWND      h_window_main;

// the drawing buffer
int buffer_index = 0;
HDC ha_buffer_dc[BUFFER_SIZE];
HBITMAP ha_buffer_bmp[BUFFER_SIZE];

Image*p_a_image;

// thread & event control
extern volatile int thread_live ;
extern HANDLE p_render_buffer_event;
extern HANDLE p_render_window_event;

// drawing
long long game_ms = 0;

extern GameState state;


DWORD _refresh_interval_thread(LPVOID lpParam) {
    // temp no change to here
    while(thread_live==1){
        putchar('.');
        SetEvent(p_render_buffer_event);
        Sleep(1000/FPS);
        game_ms+=1000/FPS;

        state.time = game_ms;
    }
    return 0;
}


DWORD _render_buffer_thread(LPVOID lpParam) {
    while(thread_live==1){
        WaitForSingleObject(p_render_buffer_event, INFINITE);
        ResetEvent(p_render_buffer_event);

        _state_update();
        _render_buffer();

        SetEvent(p_render_window_event);
    }
    return 0;
}
DWORD _render_window_thread(LPVOID lpParam) {

    while(thread_live==1){
        WaitForSingleObject(p_render_window_event, INFINITE);
        ResetEvent(p_render_window_event);
        _render_window();
    }

    return 0;
}

extern GameState state;
void _render_buffer() {
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

    // loop to paint all image
    for (int i = 0; i < state.render_object_size; ++i) {
        RenderObject* p_render_object = state.a_p_render_object+i;
        Image*        p_image = p_render_object->p_image;
        TransparentBlt(
                ha_buffer_dc[indx],
                p_render_object->x,
                WINDOW_HEIGHT-p_image->h-p_render_object->y,
                p_image->w,
                p_image->h,
                p_image->h_dc,
                0,0,
                p_image->w,
                p_image->h,
                p_image->mask_color
        );
    }

    buffer_index = indx;

}
void _render_window() {
    HDC h_dc;
    int buffer_index_l ;

    buffer_index_l = buffer_index;

    //DEBUG
    putchar('a'+buffer_index_l);

    h_dc = GetDC(h_window_main);
    BitBlt(h_dc,0,0,WINDOW_WIDTH,WINDOW_HEIGHT,
           ha_buffer_dc[buffer_index_l],
           0,0,
           SRCCOPY
    );
    ReleaseDC(h_window_main,h_dc);
}
