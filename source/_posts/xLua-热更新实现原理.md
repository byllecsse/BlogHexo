---
title: xLua热更新实现原理
date: 2020-02-23 23:01:06
tags:
---

HotFix实现方案：

第一步：通过对C#的类与函数设置Hotfix标签。来标识需要支持热更的类和函数。
第二步：生成函数连接器来连接LUA脚本与C#函数。
第三步：在C#脚本编译结束后，使用Mono提供的一套C#的API函数，对已经编译过的.Net体系生成的DLL文件进行修改。
第四步，通过LUA脚本修改C#带有标签的类中静态变量，把代码的执行路径修改到LUA脚本中。


## 基础准备

IL: 的全称是 Intermediate Language，很多时候还会看到CIL（Common Intermediate Language，特指在.Net平台下的IL标准）。在Unity博客和本文中,IL和CIL表示的是同一个东西：翻译过来就是中间语言。它是一种属于 通用语言架构和.NET框架的低阶（lowest-level）的人类可读的编程语言。目标为.NET框架的语言被编译成CIL，然后汇编成字节码。 CIL类似一个面向对象的汇编语言，并且它是完全基于堆栈的，它运行在虚拟机上（.Net Framework, Mono VM）的语言。
具体过程是：C#或者VB这样遵循CLI规范的高级语言，被先被各自的编译器编译成中间语言：IL（CIL），等到需要真正执行的时候，这些IL会被加载到运行时库，也就是VM中，由VM动态的编译成汇编代码（JIT）然后在执行。

CIL: 通用中间语言（Common Intermediate Language，简称CIL）
是一种属于通用语言架构和 .NET 框架的低阶（lowest-level）的人类可读的编程语言。目标为 .NET 框架的语言被编译成CIL（基于.NET框架下的伪汇编语言，原：MSIL），这是一组可以有效地转换为本机代码且独立于 CPU 的指令。CIL类似一个面向对象的汇编语言，并且它是完全基于堆栈的。它运行在CLR上（类似于JVM），其主要支持的语言有C#、VisualBasic .NET、C++/CLI以及 J#（集成这些语言向CIL的编译功能）。

在编译.NET编程语言时，源代码被翻译成CIL码，而不是基于特定平台或处理器的目标代码。CIL是一种独立于具体CPU和平台的指令集，它可以在任何支持.NET framework的环境下运行。CIL码在运行时被检查并提供比二进制代码更好的安全性和可靠性。在Unity3D中，是用过Mono虚拟机来实现运行这些中间语言指令的。

[使用微软的API函数，利用中间语言生成或注入.NET支持下的DLL]

IL2CPP: 直接理解把IL中间语言转换成CPP文件。
根据官方的实验数据，换成IL2CPP以后，程序的运行效率有了1.5-2.0倍的提升。

如果是普通Mono C#编译，编译运行如图：简单的来说，3大脚本被编译成IL，在游戏运行的时候，IL和项目里其他第三方兼容的DLL一起，放入Mono VM虚拟机，由虚拟机解析成机器码，并且执行.
![Mono](http://gameweb-img.qq.com/gad/20170512/image001.1494581139.jpg)


正是由于引入了VM，才使得很多动态代码特性得以实现。通过VM我们甚至可以由代码在运行时生成新代码并执行。这个是静态编译语言所无法做到的。Boo和Unity Script，有了IL和VM的概念我们就不难发现，这两者并没有对应的VM虚拟机，Unity中VM只有一个：Mono VM，也就是说Boo和Unity Script是被各自的编译器编译成遵循CLI规范的IL，然后再由Mono VM解释执行的。

这也是Unity Script和JavaScript的根本区别。JavaScript是最终在浏览器的JS解析器中运行的（例如大名鼎鼎的Google Chrome V8引擎），而Unity Script是在Mono VM中运行的。本质上说，到了IL这一层级，它是由哪门高级语言创建的也不是那么重要了，你可以用C#，VB，Boo，Unity Script甚至C++，只要有相应的编译器能够将其编译成IL都行！


IL2CPP编译做出的改变如图红色部分：在得到中间语言IL后，使用IL2CPP将他们重新变回C++代码，然后再由各个平台的C++编译器直接编译成能执行的原生汇编代码。
![IL2CPP](http://gameweb-img.qq.com/gad/20170512/image002.1494581139.gif)

在得到中间语言IL后，使用IL2CPP将他们重新变回C++代码，然后再由各个平台的C++编译器直接编译成能执行的原生汇编代码。

> 需要注意：由于C++是一门静态语言，这就意味着我们不能使用动态语言的那些酷炫特性。运行时生 成代码并执行肯定是不可能了。这就是Unity里面提到的所谓AOT（Ahead Of Time）编译而非JIT（Just In Time）编译。其实很多平台出于安全的考虑是不允许JIT的，大家最熟悉的有iOS平台，在Console游戏机上，不管是微软的Xbox360， XboxOne，还是Sony的PS3，PS4，PSV，没有一个是允许JIT的。使用了IL2CPP，就完全是AOT方式了，如果原来使用了动态特性的 代码肯定会编译失败。这些代码在编译iOS平台的时候天生也会失败。


#### 开启IL2CPP的Unity构建流程
unity构建流程分步：

第一步：平台资源处理，主要生成Librarymetadata下面的文件。
第二步：脚本编译(主要是C#脚本)，LibraryScriptAssemblies下的Dll，主要是Assembly-CSharp.dll 和Assembly-CSharp-Editor.dll这两个Dll。
第三步：把这个Assembly-CSharp.dll编译成C++代码。在IOS中，这里是导出Xcode的工程。Andriod中直接生成APK。
第四步：在IOS中，编译Xcode，生成IPA。Andriod没有这一步。