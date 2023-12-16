.386
.model flat,stdcall
option casemap:none

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

include     bitrun.inc

; ��Ⱦģ��
_init_render PROTO ; ��ʼ����Ⱦģ��
_free_render PROTO ; �ͷ���Ⱦģ��
_render_buffer PROTO ; ��Ⱦ������
_render_window PROTO ; ��Ⱦ������������

; ״̬ģ��
_state_update PROTO ; ״̬����

public $h_instance, $h_window_main, $state

.const
S_MAIN_WINDOW_TITLE byte '������ - BITRun', 0 ; �����ڱ���
S_MAIN_CLASS_NAME byte 'main_window_class', 0 ; ����������

S_SHCOREDLL byte 'User32.dll',0
S_SETDPIFNAME byte 'SetProcessDPIAware',0



.data?
$h_instance dword ? ; ����ʵ�����
$h_window_main dword ? ; �����ھ��

$state GameState <> ; ��Ϸ״̬

$thread_live dword ? ; �̴߳���־ Ϊ0ʱ�߳��˳�
$p_render_buffer_event dword ? ; ֪ͨ���ƻ�����
$p_render_window_event dword ? ; ֪ͨ�ӻ�����ͬ��������

.code

; ֡ʱ���źŲ����߳�
_refresh_interval_thread PROC
    local @freq:QWORD ; ʱ��Ƶ��
    local @time0:QWORD, @time1:QWORD ; ʱ��
    local @1k:DWORD ; ����1000 ���ڼ������
    mov @1k, 1000

    mov $state.time, 0
    invoke QueryPerformanceFrequency, addr @freq ; ��ȡʱ��Ƶ��
    invoke QueryPerformanceCounter, addr @time0 ; ��ȡ��ʼʱ��
    finit
    .while $thread_live == 1
        ; ����ʱ���
        invoke QueryPerformanceCounter,addr @time1
        mov eax, dword ptr @time0
        mov edx, dword ptr @time0+4
        sub dword ptr @time1, eax
        sbb dword ptr @time1+4, edx
        fild @time1 ; ��������ֵ
        fimul @1k ; ���Ե�λƵ��
        fild @freq ; ����Ƶ�� �õ��Ե�λƵ��Ϊ��λ��ʱ���
        fdiv
        fistp @time1 ; ��ʼ�����ڵ�ʱ���

        ; ������һ֡ʱ��
        mov eax, $state.time
        add eax, 1000/FPS

        .if eax > dword ptr @time1
            ; ʱ��δ��
			sub eax, dword ptr @time1
			invoke Sleep, eax
        .else
            ; DEBUG ÿ�����ڴ�ӡһ��.
            invoke crt_putchar, '.'

			; ����ʱ��
            mov eax, dword ptr @time1
			mov $state.time, eax

            ; ֪ͨ��Ⱦ������
            invoke SetEvent, $p_render_buffer_event
        .endif

    .endw
    ret
_refresh_interval_thread ENDP


; ��Ⱦ�������߳�
_render_buffer_thread PROC
    .while $thread_live != 0
        ; �¼�ͬ��
        invoke WaitForSingleObject, $p_render_buffer_event, INFINITE
        invoke ResetEvent, $p_render_buffer_event

        ; ״̬����
        invoke _state_update

        ; ��Ⱦ
        invoke _render_buffer

        ; ֪ͨͬ��������
        invoke SetEvent, $p_render_window_event
    .endw
    ret
        
_render_buffer_thread ENDP

; ͬ���������������߳�
_render_window_thread PROC

    .while $thread_live != 0
        ; �������ջ���ˢ�±�־Ϊ0ʱ�ȴ�
        invoke WaitForSingleObject, $p_render_window_event, INFINITE
        invoke ResetEvent, $p_render_window_event

        ; ��Ⱦ������������
        invoke _render_window
    .endw
    ret
_render_window_thread ENDP

; ��ʼ���ص�
_init PROC
    ; ��ʼ���¼�
    invoke CreateEvent, NULL, TRUE, FALSE, NULL
    mov $p_render_buffer_event, eax
    invoke CreateEvent, NULL, TRUE, FALSE, NULL
    mov $p_render_window_event, eax

    ; ��ʼ����Ⱦģ��
    invoke _init_render

    ; �����߳�
    mov $thread_live, 1
    invoke CreateThread, NULL, 0, _refresh_interval_thread, NULL , 0, NULL
    invoke CreateThread, NULL, 0, _render_buffer_thread, NULL, 0, NULL
    invoke CreateThread, NULL, 0, _render_window_thread, NULL, 0, NULL
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

    ; �ͷ���Ⱦģ��
    invoke _free_render

    ; �ͷ��¼�
    invoke CloseHandle, $p_render_window_event
    invoke CloseHandle, $p_render_buffer_event

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
    local @rect:RECT
    local @msg:MSG

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


    ;invoke SetProcessDPIAware
    ;invoke LoadLibrary, offset S_SHCOREDLL
    ;invoke GetProcAddress,eax, offset S_SETDPIFNAME
    ;call eax

    mov @rect.left, 0
    mov @rect.top, 0
    mov @rect.right, WINDOW_WIDTH
    mov @rect.bottom, WINDOW_HEIGHT
    invoke AdjustWindowRect, addr @rect, WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX, FALSE
    mov eax, @rect.right
    sub eax, @rect.left
    mov ebx, @rect.bottom
    sub ebx, @rect.top

    invoke CreateWindowEx, 0, offset S_MAIN_CLASS_NAME, offset S_MAIN_WINDOW_TITLE, WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX, CW_USEDEFAULT, CW_USEDEFAULT, eax, ebx, NULL, NULL, $h_instance, NULL
    mov $h_window_main, eax
    invoke ShowWindow, $h_window_main, SW_SHOWNORMAL
    invoke UpdateWindow, $h_window_main

    .while TRUE
        invoke GetMessage, addr @msg, NULL, 0, 0
        .break .if eax == 0
        invoke TranslateMessage, addr @msg
        invoke DispatchMessage, addr @msg
    .endw

    ret
_main_window ENDP


start:
    invoke _main_window 
    invoke ExitProcess, NULL
    ret
end start