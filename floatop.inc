
; 定义一些浮点数运算的宏，方便处理


; 加载一个立即数或寄存器到寄存器栈宏（fild好像不行）,I代表整数
fldI  MACRO IMDR
	push eax ; 保存eax
	mov eax,IMDR
	push eax
	fild dword ptr [esp]
	pop eax  ; 维护栈平衡
	pop eax  ; 恢复eax
ENDM


; 用于初始化一个绘制对象的x与y坐标
RobjLoadx MACRO robj, INT_X
	mov robj.x,INT_X
	fldI INT_X
	fstp robj.phsx
ENDM


RobjLoady MACRO robj, INT_Y
	mov robj.y,INT_Y
	fldI INT_Y
	fstp robj.phsy
ENDM