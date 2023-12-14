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
include     winmm.inc
includelib  winmm.lib
include     msvcrt.inc
includelib  msvcrt.lib

.const
S_main_window_title byte '������ - BITRun', 0 ; �����ڱ���
S_main_class_name byte 'main_window_class', 0 ; ����������

.data
$thread_live dword 1 ; �̴߳���־ Ϊ0ʱ�߳��˳�
$buffer_index dword 0 ; ���������� ָ�����»��ƺõĻ�����
$refresh_flag dword 0 ; ˢ�±�־ Ϊ1ʱˢ�»�����

.data?
$h_instance dword ? ; ����ʵ�����
$h_window_main dword ? ; �����ھ��

$h_buffer_dc_array dword BUFFER_SIZE dup (?) ; �������豸������
$h_buffer_bmp_array dword BUFFER_SIZE dup(?) ; ������λͼ

$h_draw_buffer_event dword ? ; ֪ͨ���ƻ�����
$h_draw_window_event dword ? ; ֪ͨ�ӻ�����ͬ��������


.code

; ��ʼ��������
_init_buffer PROC uses esi edi
    LOCAL @h_dc, @cnt
    LOCAL @h_bmp
    
    ; ��ȡ�豸������
    invoke GetDC, $h_window_main
    mov @h_dc, eax

    ; ��仺��������
    mov @cnt, 0
    mov esi, offset $h_buffer_dc_array
    mov edi, offset $h_buffer_bmp_array
    .WHILE @cnt != BUFFER_SIZE
        invoke	CreateCompatibleDC, @h_dc
        mov	[esi], eax
        invoke CreateCompatibleBitmap, @h_dc, WINDOW_WIDTH, WINDOW_HEIGHT
        mov [edi], eax
        invoke	SelectObject,[esi],[edi]
        invoke SetStretchBltMode,[esi],HALFTONE
        add esi, 4
        add edi, 4
        inc @cnt
    .ENDW

    invoke ReleaseDC,$h_window_main, @h_dc 
    ret 
_init_buffer ENDP


; ˢ��ʱ���źŲ����߳�
_refresh_interval_thread PROC
    .WHILE $thread_live == 1
        invoke crt_putchar, '.' ; ÿ�����ڴ�ӡһ��.
        mov $refresh_flag, 1
        invoke SetEvent, $h_draw_buffer_event
        invoke Sleep, 1000/FPS
    .ENDW
    ret
_refresh_interval_thread ENDP


; ���ƻ������߳�
_draw_buffer_thread PROC uses ebx esi edi

    .WHILE $thread_live != 0
        ; �¼�ͬ��
        invoke WaitForSingleObject, $h_draw_buffer_event, INFINITE
        invoke ResetEvent, $h_draw_buffer_event

        ; ��ȡд�뻺����������
        mov ebx, $buffer_index
        inc ebx
        .IF ebx == BUFFER_SIZE
	        mov ebx, 0
        .ENDIF
        
        ; DEBUG ���д�뻺��������
        mov eax, ebx
        add eax, 'A'
        invoke crt_putchar, eax

        ; DEBUG ������ɫ����
        mov esi, 0
        .WHILE esi < 30
            mov edi, 0
            .WHILE edi < 30
                mov eax, ebx
                lea eax, [8*eax+esi]
            	invoke SetPixel, $h_buffer_dc_array[4*ebx], eax, edi, 00FF00h
                inc edi
            .ENDW
            inc esi
        .ENDW

        ; ���»���������
        mov $buffer_index, ebx
        invoke SetEvent, $h_draw_window_event
    .ENDW
    ret
        
_draw_buffer_thread ENDP

; ͬ���������������߳�
_draw_window_thread PROC uses ebx
    LOCAL @h_dc
    mov ebx, 0 ; ������ˢ��λ��

    .WHILE $thread_live != 0
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
        mov	@h_dc,eax
        invoke	BitBlt,@h_dc, 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, $h_buffer_dc_array[4*ebx], 0, 0, SRCCOPY
        invoke ReleaseDC,$h_window_main,@h_dc
        
    .ENDW
        ret
_draw_window_thread ENDP

; ��ʼ���ص�
_init PROC
    ; ��ʼ���¼�
    invoke CreateEvent, NULL, TRUE, FALSE, NULL
    mov $h_draw_buffer_event, eax
    invoke CreateEvent, NULL, TRUE, FALSE, NULL
    mov $h_draw_window_event, eax

    invoke _init_buffer
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
    LOCAL @cnt

    ; �ͷŻ�����
    mov @cnt, 0
    mov esi, offset $h_buffer_dc_array
    mov edi, offset $h_buffer_bmp_array
    .WHILE @cnt != BUFFER_SIZE
        invoke DeleteDC, [esi]
        invoke DeleteObject, [edi]
        add esi, 4
        add edi, 4
        inc @cnt
    .ENDW

    ; �ͷ��¼�
    invoke CloseHandle, $h_draw_buffer_event
    invoke CloseHandle, $h_draw_window_event

    ; �ر��߳�
    mov $thread_live, 0

    ; �رմ���
    invoke DestroyWindow, $h_window_main
    invoke PostQuitMessage, NULL

    ret
_close ENDP


; �����ڻص�
_main_window_proc PROC @h_instance, @msg, @wParam, @lParam
    mov eax, @msg
    .IF eax == WM_CREATE
        invoke _init
    .ELSEIF eax == WM_KEYDOWN
        invoke _key_down, @wParam
    .ELSEIF eax == WM_CLOSE
        invoke _close
    .ELSE
        invoke DefWindowProc, @h_instance, @msg, @wParam, @lParam
        ret
    .ENDIF

    xor eax, eax
    ret
_main_window_proc ENDP

; ������
_main_window PROC 
    LOCAL @window_class:WNDCLASSEX
    LOCAL st_msg:MSG

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
    mov @window_class.lpszClassName, offset S_main_class_name
    invoke RegisterClassEx, addr @window_class

    invoke CreateWindowEx, 0, offset S_main_class_name, offset S_main_window_title, WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX xor WS_BORDER, CW_USEDEFAULT, CW_USEDEFAULT, WINDOW_WIDTH, WINDOW_HEIGHT, NULL, NULL, $h_instance, NULL
    mov $h_window_main, eax
    invoke ShowWindow, $h_window_main, SW_SHOWNORMAL
    invoke UpdateWindow, $h_window_main

    .WHILE TRUE
        invoke GetMessage, addr st_msg, NULL, 0, 0
        .BREAK .IF eax == 0
        invoke TranslateMessage, addr st_msg
        invoke DispatchMessage, addr st_msg
    .ENDW

    ret
_main_window ENDP


start:
    call _main_window 
    invoke ExitProcess, NULL
    ret
end start