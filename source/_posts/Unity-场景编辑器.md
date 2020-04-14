---
title: Unity 场景编辑器
date: 2020-01-24 20:55:31
tags:
---

这个场景编辑器是策划配置地图工具，包含NPC、刷怪区、安全区、空气墙、传送点的放置，直接在Unity编辑模式下到处到csv配置。

``` c#
private string[] toolbarNames = new[]
{
    "Npc",
    "AI组",
    "重生组",
    "路径点",
    "逻辑区",
    "设置",
    "地图元素"
};
enum ToolbarEnum
{
    Npc,
    AIGroup,
    RefreshGroup,
    Path,
    NavMesh,
    Setting,
    MapElementExtract,
}
```
将每个layout的配置抽出公共部分为BaseListLayout，每个ListLayout的搜索框和刷新列表绘制DrawList(). 下面是BaseListLayout的简化代码。

``` c#
    public class BaseListLayout
    {
        protected string searchString;

        public virtual void Show(List<BaseInfo> baseInfos)
        {
            searchString = DrawInputTextField(searchString);
            if (string.IsNullOrEmpty(searchString))
                DrawList(baseInfos);
            else
                DrawSearchList(baseInfos, searchString);
        }

        // 绘制搜索结果列表
        protected virtual void DrawSearchList(List<BaseInfo> baseInfos, string searchString)
        {
            List<BaseInfo> searchList = new List<BaseInfo>();
            for (int i = 0; i < baseInfos.Count; i++)
            {
                BaseInfo baseInfo = baseInfos[i];
                searchList.Add(baseInfo);
            }
            DrawList(searchList);
        }

        // 绘制所有列表
        protected virtual void DrawList(List<BaseInfo> baseInfos)
        {
            for (int i = 0; i < baseInfos.Count; i++)
            {
                var baseInfo = baseInfos[i];
                baseInfo.Draw();
            }
        }
    }
```

BaseListLayout首先为最顶部显示个搜索框，虽然只是个搜索框，但输入文本前后以及输入完打印出结果后，都需要计算gui的样式显示rect.sizeDelta/position等。

``` c#
        // 搜索框
        public string DrawInputTextField(string searchText)
        {
            // 获取该窗口2D区域大小
            Rect position = EditorGUILayout.GetControlRect();

            // readonly GUIStyle _textFieldRoundEdge
            GUIStyle textFieldRoundEdge = _textFieldRoundEdge;
            GUIStyle transparentTextField = _transparentTextField;
            GUIStyle gUIStyle = (!string.IsNullOrEmpty(searchText)) ? _textFieldRoundEdgeCancelButton : _textFieldRoundEdgeCancelButtonEmpty;

            // ControlRect宽度减去guiStype的适应宽度
            position.width -= gUIStyle.fixedWidth;

            // 当前界面事件类型：重绘
            if (Event.current.type == EventType.Repaint)
            {
                Color temp = GUI.contentColor;

                if (string.IsNullOrEmpty(searchText))
                {
                    // 未输入文本或者输入空文本，显示灰色半透明字体
                    GUI.contentColor = new Color(0.5f, 0.5f, 0.5f, 0.5f);
                    textFieldRoundEdge.Draw(position, new GUIContent("请输入"), 0);
                }
                else
                {
                    // 输入非空文本显示黑色字体，并清空输入框内容
                    GUI.contentColor = Color.black;
                    textFieldRoundEdge.Draw(position, new GUIContent(""), 0);
                }

                GUI.contentColor = temp;
            }
            Rect rect = position;

            // 计算textFieldRoundEdge的大小，修改rect位置
            float num = textFieldRoundEdge.CalcSize(new GUIContent("")).x - 2f;
            rect.width -= num;
            rect.x += num;
            rect.y += 1f;

            // 获取EditorGUI文本内容
            // return: [sting]The text entered by the user.
            searchText = EditorGUI.TextField(rect, searchText, transparentTextField);

            // 重设gui面板显示参数
            position.x += position.width;
            position.width = gUIStyle.fixedWidth;
            position.height = gUIStyle.fixedHeight;

            // 内容非空时，重置输入框内容
            if (GUI.Button(position, GUIContent.none, gUIStyle) && !string.IsNullOrEmpty(searchText))
            {
                searchText = "";
                GUI.changed = true;
                GUIUtility.keyboardControl = 0;
            }
            return searchText;
        }
    }

```

## NpcListLayout
NpcListLayout继承了BaseListLayout，

先大致看下NpcListLayout的结构

``` c#
    public class NpcListLayout : BaseListLayout
    {
        // 预创建列组，用于展开分类下的列表显示
        private int preGroupCount = 50;
        private List<bool> npcListStatus = new List<bool>();

        private bool showNotEmptyNpcType = false;

        // 重写了show而不是继承它
        public void Show(List<NpcTypeInfo> npcTypeInfos){}

        private void DrawAnimalGroup(List<NpcTypeInfo> npcTypeInfos){}

        private void DrawAnimalGroupByCount(List<NpcTypeInfo> npcTypeInfos, ref int index){}

        private void DrawNpcTypeList(List<NpcTypeInfo> npcTypeInfos, int begin, int end){}

        private void DrawNotEmptyNpcType(List<NpcTypeInfo> npcTypeInfos){}
    }
```

显示非空NPC列表，npcTypeInfos按类别划分的npc，检查npc数量>0加入列表准备界面刷新显示。

``` c#
        private void DrawNotEmptyNpcType(List<NpcTypeInfo> npcTypeInfos)
        {
            List<BaseInfo> list = new List<BaseInfo>();
            for (int i = 0; i < npcTypeInfos.Count; i++)
            {
                var npcType = npcTypeInfos[i];
                if (npcType.npcInfos.Count > 0)
                {
                    list.Add(npcTypeInfos[i]);
                }
            }
            DrawList(list);
        }

```

简化后的DrawAnimalGroupByCount代码，按组绘制animal列表，这里用了两个EditorGUI的方法：EditorGUILayout.Foldout、EditorGUI.indentLevel.
``` c#
        private void DrawAnimalGroupByCount(List<NpcTypeInfo> npcTypeInfos, ref int index)
        {
            // 直接‘一键’增加preGroupCount数量
            for (int i = 0; i < npcTypeInfos.Count; i += preGroupCount)
            {
                int beginIndex = i;
                int endIndex = i + preGroupCount - 1;
                // 增加preGroupCount超长后，需设回npcTypeInfos数量
                if (endIndex >= npcTypeInfos.Count)
                {
                    endIndex = npcTypeInfos.Count - 1;
                }

                // 以头部数据为分类显示
                NpcTypeInfo beginNpcType = npcTypeInfos[beginIndex];
                NpcTypeInfo endNpcType = npcTypeInfos[endIndex];

                string animalTypeStr = SceneEditorObjManager.Instance.GetAnimalTypeString(beginNpcType.animalType);
                string title = string.Format("[{0}]{1}-{2}", animalTypeStr, beginNpcType.typeId, endNpcType.typeId);

                // 记录展开标签
                npcListStatus[index] = EditorGUILayout.Foldout(npcListStatus[index], title, true);
                if (npcListStatus[index])
                {
                    // EditorGUI.indentLevel为文本缩进距离级别
                    EditorGUI.indentLevel += 1;
                    DrawNpcTypeList(npcTypeInfos, beginIndex, endIndex);
                    EditorGUI.indentLevel -= 1;
                }
                index += 1;
            }
        }
```
> EditorGUI提供了一堆编辑器下刷新界面的参数接口。