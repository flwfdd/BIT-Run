.386
.model flat,stdcall
option casemap:none

include     bitrun.inc
include     floatop.inc
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
include     wdm.inc

extern $h_instance:dword ; 程序实例句柄
extern $h_window_main:dword ; 主窗口句柄
extern $state:GameState ; 游戏状态
extern $voice_input:dword ; 麦克风模块：是否到达阈值

_get_image PROTO @id:DWORD ; 获取图像
_check_obj_in_window PROTO @p_obj:DWORD ; 检查对象是否在窗口内
_check_obj_overlap PROTO @p_obj1:DWORD, @p_obj2:DWORD ; 检查重叠

; 对绘制列表的操作
_init_render_list   PROTO @p_a_rlist:DWORD;初始化
_add_render_object  PROTO @p_robj   :DWORD;将对象拷贝添加到列表中
_update_render_list PROTO @isOver   :DWORD;更新绘制列表（剔除已经出界的对象）

; 更新绘制对象到下一个位置
_update_render_object  PROTO @p_robj :DWORD;更新绘制对象
_update_goose 	       PROTO @p_goose:DWORD;专门更新大鹅


; 在更新状态时随机添加若干障碍物
_update_obstacles   PROTO 

.data

; DEBUG 渲染对象
a_render_object_test RenderObject 10 dup (<>) ; 渲染对象数组
x_text dword 0

$state_jumping  dword 0;鹅是否滞空
$state_keypress  word 0;上一次检测到的按键输入(word->SHORT)
$state_voiceinput  dword 0;上一次检测到的按键输入(word->SHORT)


FLOATSCONST1 REAL4 0.001
FLOATSCONST2 REAL4 0.5
.code


; 内存移动宏
m2m  MACRO M1,M2
	push M2
	pop  M1
ENDM


; 用于快速定义字符串DEBUG
szText MACRO Name, Text:VARARG
LOCAL lbl
	jmp lbl
	Name db Text,13,10,0
	lbl:
ENDM


; 初始化状态
_init_state PROC uses ecx
	local @Goose:RenderObject
	local @Bkg1:RenderObject
	local @Bkg2:RenderObject

	mov $state_jumping,0
	mov $state_keypress,0
	mov $state_voiceinput,0
	mov $state.score, 0
	mov $state.status,GAME_STATUS_INIT
	; 加载 global vx
	fldI GINIT_VX
	fchs
	fstp $state.global_vx

	; 申请绘制列表内存
	mov $state.render_object_size,0
	mov eax, sizeof RenderObject
	mov ecx, RENDER_OBJ_SIZE
	mul ecx
	invoke crt_malloc,eax
	mov $state.p_a_render_object,eax
	
	; 初始化绘制列表
	invoke _init_render_list, $state.p_a_render_object


	; 创建一个鹅
	mov @Goose.obj_id,OBJ_GOOSE
	RobjLoadx @Goose,GOOSE_INITIAL_X
	RobjLoady @Goose,GOOSE_INITIAL_Y
	mov @Goose.z,0
	invoke _get_image, IMAGE_GOOSE_RUN0_ID
	mov @Goose.p_image,eax
	mov @Goose.vx,0
	mov @Goose.vy,0
	m2m  @Goose.lasttsp,$state.time

	;创建两个背景循环绘制
	;背景1
	mov @Bkg1.obj_id,OBJ_BKG
	RobjLoadx @Bkg1,0
	RobjLoady @Bkg1,0
	mov @Bkg1.z,2
	invoke _get_image, IMAGE_BACKGROUND_ID
	mov @Bkg1.p_image,eax
	m2m @Bkg1.vx,$state.global_vx
	mov @Bkg1.vy,0
	m2m @Bkg1.lasttsp,$state.time

	;背景2
	mov @Bkg2.obj_id,OBJ_BKG
	RobjLoadx @Bkg2,WINDOW_WIDTH
	RobjLoady @Bkg2,0
	mov @Bkg2.z,2
	invoke _get_image, IMAGE_BACKGROUND_ID
	mov @Bkg2.p_image,eax
	m2m @Bkg2.vx,$state.global_vx
	mov @Bkg2.vy,0
	m2m @Bkg2.lasttsp,$state.time


	; 将上述创建的背景，鹅加入到绘制列表中
	invoke _add_render_object, addr @Goose
	invoke _add_render_object, addr @Bkg1
	invoke _add_render_object, addr @Bkg2

	ret
