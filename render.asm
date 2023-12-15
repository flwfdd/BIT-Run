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

extern $h_instance:dword ; 程序实例句柄
extern $h_window_main:dword ; 主窗口句柄
extern $state:GameState ; 游戏状态

.data

$a_buffer_dc dword BUFFER_SIZE dup(?) ; 缓冲区设备上下文数组
$a_buffer_bmp dword BUFFER_SIZE dup(?) ; 缓冲区位图数组
$buffer_index dword 0 ; 缓冲区索引 指向最新绘制好的缓冲区

$p_a_image dword ? ; 指向图像数组的指针

.code

; 渲染缓冲区
_render_buffer PROC uses ebx esi edi
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

    ; 渲染对象
    mov ecx, 0 ; 渲染对象索引
    mov esi, $state.a_p_render_object ; 渲染对象地址
    .while ecx < $state.render_object_size
		mov eax, [esi + RenderObject.p_image]
        ; 转换坐标
        mov edx, WINDOW_HEIGHT
        sub edx, [esi + RenderObject.y]
        sub edx, [eax + Image.h]
        invoke TransparentBlt, $a_buffer_dc[4*ebx], [esi + RenderObject.x], edx, [eax + Image.w], [eax + Image.h], [eax + Image.h_dc], 0, 0, [eax + Image.w], [eax + Image.h], [eax + Image.mask_color]
		
		inc ecx
        add esi, 4
    .endw


    ; 更新缓冲区索引
    mov $buffer_index, ebx
    ret
_render_buffer ENDP


; 渲染缓冲区到窗口
_render_window PROC uses ebx
    local @h_dc:DWORD

    ; 获取缓冲区索引
    mov ebx, $buffer_index

    ; DEBUG 输出读出缓冲区索引
    mov eax, ebx
    add eax, 'a'
    invoke crt_putchar, eax

    ; 将缓冲区中的内容传到设备上下文中
    invoke GetDC, $h_window_main
    mov @h_dc, eax
    invoke	BitBlt, @h_dc, 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, $a_buffer_dc[4*ebx], 0, 0, SRCCOPY
    invoke ReleaseDC, $h_window_main, @h_dc

    ret
_render_window ENDP

; 初始化缓冲区
_init_buffer PROC uses esi edi
    local @h_dc:DWORD
    local @cnt:DWORD
    
    ; 获取设备上下文
    invoke GetDC, $h_window_main
    mov @h_dc, eax

    ; 填充缓冲区数组
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

; 释放缓冲区
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

; 初始化单个图像
_init_image PROC uses ebx esi edi @p_image:DWORD
    local @h_dc:DWORD, @bmp:BITMAP
    mov ebx, @p_image

    ; 转换RGB为BGR
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
    mov ebx, eax ; ebp指向mask数组
    mov esi, 0 ; 行索引
    .while esi < @bmp.bmHeight
        mov edi, 0 ; 列索引
        .while edi < @bmp.bmWidth
            ; 获取像素
            mov eax, @p_image
            invoke GetPixel, [eax + Image.h_dc], edi, esi
            ; 判断是否为mask_color
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


; 获取单个图像 传入图像ID 输出图像指针
_get_image PROC uses esi edi @id:DWORD
    mov esi, $p_a_image ; esi指向图像
    mov edi, @id ; edi指向图像ID
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


; 释放单个图像
_free_image PROC  @p_image:DWORD
	mov ebx, @p_image
	invoke DeleteDC, [ebx + Image.h_dc]
	invoke DeleteObject, [ebx + Image.h_bmp]
	invoke crt_free, [ebx + Image.a_mask]
	ret
_free_image ENDP


; 初始化所有图像
_init_images PROC
    ; 申请内存
    mov eax, IMAGES_SIZE
    mov ecx, sizeof Image
    mul ecx
    invoke crt_malloc, eax
    mov $p_a_image, eax

    ; 初始化图像
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


; 释放所有图像
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

; 初始化渲染模块
_init_render PROC
    invoke _init_buffer
    invoke _init_images
    ret
_init_render ENDP

; 释放渲染模块
_free_render PROC
    invoke _free_buffer
    invoke _free_images
    ret
_free_render ENDP


end