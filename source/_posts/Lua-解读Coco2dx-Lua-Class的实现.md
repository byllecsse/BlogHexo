---
title: 解读coco2d-x lua class的实现
date: 2020-01-23 00:09:50
tags:
---

Lua class没有原生实现，因为lua本来目的就不是OO语言，它更愿意当一个快速执行脚本，用于注入高级语言中执行，但是广大游戏开发者又需要用lua实现一堆对象，或者还有继承的概念，coco2d-x等实现了class，这篇文章就记录我看这些class实现的感悟吧（目的是看懂）。

## coco2d-x的官方class实现
``` lua
--Create an class.
function class(classname, super)
    local superType = type(super)
    local cls

    -- 检查传入的super是这两个类型，我不知道function也可以作为父类
    if superType ~= "function" and superType ~= "table" then
        superType = nil
        super = nil
    end

    if superType == "function" or (super and super.__ctype == 1) then
        -- inherited from native C++ Object
        cls = {}

        if superType == "table" then
            -- copy fields from super
            -- 将super内的所有变量、函数拷贝过来
            for k,v in pairs(super) do cls[k] = v end
            cls.__create = super.__create
            cls.super    = super
        else
            cls.__create = super
        end

        cls.ctor    = function() end
        cls.__cname = classname
        cls.__ctype = 1

        function cls.new(...)
            local instance = cls.__create(...)
            -- copy fields from class to native object
            for k,v in pairs(cls) do instance[k] = v end
            instance.class = cls
            instance:ctor(...)
            return instance
        end

    else
        -- inherited from Lua Object
        if super then
            cls = clone(super)
            cls.super = super
        else
            cls = {ctor = function() end}
        end

        cls.__cname = classname
        cls.__ctype = 2 -- lua
        cls.__index = cls

        function cls.new(...)
            -- 直接用设置元表的方式处理构造函数
            local instance = setmetatable({}, cls)
            instance.class = cls
            instance:ctor(...)
            return instance
        end
    end

    return cls
end
```