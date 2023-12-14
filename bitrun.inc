.data
; 配置变量
WINDOW_WIDTH EQU 800 ; 窗口宽度
WINDOW_HEIGHT EQU 600 ; 窗口高度
BUFFER_SIZE EQU 24 ; 缓冲大小
FPS EQU 100 ; 帧率


; 图片结构体
Image STRUCT
    id DWORD ? ; 图片ID
    w DWORD ? ; 宽度
    h DWORD ? ; 高度
    mask_color DWORD ? ; 透明色
    h_dc DWORD ? ; DC句柄
    h_bmp DWORD ? ; BMP句柄
    a_mask DWORD ? ; w*h的数组 每个元素为BYTE 表明位置是否有像素 0无否则有
Image ENDS

$image_demo Image <65535, ?, ?, 0, ?, ?, ?>


; 绘制元素结构体
DrawObject STRUCT
    x DWORD ? ; 画布上的X坐标
    y DWORD ? ; 画布上的Y坐标
    z DWORD ? ; 优先级 越大越在上面
    image_size DWORD ? ; 帧数量
    image_index DWORD ? ; 当前帧
    a_image DWORD ? ; 图片指针数组 每个元素是Image指针
DrawObject ENDS

; 游戏状态
GAME_STATUS_INIT EQU 0 ; 未开始
GAME_STATUS_RUN EQU 1 ; 运行中
GAME_STATUS_OVER EQU 2 ; 结束

; 游戏主结构
GameState STRUCT
    status DWORD ? ; 状态
    score DWORD ? ; 分数
    draw_object_size DWORD ? ; 绘制元素数量
    a_draw_object DWORD ? ; 绘制元素指针数组 每个元素是DrawObject指针
GameState ENDS
