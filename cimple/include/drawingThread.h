//
// Created by no3core on 2023/12/15.
//

#ifndef BIT_RUN_DRAWINGTHREAD_H
#define BIT_RUN_DRAWINGTHREAD_H

#include "windows.h"

 DWORD _refresh_interval_thread(LPVOID lpParam);
 DWORD _draw_window_thread(LPVOID lpParam);
 DWORD _draw_buffer_thread(LPVOID lpParam);

#endif //BIT_RUN_DRAWINGTHREAD_H