_init_state ENDP

; 重置状态
_reset_state PROC
	invoke crt_free,$state.p_a_render_object
	invoke _init_state
_reset_state ENDP

; 统一绘制对象更新时间
_start_state PROC uses ecx edi edx

    ; align the timestamp
    xor ecx, ecx                     
    mov eax, $state.render_object_size 
    mov edi, $state.p_a_render_object 

    align_loop:
		mov edx,$state.time
        mov DWORD PTR [edi + RenderObject.lasttsp],edx
        inc ecx                   
		add edi, sizeof RenderObject
        cmp ecx, eax              
        jl align_loop             
    
    mov eax, 0

    ret

_start_state ENDP

; 更新状态
_state_update PROC uses ebx esi
	local @collide


	mov @collide,0
	mov ebx,0
	.if $state.status!=GAME_STATUS_RUN
		ret
	.endif

	; 这里更新所有的对象运动状态，如果发生了碰撞则终止
	mov esi,$state.p_a_render_object
	mov ecx,0
	.while ecx!=$state.render_object_size
		invoke _update_render_object,esi
	 	.if eax!=0
			mov @collide,eax
			.break
		.endif
		inc ecx
		add esi, sizeof RenderObject
	.endw

	.if @collide
		mov $state.status,GAME_STATUS_OVER
	.endif

	; 根据是否发生碰撞更新绘制列表
	invoke _update_render_list,@collide

	; 根据绘制状态添加屏幕外准备出现的障碍物
	invoke _update_obstacles
	
 	ret
_state_update ENDP

; 检查按键
_check_key_down PROC uses ecx edi edx
	local @keystate:word
	invoke GetAsyncKeyState, VK_SPACE
	mov  @keystate,ax
	.if $voice_input || ax != 0
		;DEBUG
		;szText debugstr1,"detect key pressed"
		;invoke crt_printf,addr debugstr1

		; 处理各个阶段按下空格的状态更新
		.if $state.status == GAME_STATUS_INIT
			mov $state.status,GAME_STATUS_RUN
			invoke _start_state
		.endif

		.if $state.status == GAME_STATUS_INIT || $state.status == GAME_STATUS_RUN


			.if $state_jumping ==0 
				mov $state_jumping,1

				;遍历绘制列表找到鹅
				mov ecx,0
				mov edi, $state.p_a_render_object
				.while ecx != $state.render_object_size
					mov edx,[edi+RenderObject.obj_id]
					.if edx == OBJ_GOOSE

						fldI JUMP_VY
						;fstp [@pGoose+RenderObject.vy]
						fstp [edi+RenderObject.vy]

						invoke _get_image,IMAGE_GOOSE_JUMP_ID
						mov [edi+RenderObject.p_image],eax

						.break
					.endif
					add edi, sizeof RenderObject
					inc ecx
				.endw

			.endif
		.endif

		.if $state.status == GAME_STATUS_OVER
			; .if $state_keypress == 0
			.if $state_voiceinput || $state_keypress == 0
				invoke Sleep,1000
				invoke _reset_state
			.endif
		.endif

	; DEBUG
	; .else
	; 	szText debugstr2,"detect no key pressed"
	; 	invoke crt_printf,addr debugstr2
	.endif

	mov cx, @keystate
	mov $state_keypress,cx
	mov ecx, $voice_input
	mov $state_voiceinput,ecx

	ret

_check_key_down ENDP


