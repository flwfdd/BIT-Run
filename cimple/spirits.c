//
// Created by no3core on 2023/12/15.
//

#include <stdio.h>
#include "spirits.h"
#include "lifecycle.h"
#include "BIT_run.h"

GameState state;

// goose state
int jumping;
int presshold;
int jumptstp;

#define OBJ_BKG   0
#define OBJ_GOOSE 1
RenderObject rObjList[2];

Sprite       DebugGoose;
Sprite       DebugBkg;

void _init_state() {
    presshold = 0;
    state.score = 0;
    state.status = GAME_STATUS_INIT;
    state.global_vx = -GINITVX;
    // debugging use
    state.render_object_size = 2;
    state.a_p_render_object =rObjList;

    // debug for goose move
    rObjList[OBJ_GOOSE].x=GOOSE_INITIAL_X;
    rObjList[OBJ_GOOSE].y=GOOSE_INITIAL_Y;
    rObjList[OBJ_GOOSE].z=1;
    rObjList[OBJ_GOOSE].p_image = _get_image("./image/goose_run0.bmp");

    rObjList[OBJ_BKG].x=0;
    rObjList[OBJ_BKG].y=0;
    rObjList[OBJ_BKG].z=0;
    rObjList[OBJ_BKG].p_image = _get_image("./image/back_ground.bmp");


    DebugGoose.prObj = &rObjList[OBJ_GOOSE];
    DebugGoose.y  = GOOSE_INITIAL_Y;
    DebugGoose.vx = 0;
    DebugGoose.vy = 0;
    jumping = 0;

    DebugBkg.prObj = &rObjList[OBJ_BKG];
    DebugBkg.vx = -GINITVX;
    DebugBkg.vy = 0;


}

void _state_update(){

    // updating goose (may move to a single func)

    if(!jumping){
        if(state.time&0x10){
            rObjList[OBJ_GOOSE].p_image = _get_image("./image/goose_run0.bmp");
        } else{
            rObjList[OBJ_GOOSE].p_image = _get_image("./image/goose_run1.bmp");
        }
    } else{
        int deltat = state.time - jumptstp;
        // motion calculate
        float fdelta = 0.001*deltat;

        float accer  = (presshold)?(G-JG):G;
        if(presshold) presshold = 0;

        DebugGoose.y = DebugGoose.y + DebugGoose.vy*fdelta - 0.5*accer*fdelta*fdelta;
        DebugGoose.vy = DebugGoose.vy - accer*fdelta;


        // discrete the px location
        DebugGoose.prObj->y = (int)DebugGoose.y;

        printf("goose state update y:%f vy:%f!\n",DebugGoose.y,DebugGoose.vy);

        // check if it is on the ground
        if(DebugGoose.y<=HORIZON_HEIGHT){
            printf("goose onground!\n");
            jumping = 0;
            DebugGoose.y = GOOSE_INITIAL_Y;
            DebugGoose.vy= 0;

            DebugGoose.prObj->y = GOOSE_INITIAL_Y;
            DebugGoose.prObj->p_image = _get_image("./image/goose_run0.bmp");
        }
    }

    // updating the background




}


void _key_down(WPARAM wParam, LPARAM lParam) {
    if(wParam==VK_SPACE){
        switch (state.status) {
            case GAME_STATUS_INIT:
                state.status = GAME_STATUS_RUN;
            case GAME_STATUS_RUN:{
                printf("\ndetect keypress\n");
                presshold = 1;

                // set its to jump
                if(jumping==0){
                    printf("goose jumpped!\n");
                    jumping = 1;
                    DebugGoose.vy = JUMPVY;
                    DebugGoose.prObj->p_image = _get_image("./image/goose_jump.bmp");
                    jumptstp = state.time;
                } else{
                    printf("goose is jumpping,add more jump!\n");
                }
                break;
            }
            case GAME_STATUS_OVER:
                state.status = GAME_STATUS_INIT;
                break;
            default:
                break;
        }
    }

}
