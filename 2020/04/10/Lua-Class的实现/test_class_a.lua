require("test_class")

classA = class('ClassA')

function classA:ctor()
    print("classA ctor")
end

function classA:Ask()
    print("classA Ask")
end
