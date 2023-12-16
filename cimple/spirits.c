//
// Created by no3core on 2023/12/15.
//

#include <stdio.h>
#include <assert.h>
#include "spirits.h"
#include "lifecycle.h"
#include "BIT_run.h"

GameState state;

// goose state
int jumping;
int presshold;

//#define OBJ_BKG   0

void _init_render_list(RenderObject*p_a_rlist){
    // use rtlzero instead here please
    for(int i=0;i<RENDER_OBJECT_SIZE;i++){
        p_a_rlist[i].x = 0;
        p_a_rlist[i].y = 0;
        p_a_rlist[i].z = 0;
        p_a_rlist[i].p_image = NULL;
        p_a_rlist[i].obj_id = OBJ_NONE;
        p_a_rlist[i].vx = 0;
        p_a_rlist[i].vy = 0;
        p_a_rlist[i].phsy = 0;
        p_a_rlist[i].phsx = 0;
        p_a_rlist[i].lasttstp = 0;
    }
}


void _init_state() {
    presshold = 0;
    state.score = 0;
    state.status = GAME_STATUS_INIT;
    state.global_vx = -GINITVX;
    // debugging use
    state.render_object_size = 0;
    state.a_p_render_object  = malloc(sizeof(RenderObject)*RENDER_OBJECT_SIZE);;

    // initialize the render object list
    _init_render_list(state.a_p_render_object);

    // debug for goose move
    RenderObject Goose = {
            .obj_id = OBJ_GOOSE,
            .x = GOOSE_INITIAL_X,
            .y = GOOSE_INITIAL_Y,
            .z = 1,
            .p_image = _get_image("./image/goose_run0.bmp"),
            .vx = 0,
            .vy = 0,
            .phsx = 0,
            .phsy = GOOSE_INITIAL_Y
    };
    _add_render_object(&Goose);

    jumping = 0;

}

