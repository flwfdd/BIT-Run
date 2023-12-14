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
S_main_window_title byte '北理润 - BITRun', 0 ; 主窗口标题
S_main_class_name byte 'main_window_class', 0 ; 主窗口类名

.data
$thread_live dword 1 ; 线程存活标志 为0时线程退出
$buffer_index dword 0 ; 缓冲区索引 指向最新绘制好的缓冲区
$refresh_flag dword 0 ; 刷新标志 为1时刷新缓冲区

.data?
$h_instance dword ? ; 程序实例句柄
$h_window_main dword ? ; 主窗口句柄

$h_buffer_dc_array dword BUFFER_SIZE dup (?) ; 缓冲区设备上下文
$h_buffer_bmp_array dword BUFFER_SIZE dup(?) ; 缓冲区位图

$h_draw_buffer_event dword ? ; 通知绘制缓冲区
$h_draw_window_event dword ? ; 通知从缓冲区同步到窗口


.code

; 初始化缓冲区
_init_buffer PROC uses esi edi
    LOCAL @h_dc, @cnt
    LOCAL @h_bmp
    
    ; 获取设备上下文
    invoke GetDC, $h_window_main
    mov @h_dc, eax

    ; 填充缓冲区数组
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


; 刷新时钟信号产生线程
_refresh_interval_thread PROC
    .WHILE $thread_live == 1
        invoke crt_putchar, '.' ; 每个周期打印一个.
        mov $refresh_flag, 1
        invoke SetEvent, $h_draw_buffer_event
        invoke Sleep, 1000/FPS
    .ENDW
    ret
_refresh_interval_thread ENDP


; 绘制缓冲区线程
_draw_buffer_thread PROC uses ebx esi edi

    .WHILE $thread_live != 0
        ; 事件同步
        invoke WaitForSingleObject, $h_draw_buffer_event, INFINITE
        invoke ResetEvent, $h_draw_buffer_event

        ; 获取写入缓冲区的索引
        mov ebx, $buffer_index
        inc ebx
        .IF ebx == BUFFER_SIZE
	        mov ebx, 0
        .ENDIF
        
        ; DEBUG 输出写入缓冲区索引
        mov eax, ebx
        add eax, 'A'
        invoke crt_putchar, eax

        ; DEBUG 绘制绿色方块
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

        ; 更新缓冲区索引
        mov $buffer_index, ebx
        invoke SetEvent, $h_draw_window_event
    .ENDW
    ret
        
_draw_buffer_thread ENDP

; 同步缓冲区到窗口线程
_draw_window_thread PROC uses ebx
    LOCAL @h_dc
    mov ebx, 0 ; 缓冲区刷新位置

    .WHILE $thread_live != 0
        ; 缓冲区空或者刷新标志为0时等待
        invoke WaitForSingleObject, $h_draw_window_event, INFINITE
        invoke ResetEvent, $h_draw_window_event

        ; 获取缓冲区索引
        mov ebx, $buffer_index

        ; DEBUG 输出读出缓冲区索引
        mov eax, ebx
        add eax, 'a'
        invoke crt_putchar, eax

        ; 将缓冲区中的内容传到设备上下文中
        invoke GetDC, $h_window_main
        mov	@h_dc,eax
        invoke	BitBlt,@h_dc, 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, $h_buffer_dc_array[4*ebx], 0, 0, SRCCOPY
        invoke ReleaseDC,$h_window_main,@h_dc
        
    .ENDW
        ret
_draw_window_thread ENDP

; 初始化回调
_init PROC
    ; 初始化事件
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

; 用户操作回调
_key_down PROC @key
    ret
_key_down ENDP

; 关闭回调
_close PROC
    LOCAL @cnt

    ; 释放缓冲区
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

    ; 释放事件
    invoke CloseHandle, $h_draw_buffer_event
    invoke CloseHandle, $h_draw_window_event

    ; 关闭线程
    mov $thread_live, 0

    ; 关闭窗口
    invoke DestroyWindow, $h_window_main
    invoke PostQuitMessage, NULL

    ret
_close ENDP


; 主窗口回调
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

; 主窗口
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