; 对绘制列表的操作
; 初始化绘制列表
_init_render_list PROC uses ecx @p_a_rlist:DWORD

	mov eax, sizeof RenderObject
	mov ecx, RENDER_OBJ_SIZE
	mul ecx
	invoke RtlZeroMemory,@p_a_rlist,eax
	ret
_init_render_list ENDP

; 更新绘制列表
_update_render_list PROC uses ecx @isOver:DWORD
	local @pOldL: dword  
	local @pNewL: dword
	local @oldsize:dword   ;绘制列表的大小
	mov @pNewL,0
	mov ecx,$state.p_a_render_object
	mov @pOldL,ecx

	mov ecx,$state.render_object_size
	mov @oldsize,ecx

	.if @isOver
		;在这里加上结算分数绘制的代码（创建图像后add_render_obj即可）

	.endif

	;检查是否有出界的绘制对象，如果有则更新列表
	mov ecx,0
	mov esi,@pOldL
	.while ecx!=@oldsize
		invoke _check_obj_in_window, esi
		.if eax!=0
			mov eax, sizeof RenderObject
			mov ecx, RENDER_OBJ_SIZE
			mul ecx
			invoke crt_malloc,eax
			mov @pNewL,eax
			invoke _init_render_list,@pNewL
			.break
		.endif
		inc ecx
		add esi,sizeof RenderObject
	.endw

	;将没有出界的物品放入到新的绘制列表中
	.if @pNewL != 0
		mov $state.render_object_size,0

		push @pNewL
		pop  $state.p_a_render_object

		mov ecx,0
		mov esi,@pOldL

		.while ecx!=@oldsize
			invoke _check_obj_in_window,esi
			.if eax!=0
				invoke _add_render_object,esi
			.endif
			inc ecx		
			add esi,sizeof RenderObject
		.endw

		invoke crt_free,@pOldL
	.endif
	ret
_update_render_list ENDP


; 这里是根据$state.p_a_render_object 进行添加的
_add_render_object PROC uses ecx edi esi @p_robj:DWORD
	mov ecx,0
	mov edi,$state.p_a_render_object

	.while ecx!=RENDER_OBJ_SIZE
		.if [edi + RenderObject.obj_id] == 0
			;这里不知道为啥链接不上拷贝函数，用rep代替一下
			;invoke RtlCopyMemory,edi,@p_robj,sizeof RenderObject
			mov esi,@p_robj
			mov ecx,sizeof RenderObject
			rep movsb

			inc $state.render_object_size
			.break
		.endif
		inc ecx
		add edi, sizeof RenderObject
	.endw
	ret
_add_render_object ENDP


; 对绘制对象的更新操作

