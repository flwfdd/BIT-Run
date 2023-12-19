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

extern $h_instance:dword ; ����ʵ�����
extern $h_window_main:dword ; �����ھ��
extern $state:GameState ; ��Ϸ״̬
extern $voice_input:dword ; ��˷�ģ�飺�Ƿ񵽴���ֵ

_get_image PROTO @id:DWORD ; ��ȡͼ��
_check_obj_in_window PROTO @p_obj:DWORD ; �������Ƿ��ڴ�����
_check_obj_overlap PROTO @p_obj1:DWORD, @p_obj2:DWORD ; ����ص�

; �Ի����б�Ĳ���
_init_render_list   PROTO @p_a_rlist:DWORD;��ʼ��
_add_render_object  PROTO @p_robj   :DWORD;�����󿽱���ӵ��б���
_update_render_list PROTO @isOver   :DWORD;���»����б��޳��Ѿ�����Ķ���

; ���»��ƶ�����һ��λ��
_update_render_object  PROTO @p_robj :DWORD;���»��ƶ���
_update_goose 	       PROTO @p_goose:DWORD;ר�Ÿ��´��


; �ڸ���״̬ʱ�����������ϰ���
_update_obstacles   PROTO 

.data

; DEBUG ��Ⱦ����
a_render_object_test RenderObject 10 dup (<>) ; ��Ⱦ��������
x_text dword 0

$state_jumping  dword 0;���Ƿ��Ϳ�
$state_keypress  word 0;��һ�μ�⵽�İ�������(word->SHORT)
$state_voiceinput  dword 0;��һ�μ�⵽�İ�������(word->SHORT)


FLOATSCONST1 REAL4 0.001
FLOATSCONST2 REAL4 0.5
.code


; �ڴ��ƶ���
m2m  MACRO M1,M2
	push M2
	pop  M1
ENDM


; ���ڿ��ٶ����ַ���DEBUG
szText MACRO Name, Text:VARARG
LOCAL lbl
	jmp lbl
	Name db Text,13,10,0
	lbl:
ENDM


; ��ʼ��״̬
_init_state PROC uses ecx
	local @Goose:RenderObject
	local @Bkg1:RenderObject
	local @Bkg2:RenderObject

	mov $state_jumping,0
	mov $state_keypress,0
	mov $state_voiceinput,0
	mov $state.score, 0
	mov $state.status,GAME_STATUS_INIT
	; ���� global vx
	fldI GINIT_VX
	fchs
	fstp $state.global_vx

	; ��������б��ڴ�
	mov $state.render_object_size,0
	mov eax, sizeof RenderObject
	mov ecx, RENDER_OBJ_SIZE
	mul ecx
	invoke crt_malloc,eax
	mov $state.p_a_render_object,eax
	
	; ��ʼ�������б�
	invoke _init_render_list, $state.p_a_render_object


	; ����һ����
	mov @Goose.obj_id,OBJ_GOOSE
	RobjLoadx @Goose,GOOSE_INITIAL_X
	RobjLoady @Goose,GOOSE_INITIAL_Y
	mov @Goose.z,0
	invoke _get_image, IMAGE_GOOSE_RUN0_ID
	mov @Goose.p_image,eax
	mov @Goose.vx,0
	mov @Goose.vy,0
	m2m  @Goose.lasttsp,$state.time

	;������������ѭ������
	;����1
	mov @Bkg1.obj_id,OBJ_BKG
	RobjLoadx @Bkg1,0
	RobjLoady @Bkg1,0
	mov @Bkg1.z,2
	invoke _get_image, IMAGE_BACKGROUND_ID
	mov @Bkg1.p_image,eax
	m2m @Bkg1.vx,$state.global_vx
	mov @Bkg1.vy,0
	m2m @Bkg1.lasttsp,$state.time

	;����2
	mov @Bkg2.obj_id,OBJ_BKG
	RobjLoadx @Bkg2,WINDOW_WIDTH
	RobjLoady @Bkg2,0
	mov @Bkg2.z,2
	invoke _get_image, IMAGE_BACKGROUND_ID
	mov @Bkg2.p_image,eax
	m2m @Bkg2.vx,$state.global_vx
	mov @Bkg2.vy,0
	m2m @Bkg2.lasttsp,$state.time


	; �����������ı���������뵽�����б���
	invoke _add_render_object, addr @Goose
	invoke _add_render_object, addr @Bkg1
	invoke _add_render_object, addr @Bkg2

	ret
