---
title: 浅谈衣柜系统
date: 2020-04-10 11:29:26
tags:
---

　　游戏角色换装分为以下几步：

　　　　1.替换蒙皮网格

　　　　2.刷新骨骼

　　　　3.替换材质

 

　　上面这种是比较简单的换装，可以实现，但是一般我们为了降低游戏的Draw Call会合并模型的网格，这就需要我们重新计算UV，还要合并贴图和材质。这种复杂的实现分为以下几步：

　　　　1.替换蒙皮网格（或者直接替换模型换装部位的GameObject，因为合并的时候会合并所有的蒙皮网格，而不会关心它是否属于原来角色身体的一部分，而且如果需要替换的部位有多个配件拥有独立的网格和贴图，那这种方式都可以正常执行。我下面的代码就是直接替换了换装部位的GameObject）

　　　　2.合并所有蒙皮网格

　　　　3.刷新骨骼

　　　　4.附加材质（我下面是获取第一个材质作为默认材质）

　　　　5.合并贴图（贴图的宽高最好是2的N次方的值）

　　　　6.重新计算UV


## 衣柜系统

点击主界面-衣柜按钮，打开衣柜主界面，隐藏主界面并关闭click响应，隐藏物品快捷使用；

在界面代码OnOpen()中调用WardrobeMgr:EnterLockerRoom()进入更衣室；

加载衣柜专属模型相机和模型灯光，将模型相机和灯光都挂到ObjParent下，将主相机设为lua全局访问：rawset(_G, 'CameraTransform', ObjectManager.MainCamera.transform)；

获取模型的位置和朝向角度，设置相机的目标位置和前向偏转local targetRotation = Quaternion.LookRotation，将摄像机参数传入WardrobeCameraController；

设置其他模块开关:角色不可点地移动、角色不可键盘移动、隐藏场景摄像机、隐藏hub；

延迟处理相机景深等参数，并将主角模型隐藏。

正式处理衣柜相关数据：清空/设置收货人数据，请求服务器积分，获取目标角色已有时装列表，设置模型显示光效；

处理进入时装更衣室场景信息，清理坐骑模型，释放坐骑特效，重置角色阴影，设置武器显示（格斗家武器较特殊）：
- 恢复坐骑材质，模型回收；
- 重置动画控制器；
- 恢复角色节点位置；
- 坐骑乘客=null；
- 清理坐骑模型资源（缓存或销毁）；
- 坐骑绑点clear；
- 各种坐骑参数恢复默认值：
    - IsControl 受控状态
    - _mount 坐骑对象
    - _master 主人
    - _passenger 乘客
    - _hasPassenger
    - _hasMaster
    - _mountAssetPath
    - _isMountLoaded
    - _mountAnimator
    - _curMountAnimatorParamNameSet 当前缓存的mount animator controller的parameter集合
    - _bodyMaterialPath 各部件的材质路径


显示时装衣物列表，处理翻页视图UIPageView。

<br>

### 翻页视图UIPageView

``` c#
namespace UnityEngine.UI
{
    public class UIPageView : MonoBehaviour, IBeginDragHandler, IEndDragHandler
    {
        private ScrollRect rect;                                //滑动组件  
        private float targethorizontal = 0;                     //滑动的起始坐标  
        private bool isDrag = false;                            //是否拖拽结束  
        private List<float> posList = new List<float>();        //求出每页的临界角，页索引从0开始 
        public Action<int> pageChangeEvent;                     //回调给Lua页签变化事件

        public void OnBeginDrag(PointerEventData eventData)
        {
            // 记录拖拽状态和scrollView初始移动位置
        }

        public void OnEndDrag(PointerEventData eventData)
        {
            // 计算终末位置所属的pageIndex

            if(currentPageIndex != index) currentPageIndex = index;
            if(pageChangeEvent!=null) pageChangeEvent(index);   // 通知Lua页签变更
        }

        private void Update()
        {
            // 对scrollview位置插值动画
        }
    }
}
```


显示玩家模型用的是InterfaceModel.SetDummyPlayer，这里分为设置赠送时装和自己穿戴的时装模型显示，自己的时装用InterfaceModel.SetPlayer，设置模型属性：
- 模型lod
- 模型阴影shadowType
- 角色光效
- 雕塑判断，太阳城雕塑判断
- 模型layer
- 模型播放待机动画

设置角色模型，获取模型路径、身体材质路径、武器材质路径、武器模型路径，有数据变更则更新模型显示，模型替换材质，更新灯光和特效，场景模型采样环境光，设置阴影状态，替换shader；

C# SetModel()，判定模型资源路径有变否则返回，回收旧模型：
- 清理部件
- 恢复身体和武器材质
- 清理渲染节点缓存，被回收了旧不需要缓存材质
- 销毁rigidbody
- 显示武器 ?
- 隐藏身体obj，计入缓存池，如果入池出错则直接Destroy
- 还原/恢复animator controller

设置模型材质SetModelMaterial()，替换的是sharedMaterial，加载assetObject，预先判断该assetObject是否存在，不存在可选同步或异步模式加载bundle，设置引用计数，返回assetObject.asset as Material。
assetObject则在Update()中设置自身的加载状态。

角色添加特效，获取时装上的特效绑点集合{特效绑点，特效名称}，BattleEffectManager.PlayEffectOnActor, 特效播放有自己的一套规则，主角和主角机甲的非受击特效优先播放。

全部模型特效加载完成后，调用lua回调LoadModelCallback，再设置一些动画播放、武器特效、角色灯光、机甲特效之类的。

