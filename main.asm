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

.const
S_MAIN_WINDOW_TITLE byte '������ - BITRun', 0 ; �����ڱ���
S_MAIN_CLASS_NAME byte 'main_window_class', 0 ; ����������

.data
$thread_live dword 1 ; �̴߳���־ Ϊ0ʱ�߳��˳�
$buffer_index dword 0 ; ���������� ָ�����»��ƺõĻ�����

.data?
$h_instance dword ? ; ����ʵ�����
$h_window_main dword ? ; �����ھ��

$ha_buffer_dc dword BUFFER_SIZE dup (?) ; �������豸����������
$ha_buffer_bmp dword BUFFER_SIZE dup(?) ; ������λͼ����

$game_ms dword ? ; ��Ϸʱ�� ���м����Դ�Ϊ��׼ �Ժ���Ϊ��λ
$h_draw_buffer_event dword ? ; ֪ͨ���ƻ�����
$h_draw_window_event dword ? ; ֪ͨ�ӻ�����ͬ��������

.code

; ֡ʱ���źŲ����߳�
_refresh_interval_thread PROC
    .while $thread_live == 1
        invoke crt_putchar, '.' ; ÿ�����ڴ�ӡһ��.
        invoke SetEvent, $h_draw_buffer_event
        invoke Sleep, 1000/FPS
        add $game_ms, 1000/FPS
    .endw
    ret
_refresh_interval_thread ENDP


; ���ƻ������߳�
_draw_buffer_thread PROC uses ebx esi edi
    .while $thread_live != 0
        ; �¼�ͬ��
        invoke WaitForSingleObject, $h_draw_buffer_event, INFINITE
        invoke ResetEvent, $h_draw_buffer_event

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
        .while esi < 30
            mov edi, 0
            .while edi < 30
                mov eax, ebx
                lea eax, [8*eax+esi]
            	invoke SetPixel, $ha_buffer_dc[4*ebx], eax, edi, 00FF00h
                inc edi
            .endw
            inc esi
        .endw

        ; DEBUG ����ͼ��
        mov eax, offset $image_demo
        invoke TransparentBlt, $ha_buffer_dc[4*ebx], 0, 0, [eax + Image.w], [eax + Image.h], [eax + Image.h_dc], 0, 0, [eax + Image.w], [eax + Image.h], [eax + Image.mask_color]

        ; ���»���������
        mov $buffer_index, ebx
        invoke SetEvent, $h_draw_window_event
    .endw
    ret
        
_draw_buffer_thread ENDP

; ͬ���������������߳�
_draw_window_thread PROC uses ebx
    local @h_dc:DWORD
    mov ebx, 0 ; ������ˢ��λ��

    .while $thread_live != 0
        ; �������ջ���ˢ�±�־Ϊ0ʱ�ȴ�
        invoke WaitForSingleObject, $h_draw_window_event, INFINITE
        invoke ResetEvent, $h_draw_window_event

        ; ��ȡ����������
        mov ebx, $buffer_index

        ; DEBUG �����������������
        mov eax, ebx
        add eax, 'a'
        invoke crt_putchar, eax

        ; ���������е����ݴ����豸��������
        invoke GetDC, $h_window_main
        mov @h_dc, eax
        invoke	BitBlt, @h_dc, 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, $ha_buffer_dc[4*ebx], 0, 0, SRCCOPY
        invoke ReleaseDC, $h_window_main, @h_dc
    .endw

        ret
_draw_window_thread ENDP

; ��ʼ��������
_init_buffer PROC uses esi edi
    local @h_dc:DWORD
    local @cnt:DWORD
    
    ; ��ȡ�豸������
    invoke GetDC, $h_window_main
    mov @h_dc, eax

    ; ��仺��������
    mov @cnt, 0
    mov esi, offset $ha_buffer_dc
    mov edi, offset $ha_buffer_bmp
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
    mov esi, offset $ha_buffer_dc
    mov edi, offset $ha_buffer_bmp
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
_init_image PROC uses ebx esi edi @h_image:DWORD
    local @h_dc:DWORD
    local @bmp:BITMAP
    mov ebx, @h_image

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
    mov ebx, eax ; ebxָ��mask����
    mov esi, 0 ; ������
    .while esi < @bmp.bmHeight
        mov edi, 0 ; ������
        .while edi < @bmp.bmWidth
            ; ��ȡ����
            mov eax, @h_image
            invoke GetPixel, [eax + Image.h_dc], edi, esi
            ; �ж��Ƿ�Ϊmask_color
            .if eax == [ebx + Image.mask_color]
                mov eax, 0
            .else
                mov eax, 1
            .endif
            mov [ebx], eax
            inc ebx
            inc edi
        .endw
        inc esi
    .endw
    
    ret
