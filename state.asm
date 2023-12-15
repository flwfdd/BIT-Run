.386
.model flat,stdcall
option casemap:none

include     bitrun.inc
include		windows.inc
include		user32.inc
includelib	user32.lib
include		kernel32.inc
includelib	kernel32.lib
include		Gdi32.inc
includelib	Gdi32.lib
include     Msimg32.inc
includelib  Msimg32.lib
include     winmm.inc
includelib  winmm.lib
include     msvcrt.inc
includelib  msvcrt.lib

extern $h_instance:dword ; ����ʵ�����
extern $h_window_main:dword ; �����ھ��
extern $state:GameState ; ��Ϸ״̬

_get_image PROTO @id:DWORD ; ��ȡͼ��

.data

; DEBUG ��Ⱦ����
render_object_test RenderObject <>

.code

; ����״̬
_state_update PROC
	mov $state.render_object_size, 1
	mov $state.a_p_render_object, offset render_object_test
	mov render_object_test.x, 0
	mov render_object_test.y, 0
	mov render_object_test.z, 0
	mov eax, $state.time
	and eax, 0100h
	.if eax == 0
		invoke _get_image, IMAGE_GOOSE_RUN0_ID
		mov render_object_test.p_image, eax
	.elseif
		invoke _get_image, IMAGE_GOOSE_RUN1_ID
		mov render_object_test.p_image, eax
	.endif
	mov $state.a_p_render_object, offset render_object_test

	ret
_state_update ENDP

end