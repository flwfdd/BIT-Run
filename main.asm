.386
.model flat,stdcall
option casemap:none

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

include     bitrun.inc

; ��Ⱦģ��
_init_render PROTO ; ��ʼ����Ⱦģ��
_free_render PROTO ; �ͷ���Ⱦģ��
_render_buffer PROTO ; ��Ⱦ������
_render_window PROTO ; ��Ⱦ������������

; ״̬ģ��
_init_state   PROTO ; ��ʼ��״̬ģ��
_state_update PROTO ; ״̬����
_check_key_down PROTO;��ⰴ��������״̬

public $h_instance, $h_window_main, $state, $voice_input

.const
S_MAIN_WINDOW_TITLE byte '������ - BITRun', 0 ; �����ڱ���
S_MAIN_CLASS_NAME byte 'main_window_class', 0 ; ����������

.data

.data?
$h_instance dword ? ; ����ʵ�����
$h_window_main dword ? ; �����ھ��

$state GameState <> ; ��Ϸ״̬

$thread_live dword ? ; �̴߳���־ Ϊ0ʱ�߳��˳�
$p_render_buffer_event dword ? ; ֪ͨ���ƻ�����
$p_render_window_event dword ? ; ֪ͨ�ӻ�����ͬ��������

; ��Ƶ�������
$hWaveIn dword  ? ; wave ���
$pBuffer dword  ? ; ������ָ��
$wHdr WAVEHDR <> ; ������Ƶ�������ı�ͷ
$waveform WAVEFORMATEX <>    ; ����һ�� WAVEFORMATEX �ṹ����������ڴ洢�ɼ���Ƶ�ĸ�ʽ

$bStop dword 0     ; ֪ͨ��Ƶ�����ص��ѽ���
$voice_input dword 0    ; ��˷�ģ�飺�Ƿ񵽴���ֵ

.code

; ���ڿ��ٶ����ַ���
szText MACRO Name, Text:VARARG
LOCAL lbl
	jmp lbl
	Name db Text,13,10,0
	lbl:
ENDM



; ֡ʱ���źŲ����߳�
_refresh_interval_thread PROC 
    local @freq:QWORD ; ʱ��Ƶ��
    local @time0:QWORD, @time1:QWORD ; ʱ��
    local @last_us:DWORD ; ��һ�ε�ʱ�� ��λ΢��
    local @1m:DWORD ; ����1000000 ���ڼ���΢��
    mov @1m, 1000000
    mov @last_us, 0
    invoke QueryPerformanceFrequency, addr @freq ; ��ȡʱ��Ƶ��
    invoke QueryPerformanceCounter, addr @time0 ; ��ȡ��ʼʱ��
    finit
    .while $thread_live == 1
        ; ����ʱ���
        invoke QueryPerformanceCounter,addr @time1
        mov eax, dword ptr @time0
        mov edx, dword ptr @time0+4
        sub dword ptr @time1, eax
        sbb dword ptr @time1+4, edx
        fild @time1 ; ��������ֵ
        fimul @1m ; ���Ե�λƵ��
        fild @freq ; ����Ƶ�� �õ��Ե�λƵ��Ϊ��λ��ʱ���
        fdiv
        fistp @time1 ; ��ʼ�����ڵ�ʱ���

        ; ������һ֡ʱ��
        mov eax, @last_us
        add eax, 1000000/FPS

        .if eax > dword ptr @time1
            ; ʱ��δ��
			sub eax, dword ptr @time1
			;invoke Sleep, eax
        .else
            ; DEBUG ÿ�����ڴ�ӡһ��.
            invoke crt_putchar, '.'

            ; ����ʱ��
            mov eax, dword ptr @time1
            mov @last_us, eax

            ; ��ⰴ������
            invoke _check_key_down

            ; ֪ͨ��Ⱦ������
            invoke SetEvent, $p_render_buffer_event
        .endif

    .endw
    ret
_refresh_interval_thread ENDP


; ��Ⱦ�������߳�
_render_buffer_thread PROC
    local @freq:QWORD ; ʱ��Ƶ��
    local @time0:QWORD, @time1:QWORD ; ʱ��
    local @1k:DWORD ; ����1000 ���ڼ������
    mov @1k, 1000
    invoke QueryPerformanceFrequency, addr @freq ; ��ȡʱ��Ƶ��
    invoke QueryPerformanceCounter, addr @time0 ; ��ȡ��ʼʱ��
    finit
    .while $thread_live != 0
        ; �¼�ͬ��
        invoke WaitForSingleObject, $p_render_buffer_event, INFINITE
        invoke ResetEvent, $p_render_buffer_event

        ; ����ʱ��
        invoke QueryPerformanceCounter,addr @time1
        mov eax, dword ptr @time0
        mov edx, dword ptr @time0+4
        sub dword ptr @time1, eax
        sbb dword ptr @time1+4, edx
        fild @time1 ; ��������ֵ
        fimul @1k ; ���Ե�λƵ��
        fild @freq ; ����Ƶ�� �õ��Ե�λƵ��Ϊ��λ��ʱ���
        fdiv
        fistp @time1 ; ��ʼ�����ڵ�ʱ���
        mov eax, dword ptr @time1
        mov $state.time, eax
        

        ; ״̬����
        invoke _state_update

        ; ��Ⱦ
        invoke _render_buffer

        ; ֪ͨͬ��������
        invoke SetEvent, $p_render_window_event
    .endw
    ret
        
