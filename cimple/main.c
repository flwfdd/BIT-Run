//
// Created by no3core on 2023/12/15.
//

#include "windows.h"
#include "BIT_run.h"
#include "spirits.h"
#include "lifecycle.h"
#include "winuser.h"
//#include "shellscalingapi.h"

// global vars
HINSTANCE h_instance;
HWND      h_window_main;


const char* S_MAIN_CLASS_NAME = "main_window_class";
const char* S_MAIN_WINDOW_TITLE = "北理润 - BITRun";


LRESULT CALLBACK _main_window_proc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);


int main(){ //_main_window
    WNDCLASSEX at_window_class;
    MSG      at_st_msg;

    h_instance = (HINSTANCE)GetModuleHandle(NULL);

    // memset zero
    RtlZeroMemory(&at_window_class,sizeof(at_window_class));

    // temp no icon
    // at_window_class.hicon  =

    // use default system arrow cursor
    at_window_class.hCursor   = LoadCursor(NULL,IDC_ARROW);
    at_window_class.hInstance = h_instance;
    at_window_class.cbSize    = sizeof(WNDCLASSEX);
    // redraw whole window when resize its edge
    at_window_class.style     = CS_HREDRAW | CS_VREDRAW;
    at_window_class.lpfnWndProc = _main_window_proc;

    // use a brush/ color(need to add one)
    at_window_class.hbrBackground = (HBRUSH)COLOR_WINDOW+1;
    at_window_class.lpszClassName = S_MAIN_CLASS_NAME;

    RegisterClassEx(&at_window_class);


    // use these to create proper size window
    // (no adjust for dpi and bias for style)
    SetProcessDPIAware();
    RECT adjustWindowSize={0,0,WINDOW_WIDTH,WINDOW_HEIGHT};
    AdjustWindowRect(&adjustWindowSize,( WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX ),0);

    h_window_main = CreateWindowEx(
            0, // no window extended style
            S_MAIN_CLASS_NAME,
            S_MAIN_WINDOW_TITLE,
            ( WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX ) ,//TODO:??
//            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            adjustWindowSize.right-adjustWindowSize.left,
            adjustWindowSize.bottom-adjustWindowSize.top,
            NULL,NULL,//no parent/menu
            h_instance,
            NULL);

    ShowWindow(h_window_main,SW_SHOWNORMAL);
    UpdateWindow(h_window_main);

    while(1){
        if(GetMessage(&at_st_msg,NULL,0,0)==0)
            break;
        TranslateMessage(&at_st_msg);
        DispatchMessage(&at_st_msg);
    }
    return 0;
}


// window proc
LRESULT CALLBACK _main_window_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam){
    switch (msg) {
        case WM_CREATE:
            _init();
            break;
        case WM_KEYDOWN:
            _key_down(wParam,lParam);
            break;
        case WM_CLOSE:
            _close();
            break;
        default:
            return DefWindowProc(hwnd,msg,wParam,lParam);
    }
    return 0;
}
