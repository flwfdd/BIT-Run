.386
.model flat, stdcall
option casemap: none

; ������Ҫ��ͷ�ļ��Ϳ��ļ�
include windows.inc
include kernel32.inc
include user32.inc
include msvcrt.inc
include winmm.inc
include bitrun.inc
includelib kernel32.lib
includelib user32.lib
includelib msvcrt.lib
includelib winmm.lib

public $voice_input

.data
    ; ���з�
    endl equ         <0DH,0AH,0>
    ; ��Ƶ�������
$hWaveIn dword  ?                                                                          ; wave ���
$pBuffer dword  ?                                                                          ; ������ָ��
$wHdr WAVEHDR <>                                                                           ; ������Ƶ�������ı�ͷ
$waveform WAVEFORMATEX <>                                                                  ; ����һ�� WAVEFORMATEX �ṹ����������ڴ洢�ɼ���Ƶ�ĸ�ʽ
$bStop dword 0                                                                             ; ֪ͨ��Ƶ�����ص��ѽ���
$voice_input dword 0                                                                       ; ��˷�ģ�飺�Ƿ񵽴���ֵ

    ; ������
         prompt      byte   "Press any key to start recording and 'q' to quit...", endl
         recording   byte   "Recording... Press 'q' to stop.", endl
         newline     byte   endl
         depoint     byte   "#", 0
         szFmtStr    byte "%s",0
         szFmtDevNum byte "Input device num: %d",endl
         szOpen      byte "Device open...",endl
         szData      byte "Buffer is full...",endl
         szClose     byte "Device close...",endl
         szDBVal     byte "volume sum: %d", endl
         szbJump     byte "$voice_input: %d", endl
         startTime   DWORD 0
         endTime     DWORD 0
         elapsedTime DWORD 0
    ; ��ʽ���ַ���
         timeFormat  byte  "Time proc use: %u ms", endl


.code

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
                        invoke crt_printf, offset szFmtStr, offset szOpen
.elseif uMsg == WIM_CLOSE
                        invoke crt_printf, offset szFmtStr, offset szClose
.elseif uMsg == WIM_DATA
                        cmp    $bStop, 1
                        je     @end
                        invoke _micro_get_volume, $wHdr.lpData , $wHdr.dwBytesRecorded
.if eax >= DBTHRESHOLD
                        mov    $voice_input, 1
                        invoke crt_printf, offset szbJump, $voice_input
    ; ��� volsum
    ;  invoke crt_printf, offset szDBVal, eax
.else
         invoke crt_printf, offset szFmtStr, offset depoint
         mov    $voice_input, 0
.endif
    ; ���뻺�����
    ;  invoke crt_printf, offset szFmtStr, offset szData
          invoke waveInAddBuffer, hwi, dwParam1, sizeof WAVEHDR
.endif
    ; ��ȡ�������ʱ��
                        invoke GetTickCount
                        mov    endTime, eax

    ; ����ִ��ʱ���ֵ
                        sub    eax, startTime
                        mov    elapsedTime, eax

    ; ��ӡִ��ʱ��
    ;  invoke crt_printf, OFFSET timeFormat,  elapsedTime
    ; ���¼�ʱ
                        invoke GetTickCount
                        mov    startTime, eax
@end:
                        ret
_change_voice_state ENDP


    ; ¼���̺߳���
_record_thread PROC
                        push   ebp
                        mov    ebp, esp

    ; ��ȡ����ʼʱ��
                        invoke GetTickCount
                        mov    startTime, eax

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
_free_micro PROC
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
_init_micro PROC
    ; ��ʼ��WAVEFORMATEX�ṹ��
                mov    $waveform.wFormatTag,      WAVE_FORMAT_PCM                       ; ������Ƶ��ʽ��ǩΪPCM
                mov    $waveform.nChannels,       1                                     ; ����������Ϊ1����������
                mov    $waveform.nSamplesPerSec,  44100                                 ; ���ò�����Ϊ 44100 Hz
                mov    $waveform.nAvgBytesPerSec, 88200                                 ; ����ƽ�����ݴ������ʣ�ÿ���ֽ�����
                mov    $waveform.nBlockAlign,     2                                     ; �������ݿ�����С 8*1/8
                mov    $waveform.wBitsPerSample,  16                                    ; ����ÿ��������λ��
                mov    $waveform.cbSize,          0                                     ; ���ø�����Ϣ�Ĵ�С

    ; ��ʾ��ʾ��Ϣ
                invoke crt_printf, offset szFmtStr, offset prompt
    ; �����豸����
                invoke waveInGetNumDevs
                invoke crt_printf, offset szFmtDevNum, eax
.if eax == 0
                invoke crt_exit
.endif

    ; ����¼���߳�
                invoke CreateThread, NULL, 0, _record_thread, NULL, 0, NULL
                ret
_init_micro ENDP

END