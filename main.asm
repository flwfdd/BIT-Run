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

; 渲染模块
_init_render PROTO ; 初始化渲染模块
_free_render PROTO ; 释放渲染模块
_render_buffer PROTO ; 渲染缓冲区
_render_window PROTO ; 渲染缓冲区到窗口

; 状态模块
_init_state   PROTO ; 初始化状态模块
_state_update PROTO ; 状态更新
_check_key_down PROTO;检测按键并更新状态

public $h_instance, $h_window_main, $state

.const
S_MAIN_WINDOW_TITLE byte '北理润 - BITRun', 0 ; 主窗口标题
S_MAIN_CLASS_NAME byte 'main_window_class', 0 ; 主窗口类名

.data

.data?
$h_instance dword ? ; 程序实例句柄
$h_window_main dword ? ; 主窗口句柄

$state GameState <> ; 游戏状态

$thread_live dword ? ; 线程存活标志 为0时线程退出
$p_render_buffer_event dword ? ; 通知绘制缓冲区
$p_render_window_event dword ? ; 通知从缓冲区同步到窗口

.code

; 用于快速定义字符串
szText MACRO Name, Text:VARARG
LOCAL lbl
	jmp lbl
	Name db Text,13,10,0
	lbl:
ENDM



; 帧时钟信号产生线程
_refresh_interval_thread PROC 
    local @freq:QWORD ; 时钟频率
    local @time0:QWORD, @time1:QWORD ; 时间
    local @last_us:DWORD ; 上一次的时间 单位微秒
    local @1m:DWORD ; 常量1000000 用于计算微秒
    mov @1m, 1000000
    mov @last_us, 0
    invoke QueryPerformanceFrequency, addr @freq ; 获取时钟频率
    invoke QueryPerformanceCounter, addr @time0 ; 获取初始时间
    finit
    .while $thread_live == 1
        ; 计算时间差
        invoke QueryPerformanceCounter,addr @time1
        mov eax, dword ptr @time0
        mov edx, dword ptr @time0+4
        sub dword ptr @time1, eax
        sbb dword ptr @time1+4, edx
        fild @time1 ; 计数器差值
        fimul @1m ; 乘以单位频率
        fild @freq ; 除以频率 得到以单位频率为单位的时间差
        fdiv
        fistp @time1 ; 开始到现在的时间差

        ; 计算下一帧时间
        mov eax, @last_us
        add eax, 1000000/FPS

        .if eax > dword ptr @time1
            ; 时候未到
			sub eax, dword ptr @time1
			;invoke Sleep, eax
        .else
            ; DEBUG 每个周期打印一个.
            invoke crt_putchar, '.'

            ; 更新时间
            mov eax, dword ptr @time1
            mov @last_us, eax

            ; 检测按键输入
            invoke _check_key_down

            ; 通知渲染缓冲区
            invoke SetEvent, $p_render_buffer_event
        .endif

    .endw
    ret
_refresh_interval_thread ENDP


; 渲染缓冲区线程
_render_buffer_thread PROC
    local @freq:QWORD ; 时钟频率
    local @time0:QWORD, @time1:QWORD ; 时间
    local @1k:DWORD ; 常量1000 用于计算毫秒
    mov @1k, 1000
    invoke QueryPerformanceFrequency, addr @freq ; 获取时钟频率
    invoke QueryPerformanceCounter, addr @time0 ; 获取初始时间
    finit
    .while $thread_live != 0
        ; 事件同步
        invoke WaitForSingleObject, $p_render_buffer_event, INFINITE
        invoke ResetEvent, $p_render_buffer_event

        ; 更新时间
        invoke QueryPerformanceCounter,addr @time1
        mov eax, dword ptr @time0
        mov edx, dword ptr @time0+4
        sub dword ptr @time1, eax
        sbb dword ptr @time1+4, edx
        fild @time1 ; 计数器差值
        fimul @1k ; 乘以单位频率
        fild @freq ; 除以频率 得到以单位频率为单位的时间差
        fdiv
        fistp @time1 ; 开始到现在的时间差
        mov eax, dword ptr @time1
        mov $state.time, eax
        

        ; 状态更新
        invoke _state_update

        ; 渲染
        invoke _render_buffer

        ; 通知同步到窗口
        invoke SetEvent, $p_render_window_event
    .endw
    ret
        
_render_buffer_thread ENDP

; 同步缓冲区到窗口线程
_render_window_thread PROC

    .while $thread_live != 0
        ; 缓冲区空或者刷新标志为0时等待
        invoke WaitForSingleObject, $p_render_window_event, INFINITE
        invoke ResetEvent, $p_render_window_event

        ; 渲染缓冲区到窗口
        invoke _render_window
    .endw
    ret
_render_window_thread ENDP

; 初始化回调
_init PROC
    ; 初始化事件
    invoke CreateEvent, NULL, TRUE, FALSE, NULL
    mov $p_render_buffer_event, eax
    invoke CreateEvent, NULL, TRUE, FALSE, NULL
    mov $p_render_window_event, eax

    ; 初始化渲染模块
    invoke _init_render
    ; 初始化游戏状态
    invoke _init_state

    ; 启动线程
    mov $thread_live, 1
    invoke CreateThread, NULL, 0, _refresh_interval_thread, NULL , 0, NULL
    invoke CreateThread, NULL, 0, _render_buffer_thread, NULL, 0, NULL
    invoke CreateThread, NULL, 0, _render_window_thread, NULL, 0, NULL
    ret
_init ENDP


; 关闭回调
_close PROC
    ; 关闭线程
    mov $thread_live, 0

    ; 释放渲染模块
    invoke _free_render

    ; 可能需要一个释放状态的

    ; 释放事件
    invoke CloseHandle, $p_render_window_event
    invoke CloseHandle, $p_render_buffer_event

    ; 关闭窗口
    invoke DestroyWindow, $h_window_main
    invoke PostQuitMessage, NULL

    ret
_close ENDP


; 主窗口回调
_main_window_proc PROC @h_instance, @msg, @wParam, @lParam
    mov eax, @msg
    .if eax == WM_CREATE
        invoke _init
    .elseif eax == WM_CLOSE
        invoke _close
    .else
        invoke DefWindowProc, @h_instance, @msg, @wParam, @lParam
        ret
    .endif

    xor eax, eax
    ret
_main_window_proc ENDP

; 主窗口
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