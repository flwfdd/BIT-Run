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
S_MAIN_WINDOW_TITLE byte '北理润 - BITRun', 0 ; 主窗口标题
S_MAIN_CLASS_NAME byte 'main_window_class', 0 ; 主窗口类名

.data
$thread_live dword 1 ; 线程存活标志 为0时线程退出
$buffer_index dword 0 ; 缓冲区索引 指向最新绘制好的缓冲区

.data?
$h_instance dword ? ; 程序实例句柄
$h_window_main dword ? ; 主窗口句柄

$ha_buffer_dc dword BUFFER_SIZE dup (?) ; 缓冲区设备上下文数组
$ha_buffer_bmp dword BUFFER_SIZE dup(?) ; 缓冲区位图数组

$game_ms dword ? ; 游戏时间 所有计算以此为基准 以毫秒为单位
$h_draw_buffer_event dword ? ; 通知绘制缓冲区
$h_draw_window_event dword ? ; 通知从缓冲区同步到窗口

.code

; 帧时钟信号产生线程
_refresh_interval_thread PROC
    .while $thread_live == 1
        invoke crt_putchar, '.' ; 每个周期打印一个.
        invoke SetEvent, $h_draw_buffer_event
        invoke Sleep, 1000/FPS
        add $game_ms, 1000/FPS
    .endw
    ret
_refresh_interval_thread ENDP


; 绘制缓冲区线程
_draw_buffer_thread PROC uses ebx esi edi
    .while $thread_live != 0
        ; 事件同步
        invoke WaitForSingleObject, $h_draw_buffer_event, INFINITE
        invoke ResetEvent, $h_draw_buffer_event

        ; 获取写入缓冲区的索引
        mov ebx, $buffer_index
        inc ebx
        .if ebx == BUFFER_SIZE
	        mov ebx, 0
        .endif
        
        ; DEBUG 输出写入缓冲区索引
        mov eax, ebx
        add eax, 'A'
        invoke crt_putchar, eax

        ; DEBUG 绘制绿色方块
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

        ; DEBUG 绘制图像
        mov eax, offset $image_demo
        invoke TransparentBlt, $ha_buffer_dc[4*ebx], 0, 0, [eax + Image.w], [eax + Image.h], [eax + Image.h_dc], 0, 0, [eax + Image.w], [eax + Image.h], [eax + Image.mask_color]

        ; 更新缓冲区索引
        mov $buffer_index, ebx
        invoke SetEvent, $h_draw_window_event
    .endw
    ret
        
_draw_buffer_thread ENDP

; 同步缓冲区到窗口线程
_draw_window_thread PROC uses ebx
    local @h_dc:DWORD
    mov ebx, 0 ; 缓冲区刷新位置

    .while $thread_live != 0
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
        mov @h_dc, eax
        invoke	BitBlt, @h_dc, 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, $ha_buffer_dc[4*ebx], 0, 0, SRCCOPY
        invoke ReleaseDC, $h_window_main, @h_dc
    .endw

        ret
_draw_window_thread ENDP

; 初始化缓冲区
_init_buffer PROC uses esi edi
    local @h_dc:DWORD
    local @cnt:DWORD
    
    ; 获取设备上下文
    invoke GetDC, $h_window_main
    mov @h_dc, eax

    ; 填充缓冲区数组
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

; 释放缓冲区
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

; 初始化单个图像
_init_image PROC uses ebx esi edi @h_image:DWORD
    local @h_dc:DWORD
    local @bmp:BITMAP
    mov ebx, @h_image

    ; 创建兼容设备上下文
    invoke GetDC, $h_window_main
    mov @h_dc, eax
    invoke CreateCompatibleDC, @h_dc
    mov [ebx + Image.h_dc], eax
    invoke ReleaseDC, $h_window_main, @h_dc
    ; 加载位图
    invoke LoadBitmap, $h_instance, [ebx + Image.id]
    mov [ebx + Image.h_bmp], eax
    ; 选择位图到设备上下文
    invoke SelectObject, [ebx + Image.h_dc], [ebx + Image.h_bmp]
    ; 获取位图宽高
    invoke GetObject, [ebx + Image.h_bmp], sizeof BITMAP, addr @bmp
    mov eax, @bmp.bmWidth
    mov [ebx + Image.w], eax
    mov eax, @bmp.bmHeight
    mov [ebx + Image.h], eax

    ; 申请mask内存
    mov eax, @bmp.bmWidth
    mul @bmp.bmHeight
    invoke crt_malloc, eax
    mov [ebx + Image.a_mask], eax

    ; 设置mask
    mov ebx, eax ; ebx指向mask数组
    mov esi, 0 ; 行索引
    .while esi < @bmp.bmHeight
        mov edi, 0 ; 列索引
        .while edi < @bmp.bmWidth
            ; 获取像素
            mov eax, @h_image
            invoke GetPixel, [eax + Image.h_dc], edi, esi
            ; 判断是否为mask_color
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

; 释放单个图像
_free_image PROC  @h_image:DWORD
	mov ebx, @h_image
	invoke DeleteDC, [ebx + Image.h_dc]
	invoke DeleteObject, [ebx + Image.h_bmp]
	invoke crt_free, [ebx + Image.a_mask]
	ret
_free_image ENDP

; 初始化图像
_init_images PROC
    invoke _init_image, offset $image_demo
    ret
_init_images ENDP

; 释放图像
_free_images PROC
    invoke _free_image, offset $image_demo
	ret
_free_images ENDP

; 初始化回调
_init PROC
    ; 初始化事件
    invoke CreateEvent, NULL, TRUE, FALSE, NULL
    mov $h_draw_buffer_event, eax
    invoke CreateEvent, NULL, TRUE, FALSE, NULL
    mov $h_draw_window_event, eax

    ; 初始化资源
    invoke _init_buffer
    invoke _init_images

    ; 启动线程
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

    ; 关闭线程
    mov $thread_live, 0

    ; 释放资源
    invoke _free_images
    invoke _free_buffer
    

    ; 释放事件
    invoke CloseHandle, $h_draw_buffer_event
    invoke CloseHandle, $h_draw_window_event

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

; 主窗口
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