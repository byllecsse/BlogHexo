---
title: Lua class  实现
date: 2020-04-10 11:00:44
tags:
---


Lua是没有类的(class)，它只有表(table)

这个class本身传参了class name，class_name被赋值给了自身new_class lua table的__cname键值属性，检查有无super传入，设置自身元表super，否则定义元表为自身表，其实可以写成__index = self.
new方法是外部用来创建类对象，new方法内创建一个临时变量Object是该类的对象，object.__class字段赋值自身new_class，设置自身的元表：

``` lua
new_class.__meta = { __index = new_class }
setmetatable(object, new_class.__meta)

-- 等价于
setmetatable(object, {
    __index = self
})
```
<font color=red>至于这里为何不直接用个匿名直接设置__index，我猜是为了可以随时打印出__index设置内容。</font>
这里理解有误，存储__meta是为了不要再new方法中重复创建匿名table = { __index = self }，每次{}创建的是个局部的新table。


new方法内多进行了一个操作，derive_variable()调用所有继承父类的ctor构造方法，调用方式为遍历supers.ctor，supers则是用rawset()一层层向上获取父类的对象，所以又封装一个函数super_classes()，用来链式获取子类的所有基类，每个子类都知道自己的父类对象:

``` lua
    local super = class.super
    while super do
        table.insert(super_classes, super)
        super = super.super
    end

```
用rawget()和rawset()直接设置class的字段而不改变元表内的属性值，会跳过__index设置属性。


### __call用法

元方法__call是table被当作方法使用调用的方法，应用到类的实现上，只有当table被当作构造函数调用时会调用__call，如果在创建实例时使用了class:new都不会调用__call方法，调用__call必须是将table本身当作function使用，如果存在table.param参数的调用（比如function类型的参数）都不会调用__call。

``` lua
Lion = class(Cat)
leo = Lion('Leo', 'African') -- 调用__call
```

### __tostring

源代码：
[class实现](test_class.lua)
[class a声明](test_class_a.lua)
[class b申明](test_class_b.lua)
[test实例化](test.lua)

<br>

## 实现class的坑

来看lua实现class一种常见的方式：
``` lua
ClassBase = {
    data = {1, 2, 3, x = 0};
}
function ClassBase:New()
    local obj = {};
    setmetatable(obj, {__index = self});
    return obj;
end

function ClassBase:SetData()
    self.data.x = 999;
end
​
a = ClassBase:New();
b = ClassBase:New();
​
b:SetData();    -- 修改self.data.x的值

print("a.data.x is :" .. tostring(a.data.x));
print("b.data.x is :" .. tostring(b.data.x));
print("ClassBase.data.x is :" .. tostring(ClassBase.data.x));
```

得到的结果：
a.data.x is : 999
b.data.x is : 999
ClassBase.data.x is : 999

意外产生了，我只修改b的data.x数据，为何影响到a甚至ClassBase的数据。

在New函数里，实例通过将父类设置为metatable和将父类的__index设置为父类本身来实现继承和简单的多态。
SetData里对参数data.x做赋值，b对象本身不存在自己实例化的data，它使用的其实是元方法__index指向父类ClassBase里的data，a.data也是指向了ClassBase中的data，这样一来data其实在3者中共享的，因为__index方法，他们的data都是ClassBase中的，而data.x，则是metatable中也就是ClassBase.data.x。

self.data = 999不会产生这样的问题，因为对一个不存在的键值赋值调用的是元表__newindex方法。

**规避方法**
这样每个实例都有了自己的data属性。

``` lua
ClassBase = {
     data = {1,2,3,x = 0}
}
--新增初始化函数 在初始化函数里为成员赋值
function ClassBase:ctor()
    self.data = {1,2,3,x = 0};
end
function ClassBase:New()
     local obj = {};
     setmetatable(obj, {__index = self});
     -- 初始化函数
     obj:ctor()
     return obj;
end
```


## 自己实现简单版本class

``` lua
function class(name, super)
    local obj = {}
    obj.super = super
    obj.name = name

    local mt = {}
    mt.__call = function(self, ...)
        local arg = {...}
        if self.init then
            self.init(self, ...)    -- 用冒号语法糖 self:init(...)
        end
        return self
    end
    mt.__index = super
    setmetatable(obj, mt)
    return obj
end

base = class('base')

function base:init(...)
    local arg = {...}
    print(arg[1], "base init")
end

animal = class('animal', base)

function animal:call()
    print("call")
end

local dog = animal('dog')
dog.call()

--[[
    运行结果：
    dog     base init
    call
]]
```

我在让dog调用base打印name时花了点时间，__call=function(self, ...) 这个self是传入的dog对象，由于是匿名方法无法使用冒号语法糖，所以传入dog参数调用init()，animal类不存在init()，查找__index=super父类存在Init()方法；
animal('dog')将table按照方法模式使用调用__call，传入可变参数...，获取可变参数arg={...}，self.init()的调用<font color=red>我犯了个错误</font>，self.init(...)导致base:init(...)没有自身对象信息无法取到...值，为了避免漏传self，建议使用冒号语法糖self:init(...)