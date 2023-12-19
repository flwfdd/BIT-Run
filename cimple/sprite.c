//
// Created by no3core on 2023/12/15.
//

#include <stdio.h>
#include <assert.h>
#include "sprite.h"
#include "lifecycle.h"
#include "BIT_run.h"

GameState state;

// goose state
int jumping;
SHORT lastkeystate;

void _init_state() {
    lastkeystate = 0;
    jumping = 0;
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
            .phsy = GOOSE_INITIAL_Y,
            .lasttstp = state.time

    };

    RenderObject Bkg1= {
            .obj_id = OBJ_BKG,
            .x = 0,
            .y = 0,
            .z = 0,
            .p_image = _get_image("./image/back_ground.bmp"),
            .vx = state.global_vx,
            .vy = 0,
            .phsx = 0,
            .phsy = 0,
            .lasttstp = state.time
    };

    RenderObject Bkg2= {
            .obj_id = OBJ_BKG,
            .x = WINDOW_WIDTH,
            .y = 0,
            .z = 0,
            .p_image = _get_image("./image/back_ground.bmp"),
            .vx = state.global_vx,
            .vy = 0,
            .phsx = WINDOW_WIDTH,
            .phsy = 0,
            .lasttstp = state.time
    };

    _add_render_object(&Goose);
    _add_render_object(&Bkg1);
    _add_render_object(&Bkg2);

}

void _reset_state(){
    free(state.a_p_render_object);
    _init_state();
}

void _start_state(){
    // align the timestamp
    for(int i=0;i<state.render_object_size;i++){
        state.a_p_render_object[i].lasttstp = state.time;
    }
}

