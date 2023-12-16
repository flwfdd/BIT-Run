//
// Created by no3core on 2023/12/15.
//

#ifndef BIT_RUN_SPIRITS_H
#define BIT_RUN_SPIRITS_H
#include "windows.h"
#include "drawingThread.h"

#define GAME_STATUS_INIT 0
#define GAME_STATUS_RUN  1
#define GAME_STATUS_OVER 2

typedef struct GameState{
    int status;
    int time;
    int score;
    int render_object_size;
    RenderObject* a_p_render_object;
} GameState;


void _key_down(WPARAM wParam, LPARAM lParam);
void _state_update();

#endif //BIT_RUN_SPIRITS_H
