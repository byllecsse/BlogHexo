---
title: c lua 交互
date: 2020-02-05 23:21:19
tags:
---

## 编译lua
这种编译方式使用VS开发人员命令提示符，比较快而且高效，不用在VS解决方案里弄3个工程再添加或者配置各种东西。
切换到lua源码src文件夹下，执行以下命令:

```
cl /MD /O2 /c /DLUA_BUILD_AS_DLL *.c  
ren lua.obj lua.o  
ren luac.obj luac.o  
link /DLL /IMPLIB:lua5.3.4.lib /OUT:lua5.3.4.dll *.obj  
link /OUT:lua.exe lua.o lua5.3.4.lib  
lib /OUT:lua5.3.4-static.lib *.obj  
link /OUT:luac.exe luac.o lua5.3.4-static.lib 
————————————————
版权声明：本文为CSDN博主「小平_」的原创文章，遵循 CC 4.0 BY-SA 版权协议，转载请附上原文出处链接及本声明。
原文链接：https://blog.csdn.net/xiaoping0915/article/details/74823726
```

> 用VS Studio编译, [这篇图文教程不错](https://www.chenxublog.com/2018/12/04/use-visual-studio-2017-compile-lua-source-code.html)


## 配置解决方案
编译完成后，dll&lib都在原lua/src文件目录下，新建VC++ Win32控制台，添加**配置属性**：

右键解决方案-属性-VC++目录-包含目录/库目录，包含目录是C交互使用的源码目录(lua.h lauxlib.h lualib.h)，库目录是静态库lib的所在目录。
![配置VC++目录](c_pcall_lua.png)

右键解决方案-属性-链接器-输入-附加依赖项-加上"lua5.3.4.lib;"
只用加"lua5.3.4.lib"是因为在之前的VC++目录里 库目录已经将当前lua5.3.4.lib的所在目录添加进了工程，也就是说工程知道lua5.3.4.lib应该去哪里找。


## C调用lua
Lua和C/c++语言通信的主要方法是一个无处不在的虚拟栈。栈的特点是先进后出。

在lua中，lua堆栈就是一个struct，堆栈索引的方式可是是正数也可以是负数，区别是：正数索引1永远表示栈底，负数索引-1永远表示栈顶。

下面这段代码是单纯的用c操作lua调用栈。
``` c
#include "stdafx.h"
#include <iostream>
#include <string.h>
using namespace std;

extern "C"
{
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
}
void main()
{
	//1.创建一个state
	lua_State *L = luaL_newstate();

	//2.入栈操作
	lua_pushstring(L, "I am so cool~");
	lua_pushnumber(L, 20);

	//3.取值操作
	if (lua_isstring(L, 1)) {            	//判断是否可以转为string
		cout << lua_tostring(L, 1) << endl;	//转为string并返回
	}
	if (lua_isnumber(L, 2)) {
		cout << lua_tonumber(L, 2) << endl;
	}

	//4.关闭state
	lua_close(L);
	return;
}
```

<br>

### 已存在的lua文件，C对其变量和方法的调用：

hello.lua文件到底放在哪里，直接调用_getcwd将当前的执行路径打印出来，搞定！

lua_loadfile()：手册上写的是"This function uses lua_load to load the chunk in the filenamedfilename." 而lua_load就是把编译过的chunk放在stack的顶部。

luaL_loadfile后只是将该编译文件保存在了栈顶，相当于一个匿名函数，此时该文件并未执行，它只是被当作文本被加入了内存中（在lua c交互的栈中），需要lua_pcall执行这个函数，将它以lua的形式动态加载，否则下面的lua_tostring、lua_tonumber是取不到栈中的值。
``` c
#include ...

extern "C"
{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}
void main()
{
	lua_State *L = luaL_newstate();
	if (L == NULL)
		return;

	// 打印执行路径
	char buff[1000];
	_getcwd(buff, 1000);
	cout << "当前路径是：" << buff << endl;

	// 读取该文件内容，作为匿名方法入栈
	int bRet = luaL_loadfile(L, "hello.lua");
	if (bRet)
	{
		cout << "loadfile error" << endl;
		return;
	}

	// 执行hello.lua内的lua代码
	bRet = lua_pcall(L, 0, 0, 0);
	if (bRet)
	{
		cout << "pcall error" << endl;
		return;
	}

	lua_getglobal(L, "str");
	string str = lua_tostring(L, -1);
	cout << "str=" << str.c_str() << endl;

	// ... 省略一些代码

	if (lua_isnumber(L, -1))
	{
		double fValue = lua_tonumber(L, -1);
		cout << "Result is " << fValue << endl;
	}
	lua_close(L);
	return;
}
```

lua.h定义了基本lua方法，包含创建lua环境（状态机），或者是lua的方法调用(lua_pcall)，在lua环境中读写全局变量。
lauxlib.h是auxiliary library（翻译成辅助库？），它使用lua.h基础api的方式为lua.h接口做一次延申，包含一些高阶用法

api调用lua的几个步骤：
1.将调用方法压栈
2.将方法参数压栈
3.使用lua_pcall进行实际调用
4.栈弹出方法结果（返回值）