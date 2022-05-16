using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public static class MenuBakeGPUMecAnim
{
    [MenuItem("GPUMecAnim/OpenWindow")]
    public static void ShowWindow()
    {
        //显示现有窗口实例。如果没有，请创建一个。
        EditorWindow.GetWindow(typeof(GPUMecAnimWindow));
    }
}