void _state_update(){
    int collide = 0;
    if(state.status!=GAME_STATUS_RUN)
        return;
    // update all object state
    for (int i = 0; i < state.render_object_size; ++i) {
        if((collide=_update_render_object(&state.a_p_render_object[i])))
            break;
    }

    if(collide){
        state.status = GAME_STATUS_OVER;
        printf("game over ! score now:%d\n",state.score);
    }
    else{
        state.score+=-state.global_vx*SCORE_RATIO;
        printf("score now:%d\n",state.score);
    }

    // remove those may outbound object or draw the final score
    _update_render_list(collide);

    // here we can add more obstacles according to current state

    if(!collide&&state.render_object_size<=3){
        RenderObject debugtower1 = {
                .obj_id = OBJ_DEBUG1,
                .x = WINDOW_WIDTH,
                .y = HORIZON_HEIGHT,
                .z = 1,
                .p_image = _get_image("./image/bird1.bmp"),
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
                .p_image = _get_image("./image/bird1.bmp"),
                .vx = state.global_vx-20,
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
                .p_image = _get_image("./image/bird1.bmp"),
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

void _check_key_down() {
    SHORT keystate;
    if((keystate=GetAsyncKeyState(VK_SPACE))){
        printf("detect keypress at %d\n",state.time);
        switch (state.status) {
            case GAME_STATUS_INIT:
                state.status = GAME_STATUS_RUN;
                _start_state();
            case GAME_STATUS_RUN:{
                // set its to jump
                if(jumping==0){
                    RenderObject*pGoose;
                    jumping = 1;
                    for (int i = 0; i < state.render_object_size; ++i) {
                        if(state.a_p_render_object[i].obj_id==OBJ_GOOSE){
                            pGoose = &state.a_p_render_object[i];
                            pGoose->vy = JUMPVY;
                            pGoose->p_image = _get_image("./image/goose_jump.bmp");
                            break;
                        }
                    }
                }
                break;
            }
            case GAME_STATUS_OVER:
                // try to restart game here, must release+press
                if(!lastkeystate)
                    _reset_state();
                break;
            default:
                break;
        }
    }
    lastkeystate=keystate;
}

void _init_render_list(RenderObject*p_a_rlist){
    // use rtlzero instead here please
    RtlZeroMemory(p_a_rlist,RENDER_OBJECT_SIZE*sizeof(RenderObject));
}

void _update_render_list(int isOver) {

    RenderObject* pRobj = state.a_p_render_object;
    RenderObject* newList = NULL;

    // if its over , append a score show board in the render list
    if(isOver){
        return;
    }

    // check in window
    for(int i=0;i<state.render_object_size;i++,pRobj++){
        assert(pRobj->p_image!=NULL);
        if(!_check_obj_in_window(pRobj)){
            // cannot trigger this when bkg is out
            assert(pRobj->obj_id!=OBJ_BKG);
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

void _add_render_object(RenderObject *p_render_object) {
    // find a slots in the render object list
    // and add to its
    RenderObject* pRobj = state.a_p_render_object;
    int i;
    for( i=0;i<RENDER_OBJECT_SIZE;i++){
        if(pRobj->p_image==NULL){
            memcpy(pRobj,p_render_object,sizeof(RenderObject));
            state.render_object_size++;
            break;
        }
        pRobj++;
    }
    assert(i!=RENDER_OBJECT_SIZE);

}

// return 1 if goose collide 0 if no thing happened
int _update_render_object(RenderObject *p_robj) {
    if(p_robj->obj_id == OBJ_GOOSE){
        // special handle for goose
        return _update_goose(p_robj);
    } else{
        // handle normal object
        int deltat = state.time - p_robj->lasttstp;
        float fdeltat = 0.001*deltat;

        p_robj->phsx = p_robj->phsx + p_robj->vx*fdeltat;
        p_robj->phsy = p_robj->phsy + p_robj->vy*fdeltat; // may need

        p_robj->x = (int)p_robj->phsx;
        p_robj->y = (int)p_robj->phsy;

        p_robj->lasttstp = state.time;
    }

    if(p_robj->obj_id==OBJ_BKG){
        assert(p_robj->p_image->w==WINDOW_WIDTH);
        if(p_robj->x+p_robj->p_image->w<=0){
            p_robj->x    += 2*p_robj->p_image->w;
            p_robj->phsx += 2*p_robj->p_image->w;
        }
    }
    return 0;

}

int _update_goose(RenderObject *p_goose){


    if(!jumping){
        if(state.time&GOOSE_INTERVAL)
            p_goose->p_image = _get_image("./image/goose_run0.bmp");
         else
            p_goose->p_image = _get_image("./image/goose_run1.bmp");

    } else{
        int deltat = state.time - p_goose->lasttstp;
        // motion calculate
        float fdelta = 0.001*deltat;
        float accer  = (lastkeystate)?(G-JG):G;
        p_goose->phsy = p_goose->phsy + p_goose->vy*fdelta - 0.5*accer*fdelta*fdelta;
        p_goose->vy = p_goose->vy - accer*fdelta;

        // discrete the px location
        p_goose->y = (int)p_goose->phsy;

        // check if it is on the ground
        if(p_goose->phsy<=HORIZON_HEIGHT){
            jumping = 0;
            p_goose->y = GOOSE_INITIAL_Y;
            p_goose->phsy = GOOSE_INITIAL_Y;
            p_goose->vy= 0;
            p_goose->p_image = _get_image("./image/goose_run0.bmp");
        }
    }


    p_goose->lasttstp = state.time;

    // check collision
    int iscollide=0;
    RenderObject *p_robj = state.a_p_render_object;
    for (int i = 0; i < state.render_object_size; ++i,p_robj++) {
        if(p_robj->obj_id==OBJ_GOOSE||p_robj->obj_id==OBJ_BKG)
            continue;
        if(_check_obj_overlap(p_goose,p_robj)){
            printf("detect collision!\n");
            iscollide = 1;
        }
    }

    return iscollide;
}

int _check_obj_in_window(RenderObject *p_render_object) {
    if(p_render_object->x+p_render_object->p_image->w<=0)
        return 0;
    else
        return 1; // return 1 for test
}

//  Debugging
void DrawRectOutline(HDC hdc, RECT rect) {
    // 创建画笔
    HPEN hPen = CreatePen(PS_SOLID, 1, RGB(255, 0, 0));  // 红色画笔
    HPEN hOldPen = (HPEN)SelectObject(hdc, hPen);

    // 绘制边框
    MoveToEx(hdc, rect.left, rect.top, NULL);
    LineTo(hdc, rect.right, rect.top);
    LineTo(hdc, rect.right, rect.bottom);
    LineTo(hdc, rect.left, rect.bottom);
    LineTo(hdc, rect.left, rect.top);

    // 清理资源
    SelectObject(hdc, hOldPen);
    DeleteObject(hPen);
}
extern HANDLE h_window_main;

int _check_obj_overlap(RenderObject *p_obj1, RenderObject *p_obj2) {
    Image* p_image1 = p_obj1->p_image;
    Image* p_image2 = p_obj2->p_image;
    RECT obj1_rect, obj2_rect, overlap_rect;

    // 这里汇编有点问题要改
    // 快速判断矩形框是否重叠
    // 1完全在2左侧
    obj1_rect.left  = p_obj1->x;
    obj1_rect.right = p_obj1->x + p_image1->w; // Adjusted index
    if (obj1_rect.right <= p_obj2->x) {
        return 0;
    }
    // 1完全在2右侧
    obj2_rect.left  = p_obj2->x;
    obj2_rect.right = p_obj2->x + p_image2->w; // Adjusted index
    if (obj2_rect.right <= p_obj1->x) {
        return 0;
    }
    // 1完全在2下方
    obj1_rect.bottom = p_obj1->y;
    obj1_rect.top    =  p_obj1->y + p_image1->h; // Adjusted index
    if (obj1_rect.top <= p_obj2->y) {
        return 0;
    }
    // 1完全在2上方
    obj2_rect.bottom = p_obj2->y;
    obj2_rect.top    = p_obj2->y + p_image2->h ; // Adjusted index
    if (obj2_rect.top <=p_obj1->y) {
        return 0;
    }

    // 计算交叉区域
    overlap_rect.left   = obj1_rect.left   > obj2_rect.left   ? obj1_rect.left   : obj2_rect.left;
    overlap_rect.right  = obj1_rect.right  < obj2_rect.right  ? obj1_rect.right  : obj2_rect.right;
    overlap_rect.bottom = obj1_rect.bottom > obj2_rect.bottom ? obj1_rect.bottom : obj2_rect.bottom;
    overlap_rect.top    = obj1_rect.top    < obj2_rect.top    ? obj1_rect.top    : obj2_rect.top;

    //DEBUG
    HDC hdc = GetDC(h_window_main);
    DrawRectOutline(hdc, overlap_rect);
    DrawRectOutline(hdc, obj1_rect);
    DrawRectOutline(hdc, obj2_rect);

    // 像素判断是否有交叉区域
    for (int esi_val = overlap_rect.top-1; esi_val >= overlap_rect.bottom; esi_val--) {
        for (int edi_val = overlap_rect.left; edi_val < overlap_rect.right; edi_val++) {
            int obj1_row_index = (obj1_rect.top-1) - esi_val;
            int obj1_col_index = edi_val - obj1_rect.left;
            int obj1_offset    = obj1_row_index * p_image1->w + obj1_col_index;
            char* obj1_mask    = p_image1->a_mask;

            if (obj1_mask[obj1_offset] == 0) {
                continue;
            }

            int obj2_row_index = (obj2_rect.top-1) - esi_val;
            int obj2_col_index = edi_val - obj2_rect.left;
            int obj2_offset    = obj2_row_index * p_image2->w + obj2_col_index;
            char* obj2_mask    = p_image2->a_mask;
            if (obj2_mask[obj2_offset] == 0) {
                continue;
            }

            return  1;
        }
    }

    return 0;
}
