---
title: 简单记录学习lua元表
date: 2020-02-08 23:21:04
tags:
---

元表其实是对table的功能扩展，让table可以像普通类型一样加减运算，或者是模拟类和继承以实现面向对象，先来看个简单的代码：

setmetatable(opt, mt)等价于:
setmetatable(opt, {__index = B})

``` lua
local B = {}
-- mt的无索标签引指向B
local mt = {__index=B}

function B:new(opt)
    opt.age = opt.age or 10
    opt.name = opt.name or 'heli'
    -- opt设置元表为mt，即opt的不存在索引值会去B中查找
    return setmetatable(opt, mt)
end

function B:string()
-- self指向调用者自身
-- B:string()是冒号省略了self参数，如果是点则需要B.string(self)
    print(string.format("xxxx, %s %s", self.age, self.name))
end

local c = B:new{age=20, name='c'}
c:string()

```


### __index
``` lua
father = {
    prop1 = 1
}

father.__index = father

son = {
    prop2 = 1
}

setmetatable(son, {
    __index = {
        prop1 = 2
    }
})
print(son.prop1)
```
一步步理下调用过程，从最后一行print()开始：
1.son不存在prop1索引，查找元表__index；
2.发现__index中存在prop1；
3.输出__index中的prop1 = 2.

setmetatable(son, father) 设置了son的元表为father，于是去father里找__index，去father里找__index是因为我查找了son不存在的prop1索引key，father.__index指向了自己，于是就会到__index方法所指向的这个表中去查找名为prop1的成员


如果__index中不存在prop1，则print()输出nil.
> 按照这个写法，father整个都没用，我来改下代码：

``` lua
father = {
    prop1 = 1
}

father.__index = father -- 如果不写这行，print(son.prop1)为nil

son = {
    prop2 = 1
}

setmetatable(son, {
    __index = father
})
print(son.prop1)
```

这样print()输出的就是father.prop1.


### __add

因为程序在执行t1+t2的时候，会去调用t1的元表mt的__add元方法进行计算。
具体的过程是：
1.查看t1是否有元表，若有，则查看t1的元表是否有__add元方法，若有则调用。
2.查看t2是否有元表，若有，则查看t2的元表是否有__add元方法，若有则调用。
3.若都没有则会报错。
所以说，我们通过定义了t1元表的__add元方法，达到了让两个表通过+号来相加的效果

``` lua
local mt = {}
mt.__add = function(t1, t2)
    local temp = {}
    for _, v in pairs(t1) do
        table.insert(temp, v)
    end

    for _, v in pairs(t2) do
        table.insert(temp, v)
    end
    return temp
end

local t1 = {1,2,3}
local t2 = {2}

setmetatable(t1, mt)
local t3 = t1 + t2
print(t3[1], t3[2], t3[3], t3[4])
```


### __newindex

``` lua
local mt = {}
mt.__newindex = function(t, index, value)
    print("index is " .. index)
    print("value is " .. value)
end

t = {key = "it is key"}
setmetatable(t, mt)
print(t.key)
t.newKey = 10
--表中的newKey索引值还是空，上面看着是一个赋值操作，其实只是调用了__newIndex元方法，并没有对t中的元素进行改动
print(t.newKey)

--[[
    输出：
    it is key
    index is newKey
    value is 10
    nil
]]
```
t.newKey = 10对不存在的键值赋值会调用元表的__newindex, 但不进行原表内键值的修改。


### 简单class模拟

在lua文件中required另一个lua文件，系统会在LUA_PATH环境变量中依次寻找required的文件名，我默认安装时LUA_PATH写的是?.luac导致找不到lua文件而报错。

``` lua
local People = {
    name = ''
}

function People:say( )
-- self是该表自身，应该是lua实现的
    print(self.name)
end

function People:ask()
    print("ask")
end

function People:new(name)
    local o = {name = name}
    -- 父类的__index为自身，这样感觉都没必要这一行
    -- 经测试，People对象访问不存在的方法，有无这行都会报错： attempt to call method 'ask' (a nil value)
    setmetatable(o, {__index = self})

    return o
end

local Teacher = {}
function Teacher:say( )
    print('teacher ' .. self.name)
end

-- People作为父类，Teacher不存在的方法应去父类People中寻找
setmetatable(Teacher, {__index = People})

local xiaoming = Teacher:new('xiaoming')
xiaoming:say()
```
继承的子类用元表将__index指向父类People，子类不存在的方法即会调用父类，子类的方法会重写父类方法，即子类的table存在相应索引，则不会去调用__index.