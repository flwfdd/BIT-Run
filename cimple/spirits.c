//
// Created by no3core on 2023/12/15.
//

#include "spirits.h"
#include "lifecycle.h"

GameState state;

void _key_down(WPARAM wParam, LPARAM lParam) {

}

RenderObject renderObjectTest;

void _state_update(){
    // debug for goose move
    state.render_object_size=1;
    state.a_p_render_object =&renderObjectTest;
    renderObjectTest.x=0;
    renderObjectTest.y=0;
    renderObjectTest.z=0;
    if(state.time&0x100){
        renderObjectTest.p_image = _get_image("./image/goose_run0.bmp");
    } else{
        renderObjectTest.p_image = _get_image("./image/goose_run1.bmp");
    }
    state.a_p_render_object =&renderObjectTest;
}
