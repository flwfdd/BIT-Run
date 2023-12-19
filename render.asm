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

S_SCORE_FORMAT db "SCORE: %05d HI: %05d", 0
$s_score db "SCORE: 00000 HI: 00000", 0

$a_buffer_dc dword BUFFER_SIZE dup(?) ; 缓冲区设备上下文数组
$a_buffer_bmp dword BUFFER_SIZE dup(?) ; 缓冲区位图数组
$buffer_index dword 0 ; 缓冲区索引 指向最新绘制好的缓冲区

$p_a_image dword ? ; 指向图像数组的指针

.code

; 转换RGB为BGR
_rgb2bgr PROC uses ebx esi edi @rgb:DWORD
    mov eax, @rgb
    and eax, 00FF0000h
    shr eax, 16
    mov ecx, @rgb
    and ecx, 0000FF00h
    or eax, ecx
    mov ecx, @rgb
    and ecx, 000000FFh
    shl ecx, 16
    or eax, ecx
    ret
_rgb2bgr ENDP

; 判断是否在窗口内 输入RenderObject指针 输出是否在窗口内
_check_obj_in_window PROC uses ebx esi edi ecx @p_obj:DWORD
	; 获取图像指针
	mov esi, @p_obj
    mov ecx, [esi + RenderObject.p_image]

	; 判断是否在窗口内
    ; 右
	;.if [esi + RenderObject.x] >= WINDOW_WIDTH
	;	xor eax, eax
	;	ret
    ;.endif
    ; 上
    ;.if [esi + RenderObject.y] >= WINDOW_HEIGHT
	;	xor eax, eax
	;	ret
	;.endif
    ; 左
	mov eax, [esi + RenderObject.x]
	add eax, [ecx + Image.w]
    cmp eax,0
    jg @label1_c_o_i_w
		xor eax, eax
		ret
    @label1_c_o_i_w:
    ; 下
	;mov eax, [esi + RenderObject.y]
	;add eax, [ecx + Image.h]
	;.if eax <= 0
	;	xor eax, eax
	;	ret
	;.endif

	mov eax, 1
	ret
_check_obj_in_window ENDP

; 判断是否碰撞 输入两个RenderObject指针 输出是否碰撞
_check_obj_overlap PROC uses ebx esi edi ecx @p_obj1:DWORD, @p_obj2:DWORD
    local @p_image1:DWORD, @p_image2:DWORD
    local @obj1_rect:RECT, @obj2_rect:RECT, @overlap_rect:RECT

    ; 获取图像指针
    mov esi, @p_obj1
    mov eax, [esi + RenderObject.p_image]
    mov ecx, eax
    mov @p_image1, eax
    mov edi, @p_obj2
    mov eax, [edi + RenderObject.p_image]
    mov edx, eax
    mov @p_image2, eax

    ; 快速判断矩形框是否重叠
    ; 1完全在2左侧
    mov eax, [esi + RenderObject.x]
    mov @obj1_rect.left, eax
    add eax, [ecx + Image.w]
    mov @obj1_rect.right, eax
    .if eax <= [edi + RenderObject.x]
        xor eax, eax
        ret
    .endif
    ; 1完全在2右侧
    mov eax, [edi + RenderObject.x]
    mov @obj2_rect.left, eax
    add eax, [edx + Image.w]
    mov @obj2_rect.right, eax
    .if eax <= [esi + RenderObject.x]
        xor eax, eax
        ret
    .endif
    ; 1完全在2下方
    mov eax, [esi + RenderObject.y]
    mov @obj1_rect.bottom, eax
    add eax, [ecx + Image.h]
    mov @obj1_rect.top, eax
    .if eax <= [edi + RenderObject.y]
        xor eax, eax
        ret
    .endif
    ; 1完全在2上方
    mov eax, [edi + RenderObject.y]
    mov @obj2_rect.bottom, eax
    add eax, [edx + Image.h]
    mov @obj2_rect.top, eax
    .if eax <= [esi + RenderObject.y]
        xor eax, eax
        ret
    .endif

    ; 计算交叉区域
    ; 计算交叉区域左侧
    mov eax, @obj1_rect.left
    .if eax < @obj2_rect.left
        mov eax, @obj2_rect.left
    .endif
    mov @overlap_rect.left, eax
    ; 计算交叉区域右侧
    mov eax, @obj1_rect.right
    .if eax > @obj2_rect.right
        mov eax, @obj2_rect.right
    .endif
    mov @overlap_rect.right, eax
    ; 计算交叉区域下方
    mov eax, @obj1_rect.bottom
    .if eax < @obj2_rect.bottom
        mov eax, @obj2_rect.bottom
    .endif
    mov @overlap_rect.bottom, eax
    ; 计算交叉区域上方
    mov eax, @obj1_rect.top
    .if eax > @obj2_rect.top
        mov eax, @obj2_rect.top
    .endif
    mov @overlap_rect.top, eax

    ; 像素判断是否有交叉区域
    mov esi, @overlap_rect.top ; 从上到下
    dec esi ; 修正索引
    .while esi >= @overlap_rect.bottom
        mov edi, @overlap_rect.left ; 从左到右
        .while edi < @overlap_rect.right
            ; 计算obj1 mask中相对坐标
            mov eax, @obj1_rect.top
            dec eax ;修正索引
            sub eax, esi ; 从上往下行索引
            mov ebx, @p_image1
            mov ebx, [ebx + Image.w]
            mul ebx ; 计算行偏移
            mov ebx, edi
            sub ebx, @obj1_rect.left ; 从左往右列索引
            add eax, ebx ; 计算偏移
            ; 获取obj1 mask像素
            mov ebx, @p_image1
            mov ebx, [ebx + Image.a_mask]
            .if byte ptr [ebx + eax] == 0
                inc edi
                .continue
            .endif

            ; 计算obj2 mask中相对坐标
            mov eax, @obj2_rect.top
            dec eax ;修正索引
            sub eax, esi ; 从上往下行索引
            mov ebx, @p_image2
            mov ebx, [ebx + Image.w]
            mul ebx ; 计算行偏移
            mov ebx, edi
            sub ebx, @obj2_rect.left ; 从左往右列索引
            add eax, ebx ; 计算偏移
            ; 获取obj2 mask像素
            mov ebx, @p_image2
            mov ebx, [ebx + Image.a_mask]
            .if byte ptr [ebx + eax] == 0
                inc edi
                .continue
            .endif

            ; 有交叉区域
            mov eax, 1
            ret
        .endw
        dec esi
    .endw

    xor eax, eax
    ret
