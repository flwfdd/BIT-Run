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

.data

$a_buffer_dc dword BUFFER_SIZE dup(?) ; �������豸����������
$a_buffer_bmp dword BUFFER_SIZE dup(?) ; ������λͼ����
$buffer_index dword 0 ; ���������� ָ�����»��ƺõĻ�����

$p_a_image dword ? ; ָ��ͼ�������ָ��

.code

; ��Ⱦ������
_render_buffer PROC uses ebx esi edi
    ; ��ȡд�뻺����������
    mov ebx, $buffer_index
    inc ebx
    .if ebx == BUFFER_SIZE
        mov ebx, 0
    .endif
    
    ; DEBUG ���д�뻺��������
    mov eax, ebx
    add eax, 'A'
    invoke crt_putchar, eax

    ; DEBUG ������ɫ����
    mov esi, 0
    .while esi < 30 ; x
        mov edi, 0
        .while edi < 30 ; y
            ;lea eax, [8*eax+esi]
            mov eax, 370
            add eax, esi
            mov ecx, edi
            add ecx, 300
            invoke SetPixel, $a_buffer_dc[4*ebx], eax, ecx, 00FF00h
            inc edi
        .endw
        inc esi
    .endw

    ; ��Ⱦ����
    mov ecx, 0 ; ��Ⱦ��������
    mov esi, $state.a_p_render_object ; ��Ⱦ�����ַ
    .while ecx < $state.render_object_size
		mov eax, [esi + RenderObject.p_image]
        ; ת������
        mov edx, WINDOW_HEIGHT
        sub edx, [esi + RenderObject.y]
        sub edx, [eax + Image.h]
        invoke TransparentBlt, $a_buffer_dc[4*ebx], [esi + RenderObject.x], edx, [eax + Image.w], [eax + Image.h], [eax + Image.h_dc], 0, 0, [eax + Image.w], [eax + Image.h], [eax + Image.mask_color]
		
		inc ecx
        add esi, 4
    .endw


    ; ���»���������
    mov $buffer_index, ebx
    ret
_render_buffer ENDP


; ��Ⱦ������������
_render_window PROC uses ebx
    local @h_dc:DWORD

    ; ��ȡ����������
    mov ebx, $buffer_index

    ; DEBUG �����������������
    mov eax, ebx
    add eax, 'a'
    invoke crt_putchar, eax

    ; ���������е����ݴ����豸��������
    invoke GetDC, $h_window_main
    mov @h_dc, eax
    invoke	BitBlt, @h_dc, 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, $a_buffer_dc[4*ebx], 0, 0, SRCCOPY
    invoke ReleaseDC, $h_window_main, @h_dc

    ret
_render_window ENDP

; ��ʼ��������
_init_buffer PROC uses esi edi
    local @h_dc:DWORD
    local @cnt:DWORD
    
    ; ��ȡ�豸������
    invoke GetDC, $h_window_main
    mov @h_dc, eax

    ; ��仺��������
    mov @cnt, 0
    mov esi, offset $a_buffer_dc
    mov edi, offset $a_buffer_bmp
    .while @cnt != BUFFER_SIZE
        invoke	CreateCompatibleDC, @h_dc
        mov	[esi], eax
        invoke CreateCompatibleBitmap, @h_dc, WINDOW_WIDTH, WINDOW_HEIGHT
        mov [edi], eax
        invoke	SelectObject, [esi], eax
        invoke SetStretchBltMode,[esi],HALFTONE
        add esi, 4
        add edi, 4
        inc @cnt
    .endw

    invoke ReleaseDC, $h_window_main, @h_dc

    ret 
_init_buffer ENDP

; �ͷŻ�����
_free_buffer PROC uses esi edi
	local @cnt:DWORD

	mov @cnt, 0
    mov esi, offset $a_buffer_dc
    mov edi, offset $a_buffer_bmp
    .while @cnt != BUFFER_SIZE
        invoke DeleteDC, [esi]
        invoke DeleteObject, [edi]
        add esi, 4
        add edi, 4
        inc @cnt
    .endw
    ret
_free_buffer ENDP