void _state_update(){
    // update all object state
    for (int i = 0; i < state.render_object_size; ++i) {
        _update_render_object(&state.a_p_render_object[i]);
    }

    // remove those may outbound object
    _update_render_list();

    // here we can add more obstacles according to current state

    if(state.render_object_size<=3){
        RenderObject debugtower1 = {
                .obj_id = OBJ_DEBUG1,
                .x = WINDOW_WIDTH,
                .y = HORIZON_HEIGHT,
                .z = 1,
                .p_image = _get_image("./image/tower25x50.bmp"),
                .vx = state.global_vx,
                .vy = 0,
                .phsx = WINDOW_WIDTH,
                .phsy = HORIZON_HEIGHT,
                .lasttstp = state.time

        };

        RenderObject debugtower2 = {
                .obj_id = OBJ_DEBUG2,
                .x = WINDOW_WIDTH+100,
                .y = HORIZON_HEIGHT,
                .z = 1,
                .p_image = _get_image("./image/tower25x50.bmp"),
                .vx = state.global_vx,
                .vy = 0,
                .phsx = WINDOW_WIDTH+100,
                .phsy = HORIZON_HEIGHT,
                .lasttstp = state.time
        };

        RenderObject debugtower3 = {
                .obj_id = OBJ_DEBUG3,
                .x = WINDOW_WIDTH+300,
                .y = HORIZON_HEIGHT,
                .z = 1,
                .p_image = _get_image("./image/tower25x50.bmp"),
                .vx = state.global_vx,
                .vy = 0,
                .phsx = WINDOW_WIDTH+300,
                .phsy = HORIZON_HEIGHT,
                .lasttstp = state.time
        };

        _add_render_object(&debugtower1);
        _add_render_object(&debugtower2);
        _add_render_object(&debugtower3);
    }
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
                    RenderObject*pGoose;
                    jumping = 1;
                    printf("goose jumpped!\n");
                    for (int i = 0; i < state.render_object_size; ++i) {
                        if(state.a_p_render_object[i].obj_id==OBJ_GOOSE){
                            pGoose = &state.a_p_render_object[i];
                            pGoose->vy = JUMPVY;
                            pGoose->p_image = _get_image("./image/goose_jump.bmp");
                            break;
                        }
                    }
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

void _add_render_object(RenderObject *p_render_object) {
    // find a slots in the render object list
    // and add to its
    RenderObject* pRobj = state.a_p_render_object;
    int i;
    for( i=0;i<RENDER_OBJECT_SIZE;i++){
        if(pRobj->p_image==NULL){
            pRobj->obj_id = p_render_object->obj_id;
            pRobj->x = p_render_object->x;
            pRobj->y = p_render_object->y;
            pRobj->phsx = p_render_object->phsx;
            pRobj->phsy = p_render_object->phsy;
            pRobj->z = p_render_object->z;
            pRobj->vx = p_render_object->vx;
            pRobj->vy = p_render_object->vy;
            pRobj->p_image = p_render_object->p_image;
            pRobj->lasttstp = p_render_object->lasttstp;

            state.render_object_size++;
            break;
        }
        pRobj++;
    }
    assert(i!=RENDER_OBJECT_SIZE);

}

void _update_render_list(){

    RenderObject* pRobj = state.a_p_render_object;
    RenderObject* newList = NULL;

    // check in window
    for(int i=0;i<state.render_object_size;i++,pRobj++){
        assert(pRobj->p_image!=NULL);
        if(!_check_obj_in_window(pRobj)){
            newList = malloc(sizeof(RenderObject)*RENDER_OBJECT_SIZE);
            _init_render_list(newList);
            break;
        }
    }

    // handle the case there is thing(s)  not in the window
    if(newList!=NULL){
        int oldsize = state.render_object_size;
        RenderObject * p_a_oldrlist = state.a_p_render_object;
        pRobj = state.a_p_render_object;
        // reset render state
        state.render_object_size = 0;
        state.a_p_render_object  = newList;

        // put object still in the window
        for(int i=0;i<oldsize;i++,pRobj++){
            assert(pRobj->p_image!=NULL);
            if(_check_obj_in_window(pRobj))
                _add_render_object(pRobj);
        }

        free(p_a_oldrlist);
    }
}

void _update_render_object(RenderObject *p_robj) {
    if(p_robj->obj_id == OBJ_GOOSE){
        _update_goose(p_robj);
    }else{
        int deltat = state.time - p_robj->lasttstp;
        float fdeltat = 0.001*deltat;

        p_robj->phsx = p_robj->phsx + p_robj->vx*fdeltat;
        p_robj->phsy = p_robj->phsy + p_robj->vy*fdeltat; // may need

        p_robj->x = (int)p_robj->phsx;
        p_robj->y = (int)p_robj->phsy;

        p_robj->lasttstp = state.time;
    }

}

void _update_goose(RenderObject *p_goose){

    if(!jumping){
        if(state.time&0x10)
            p_goose->p_image = _get_image("./image/goose_run0.bmp");
         else
            p_goose->p_image = _get_image("./image/goose_run1.bmp");

    } else{

        int deltat = state.time - p_goose->lasttstp;
        // motion calculate
        float fdelta = 0.001*deltat;

        float accer  = (presshold)?(G-JG):G;
        if(presshold) presshold = 0;
//        if(presshold){
//            printf("detect long jump\n");
//        } else{
//            printf("no long jump\n");
//        }

        p_goose->phsy = p_goose->phsy + p_goose->vy*fdelta - 0.5*accer*fdelta*fdelta;
        p_goose->vy = p_goose->vy - accer*fdelta;


        // discrete the px location
        p_goose->y = (int)p_goose->phsy;

//        printf("goose state update y:%f vy:%f at %d ms\n",p_goose->phsy,p_goose->vy,state.time);

        // check if it is on the ground
        if(p_goose->phsy<=HORIZON_HEIGHT){
            printf("goose onground!\n");
            jumping = 0;
            p_goose->y = GOOSE_INITIAL_Y;
            p_goose->phsy = GOOSE_INITIAL_Y;
            p_goose->vy= 0;
            p_goose->p_image = _get_image("./image/goose_run0.bmp");
        }
    }

    p_goose->lasttstp = state.time;
}

int _check_obj_in_window(RenderObject *p_render_object) {
    if(p_render_object->x+p_render_object->p_image->w<=0)
        return 0;
    else
        return 1; // return 1 for test
}
