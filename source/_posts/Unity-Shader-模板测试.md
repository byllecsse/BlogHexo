---
title: Unity 模板测试
date: 2020-04-10 10:58:09
tags:
---

Stencil模板测试，用于检查像素是否保留（输入缓冲区），Stencil内包含Ref ReadMask WriteMask Comp Pass Fail ZFail参数，用于记录一个模板对像素值的过滤，满足条件的输入缓冲区，不满足条件的直接丢弃。

来看个例子，来自Unity官方文档：
无论深度输入值是多少，‘永远’将输入值替换为‘2’写入缓冲区。
write the value ‘2’ wherever the depth test passes. The stencil test is set to always pass.

``` c
Stencil {
    Ref 2
    Comp always
    Pass replace
}
```

![模板测试流程图](https://pic4.zhimg.com/v2-bd2ae6861be576fcfd54ca79cd25574a_1200x500.jpg)

这是项目内阴影Pass，现在来一行行分析这里面干了啥。
1. Ref 参考值，可设置范围0~255
2. Comp Equal 将参考值与缓冲区的当前内容进行比较，等于缓冲区内容的才会写入，
    表示通过模板测试和Z test的条件，只有=0的像素才算通过测试。
3. Pass IncrWrap 如果模板测试（和深度测试）通过，将当前值加入缓冲区，如果结果超出255，则会从0开始，
    通过模板测试和Z test的像素，将其值自增1直到超过255后被置为0.
4. Fail Keep 如果模板测试失败，则保留当前缓冲区的内容。
5. ZFail Keep 模板测试通过，但深度测试失败，则保留当前缓冲区的内容。

``` c
Stencil
{
    Ref 0
    Comp Equal
    Pass IncrWrap
    Fail Keep
    ZFail Keep
}
```

<br>

想更熟悉模板测试，有个经典3色球场景（貌似也是官方例子）：
![3色球](https://pic1.zhimg.com/80/v2-2571a520a784b03e6381c87ebcc34bd4_720w.png)

- 第一步画红球：
``` c
Stencil {
    Ref 2
    Comp always
    Pass replace
    ZFail derWrap
}
```
参考值Ref 2，stencilBuffer值默认为0，
永远通过Stencil测试，替换stencilBuffer值=2，
ZFail 深度失败是溢出型-1.

然后在frag()片元着色器中将球体渲染为红色，得到结果如图：在平面下方的半球没有通过深度测试，stencil值-1=255.
![](https://pic4.zhimg.com/80/v2-aa57dc8aa9210aa833e8d5a9ae8666b3_720w.png)


- 第二步画绿球：
``` c
Stencil {
    Ref 2
    Comp equal
    Pass keep
    Fail decrWrap
    ZFail keep
}
```
红球上半部分Ref 2, 因此绿球Ref 2 Comp equal得到的是和红球相交的上半部分，下半部分相交区域由于Fail decrWrap模板值变为了254.
![](https://pic3.zhimg.com/80/v2-2311879461acf0df8b87b99affecd9b2_720w.png).


- 第三步画蓝球：
``` c
Stencil {
    Ref 254
    Comp equal
}
```
限定模板254通过测试，ZTest 默认也是通过状态，所以蓝球最终渲染在红球与绿球相交区域的下平面。
![](https://pic3.zhimg.com/80/v2-6347c5e47f69f8beffbb4e3d5408795a_720w.png)



## 模型描边

大致思路两个Pass一个渲染模型本体，另一个渲染模型外描边，外描边需要进行顶点法线方向的扩充。
定义一个模板，让模型本体先通过模板测试，随后描边Pass处于模型本体区域的渲染测试失败，只有模型外描边的测试通过。

模板定义在SubShader内，在两个Pass之前，在第一个Pass对模板值已经进行了更新后，第二个模板测试使用原模板去测试新模板值，可以定义同一个模板是因为shader的模板测试在同一帧内不会进行更新，但是模板缓冲内的Ref，在第一个Pass测试结束后已经更新其值。

定义如下模板：
``` c
Stencil {
     Ref 0          //0-255
     Comp Equal     //default:always
     Pass IncrSat   //default:keep
     Fail keep      //default:keep
     ZFail keep     //default:keep
}
```

第二个描边Pass在顶点函数内，对每个顶点向外朝着法线方向扩展0.01f:
``` o.vertex=v.vertex+normalize(v.normal)*0.01f;```


## 反射区域限定

这个做法就像是遮罩，限定某些区域才输出颜色到屏幕，用stencil buffer将不应该输出颜色的区域，不通过stencil test，就达到了遮罩遮盖颜色的目的。
比如说让镜面的stencil ref 0，镜面区域的ref 通过模板测试自增1变为Ref 1，倒影Ref 1的区域通过测试进入缓冲。

``` c
Stencil {
    Ref 0
    Comp always
    Pass IncrSat
    Fail keep
    ZFail keep
}
```
镜面shader将屏幕范围内的stencil ref自增1，原值Ref 0是模板参考的默认值，即什么都不做，模板参考值=0，然后渲染人物倒影，人物渲染和人物倒影渲染可以用两个Pass，倒影Pass定义模板Ref 1满足这个参考值的才能通过模板测试，也就是在镜面上的倒影才输出到屏幕.

``` c
Stencil {
    Ref 1
    Comp Equal
    Pass keep
    Fail keep
    ZFail keep4
}
```

参考：
https://zhuanlan.zhihu.com/p/28506264
[ShaderLab: Stencil](https://docs.unity3d.com/Manual/SL-Stencil.html)
[Unity Shader: 理解Stencil buffer并将它用于一些实战案例（描边，多边形填充，反射区域限定，阴影体shadow volume阴影渲染）](https://blog.csdn.net/liu_if_else/article/details/86316361?depth_1-utm_source=distribute.pc_relevant_right.none-task&utm_source=distribute.pc_relevant_right.none-task)