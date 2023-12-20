# 北理润 - BITRun

## 环境配置

开发使用`Visual Studio 2022`，安装时选择C++套件，需要勾选依赖`MSVC v140`（高版本不兼容），默认勾选的除了`Windows SDK`外都可以不勾选以节省空间。更改代码后可能需要重新生成解决方案再运行。

另外还需要安装`MASM32`，前往官网下载安装包：[http://www.masm32.com/download.htm](http://www.masm32.com/download.htm)。安装时选择安装到`C:\masm32`，如果安装到其他目录需要在项目属性中对应修改。

项目属性中几个更改的地方：

* 在项目目录上右键，选择“属性”，在常规面板中更改“平台工具集”为`Visual Studio 2015 (v140)`，并更改“Windows SDK版本”为安装的具体版本。

* 更改“链接器”、“常规”中的“附加库目录”为`C:\masm32\lib;%(AdditionalLibraryDirectories)`。

* 更改“Microsoft Macro Assembler”、“General”中的“Inlude Paths”为`C:\masm32\include`。

* 在“连接器”、“系统”中更改“子系统”可以切换是否显示控制台窗口。

注意在配置属性和运行时都要选择`Win32`或`x86`，不要出现`x64`。

## 代码规范

命名规范：
* 常量全部大写，单词之间用下划线分隔。
* 字符串常量以`S_`开头。
* 变量全部小写，单词之间用下划线分隔。
* 全局变量以`$`开头。
* 局部变量以`@`开头。
* 函数名以`_`开头。
* 句柄变量以`h_`开头。
* 指针变量以`p_`开头，与句柄变量的区别是指针变量指向的是内存地址，而句柄变量则不一定。
* 数组变量以`a_`开头，后面指示了元素的类型，例如指针组成的数组以`a_p_`开头。


## 整体流程

主线程运行流程：
1. `_main_window`创建主窗口，进入消息循环。
2. `_main_window_proc`处理主窗口事件。
3. `_init`负责处理窗口初始化事件。
4. `_check_key_down`负责处理窗口处理键盘事件。
5. `_close`负责处理窗口关闭事件。

绘制过程主要由三个线程合作完成：
1. `_refresh_interval_thread`负责按照设定好的帧率发送`p_render_buffer_event`事件。
2. `_render_buffer_thread`负责处理`p_render_buffer_event`事件，将绘制结果保存到`buffer_index`中，然后发送`p_render_window_event`事件。
3. `_render_window_thread`负责处理`p_render_window_event`事件，将`buffer_index`中的绘制结果同步到窗口中。

