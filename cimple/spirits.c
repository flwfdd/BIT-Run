//
// Created by no3core on 2023/12/15.
//

#include <stdio.h>
#include "spirits.h"
#include "lifecycle.h"
#include "BIT_run.h"

GameState state;


RenderObject DebugObject;
Spirit       DebugGoose;

void _init_state() {
    state.score = 0;
    state.status = GAME_STATUS_INIT;
    // debugging use
    state.render_object_size = 1;

    state.a_p_render_object =&DebugObject;
    // debug for goose move
    DebugObject.x=0;
    DebugObject.y=0;
    DebugObject.z=0;

    DebugGoose.prObj = &DebugObject;
    DebugGoose.vx = 0;
    DebugGoose.vy = 0;
    DebugGoose.jumping = 0;


}

void _state_update(){
    if(!DebugGoose.jumping){
        if(state.time&0x10){
            DebugObject.p_image = _get_image("./image/goose_run0.bmp");
        } else{
            DebugObject.p_image = _get_image("./image/goose_run1.bmp");
        }
    } else{
        int deltat = state.time - DebugGoose.jumptstp;
        // motion calculate
        float fdelta = 0.001*deltat;
        DebugGoose.y = DebugGoose.y + DebugGoose.vy*fdelta - 0.5*G*fdelta*fdelta;
        DebugGoose.vy = DebugGoose.vy - 9.8*deltat;

        // discrete the px location
        DebugGoose.prObj->y = (int)DebugGoose.y;

        printf("goose state update y:%f vy:%f!\n",DebugGoose.y,DebugGoose.vy);

        // check if it is on the ground
        if(DebugGoose.y<=0){
            printf("goose onground!\n");
            DebugGoose.jumping = 0;
            DebugGoose.y = 0;
            DebugGoose.vy= 0;

            DebugGoose.prObj->y = 0;
            DebugGoose.prObj->p_image = _get_image("./image/goose_run0.bmp");
        }
    }
}


void _key_down(WPARAM wParam, LPARAM lParam) {
    if(wParam==VK_SPACE){
        if(state.status==GAME_STATUS_INIT){
            state.status = GAME_STATUS_RUN;
        } else if(state.status==GAME_STATUS_RUN){
            printf("\ndetect keypress\n");
            // set its to jump
            if(DebugGoose.jumping==0){
                printf("goose jumpped!\n");
                DebugGoose.jumping = 1;
                DebugGoose.vy = JUMPVY;
                DebugGoose.prObj->p_image = _get_image("./image/goose_jump.bmp");
                DebugGoose.jumptstp = state.time;
            } else{
                printf("goose is jumpping, ignore!\n");
            }

        } else if(state.status==GAME_STATUS_OVER){
            state.status = GAME_STATUS_INIT;
        }
    }

}
