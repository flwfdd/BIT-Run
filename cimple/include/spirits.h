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


typedef struct Spirit{
    RenderObject *prObj;
    float vx; // relative to goose Reference System
    float vy;
    float x;
    float y;

    int jumping; // 0: not jumping, 1: jumping
    int jumptstp;
}Spirit;


void _init_state();




void _state_update();
void _key_down(WPARAM wParam, LPARAM lParam);

#endif //BIT_RUN_SPIRITS_H
