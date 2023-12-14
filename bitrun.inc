.const
; 配置变量
WINDOW_WIDTH EQU 800 ; 窗口宽度
WINDOW_HEIGHT EQU 600 ; 窗口高度
BUFFER_SIZE EQU 24 ; 缓冲大小
FPS EQU 1 ; 帧率

; 绘制元素结构体
DrawObject STRUCT
    x DWORD ? ; 画布上的X坐标
    y DWORD ? ; 画布上的Y坐标
    z DWORD ? ; 优先级 越大越在上面
    bmp_size DWORD ? ; BMP数量
    bmp_now DWORD ? ; 当前显示的BMP序号
    h_bmp_array DWORD ? ; BMP指针数组 每个元素是LoadBitmap获得的
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
    h_draw_object_array DWORD ? ; 绘制元素指针数组 每个元素是DrawObject指针
GameState ENDS