; ��ʼ������ͼ��
_init_image PROC uses ebx esi edi @p_image:DWORD
    local @h_dc:DWORD, @bmp:BITMAP
    mov ebx, @p_image

    ; ת��RGBΪBGR
    mov eax, [ebx + Image.mask_color]
    and eax, 00FF0000h
    shr eax, 16
    mov ecx, [ebx + Image.mask_color]
    and ecx, 0000FF00h
    or eax, ecx
    mov ecx, [ebx + Image.mask_color]
    and ecx, 000000FFh
    shl ecx, 16
    or eax, ecx
    mov [ebx + Image.mask_color], eax

    ; ���������豸������
    invoke GetDC, $h_window_main
    mov @h_dc, eax
    invoke CreateCompatibleDC, @h_dc
    mov [ebx + Image.h_dc], eax
    invoke ReleaseDC, $h_window_main, @h_dc
    ; ����λͼ
    invoke LoadBitmap, $h_instance, [ebx + Image.id]
    mov [ebx + Image.h_bmp], eax
    ; ѡ��λͼ���豸������
    invoke SelectObject, [ebx + Image.h_dc], [ebx + Image.h_bmp]
    ; ��ȡλͼ���
    invoke GetObject, [ebx + Image.h_bmp], sizeof BITMAP, addr @bmp
    mov eax, @bmp.bmWidth
    mov [ebx + Image.w], eax
    mov eax, @bmp.bmHeight
    mov [ebx + Image.h], eax

    ; ����mask�ڴ�
    mov eax, @bmp.bmWidth
    mul @bmp.bmHeight
    invoke crt_malloc, eax
    mov [ebx + Image.a_mask], eax

    ; ����mask
    mov ebx, eax ; ebpָ��mask����
    mov esi, 0 ; ������
    .while esi < @bmp.bmHeight
        mov edi, 0 ; ������
        .while edi < @bmp.bmWidth
            ; ��ȡ����
            mov eax, @p_image
            invoke GetPixel, [eax + Image.h_dc], edi, esi
            ; �ж��Ƿ�Ϊmask_color
            mov ecx, @p_image
            mov ecx, [ecx + Image.mask_color]
            .if eax == ecx
                mov al, 0
            .else
                mov al, 1
            .endif
            mov [ebx], al
            inc ebx
            inc edi
        .endw
        inc esi
    .endw

    ret
_init_image ENDP


; ��ȡ����ͼ�� ����ͼ��ID ���ͼ��ָ��
_get_image PROC uses esi edi @id:DWORD
    mov esi, $p_a_image ; esiָ��ͼ��
    mov edi, @id ; ediָ��ͼ��ID
    mov ecx, 0
    .while ecx < IMAGES_SIZE
        .if [esi + Image.id] == edi
            mov eax, esi
            ret
        .endif
        add esi, sizeof Image
        inc ecx
    .endw
    
    xor eax, eax
    ret
_get_image ENDP


; �ͷŵ���ͼ��
_free_image PROC  @p_image:DWORD
	mov ebx, @p_image
	invoke DeleteDC, [ebx + Image.h_dc]
	invoke DeleteObject, [ebx + Image.h_bmp]
	invoke crt_free, [ebx + Image.a_mask]
	ret
_free_image ENDP


; ��ʼ������ͼ��
_init_images PROC
    ; �����ڴ�
    mov eax, IMAGES_SIZE
    mov ecx, sizeof Image
    mul ecx
    invoke crt_malloc, eax
    mov $p_a_image, eax

    ; ��ʼ��ͼ��
    mov esi, offset IMAGES_START
    mov edi, $p_a_image
    .while esi < offset IMAGES_END
        mov eax, [esi]
        mov [edi + Image.id], eax
        mov eax, [esi + 4]
        mov [edi + Image.mask_color], eax
        invoke _init_image, edi
        add esi, 8
        add edi, sizeof Image
    .endw
    ret
_init_images ENDP


; �ͷ�����ͼ��
_free_images PROC
    mov esi, $p_a_image
	mov ecx, 0
	.while ecx < IMAGES_SIZE
		invoke _free_image, esi
		add esi, sizeof Image
		dec ecx
	.endw
	invoke crt_free, $p_a_image
	ret
_free_images ENDP

; ��ʼ����Ⱦģ��
_init_render PROC
    invoke _init_buffer
    invoke _init_images
    ret
_init_render ENDP

; �ͷ���Ⱦģ��
_free_render PROC
    invoke _free_buffer
    invoke _free_images
    ret
_free_render ENDP


end