> 目前时装做的比较简单，可能就是换模型换材质，没有深层的重新绑点或者计算蒙皮信息骨骼权重之类的，染色的处理也是换材质换shader。

<br>

#### 关于AssetBundle.LoadFromFileAsync第三个参数offset

offset: An optional byte offset. This value specifies where to start reading the AssetBundle from.
大致意思是LoadFromFileAsync可以支持文件偏移读取AssetBundle，使用这个方法可以快速读取ab资源而且ab本身不会被assetStudio直接打开，虽然不算特别好的‘加密’方案，但是对AssetBundle.LoadFromMemory(Async)的读取速度来说是快很多了，本来任何加密方式在破解大神看来都是云云，没有必要牺牲80%的ab加载时间去拦20%的人。

文件偏移打包，打包完成后用文件流进行字节偏移处理，每个文件的偏移用自身assetBundleHash，拷贝offset到文件头，再用File.OpenWrite()将全部buffer数据写入.

``` c#
foreach (string bundleName in bundleNames)
{
    string filepath = outputPath + "/" + bundleName;
    // 利用 hashcode 做偏移 
    string hashcode = manifest.GetAssetBundleHash(bundleName).ToString();
    ulong offset = Utility.GetOffset(hashcode);
    if ( offset > 0)
    {
        byte[] filedata = File.ReadAllBytes(filepath);
        int filelen = ((int)offset + filedata.Length);
        byte[] buffer = new byte[filelen];
        copyHead(filedata, buffer, (uint)offset);
        copyTo(filedata, buffer, (uint)offset);
        FileStream fs = File.OpenWrite(filepath);
        fs.Write(buffer, 0, filelen);
        fs.Close();
        offsets  += filepath + " offset:" + offset + "\n";
    }
    WriteItem(stream, bundleName, filepath, hashcode);
}
```

<br>

用异步的方式加载，用Profiler.GetTotalAllocatedMemoryLong()内存计数，AssetBundle.LoadFromFileAsync第二个参数为0表示不进行内容校验，await等待assetBundleRequest完成后，进行assetBundle.LoadAsset
``` c#
// 基于offset加载AssetBundle
async void onLoadWithOffsetClicked()
{
    if (offsetBundle)
        offsetBundle.Unload(true);

    var current_memory = Profiler.GetTotalAllocatedMemoryLong();
    display_image.texture = null;
    var path = System.IO.Path.Combine(Application.streamingAssetsPath, "assets_previews_offset");
    var assetBundleRequest = AssetBundle.LoadFromFileAsync(path, 0, offset);
    await assetBundleRequest;
    var texture = assetBundleRequest.assetBundle.LoadAsset<Texture2D>("download.jpg");
    display_image.texture = texture;
    offsetBundle = assetBundleRequest.assetBundle;

    Debug.Log("Offset Load Complete:" + (Profiler.GetTotalAllocatedMemoryLong() - current_memory));
}
```

<br>

## 坐骑系统

坐骑面板点选规则和时装一样，跳过直接说坐骑绑点和动画状态机。

获取坐骑挂点偏移，坐骑gameObject有不同高度，而且人物的座椅位置相对坐骑GameObject又各有偏差，举例小车坐骑的人物挂点在汽车底盘上面一点，而飞兽的人物挂点在坐骑背上，对于飞兽gameObject坐标相对的座椅挂点就在gameObject position后上方一些位置，这就存在挂点偏移，每个坐骑都可能有不同的挂点偏移，这个随坐骑模型的形状、大小而定，人物肯定是挂载在模型的表面位置。

同样是在C# Actor_Mount.SetMount()设置坐骑绑点参数：
- _mountPoint 人物的坐骑节点名G_zuoqi
- _mountOffset 绑点偏移
- _mountRotation 坐骑旋转

LoadGameObjectAsync加载坐骑模型回调，检查返回路径与需要加载模型路径匹配、或者当前坐骑模型和需要加载的模型相同；

初始化坐骑挂点骨骼，根据骨骼名字查找骨骼节点，目前时装骨骼都是在一个层级下面，即肩膀-胳膊-手是同一个层级，这样Transform.GetChild(index)查找起来比较快，如果找不到节点就关联一个骨骼，还是找不到就返回自身位置；

初始化坐骑渲染部件，先清理渲染节点信息，恢复模型的材质为prefab的公共材质，将子物体内所有标为Tag_Mount的SkinnedMeshRenderer组件，生成对于的RendererNode：
- renderer
- hasMultiMaterial
- sharedMaterial

更新渲染材质，先记录所使用的材质路径，释放当前使用的已经实例化的材质，做个一容错，如果matPath传入为空，则恢复原材质，再立刻设置为新材质，调用materialUpdateCallBack，
更新shader，更新环境光采样；

坐骑主题加载完毕，**开始绑定坐骑**，将角色模型绑定到坐骑指定绑点上，如果获取绑点失败，则将角色模型绑定到第一个子物体上，绑定这个词听起来高大上，其实就是transform.SetParent()，随后设置上坐骑后的偏移和偏移角度，再重置animator动作，强制刷新实时阴影。

阴影应该在模型和相机参数完成设置后刷新，Actor_Shadow存在两种阴影类型：圆片阴影+真实阴影。原片阴影挂载角色actor上需要每帧刷新阴影相对actor的偏移位置，真实阴影则是设置shader参数，将角色高度和_propertyShadowOffset传入。

<br>

## 参考
https://zhuanlan.zhihu.com/p/75964237