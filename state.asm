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
_check_obj_in_window PROTO @p_obj:DWORD ; �������Ƿ��ڴ�����
_check_obj_overlap PROTO @p_obj1:DWORD, @p_obj2:DWORD ; ����ص�

.data

; DEBUG ��Ⱦ����
a_render_object_test RenderObject 10 dup (<>) ; ��Ⱦ��������
x_text dword 0

.code

; ����״̬
_state_update PROC uses ebx
	mov $state.background_color, 0AAEEFFh
	mov $state.render_object_size, 2
	mov $state.p_a_render_object, offset a_render_object_test
	mov ebx, offset a_render_object_test
	mov eax, x_text
	mov [ebx + RenderObject.x], eax
	add x_text, 10
	mov [ebx + RenderObject.y], 0
	mov [ebx + RenderObject.z], 0

	mov eax, $state.time
	and eax, 0100h
	.if eax == 0
		invoke _get_image, IMAGE_GOOSE_RUN0_ID
		mov [ebx + RenderObject.p_image], eax
	.elseif
		invoke _get_image, IMAGE_GOOSE_RUN1_ID
		mov [ebx + RenderObject.p_image], eax
	.endif

	; ����Ƿ��ڴ�����
	invoke _check_obj_in_window, offset a_render_object_test
	.if eax == 0
		mov x_text, 0
	.endif

	add ebx, sizeof RenderObject
	mov [ebx + RenderObject.x], 100
	mov [ebx + RenderObject.y], 50
	mov [ebx + RenderObject.z], 0
	invoke _get_image, IMAGE_BIT_BADGE_ID
	mov [ebx + RenderObject.p_image], eax

	; ����ص����
	invoke _check_obj_overlap, offset a_render_object_test, offset a_render_object_test + sizeof RenderObject
	.if eax == 0
		invoke crt_putchar, '-'
	.else
		invoke crt_putchar, '+'
	.endif
	
	ret
_state_update ENDP

end