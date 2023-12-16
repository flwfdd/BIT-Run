//
// Created by no3core on 2023/12/15.
//
#include <assert.h>
#include "windows.h"
#include "lifecycle.h"
#include "drawingThread.h"
#include "BIT_run.h"
#include "image.h"


// event handle here
volatile int thread_live =1;
HANDLE p_render_buffer_event;
HANDLE p_render_window_event;

extern HDC ha_buffer_dc[BUFFER_SIZE];
extern HBITMAP ha_buffer_bmp[BUFFER_SIZE];


extern HWND      h_window_main;
extern HINSTANCE h_instance;

void _init(){
    // initial event
    p_render_buffer_event = CreateEvent(
            NULL,//security
            TRUE, // manual reset
            FALSE,// initial state
            NULL//name
    );

    p_render_window_event = CreateEvent(
            NULL,//security
            TRUE, // manual reset
            FALSE,// initial state
            NULL//name
    );

    _init_render();

    // thread start
    CreateThread(NULL,0,_refresh_interval_thread,NULL,0,NULL);
    CreateThread(NULL, 0, _render_buffer_thread, NULL, 0, NULL);
    CreateThread(NULL, 0, _render_window_thread, NULL, 0, NULL);

}

void _close() {
    thread_live = 1;
    _free_render();

    CloseHandle(p_render_window_event);
    CloseHandle(p_render_buffer_event);

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
        SetStretchBltMode(ha_buffer_dc[cnt],HALFTONE);
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

extern Image*p_a_image;
#include "imagerc.h"
void _init_images() {
//    _init_image(&image_demo);
//    assert(sizeof(char*)==4);
    // different from asm
    IMAGES_SIZE = sizeof (imagesResource) / sizeof(ImageRes) - 1;
    p_a_image = malloc(sizeof(Image )*IMAGES_SIZE);
    pImage  pdst = p_a_image;
    for (ImageRes*p=(ImageRes*)imagesResource; p->id != NULL; p++,pdst++) {
        pdst->nameid = p->id;
        pdst->mask_color = p->mask_color;
        _init_image(pdst);
    }

}

void _free_images() {
    IMAGES_SIZE = sizeof (imagesResource) / sizeof(ImageRes) - 1;
    for (int i = 0; i < IMAGES_SIZE; ++i) {
        _free_image(&p_a_image[i]);
    }
    free(p_a_image);
}

void _init_image(pImage p_image) {

    HDC h_dc;
    BITMAP bmp;
    // change mask RGB to BGR
    p_image->mask_color = (p_image->mask_color&0xFF00FF00)
                          |((p_image->mask_color&0x00FF0000)>>16)
                          |((p_image->mask_color&0x000000FF)<<16);

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

    assert(p_image->h_bmp!=NULL);

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


void _init_render() {
    _init_buffer();
    _init_images();
}

void _free_render() {
    _free_buffer();
    _free_images();
}

pImage _get_image(char *nameid) {
    for (int i = 0; i < IMAGES_SIZE; ++i) {
        if(strcmp(p_a_image[i].nameid,nameid)==0){
            return &p_a_image[i];
        }
    }
    return NULL;
}
