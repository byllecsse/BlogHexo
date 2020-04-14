---
title: CSharp-Lua-交互
date: 2020-02-19 18:57:21
tags:
---

## 普通C#调用lua
需要先下载[lua支持类库](http://files.luaforge.net/releases/luainterface/luainterface)将LuaInterface.dll & luaxx.dll(xx是lua版本)引用到项目中。

步骤：
1. 申明lua虚拟机：Lua m_lua = new Lua();
2. 将C#对象方法注册到lua中，是lua可以调用该方法：m_lua.RegisterFunction("MethorName", class, class.GetType().GetMethod("MethodName"));
3. 加载lua代码：m_lua.DoFild("lua_file.lua");
4. 调用lua方法: Object[] objs = m_lua.GetFunction("MethodName").Call(args);

<br>

## 使用xLua进行C#与Lua交互

拿最简单的先举例：
在C#中生成一个对象 GameObject go = new GameObject();
用Lua代码写则是 local go = CS.UnityEngin.GameObject()

在Lua中没有new关键字，新建对象时直接省略new，所有C#相关都加上"CS."前缀，包括构造函数、静态成员属性&方法，并且跟上命名空间namespace，new GameObject的命名空间是UnityEngine，所以在Lua中就是CS.UnityEngine.GameObject.

>xLua也支持多个构造函数：local go = CS.UnityEngine.GameObject('helloLua')

为了避免每次使用某个Unity类型都去做一次寻址操作，一般会在lua文件头用个局部变量做缓存，注意lua文件和函数内local的生命周期.

``` lua
local GameObject = CS.UnityEngine.GameObject
GameObject.Find('helloworld')
```

1. xLua能支持一些参数个数，number、string、array类型区分的重载，但C#终得int、float、double都对应lua的number，若C#有这些类型的重载，Lua则无法区分开来，只能调用到其中的一个（生成代码中排前面的那个）。
2. 支持枚举类型的访问，如果加入到生成代码的话（即添加[LuaCallCSharp]标签），枚举类将支持__CastFrom方法，可以实现从一个整数或者字符串到枚举值的转换。

### 在Unity中Component调用lua

我拿xLua的框架来分析下C#和Lua在Unity游戏内的交互，xLua为构建LuaTable、lua获取Unity组件内容和C#代码变量做了很多事情，简化了很多Lua调用Unity组件的操作，当然xLua的优势在于热更新，而且提出的热更新方案比较先进，虽然后面xLua的创建者自己又写了个iFix，貌似可以更新C#...好厉害..

简单分析下xLua的交互使用，详细的xLua热更新我要再写一篇记录。

XLuaManager的构造函数内启动lua虚拟机调用LuaEnv，执行init_xlua lua代码进行了一些类与元表配置，<font color=red>(详细以后再看Q.Q)</font>，一系列操作后，在lua可以直接通过CS来访问C#的各项类与组件，比如组件统一在UnityEngine命名空间下，就可以通过CS.UnityEngine来访问。

``` lua
local UnityEngine = CS.UnityEngine;
UnityEngine.Transform
UnityEngine.UI.Button
```

UnityEngine下的各项组件已经由xLua关联好了，并且获取到实例后，可以使用UnityEngine的所有方法，超级方便。
比如我调用tranform的Button组件，或者为gameObject添加一个组件：

``` lua
m_actionText = this.transform:Find("ActionText"):GetComponent("Text");
m_actionItem = this.transform:Find("ItemPanel/ActionItem"):AddComponent("Image");
```

这样一来我只要定义好lua组件的文件头，方法内获取Unity或者是C#的函数都通过CS这个封装，像C#调用一样使用就可以，减少了很多编码和学习成本，文件头指的是lua表的创建，xLua获取文件信息都是将文件映射到lua table，变量和方法都会是这个table的参数，所以C#调用lua将会以table参数的形式调用。对于LuaTable，方法的类型是Action，调用方法是Get<Action>(funcName)。

``` c#
Action func = luaTable.Get<Action>(funcName);
if(func != null) {
    func();
}
```

<br>

### LuaComponentLoader 加载lua组件

该类继承自MonoBehaviour，必须挂在某个控件上，它没有做热更新或者C#代码替换，所以需要执行lua component是要停用lua Component 的C#版本，也就是说它单纯是个lua版的组件，用于执行原C# component的功能。

如果用 lua 模拟C#代码，必须在lua脚本中定义和C# MonoBehaviour相同的生命周期函数，至于函数名可以不一样，随LuaComponentLoader中的调用代码而定，但一般来说需要Awake、Start、Update。

其实LuaComponentLoad也没有什么特别高深的东西，它是以LuaTable的形式获取了lua脚本的各项参数，并在自己的MonoBehaviour生命周期中调用lua相应的生命周期函数，比如LuaComponentLoad中的Awake调用Lua中的Awake.

> 为了让代码简短些，我省略了一些值的判断。

``` c#
public class LuaComponentLoader : MonoBehaviour {
    public string luaComponentName;
    public bool Load() {
        luaTable = XLuaManager.instance.GetLuaTable(luaComponentName);  // 需要判断string.IsNullOrEmpty
        luaTable.Set<string, Transform>("transform", transform);
    }

    void CallLuaFunction(string funcName) {
        Action func = luaTable.Get<Action>(funcName);
        func(); // 需要判断func != null
    }

    void Awake() {
        if (Load())
            CallLuaFunction("Awake");
    }
}
```

<br>

### 访问自定义类成员属性、方法

和C#访问自身类一样，访问成员属性方法的时候，需要通过类的实例去访问。
假设定义如下类：
``` c#
namespace MyExamples {
    [LuaCallCSharp]
    public class Test {
        public int index;
        public int Add(int a, int b) {
            return a + b;
        }
    }
}
```
Lua Call C#代码的时候，C#处生成的代码基本都需要打标签[LuaCallCSharp]。

对于[LuaCallCSharp]标签的解释，参考xLua的Github FAQ:

一个C#类型加了这个配置，xLua会生成这个类型的适配代码（包括构造该类型实例，访问其成员属性、方法，静态属性、方法），否则将会尝试用性能较低的反射方式来访问。一个类型的扩展方法（Extension Methods）加了这配置，也会生成适配代码并追加到被扩展类型的成员方法上。xLua只会生成加了该配置的类型，不会自动生成其父类的适配代码，当访问子类对象的父类方法，如果该父类加了LuaCallCSharp配置，则执行父类的适配代码，否则会尝试用反射来访问。反射访问除了性能不佳之外，在il2cpp下还有可能因为代码剪裁而导致无法访问，后者可以通过下面介绍的ReflectionUse标签来避免。


对应lua代码的访问：
``` lua
local Test = CS.MyExamples.Test
local test = Test()
test.index = 66
print(test.index, test.Add(test, 1, 2), test:Add(3, 4))
```

> 注意：一般用':'访问成员函数（冒号语法糖），如果是'.'访问则需要第一个参数传递该对象。


#### 输入输出属性out, ref
C#有两个特殊关键字out、ref，使得定义该关键字的参数不用经过函数返回值return，lua对此的处理是统一当作返回值处理（反正lua可以返回多个值）

``` c#
// c#
public class A {
    public static int Method(int a, ref int b, out int c, Action funA, out Action funB)  {
        c = 10;
        funA();
        funB() => { Debug.Log("funB"); }
        return 5;
    }
}
-- lua
local ret, ret_b, ret_c, ret_funB = CS.MyExamples.A.Method(1, 2, function()
    print("funA")
end)
ret_funB()
```
funB在C#函数内用了lamaba表达式重新定义了匿名方法，return返回值是函数多返回值的第一个，如果return多个值也会按照顺序优先排列，随后根据ref和out的参数顺序返回，暂时还没有查到lua多重返回最多可以返回多少个值。

将lua的function传递到了C# Action参数中，等于上一篇说讲到的lua函数映射到C#委托，因此我们需要将Action添加到CSharpCallLua白名单中。类似的还有Func<>等委托（否则将会报错LuaException: c# exception:System.InvalidCastException: This type must add to CSharpCallLua: System.Action）

<br>

### 事件类型的使用

#### Delegate

调用C# delegate就像和调用普通lua函数一样。

``` c#
[LuaCallCSharp]
public class TestSon : Test {
    public delegate int IntDelegate(int a);
    public IntDelegate intDelegate = (a) => {
        Debug.Log("C# -- intDelegate --a = " + a);
        return a;
    };
}

-- lua访问
testSon.intDelegate(10);
```

+操作符：对应C#的+操作符，把两个调用串成一个调用链，右操作数可以是同类型的C# delegate或者lua函数。
-操作符：和+相反，把一个delegate从调用链中移除。

> delegate属性可以用一个lua function来赋值。

``` lua
local function lua_delegate(a)
    print('lua_delegate :', a)
end
testSon.intDelegate = lua_delegate + testSon.intDelegate --combine，这里演示的是C#delegate作为右值，左值也支持
testSon.intDelegate(100)
testSon.intDelegate = testSon.intDelegate - lua_delegate --remove
testSon.intDelegate(1000)
```

#### Event
比如定义如下event，从定义intEvent的地方可以看出，intEvent是委托IntDelegate的对象，一个主要的区别是委托是类型，而事件是委托的对象，event只能写在'+''-'的左侧，
``` c#
public class TestSon : Test {
    public event IntDelegate intEvent;

    public void ExeEvent(int a) {
        intEvent(a);
    }
}
```

在lua内对事件对象进行访问，并添加/移除其委托的函数方法，在C#方法中执行这个事件。
``` lua
local function lua_eventCallback1(a)
    print('lua_eventCallback1 :', a)
end
local function lua_eventCallback2(a)
    print('lua_eventCallback2 :', a)
end
--增加事件回调
testSon:intEvent('+', lua_eventCallback1);
testSon:intEvent('+', lua_eventCallback2);
testSon:ExeEvent(100);
--移除事件回调
testSon:intEvent('-', lua_eventCallback1);
testSon:ExeEvent(1000);
testSon:intEvent('-', lua_eventCallback2)
```


这里又可以扯一下**C#委托与事件**的区别：
委托是一个类，该类内部维护着一个字段，指向一个方法。
事件可以被看作一个委托类型的变量，通过事件注册、取消多个委托或方法。

举几个代码例子：
``` c#
// 通过委托执行方法
class Program
    {
        static void Main(string[] args)
        {
            Example example = new Example();
            example.Go();
            Console.ReadKey();
        }
    }
    public class Example
    {
        public delegate void DoSth(string str);
        internal void Go()
        {
            //声明一个委托变量，并把已知方法作为其构造函数的参数
            DoSth d = new DoSth(Print);
            string str = "Hello,World";
            //通过委托的静态方法Invoke触发委托
            d.Invoke(str);
        }
        void Print(string str)
        {
            Console.WriteLine(str);
        }
    }
```
- 在CLR运行时，委托DoSth实际上就一个类，该类有一个参数类型为方法的构造函数，并且提供了一个Invoke实例方法，用来触发委托的执行。
- 委托DoSth定义了方法的参数和返回类型
- 通过委托DoSth的构造函数，可以把符合定义的方法赋值给委托
- 调用委托的实例方法Invoke执行了方法

当我们定义委托的时候：
public delegate void GreetingDelegate(string name);

编译器会生成下面这一段代码：
``` c#
public sealed class GreetingDelegate:System.MulticastDelegate{
   public GreetingDelegate(object @object, IntPtr method);
   public virtual IAsyncResult BeginInvoke(string name, AsyncCallback callback, object @object);
   public virtual void EndInvoke(IAsyncResult result);
   public virtual void Invoke(string name);
}
```
<br>

``` c#
// 通过事件执行方法
 public class Example
    {
        public delegate void DoSth(object sender, EventArgs e);
        public event DoSth myDoSth;
        internal void Go()
        {
            //声明一个委托变量，并把已知方法作为其构造函数的参数
            DoSth d = new DoSth(Print);
            object sender = 10;
            EventArgs e = new EventArgs();
            myDoSth += new DoSth(d);
            myDoSth(sender, e);
        }
        void Print(object sender, EventArgs e)
        {
            Console.WriteLine(sender);
        }
    }
```
- 声明了事件myDoSth,事件的类型是DoSth这个委托
- 通过+=为事件注册委托
- 通过DoSth委托的构造函数为事件注册委托实例
- 采用委托变量(参数列表)这种形式，让事件执行方法

稍微总结下：
1. 委托可以理解为指向函数的指针；
2. 委托是类型，事件是对象；
3. 事件是一个private的委托，只能执行add、remove方法。


## 参考
https://blog.csdn.net/wangjiangrong/article/details/79784785
https://www.cnblogs.com/darrenji/p/3967381.html