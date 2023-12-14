# BIT-Run

## 代码规范

命名规范：
* 常量全部大写，单词之间用下划线分隔
* 字符串常量以`S_`开头
* 变量全部小写，单词之间用下划线分隔
* 全局变量以`$`开头
* 局部变量以`@`开头
* 函数名以`_`开头
* 句柄变量以`h_`开头
* 数组变量以`a_`开头


## 整体流程

主线程运行流程：
1. `_main_window`创建主窗口，进入消息循环。
2. `_main_window_proc`处理主窗口事件。
3. `_init`负责处理窗口初始化事件。
4. `_key_down`负责处理窗口处理键盘事件。
5. `_close`负责处理窗口关闭事件。

绘制过程主要由三个线程合作完成：
1. `_refresh_interval_thread`负责按照设定好的帧率发送`h_draw_buffer_event`事件
2. `_draw_buffer_thread`负责处理`h_draw_buffer_event`事件，将绘制结果保存到`buffer_index`中