_check_obj_overlap ENDP

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


    ; 创建画刷
    invoke _rgb2bgr, $state.background_color
    invoke CreateSolidBrush, eax
    mov esi, eax
    ; 选择画刷
    invoke SelectObject, $a_buffer_dc[4*ebx], esi
    ; 填充背景颜色
    invoke PatBlt, $a_buffer_dc[4*ebx], 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, PATCOPY
    ; 释放画刷
    invoke DeleteObject, esi



    ; 根据优先级依次绘制
    mov ecx, 2
    @label1_r_b:
        mov esi, 0
        mov edi, $state.p_a_render_object ; 渲染对象地址
        .while esi < $state.render_object_size
            .if [edi + RenderObject.z] != ecx
		        inc esi
                add edi, sizeof RenderObject
                .continue
            .endif
            ; 转换坐标为左下角原点 右上方向为正

            mov eax, [edi + RenderObject.p_image]
            mov edx, WINDOW_HEIGHT
            sub edx, [edi + RenderObject.y]
            sub edx, [eax + Image.h]
            push ecx
            invoke TransparentBlt, $a_buffer_dc[4*ebx], [edi + RenderObject.x], edx, [eax + Image.w], [eax + Image.h], [eax + Image.h_dc], 0, 0, [eax + Image.w], [eax + Image.h], [eax + Image.mask_color]
            pop ecx

		    inc esi
            add edi, sizeof RenderObject
        .endw

        dec ecx
        jge @label1_r_b


    ; 渲染游戏结束
    .if $state.status == GAME_STATUS_OVER
        invoke _get_image, IMAGE_GAME_OVER_ID
        invoke TransparentBlt, $a_buffer_dc[4*ebx], 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, [eax + Image.h_dc], 0, 0, [eax + Image.w], [eax + Image.h], [eax + Image.mask_color]
    .endif

    ; 渲染分数
    invoke CreateFont, 24, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH, offset FONT
    mov esi, eax
    invoke SelectObject, $a_buffer_dc[4*ebx], esi
    invoke SetTextColor, $a_buffer_dc[4*ebx], 0
    invoke SetBkMode, $a_buffer_dc[4*ebx], TRANSPARENT
    invoke SetTextAlign, $a_buffer_dc[4*ebx], TA_RIGHT
    mov eax, $state.highest_score
    mov edx, 0
    mov esi, SCORE_RATIO
    div esi
    mov ecx, eax
    mov eax, $state.score
    mov edx, 0
    div esi
    invoke crt_sprintf, offset $s_score, offset S_SCORE_FORMAT, eax, ecx
    invoke TextOut, $a_buffer_dc[4*ebx], WINDOW_WIDTH - 10, 10, offset $s_score, sizeof $s_score - 1
    invoke DeleteObject, esi


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
    invoke _rgb2bgr, [ebx + Image.mask_color]
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

; 释放单个图像
_free_image PROC @p_image:DWORD
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