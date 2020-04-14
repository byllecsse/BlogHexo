---
title: Lua 简单自增长缓存池
date: 2020-01-21 23:16:40
tags:
---

将缓存池IncreaseObjectPool定义为class，lua其实没有class的概念，它的class其实是对OO语言的class的仿真，它强大的table可以让程序员自行实现class功能，在lua中可以像这样定义class.

``` lua
NewClass = class('NewClass')

function NewClass:ctor()
end
```

在ctor构造函数参数，传入缓存池模板，外部就可以直接将缓存池对象以模板形式传入IncreaseObjectPool，达到数据由外部管理，缓存池内部只处理缓存对象。

``` lua
function IncreaseObjectPool:ctor(template, objName, preInstNum, increaseNum, ...)
    if template == nil then
        error("template is nil in IncreaseObjectPool")
        return
    end

    self.template = template               -- 对象模板
    self.preInstNum = _EnsureNumGreaterThanZero(preInstNum, 40) -- 预加载数量
    self.increaseNum = _EnsureNumGreaterThanZero(increaseNum, 20) -- 增长数量
    self.objName = objName                 -- 对象名字
    self.param = { ... }                   -- 参数


    self.allocCount = 0                    -- 创建对象总数量
    self.objects = {}                      -- 缓存的对象

```

self.objects管理缓存池内的缓存对象，在每次外部申请缓存空间时，Alloc方法都会检查self.objects的数量，当数量=0则调用_Enlarge()增加self.objects的大小，也就是增加self.template模板对象的个数。

``` lua
-- 获取空闲对象
function IncreaseObjectPool:Alloc()
    if #self.objects == 0 then
        self:_Enlarge(self.increaseNum)
    end

    local obj = self.objects[#self.objects]
    self.objects[#self.objects] = nil
end
```

_Enlarge()自增对象方法，用于创建空的self.template对象，比如self.objectPool_Buff = IncreaseObjectPool.new(Buff, 'Buff')的缓存池，self.teplate.new()的是个Buff的空对象，即会调用Buff:ctor()，如果该模板对象存在OnCreate()则会进一步调用OnCreate以创建对象，在我们的项目中GUI界面的lua代码实现了OnCreate()，但实际上几乎没有设置缓存池去管理GUI代码

``` lua
-- 增加一部分空闲对象
function IncreaseObjectPool:_Enlarge(num)
    for i = 1, num do
        local template = self.template.new(unpack(self.param))
        if template.OnCreate then
            template.OnCreate(template)
        end
        table.insert(self.objects, template)
    end
    self.allocCount = self.allocCount + num
end
```

某个对象用完后归还缓存池留以下次新对象使用，这个缓存的操作是insert(self.objects)，看起来是野对象加入缓存池，即自定义创建的对象，并非从缓存池中取出的对象。

``` lua
-- 归还对象
function IncreaseObjectPool:Free(obj)
    if obj ~= nil then
        table.insert(self.objects, obj)
    end
end
```

将缓存池的大小缩到self.preInstNum是缓存池创建函数ctor的初始缓存大小，预创建40个对象，同样OnDestroy方法也是GUI类的对象持有。
``` lua
-- 缩小缓存池 将超出预加载数量的部分释放
function IncreaseObjectPool:ResetSize()
    for i = #self.objects, self.preInstNum + 1, -1 do
        local obj = self.objects[i]
        if obj.OnDestroy then
            obj.OnDestroy()
        end

        obj = nil
        self.objects[i] = nil
    end
    self.allocCount = 0
end

```

这个Clean()方法比较直接，整个self.objects直接置为空表，空表和nil不同，#{}=0, #nil会报错。
``` lua
-- 清理缓存池 
function IncreaseObjectPool:Clean()
    for i = 1, #self.objects do
        local obj = self.objects[i]
        if obj.OnDestroy then
            obj.OnDestroy()
        end

        obj = nil
    end
    self.objects = {}
    self.allocCount = 0
end

```

### 小结

这个缓存池只管理lua代码实例，具体缓存对象的资源/gameObject由外部对象控制，比如外部对象的Instantiate内容则需要自己在Release()或者Dispose()方法内销毁，缓存池清理是直接self.objects[i] = nil，如果在这之前不调用传入模板内的Destroy()或者Unload()释放资源，则会造成内存泄漏。

> 来看个coco2d-x实现的class.
https://blog.csdn.net/mywcyfl/article/details/37706085