_init_image ENDP

; �ͷŵ���ͼ��
_free_image PROC  @h_image:DWORD
	mov ebx, @h_image
	invoke DeleteDC, [ebx + Image.h_dc]
	invoke DeleteObject, [ebx + Image.h_bmp]
	invoke crt_free, [ebx + Image.a_mask]
	ret
_free_image ENDP

; ��ʼ��ͼ��
_init_images PROC
    invoke _init_image, offset $image_demo
    ret
_init_images ENDP

; �ͷ�ͼ��
_free_images PROC
    invoke _free_image, offset $image_demo
	ret
_free_images ENDP

; ��ʼ���ص�
_init PROC
    ; ��ʼ���¼�
    invoke CreateEvent, NULL, TRUE, FALSE, NULL
    mov $h_draw_buffer_event, eax
    invoke CreateEvent, NULL, TRUE, FALSE, NULL
    mov $h_draw_window_event, eax

    ; ��ʼ����Դ
    invoke _init_buffer
    invoke _init_images

    ; �����߳�
    invoke CreateThread, NULL, 0, _refresh_interval_thread, NULL , 0, NULL
    invoke CreateThread, NULL, 0, _draw_window_thread, NULL, 0, NULL
    invoke CreateThread, NULL, 0, _draw_buffer_thread, NULL, 0, NULL
    ret
_init ENDP

; �û������ص�
_key_down PROC @key
    ret
_key_down ENDP

; �رջص�
_close PROC

    ; �ر��߳�
    mov $thread_live, 0

    ; �ͷ���Դ
    invoke _free_images
    invoke _free_buffer
    

    ; �ͷ��¼�
    invoke CloseHandle, $h_draw_buffer_event
    invoke CloseHandle, $h_draw_window_event

    ; �رմ���
    invoke DestroyWindow, $h_window_main
    invoke PostQuitMessage, NULL

    ret
_close ENDP


; �����ڻص�
_main_window_proc PROC @h_instance, @msg, @wParam, @lParam
    mov eax, @msg
    .if eax == WM_CREATE
        invoke _init
    .elseif eax == WM_KEYDOWN
        invoke _key_down, @wParam
    .elseif eax == WM_CLOSE
        invoke _close
    .else
        invoke DefWindowProc, @h_instance, @msg, @wParam, @lParam
        ret
    .endif

    xor eax, eax
    ret
_main_window_proc ENDP

; ������
_main_window PROC 
    local @window_class:WNDCLASSEX
    local st_msg:MSG

    invoke	GetModuleHandle, NULL
    mov	$h_instance,eax

    invoke	RtlZeroMemory,addr @window_class,sizeof @window_class
    ;invoke	LoadIcon,$h_instance,ICO_MAIN
    ;mov	@window_class.hIcon,eax
    ;mov	@window_class.hIconSm,eax
    invoke LoadCursor, 0, IDC_ARROW
    mov @window_class.hCursor, eax
    mov eax, $h_instance
    mov @window_class.hInstance, eax
    mov @window_class.cbSize, sizeof WNDCLASSEX
    mov @window_class.style, CS_HREDRAW or CS_VREDRAW
    mov @window_class.lpfnWndProc, offset _main_window_proc
    mov @window_class.hbrBackground, COLOR_WINDOW+1
    mov @window_class.lpszClassName, offset S_MAIN_CLASS_NAME
    invoke RegisterClassEx, addr @window_class

    invoke CreateWindowEx, 0, offset S_MAIN_CLASS_NAME, offset S_MAIN_WINDOW_TITLE, WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX xor WS_BORDER, CW_USEDEFAULT, CW_USEDEFAULT, WINDOW_WIDTH, WINDOW_HEIGHT, NULL, NULL, $h_instance, NULL
    mov $h_window_main, eax
    invoke ShowWindow, $h_window_main, SW_SHOWNORMAL
    invoke UpdateWindow, $h_window_main

    .while TRUE
        invoke GetMessage, addr st_msg, NULL, 0, 0
        .break .if eax == 0
        invoke TranslateMessage, addr st_msg
        invoke DispatchMessage, addr st_msg
    .endw

    ret
_main_window ENDP


start:
    invoke _main_window 
    invoke ExitProcess, NULL
    ret
end start