; 如果碰撞则返回1，否则为0
_update_render_object PROC uses esi ecx  @p_robj:DWORD
	local @deltat:DWORD ; 经过的毫秒
	local @fdeltat:REAL4
	local @oldprecise:WORD  ; 临时存储浮点数控制字，用于舍入调整
	local @newprecise:WORD  ;

	mov esi,@p_robj
	.if [esi+RenderObject.obj_id] == OBJ_GOOSE
		; 鹅专门处理
		invoke _update_goose,@p_robj
		ret
	.else
		; 计算距离上一次绘制经过了多少毫秒
		push $state.time
		pop @deltat
		mov ecx,[esi+RenderObject.lasttsp]
		sub @deltat,ecx

		finit
		fild @deltat
		fld  FLOATSCONST1
		fmulp st(1),st
		fstp @fdeltat

		;更新物理坐标
		fld [esi+RenderObject.phsx]
		fld [esi+RenderObject.vx]
		fmul @fdeltat
		faddp st(1),st
		fstp [esi+RenderObject.phsx]

		fld [esi+RenderObject.phsy]
		fld [esi+RenderObject.vy]
		fmul @fdeltat
		faddp st(1),st
		fstp [esi+RenderObject.phsy]

		;舍入物理坐标到绘制坐标
		fld [esi+RenderObject.phsx]
		fnstcw @oldprecise
		movzx eax,@oldprecise
		or ah,12
		mov @newprecise,ax
		fldcw @newprecise
		fistp [esi+RenderObject.x]
		fldcw @oldprecise

		fld [esi+RenderObject.phsy]
		fldcw @newprecise
		fistp [esi+RenderObject.y]
		fldcw @oldprecise

		push $state.time
		pop  [esi+RenderObject.lasttsp]
		

	.endif

	;处理循环背景图
	.if [esi+RenderObject.obj_id] == OBJ_BKG
		mov eax,[esi+RenderObject.x]
		mov ecx,[esi+RenderObject.p_image]
		mov ecx,[ecx+Image.w]
		add eax,ecx
		;.if eax <= 0 masm .if不支持有符号比较
		cmp eax,0
		jg @label1_u_r_o
			add ecx,ecx
			add [esi+RenderObject.x],ecx

			fld  [esi+RenderObject.phsx]
			push ecx
			fild dword ptr [esp]
			pop  ecx
			faddp st(1),st
			fstp [esi+RenderObject.phsx]
		@label1_u_r_o:



	.endif

	.if [esi+RenderObject.obj_id] == OBJ_BIRD
		;处理鸟的翅膀
		mov eax,$state.time
		and eax,BIRD_INTERVAL
		.if eax !=0
			invoke _get_image,IMAGE_BIRD0_ID
		.else
			invoke _get_image,IMAGE_BIRD1_ID
		.endif
		mov [esi+RenderObject.p_image],eax
	.endif
	mov eax,0
	ret

_update_render_object ENDP


_update_goose PROC uses esi ecx @p_goose:DWORD
	local @deltat:DWORD ; 经过的毫秒
	local @fdeltat:REAL4
	local @accer:REAL4  ; 鹅的加速度
	local @iscollide
	local @oldprecise:WORD  ; 临时存储浮点数控制字，用于舍入调整
	local @newprecise:WORD  ;


	mov esi,@p_goose
	.if $state_jumping ==0
		mov eax,$state.time
		and eax,GOOSE_INTERVAL
		.if eax !=0 
			invoke _get_image,IMAGE_GOOSE_RUN0_ID
		.else
			invoke _get_image,IMAGE_GOOSE_RUN1_ID
		.endif
		mov [esi+RenderObject.p_image],eax
	.else

		; 计算距离上一次绘制经过了多少毫秒
		push $state.time
		pop @deltat
		mov ecx,[esi+RenderObject.lasttsp]
		sub @deltat,ecx

		finit
		fild @deltat
		fld  FLOATSCONST1
		fmulp st(1),st
		fstp @fdeltat

		; 加载加速度
		movzx eax,$state_keypress
		or eax,$state_voiceinput 
		.if eax != 0
			mov eax,G
			sub eax,JUMPA
		.else
			mov eax,G
		.endif

		push eax
		fild dword ptr [esp]
		fstp @accer
		pop eax

		;计算鹅这一时段后的位置与速度
		;位置计算
		fld [esi+RenderObject.phsy]
		fld [esi+RenderObject.vy]
		fmul @fdeltat
		faddp st(1),st
		
		fld FLOATSCONST2
		fld @accer
		fmulp st(1),st
		fld @fdeltat
		fmulp st(1),st
		fld @fdeltat
		fmulp st(1),st

		fsubp st(1),st
		fstp [esi+RenderObject.phsy]
		
		;速度计算
		fld [esi+RenderObject.vy]
		fld @accer
		fmul @fdeltat
		fsubp st(1),st
		fstp [esi+RenderObject.vy]

		;将物理坐标取整作为绘制坐标
		fld [esi+RenderObject.phsy]
		fnstcw @oldprecise
		movzx eax,@oldprecise
		or ah,12
		mov @newprecise,ax
		fldcw @newprecise
		fistp [esi+RenderObject.y]
		fldcw @oldprecise

		;如果更新后的物理坐标小于水平线高度，则重置鹅的状态
		fld [esi+RenderObject.phsy]
		mov eax,HORIZON_HEIGHT
		push eax
		fild dword ptr [esp]
		pop eax
		fcomip st,st(1)
		fstp st(0)
		jb @label1_u_g

		;小于高度的情况处理
		mov $state_jumping,0
		mov [esi+RenderObject.y],GOOSE_INITIAL_Y
		mov eax,GOOSE_INITIAL_Y
		push eax
		fild dword ptr [esp]
		fstp [esi+RenderObject.phsy]
		pop eax
		fldz
		fstp [esi+RenderObject.vy]
		invoke _get_image,IMAGE_GOOSE_RUN0_ID
		mov [esi+RenderObject.p_image],eax
		@label1_u_g:
	.endif

	push $state.time
	pop [esi+RenderObject.lasttsp]

	mov esi,$state.p_a_render_object
	mov @iscollide,0
	mov ecx,0
	.while ecx!=$state.render_object_size
		.if [esi+RenderObject.obj_id] == OBJ_GOOSE || [esi+RenderObject.obj_id]==OBJ_BKG || [esi+RenderObject.obj_id]==OBJ_CLOUD
			inc ecx
			add esi, sizeof RenderObject
			.continue
		.endif
		invoke _check_obj_overlap,@p_goose,esi
		.if eax !=0
			mov @iscollide,1
			;szText debugstr,"collide" 加上这个打印会有bug不知道为啥,可能是使用了ecx等寄存器
			;invoke crt_printf,addr debugstr
		.endif
		inc ecx
		add esi, sizeof RenderObject
	.endw


	mov eax,@iscollide
	ret

