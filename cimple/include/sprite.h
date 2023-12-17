//
// Created by no3core on 2023/12/15.
//

#ifndef BIT_RUN_SPRITE_H
#define BIT_RUN_SPRITE_H
#include "windows.h"
#include "drawingThread.h"

#define GAME_STATUS_INIT 0
#define GAME_STATUS_RUN  1
#define GAME_STATUS_OVER 2

typedef struct GameState{
    int status;
    int time;
    int score;
    int background_color;
    int render_object_size;
    RenderObject* a_p_render_object;

    int global_vx;
} GameState;




void _init_state();
void _add_render_object(RenderObject *p_render_object);
int _update_render_object(RenderObject* p_robj);

void _update_render_list(int isOver);
int _update_goose(RenderObject* p_goose);


void _state_update();
void _check_key_down();


int _check_obj_in_window(RenderObject *p_render_object);
int _check_obj_overlap(RenderObject*p_obj1,RenderObject*p_obj2);


#endif //BIT_RUN_SPRITE_H