_render_buffer_thread ENDP

; ͬ���������������߳�
_render_window_thread PROC

    .while $thread_live != 0
        ; �������ջ���ˢ�±�־Ϊ0ʱ�ȴ�
        invoke WaitForSingleObject, $p_render_window_event, INFINITE
        invoke ResetEvent, $p_render_window_event

        ; ��Ⱦ������������
        invoke _render_window
    .endw
    ret
_render_window_thread ENDP

    ; ������Ƶ�������е�������
_micro_get_volume PROC uses ecx edx, pcmdata: ptr byte, len: dword
    local  dbVal:dword
    local  value:word
    local  sum:dword
    local  i:dword
    local  decible:dword

    mov    dbVal, 0
    mov    sum, 0
    mov    i, 0
    mov    value, 0
    mov    decible, 0

    ; ����ѭ��
    mov    ecx, len
    shr    ecx, 1                                                     ; ����2����Ϊÿ�ε���2
    mov    esi, pcmdata
    mov    edi, 0

    L_LOOP:             
    cmp    i, ecx
    jae    L_END

    ; ����1���ֽڵ�����
    mov    ax, word ptr [esi]
    mov    value, ax

    ; �����ֵ���ۼӵ�sum
    movsx  eax, value
    cdq
    ;   abs(x) = (x XOR y) - y        y = x >>> 31
    xor    eax, edx
    sub    eax, edx
    add    sum, eax

    ; ����ѭ������
    add    esi, 2
    inc    i
    jmp    L_LOOP

L_END:              
    ret

_micro_get_volume ENDP

    ; �ص�����������Ƶ
_change_voice_state PROC ,hwi: dword, uMsg: dword, dwInstance: ptr dword, dwParam1: ptr dword, dwParam2: ptr dword

    .if uMsg == WIM_OPEN
        ;invoke crt_printf, offset szFmtStr, offset szOpen
    .elseif uMsg == WIM_CLOSE
        ;invoke crt_printf, offset szFmtStr, offset szClose
    .elseif uMsg == WIM_DATA
        cmp    $bStop, 1
        je     @end
        invoke _micro_get_volume, $wHdr.lpData , $wHdr.dwBytesRecorded
        .if eax >= DBTHRESHOLD
            mov    $voice_input, 1
            ; invoke crt_printf, offset szbJump, $voice_input
            ; ��� volsum
            ;  invoke crt_printf, offset szDBVal, eax
        .else
            ;invoke crt_printf, offset szFmtStr, offset depoint
            mov    $voice_input, 0
        .endif
        ; ���뻺�����
        ;  invoke crt_printf, offset szFmtStr, offset szData
        invoke waveInAddBuffer, hwi, dwParam1, sizeof WAVEHDR
.endif
    ; ��ȡ�������ʱ��
    ; invoke GetTickCount
    ; mov    endTime, eax

    ; ����ִ��ʱ���ֵ
    ; sub    eax, startTime
    ; mov    elapsedTime, eax

    ; ��ӡִ��ʱ��
    ;  invoke crt_printf, OFFSET timeFormat,  elapsedTime
    ; ���¼�ʱ
    ; invoke GetTickCount
    ; mov    startTime, eax
@end:
    ret
_change_voice_state ENDP

    ; ¼���̺߳���
_record_thread PROC
    push   ebp
    mov    ebp, esp

    ; ��ȡ����ʼʱ��
    ; invoke GetTickCount
    ; mov    startTime, eax

    ; ��Ĭ����Ƶ�����豸
    invoke waveInOpen, offset $hWaveIn, WAVE_MAPPER, offset $waveform, _change_voice_state, 0, CALLBACK_FUNCTION

    ; ������Ƶ������
    invoke GetProcessHeap
    invoke HeapAlloc, eax, HEAP_ZERO_MEMORY, VOICEBUFFER_SIZE
    ;  mov    $pBuffer, eax

    ; ���� WAVEHDR �ṹ
    mov    $wHdr.lpData, eax
    mov    $wHdr.dwBufferLength, VOICEBUFFER_SIZE
    mov    $wHdr.dwBytesRecorded, 0
    mov    $wHdr.dwUser, 0
    mov    $wHdr.dwFlags, 0
    mov    $wHdr.dwLoops, 1

    ; ����¼��������
    invoke waveInPrepareHeader, $hWaveIn, offset $wHdr, sizeof WAVEHDR
                

    ; ��ʼ¼��
    invoke waveInAddBuffer, $hWaveIn, offset $wHdr, sizeof WAVEHDR
    invoke waveInStart, $hWaveIn
    ; ˯�� 10 s debug
    ;  invoke Sleep, 10000
    ;  mov    $bStop, 1
    ;  invoke crt_printf, offset szFmtStr, offset depoint
    pop    ebp
    ret
_record_thread ENDP

    ; �ͷ�¼����Դ