_update_goose ENDP



; 绘制对象添加

_update_obstacles PROC uses ecx esi edx ebx
	local @cloud:RenderObject		; 待添加的云
	local @lastcloudx:dword			; 新增云的x坐标
	local @ncloud:dword				; 绘制列表中云的数量
	local @obstacle:RenderObject    ; 待添加的障碍物
	local @lastobstaclex:dword		; 新增障碍物x坐标
	local @curtime:dword			; 当前时间，用于统一时间戳
	local @remain:dword				; 剩余的空间

	local @id:dword


	.if $state.render_object_size == RENDER_OBJ_SIZE
		ret
	.endif

	mov @ncloud,0
	mov @lastcloudx,0
	mov @lastobstaclex,0
	m2m @curtime,$state.time
	mov esi, $state.p_a_render_object

	mov ecx,RENDER_OBJ_SIZE
	sub ecx,$state.render_object_size
	mov @remain,ecx

	invoke crt_time,0
	invoke srand,eax

	; 查找排在最后面的云，并添加一朵新的云 
	mov edx, $state.render_object_size
	.while edx != 0
	 	m2m @id,[esi+RenderObject.obj_id]
		.if  @id==OBJ_CLOUD
			inc @ncloud
			mov eax,[esi+RenderObject.x] 
			cmp eax,0
			jle @label1_u_o
				.if eax > @lastcloudx
					mov @lastcloudx,eax
				.endif
			@label1_u_o:
		.endif
		add esi, sizeof RenderObject
		dec edx
	.endw
	; 如果没有找到云，则将lastcloudx设置为WINDOW_WIDTH
	.if @lastcloudx == 0
		mov @lastcloudx,WINDOW_WIDTH
	.endif

	; 最多容许添加4个云
	.if @ncloud < 6
		mov eax,6
		sub eax,@ncloud
		mov @ncloud,eax
		.while @ncloud !=0
			mov @cloud.obj_id,OBJ_CLOUD

			mov eax,IMAGE_CLOUD_ID
			invoke _get_image,eax
			mov @cloud.p_image,eax

			invoke crt_rand
			xor edx,edx
			mov ebx,400
			div ebx
			mov eax,edx
			add @lastcloudx,eax
			add @lastcloudx,CLOUD_INTERVAL

			mov eax,@lastcloudx
			RobjLoadx @cloud,eax

			invoke crt_rand
			xor edx,edx
			mov ebx, CLOUD_HEIGHT_MAX-CLOUD_HEIGHT_MIN
			div ebx
			mov eax,edx
			add eax,CLOUD_HEIGHT_MIN
			RobjLoady @cloud,eax

			mov @cloud.z,1

			fld  $state.global_vx
			fldI CLOUD_VX
			faddp st(1),st
			fstp @cloud.vx

			mov @cloud.vy,0
			m2m @cloud.lasttsp,@curtime
			invoke _add_render_object,addr @cloud
			
			dec @ncloud
		.endw
	.endif


	; 查找到在最后面的障碍物的坐标
	mov esi, $state.p_a_render_object
	mov edx, $state.render_object_size
	.while edx !=0 
	 	m2m @id,[esi+RenderObject.obj_id]
		.if @id == OBJ_NONE || @id == OBJ_BKG || @id == OBJ_GOOSE || @id==OBJ_CLOUD
			add esi, sizeof RenderObject
			dec edx
			.continue
		.endif

		mov eax,[esi+RenderObject.x] 
		cmp eax,0
		jle @label2_u_o
			; 如果这个障碍物在窗口内，则更新lastobstaclex
			.if eax > @lastobstaclex
				mov @lastobstaclex,eax
			.endif
		@label2_u_o:

		add esi, sizeof RenderObject
		dec edx
	.endw

	; 如果没有找到障碍物，则将lastobstaclex设置为WINDOW_WIDTH
	.if @lastobstaclex == 0
		mov @lastobstaclex,WINDOW_WIDTH
	.endif


	
	; 新添加的障碍物
	.while @remain != 0
		; 随机生成一个对象ID,获取其对应图片
		invoke crt_rand
		xor edx,edx
		mov ebx,OBSTACLE_NUM
		div ebx
		mov eax,edx
		lea eax,[OBSTACLE_START+8*eax]

		m2m @obstacle.obj_id,[eax]
		mov eax,[eax+4]
		invoke _get_image,[eax]
		mov @obstacle.p_image,eax

		; 随机生成一个新的x坐标
		invoke crt_rand
		xor edx,edx
		mov ebx, INTERVAL_MAX-INTERVAL_MIN
		div ebx
		mov eax,edx

		; 用新的x坐标更新lastobstaclex
		add @lastobstaclex,eax
		add @lastobstaclex,INTERVAL_MIN
		mov eax,@obstacle.p_image
		mov eax,[eax+Image.w]
		add @lastobstaclex,eax
		mov eax,@lastobstaclex

		;DEBUG 固定间隔
		;mov eax,WINDOW_WIDTH
		;add @lastobstaclex,eax
		;mov eax,@lastobstaclex


		; 初始化这个对象，并将其添加到绘制队列中
		RobjLoadx @obstacle,eax


		.if @obstacle.obj_id == OBJ_BIRD
			;如果是鸟需要添加随机高度
			invoke crt_rand
			xor edx,edx
			mov ebx, BIRD_HEIGHT_MAX-BIRD_HEIGHT_MIN
			div ebx
			mov eax,edx
			add eax,BIRD_HEIGHT_MIN
			add eax,HORIZON_HEIGHT
			RobjLoady @obstacle,eax

			;和相对速度
			fldI BIRD_VX
			fchs
			fld $state.global_vx
			faddp st(1),st
			fstp @obstacle.vx
		.else
			RobjLoady @obstacle,HORIZON_HEIGHT
			m2m @obstacle.vx,$state.global_vx
		.endif
		mov @obstacle.vy,0
		m2m @obstacle.lasttsp,@curtime

		mov @obstacle.z,0

		;将这个对象添加到绘制列表中
		invoke _add_render_object,addr @obstacle

		dec @remain
	.endw

	ret

_update_obstacles ENDP 

end