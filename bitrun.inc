.const
; ���ñ���
WINDOW_WIDTH EQU 800 ; ���ڿ���
WINDOW_HEIGHT EQU 600 ; ���ڸ߶�
BUFFER_SIZE EQU 24 ; �����С
FPS EQU 1 ; ֡��

; ����Ԫ�ؽṹ��
DrawObject STRUCT
    x DWORD ? ; �����ϵ�X����
    y DWORD ? ; �����ϵ�Y����
    z DWORD ? ; ���ȼ� Խ��Խ������
    bmp_size DWORD ? ; BMP����
    bmp_now DWORD ? ; ��ǰ��ʾ��BMP���
    h_bmp_array DWORD ? ; BMPָ������ ÿ��Ԫ����LoadBitmap��õ�
DrawObject ENDS

; ��Ϸ״̬
GAME_STATUS_INIT EQU 0 ; δ��ʼ
GAME_STATUS_RUN EQU 1 ; ������
GAME_STATUS_OVER EQU 2 ; ����

; ��Ϸ���ṹ
GameState STRUCT
    status DWORD ? ; ״̬
    score DWORD ? ; ����
    draw_object_size DWORD ? ; ����Ԫ������
    h_draw_object_array DWORD ? ; ����Ԫ��ָ������ ÿ��Ԫ����DrawObjectָ��
GameState ENDS