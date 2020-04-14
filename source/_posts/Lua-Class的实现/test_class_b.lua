require("test_class_a")

classB = class('ClassB', classA)

function classB:ctor()
    print("classB ctor")
end

-- function classB:Ask()
--     print("classB ask")
-- end

function classB:Sleep()
    print("classB sleep")
end