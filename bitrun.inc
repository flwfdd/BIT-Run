.const
; 配置参数
WINDOW_WIDTH EQU 1000 ; 窗口宽度
WINDOW_HEIGHT EQU 500 ; 窗口高度
BUFFER_SIZE EQU 24 ; 缓冲大小
FPS EQU 50 ; 帧率

; 图片结构体
Image STRUCT
    id DWORD ? ; 资源ID
    mask_color DWORD ? ; 透明色
    w DWORD ? ; 宽度
    h DWORD ? ; 高度
    h_dc DWORD ? ; DC句柄
    h_bmp DWORD ? ; BMP句柄
    a_mask DWORD ? ; w*h的数组 每个元素为BYTE 表明位置是否有像素 0无否则有
Image ENDS

; 绘制元素结构体
RenderObject STRUCT
    x DWORD ? ; 画布上的X坐标
    y DWORD ? ; 画布上的Y坐标
    z DWORD ? ; 优先级 大的在上面
    p_image DWORD ? ; 图片指针
RenderObject ENDS

; 游戏状态
GAME_STATUS_INIT EQU 0 ; 未开始
GAME_STATUS_RUN EQU 1 ; 运行中
GAME_STATUS_OVER EQU 2 ; 结束

; 游戏主结构
GameState STRUCT
    status DWORD ? ; 状态
    time DWORD ? ; 时间 单位毫秒
    score DWORD ? ; 分数
    background_color DWORD ? ; 背景颜色
    render_object_size DWORD ? ; 绘制元素数量
    p_a_render_object DWORD ? ; 指向绘制元素数组的指针 数组中每个元素是RenderObject结构体
GameState ENDS


; 图片

IMAGES_START EQU $ ; 开始标记

IMAGE_GOOSE_STAND_ID DWORD 101
IMAGE_GOOSE_STAND_MASK_COLOR DWORD 00FF00h
IMAGE_GOOSE_RUN0_ID DWORD 102
IMAGE_GOOSE_RUN0_MASK_COLOR DWORD 00FF00h
IMAGE_GOOSE_RUN1_ID DWORD 103
IMAGE_GOOSE_RUN1_MASK_COLOR DWORD 00FF00h
IMAGE_GOOSE_JUMP_ID DWORD 104
IMAGE_GOOSE_JUMP_MASK_COLOR DWORD 00FF00h

IMAGE_BIT_BADGE_ID DWORD 201
IMAGE_BIT_BADGE_MASK_COLOR DWORD 000000h

IMAGE_BIRD0_ID DWORD 301
IMAGE_BIRD0_MASK_COLOR DWORD 000000h
IMAGE_BIRD1_ID DWORD 302
IMAGE_BIRD1_MASK_COLOR DWORD 000000h

IMAGES_END EQU $ ; 结束标记

IMAGES_SIZE EQU (IMAGES_END - IMAGES_START) / 8 ; 计算图片数量