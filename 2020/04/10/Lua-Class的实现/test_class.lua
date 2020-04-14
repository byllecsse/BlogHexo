
-- 获取一个类的所有基类
local function super_classes(class)
    -- 修改：没有用class.super_classes而是用rawget，原因是这里的目标仅是class自己是否有super_classes字段
    -- 不应该去父类查询，所以用rawget
    -- 可能导致的问题是，如果classB继承自classA，先执行classA.new()，再执行classB.new()，在classB.new()执行到这里的时候，
    -- 会查询到classA的super_classes字段，返回空表，导致没有调用父类的构造函数
    local super_classes = rawget(class, 'super_classes')
    if super_classes then
        return super_classes
    end

    super_classes = {}
    local super = class.super
    while super do
        table.insert(super_classes, super)
        super = super.super
    end

    -- 修改；和rawget对应，用rawset
    rawset(class, 'super_classes', super_classes)
    --class.super_classes = super_classes
    return super_classes
end


-- 依次调用构造函数，因为传递的是object，所以可以保证定义的所有变量都在最终的对象上（即self上，访问这些属性是不需要经过metatable的）
local function derive_variable(object, class, ...)
    local supers = super_classes(class)
    for i=#supers, 1, -1 do
        supers[i].ctor(object, ...)
    end
    class.ctor(object, ...)
end

-- 定义一个类
function class(class_name, super)
    local new_class = {}
    new_class.__cname = class_name  -- 类名，用于类型判定
    new_class.super = super

    -- 在前面调用，否则设置完metatable后，只要父类有ctor则无法判定子类是否实现了ctor
    if not new_class.ctor then
        -- add default constructor
        new_class.ctor = function() end
    end

    -- 基类的函数访问
    if super then
        setmetatable(new_class, { __index = super })
    end

    -- 公共的metatable保存在类对象中，避免new的时候重复创建
    new_class.__meta = { __index = new_class }

    new_class.new = function (...)
                        local object = {}
                        object.__class = new_class
                        setmetatable(object, new_class.__meta)
                        derive_variable(object, new_class, ...)
                        return object
                    end
    -- new_class.__call = function (self,...) 
    --     return self:new(...) 
    -- end
    return new_class
end
