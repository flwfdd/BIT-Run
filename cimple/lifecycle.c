//
// Created by no3core on 2023/12/15.
//
#include "windows.h"
#include "lifecycle.h"
#include "drawingThread.h"
#include "BIT_run.h"
#include "image.h"

Image image_demo = {
        ".\\image\\tower25x50.bmp"
        ,0,0,0,0,0,0};

// event handle here
volatile int thread_live =1;
HANDLE h_draw_buffer_event;

HANDLE h_draw_window_event;

extern HDC ha_buffer_dc[BUFFER_SIZE];
extern HBITMAP ha_buffer_bmp[BUFFER_SIZE];

extern HWND      h_window_main;
extern HINSTANCE h_instance;

void _init(){
    // initial event
    h_draw_buffer_event = CreateEvent(
            NULL,//security
            TRUE, // manual reset
            FALSE,// initial state
            NULL//name
    );

    h_draw_window_event = CreateEvent(
            NULL,//security
            TRUE, // manual reset
            FALSE,// initial state
            NULL//name
    );

    _init_buffer();
    _init_images();

    // thread start
    CreateThread(NULL,0,_refresh_interval_thread,NULL,0,NULL);
    CreateThread(NULL,0,_draw_buffer_thread,NULL,0,NULL);
    CreateThread(NULL,0,_draw_window_thread,NULL,0,NULL);

}

void _close() {
    thread_live = 1;
    _free_images();
    _free_buffer();

    CloseHandle(h_draw_window_event);
    CloseHandle(h_draw_buffer_event);

    DestroyWindow(h_window_main);
    PostQuitMessage(0);
}


void _init_buffer() {
    HDC h_dc;
    int cnt;

    h_dc = GetDC(h_window_main);

    cnt = 0;
    while(cnt!=BUFFER_SIZE){
        ha_buffer_dc[cnt] = CreateCompatibleDC(h_dc);
        ha_buffer_bmp[cnt]= CreateCompatibleBitmap(h_dc,WINDOW_WIDTH,WINDOW_HEIGHT);
        SelectObject(ha_buffer_dc[cnt],ha_buffer_bmp[cnt]);
        cnt++;
    }

    ReleaseDC(h_window_main,h_dc);
}

void _free_buffer() {
    int cnt = 0;
    while(cnt!=BUFFER_SIZE){
        // TODO: order?
        DeleteDC(ha_buffer_dc[cnt]);
        DeleteObject(ha_buffer_bmp[cnt]);
        cnt++;
    }
}

void _init_images() {
    _init_image(&image_demo);

}

void _free_images() {
    _free_image(&image_demo);
}

void _init_image(pImage p_image) {

    HDC h_dc;
    BITMAP bmp;

    h_dc=GetDC(h_window_main);
    p_image->h_dc = CreateCompatibleDC(h_dc);
    ReleaseDC(h_window_main,h_dc);

//    p_image->h_bmp= LoadBitmap(h_instance,p_image->id);
//    p_image->h_bmp= LoadBitmap(NULL,p_image->nameid);
    p_image->h_bmp = (HBITMAP)LoadImage(
            NULL, p_image->nameid,
            IMAGE_BITMAP,
            0,
            0,
            LR_LOADFROMFILE | LR_CREATEDIBSECTION
    );

    SelectObject(p_image->h_dc,p_image->h_bmp);
    GetObject(p_image->h_bmp,sizeof(BITMAP),&bmp);
    p_image->h = bmp.bmHeight;
    p_image->w = bmp.bmWidth;

    // setting mask here
    p_image->a_mask = malloc(bmp.bmHeight*bmp.bmWidth);
    char*p = (char*)p_image->a_mask;
    for (int i = 0; i < bmp.bmHeight; ++i) {
        for (int j = 0; j < bmp.bmWidth; ++j) {
            COLORREF color = GetPixel(p_image->h_dc,i,j);
            if(color==p_image->mask_color)
                *p = 0;
            else
                *p = 1;
            p++;
        }
    }

}

void _free_image(pImage p_image) {
    DeleteDC(p_image->h_dc);
    DeleteObject(p_image->h_bmp);
    free(p_image->a_mask);
}