_free_micro PROC C
    ; ֹͣ¼��
    mov    $bStop, 1
    invoke waveInStop, $hWaveIn
    invoke waveInReset, $hWaveIn

    .if eax != MMSYSERR_NOERROR
        invoke crt_exit
    .endif

    ; ������Դ
    ; �ͷ���Ƶ������
    invoke waveInUnprepareHeader, $hWaveIn, offset $wHdr, sizeof WAVEHDR
    invoke GetProcessHeap
    invoke HeapFree, eax, 0, $pBuffer
    invoke waveInClose, $hWaveIn
    ret
_free_micro ENDP

    ; ��ʼ��¼��
_init_micro PROC C
    ; ��ʼ��WAVEFORMATEX�ṹ��
    mov    $waveform.wFormatTag,      WAVE_FORMAT_PCM                       ; ������Ƶ��ʽ��ǩΪPCM
    mov    $waveform.nChannels,       1                                     ; ����������Ϊ1����������
    mov    $waveform.nSamplesPerSec,  44100                                 ; ���ò�����Ϊ 44100 Hz
    mov    $waveform.nAvgBytesPerSec, 88200                                 ; ����ƽ�����ݴ������ʣ�ÿ���ֽ�����
    mov    $waveform.nBlockAlign,     2                                     ; �������ݿ�����С 8*1/8
    mov    $waveform.wBitsPerSample,  16                                    ; ����ÿ��������λ��
    mov    $waveform.cbSize,          0                                     ; ���ø�����Ϣ�Ĵ�С

    ; ��ʾ��ʾ��Ϣ
    ;invoke crt_printf, offset szFmtStr, offset prompt
    ; �����豸����
    invoke waveInGetNumDevs
    ;invoke crt_printf, offset szFmtDevNum, eax
.if eax == 0
    invoke crt_exit
.endif

    ; ����¼���߳�
    invoke CreateThread, NULL, 0, _record_thread, NULL, 0, NULL
    ret
_init_micro ENDP


; ��ʼ���ص�
_init PROC
    ; ��ʼ���¼�
    invoke CreateEvent, NULL, TRUE, FALSE, NULL
    mov $p_render_buffer_event, eax
    invoke CreateEvent, NULL, TRUE, FALSE, NULL
    mov $p_render_window_event, eax

    ; ��ʼ����Ⱦģ��
    invoke _init_render
    ; ��ʼ����Ϸ״̬
    invoke _init_state
    ; ��ʼ����˷�����ģ��
    invoke _init_micro

    ; �����߳�
    mov $thread_live, 1
    invoke CreateThread, NULL, 0, _refresh_interval_thread, NULL , 0, NULL
    invoke CreateThread, NULL, 0, _render_buffer_thread, NULL, 0, NULL
    invoke CreateThread, NULL, 0, _render_window_thread, NULL, 0, NULL
    ret
_init ENDP


; �رջص�
_close PROC
    ; �ر��߳�
    mov $thread_live, 0

    ; �ͷ���Ⱦģ��
    invoke _free_render

    ; �ͷ���˷�ģ��
    invoke _free_micro

    ; ������Ҫһ���ͷ�״̬��

    ; �ͷ��¼�
    invoke CloseHandle, $p_render_window_event
    invoke CloseHandle, $p_render_buffer_event

    ; �رմ���
    invoke DestroyWindow, $h_window_main
    invoke PostQuitMessage, NULL

    ret
_close ENDP


; �����ڻص�
_main_window_proc PROC @h_instance, @msg, @wParam, @lParam
    mov eax, @msg
    .if eax == WM_CREATE
        invoke _init
    .elseif eax == WM_CLOSE
        invoke _close
    .else
        invoke DefWindowProc, @h_instance, @msg, @wParam, @lParam
        ret
    .endif

    xor eax, eax
    ret
_main_window_proc ENDP

; ������
_main_window PROC 
    local @window_class:WNDCLASSEX
    local @rect:RECT
    local @msg:MSG

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

    mov @rect.left, 0
    mov @rect.top, 0
    mov @rect.right, WINDOW_WIDTH
    mov @rect.bottom, WINDOW_HEIGHT
    invoke AdjustWindowRect, addr @rect, WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX, FALSE
    mov eax, @rect.right
    sub eax, @rect.left
    mov ebx, @rect.bottom
    sub ebx, @rect.top

    invoke CreateWindowEx, 0, offset S_MAIN_CLASS_NAME, offset S_MAIN_WINDOW_TITLE, WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX, CW_USEDEFAULT, CW_USEDEFAULT, eax, ebx, NULL, NULL, $h_instance, NULL
    mov $h_window_main, eax
    invoke ShowWindow, $h_window_main, SW_SHOWNORMAL
    invoke UpdateWindow, $h_window_main

    .while TRUE
        invoke GetMessage, addr @msg, NULL, 0, 0
        .break .if eax == 0
        invoke TranslateMessage, addr @msg
        invoke DispatchMessage, addr @msg
    .endw

    ret
_main_window ENDP


start:
    invoke _main_window 
    invoke ExitProcess, NULL
    ret
end start