_init_state ENDP

; ����״̬
_reset_state PROC
	invoke crt_free,$state.p_a_render_object
	invoke _init_state
_reset_state ENDP

; ͳһ���ƶ������ʱ��
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

; ����״̬
_state_update PROC uses ebx esi
	local @collide


	mov @collide,0
	mov ebx,0
	.if $state.status!=GAME_STATUS_RUN
		ret
	.endif

	; ����������еĶ����˶�״̬�������������ײ����ֹ
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

	; �����Ƿ�����ײ���»����б�
	invoke _update_render_list,@collide

	; ���ݻ���״̬�����Ļ��׼�����ֵ��ϰ���
	invoke _update_obstacles
	
 	ret
_state_update ENDP

; ��鰴��
_check_key_down PROC uses ecx edi edx
	local @keystate:word
	invoke GetAsyncKeyState, VK_SPACE
	mov  @keystate,ax
	.if $voice_input || ax != 0
		;DEBUG
		;szText debugstr1,"detect key pressed"
		;invoke crt_printf,addr debugstr1

		; ��������׶ΰ��¿ո��״̬����
		.if $state.status == GAME_STATUS_INIT
			mov $state.status,GAME_STATUS_RUN
			invoke _start_state
		.endif

		.if $state.status == GAME_STATUS_INIT || $state.status == GAME_STATUS_RUN


			.if $state_jumping ==0 
				mov $state_jumping,1

				;���������б��ҵ���
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


; �Ի����б�Ĳ���
; ��ʼ�������б�
_init_render_list PROC uses ecx @p_a_rlist:DWORD

	mov eax, sizeof RenderObject
	mov ecx, RENDER_OBJ_SIZE
	mul ecx
	invoke RtlZeroMemory,@p_a_rlist,eax
	ret
_init_render_list ENDP

; ���»����б�
_update_render_list PROC uses ecx @isOver:DWORD
	local @pOldL: dword  
	local @pNewL: dword
	local @oldsize:dword   ;�����б�Ĵ�С
	mov @pNewL,0
	mov ecx,$state.p_a_render_object
	mov @pOldL,ecx

	mov ecx,$state.render_object_size
	mov @oldsize,ecx

	.if @isOver
		;��������Ͻ���������ƵĴ��루����ͼ���add_render_obj���ɣ�

	.endif

	;����Ƿ��г���Ļ��ƶ��������������б�
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

	;��û�г������Ʒ���뵽�µĻ����б���
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


; �����Ǹ���$state.p_a_render_object ������ӵ�
_add_render_object PROC uses ecx edi esi @p_robj:DWORD
	mov ecx,0
	mov edi,$state.p_a_render_object

	.while ecx!=RENDER_OBJ_SIZE
		.if [edi + RenderObject.obj_id] == 0
			;���ﲻ֪��Ϊɶ���Ӳ��Ͽ�����������rep����һ��
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


; �Ի��ƶ���ĸ��²���

; �����ײ�򷵻�1������Ϊ0
_update_render_object PROC uses esi ecx  @p_robj:DWORD
	local @deltat:DWORD ; �����ĺ���
	local @fdeltat:REAL4
	local @oldprecise:WORD  ; ��ʱ�洢�����������֣������������
	local @newprecise:WORD  ;

	mov esi,@p_robj
	.if [esi+RenderObject.obj_id] == OBJ_GOOSE
		; ��ר�Ŵ���
		invoke _update_goose,@p_robj
		ret
	.else
		; ���������һ�λ��ƾ����˶��ٺ���
		push $state.time
		pop @deltat
		mov ecx,[esi+RenderObject.lasttsp]
		sub @deltat,ecx

		finit
		fild @deltat
		fld  FLOATSCONST1
		fmulp st(1),st
		fstp @fdeltat

		;������������
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

		;�����������굽��������
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

	;����ѭ������ͼ
	.if [esi+RenderObject.obj_id] == OBJ_BKG
		mov eax,[esi+RenderObject.x]
		mov ecx,[esi+RenderObject.p_image]
		mov ecx,[ecx+Image.w]
		add eax,ecx
		;.if eax <= 0 masm .if��֧���з��űȽ�
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
		;������ĳ��
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
	local @deltat:DWORD ; �����ĺ���
	local @fdeltat:REAL4
	local @accer:REAL4  ; ��ļ��ٶ�
	local @iscollide
	local @oldprecise:WORD  ; ��ʱ�洢�����������֣������������
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

		; ���������һ�λ��ƾ����˶��ٺ���
		push $state.time
		pop @deltat
		mov ecx,[esi+RenderObject.lasttsp]
		sub @deltat,ecx

		finit
		fild @deltat
		fld  FLOATSCONST1
		fmulp st(1),st
		fstp @fdeltat

		; ���ؼ��ٶ�
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

		;�������һʱ�κ��λ�����ٶ�
		;λ�ü���
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
		
		;�ٶȼ���
		fld [esi+RenderObject.vy]
		fld @accer
		fmul @fdeltat
		fsubp st(1),st
		fstp [esi+RenderObject.vy]

		;����������ȡ����Ϊ��������
		fld [esi+RenderObject.phsy]
		fnstcw @oldprecise
		movzx eax,@oldprecise
		or ah,12
		mov @newprecise,ax
		fldcw @newprecise
		fistp [esi+RenderObject.y]
		fldcw @oldprecise

		;������º����������С��ˮƽ�߸߶ȣ������ö��״̬
		fld [esi+RenderObject.phsy]
		mov eax,HORIZON_HEIGHT
		push eax
		fild dword ptr [esp]
		pop eax
		fcomip st,st(1)
		fstp st(0)
		jb @label1_u_g

		;С�ڸ߶ȵ��������
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
			;szText debugstr,"collide" ���������ӡ����bug��֪��Ϊɶ,������ʹ����ecx�ȼĴ���
			;invoke crt_printf,addr debugstr
		.endif
		inc ecx
		add esi, sizeof RenderObject
	.endw


	mov eax,@iscollide
	ret

_update_goose ENDP



; ���ƶ������

_update_obstacles PROC uses ecx esi edx ebx
	local @cloud:RenderObject		; ����ӵ���
	local @lastcloudx:dword			; �����Ƶ�x����
	local @ncloud:dword				; �����б����Ƶ�����
	local @obstacle:RenderObject    ; ����ӵ��ϰ���
	local @lastobstaclex:dword		; �����ϰ���x����
	local @curtime:dword			; ��ǰʱ�䣬����ͳһʱ���
	local @remain:dword				; ʣ��Ŀռ�

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

	; ���������������ƣ������һ���µ��� 
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
	; ���û���ҵ��ƣ���lastcloudx����ΪWINDOW_WIDTH
	.if @lastcloudx == 0
		mov @lastcloudx,WINDOW_WIDTH
	.endif

	; ����������4����
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


	; ���ҵ����������ϰ��������
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
			; �������ϰ����ڴ����ڣ������lastobstaclex
			.if eax > @lastobstaclex
				mov @lastobstaclex,eax
			.endif
		@label2_u_o:

		add esi, sizeof RenderObject
		dec edx
	.endw

	; ���û���ҵ��ϰ����lastobstaclex����ΪWINDOW_WIDTH
	.if @lastobstaclex == 0
		mov @lastobstaclex,WINDOW_WIDTH
	.endif


	
	; ����ӵ��ϰ���
	.while @remain != 0
		; �������һ������ID,��ȡ���ӦͼƬ
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

		; �������һ���µ�x����
		invoke crt_rand
		xor edx,edx
		mov ebx, INTERVAL_MAX-INTERVAL_MIN
		div ebx
		mov eax,edx

		; ���µ�x�������lastobstaclex
		add @lastobstaclex,eax
		add @lastobstaclex,INTERVAL_MIN
		mov eax,@obstacle.p_image
		mov eax,[eax+Image.w]
		add @lastobstaclex,eax
		mov eax,@lastobstaclex

		;DEBUG �̶����
		;mov eax,WINDOW_WIDTH
		;add @lastobstaclex,eax
		;mov eax,@lastobstaclex


		; ��ʼ��������󣬲�������ӵ����ƶ�����
		RobjLoadx @obstacle,eax


		.if @obstacle.obj_id == OBJ_BIRD
			;���������Ҫ�������߶�
			invoke crt_rand
			xor edx,edx
			mov ebx, BIRD_HEIGHT_MAX-BIRD_HEIGHT_MIN
			div ebx
			mov eax,edx
			add eax,BIRD_HEIGHT_MIN
			add eax,HORIZON_HEIGHT
			RobjLoady @obstacle,eax

			;������ٶ�
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

		;�����������ӵ������б���
		invoke _add_render_object,addr @obstacle

		dec @remain
	.endw

	ret

_update_obstacles ENDP 

end