.386
.model flat, stdcall
option casemap: none

; 包含必要的头文件和库文件
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
    ; 换行符
    endl equ         <0DH,0AH,0>
    ; 音频处理相关
$hWaveIn dword  ?                                                                          ; wave 句柄
$pBuffer dword  ?                                                                          ; 缓冲区指针
$wHdr WAVEHDR <>                                                                           ; 波形音频缓冲区的标头
$waveform WAVEFORMATEX <>                                                                  ; 定义一个 WAVEFORMATEX 结构体变量，用于存储采集音频的格式
$bStop dword 0                                                                             ; 通知音频处理回调已结束
$voice_input dword 0                                                                       ; 麦克风模块：是否到达阈值

    ; 调试用
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
    ; 格式化字符串
         timeFormat  byte  "Time proc use: %u ms", endl


.code

    ; 计算音频缓冲区中的总音量
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

    ; 进入循环
                        mov    ecx, len
                        shr    ecx, 1                                                     ; 除以2，因为每次递增2
                        mov    esi, pcmdata
                        mov    edi, 0

    L_LOOP:             
                        cmp    i, ecx
                        jae    L_END

    ; 复制1个字节的数据
                        mov    ax, word ptr [esi]
                        mov    value, ax

    ; 求绝对值并累加到sum
                        movsx  eax, value
                        cdq
    ;   abs(x) = (x XOR y) - y        y = x >>> 31
                        xor    eax, edx
                        sub    eax, edx
                        add    sum, eax

    ; 更新循环索引
                        add    esi, 2
                        inc    i
                        jmp    L_LOOP

    L_END:              
                        ret

_micro_get_volume ENDP


    ; 回调函数处理音频
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
    ; 检查 volsum
    ;  invoke crt_printf, offset szDBVal, eax
.else
         invoke crt_printf, offset szFmtStr, offset depoint
         mov    $voice_input, 0
.endif
    ; 加入缓存继续
    ;  invoke crt_printf, offset szFmtStr, offset szData
          invoke waveInAddBuffer, hwi, dwParam1, sizeof WAVEHDR
.endif
    ; 获取程序结束时间
                        invoke GetTickCount
                        mov    endTime, eax

    ; 计算执行时间差值
                        sub    eax, startTime
                        mov    elapsedTime, eax

    ; 打印执行时间
    ;  invoke crt_printf, OFFSET timeFormat,  elapsedTime
    ; 重新计时
                        invoke GetTickCount
                        mov    startTime, eax
@end:
                        ret
_change_voice_state ENDP


    ; 录音线程函数
_record_thread PROC
                        push   ebp
                        mov    ebp, esp

    ; 获取程序开始时间
                        invoke GetTickCount
                        mov    startTime, eax

    ; 打开默认音频输入设备
                        invoke waveInOpen, offset $hWaveIn, WAVE_MAPPER, offset $waveform, _change_voice_state, 0, CALLBACK_FUNCTION

    ; 分配音频缓冲区
                        invoke GetProcessHeap
                        invoke HeapAlloc, eax, HEAP_ZERO_MEMORY, VOICEBUFFER_SIZE
    ;  mov    $pBuffer, eax

    ; 配置 WAVEHDR 结构
                        mov    $wHdr.lpData, eax
                        mov    $wHdr.dwBufferLength, VOICEBUFFER_SIZE
                        mov    $wHdr.dwBytesRecorded, 0
                        mov    $wHdr.dwUser, 0
                        mov    $wHdr.dwFlags, 0
                        mov    $wHdr.dwLoops, 1

    ; 创建录音缓冲区
                        invoke waveInPrepareHeader, $hWaveIn, offset $wHdr, sizeof WAVEHDR
                

    ; 开始录音
                        invoke waveInAddBuffer, $hWaveIn, offset $wHdr, sizeof WAVEHDR
                        invoke waveInStart, $hWaveIn
    ; 睡眠 10 s debug
    ;  invoke Sleep, 10000
    ;  mov    $bStop, 1
    ;  invoke crt_printf, offset szFmtStr, offset depoint
                        pop    ebp
                        ret
_record_thread ENDP

    ; 释放录音资源
_free_micro PROC
    ; 停止录音
                        mov    $bStop, 1
                        invoke waveInStop, $hWaveIn
                        invoke waveInReset, $hWaveIn

.if eax != MMSYSERR_NOERROR
                        invoke crt_exit
.endif

    ; 清理资源
    ; 释放音频缓冲区
                invoke waveInUnprepareHeader, $hWaveIn, offset $wHdr, sizeof WAVEHDR
                invoke GetProcessHeap
                invoke HeapFree, eax, 0, $pBuffer
                invoke waveInClose, $hWaveIn
                ret
_free_micro ENDP

    ; 初始化录音
_init_micro PROC
    ; 初始化WAVEFORMATEX结构体
                mov    $waveform.wFormatTag,      WAVE_FORMAT_PCM                       ; 设置音频格式标签为PCM
                mov    $waveform.nChannels,       1                                     ; 设置声道数为1（单声道）
                mov    $waveform.nSamplesPerSec,  44100                                 ; 设置采样率为 44100 Hz
                mov    $waveform.nAvgBytesPerSec, 88200                                 ; 设置平均数据传输速率（每秒字节数）
                mov    $waveform.nBlockAlign,     2                                     ; 设置数据块对齐大小 8*1/8
                mov    $waveform.wBitsPerSample,  16                                    ; 设置每个采样的位数
                mov    $waveform.cbSize,          0                                     ; 设置附加信息的大小

    ; 显示提示信息
                invoke crt_printf, offset szFmtStr, offset prompt
    ; 输入设备个数
                invoke waveInGetNumDevs
                invoke crt_printf, offset szFmtDevNum, eax
.if eax == 0
                invoke crt_exit
.endif

    ; 创建录音线程
                invoke CreateThread, NULL, 0, _record_thread, NULL, 0, NULL
                ret
_init_micro ENDP

END