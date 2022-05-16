using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
using Unity.Collections;

enum BakeType
{
    VertAnimTex,
    RigAnimTex,
    BakeBoth
}
[Serializable]
public struct MeshRigName
{
    public string smrName;
    public string[] rigName;
}
//[CreateAssetMenu(fileName = "ExportConfig", menuName = "GPUMecanimExportConfig", order = 1)]
public class GPUMecAnimExportData : ScriptableObject
{
    public const int _DEFAULT_FPS = 24;

    public const string _DEFAULT_PATH = "Assets/GPUMecAnim/ExportedAnimations";
    public const string _DEFAULT_MAT_NAME = "GPUMecanimMat";
    public const string _DEFAULT_ROOTBONE_NAME = "Bip001";
    public const string _DEFAULT_VERT_SHADER_NAME = "GPUMecAnim/VertAnimation";
    public const string _DEFAULT_RIG_SHADER_NAME = "GPUMecAnim/RigAnimation";

    public const bool _DEFAULT_EXPORT_OUTSIDE = false;

    public int exportFps;
    public string exportPath;
    public string materialName;
    public string rootBoneName;
    public Shader vertShader;
    public Shader rigShader;
    public bool exportPrefabOutside;

    public string prefabPath { get; private set; }
    public string[] rigNames { get; private set; }

    public void Init()
    {
        exportPath = _DEFAULT_PATH;
        exportFps = _DEFAULT_FPS;
        materialName = _DEFAULT_MAT_NAME;
        rootBoneName = _DEFAULT_ROOTBONE_NAME;
        vertShader = Shader.Find(_DEFAULT_VERT_SHADER_NAME);
        rigShader = Shader.Find(_DEFAULT_RIG_SHADER_NAME);
        exportPrefabOutside = _DEFAULT_EXPORT_OUTSIDE;
    }
    public void SetPrefabPath(string path) { prefabPath = path; }
    public void SetRigNames(string[] names) { rigNames = names; }

}
public class GPUMecAnimWindow : EditorWindow
{
    //public static string 
    SerializedObject serializedObject;

    #region Export Property
    GPUMecAnimExportData exportConfig;
    string exportPath;// "Assets/GPUMecAnim/ExportedAnimations";
    int exportFps;// 24;
    string materialName;
    string rootBoneName;// "Bip001";
    Shader vertShader;
    Shader rigShader;
    bool exportPrefabOutside;
    #endregion

    #region Bake Property
    private Mesh[] skinnedMeshRef;
    public string[] rigNames = new string[0];
    //public MeshRigName[] meshRigNames = new MeshRigName[0];

    string prefabPath;
    BakeType bakeType;
    GameObject prefab;
    SkinnedMeshRenderer[] smrs;
    #endregion

    #region Config
    static int _MAX_VERTEX = 1024; // floor(2048/2)
    GUIStyle titleStyle;
    #endregion

    #region Temp Flag
    Animator animator = null;
    Transform rootBone = null;
    string btnString = "";
    Vector2 scrollPos;
    bool modifiable_config = false;
    bool vertexAble = true;
    bool modifiable_rootBone = false;
    #endregion

    void InitConfig(bool forceUpdate = false)
    {
        if (serializedObject == null || forceUpdate) serializedObject = new SerializedObject(this);
        if (titleStyle == null || forceUpdate)
        {
            titleStyle = new GUIStyle();
            titleStyle.fontSize = 20;
            titleStyle.normal.textColor = Color.white;
        }
        if (animator == null && prefab != null)
        {
            animator = prefab.GetComponent<Animator>();
        }

    }

    private void OnEnable()
    {
        CreateExportAsset(false);
    }

    private void OnDisable()
    {
        ApplyExportConfig();
    }

    private void CreateExportAsset(bool forceCreate)
    {
        // Get Current Script's Asset Path
        string _scriptName = "GPUMecAnimWindow";
        string dir = AssetDatabase.FindAssets(_scriptName)[0];
        dir = AssetDatabase.GUIDToAssetPath(dir).Replace((@"/" + _scriptName + ".cs"), "");

        dir += "/ExportConfig.Asset";
        exportConfig = AssetDatabase.LoadAssetAtPath<GPUMecAnimExportData>(dir);
        if (exportConfig == null || forceCreate)
        {
            exportConfig = CreateInstance<GPUMecAnimExportData>();
            exportConfig.Init();
            AssetDatabase.DeleteAsset(dir);
            AssetDatabase.CreateAsset(exportConfig, dir);
            AssetDatabase.Refresh();
        }
        InitExportConfig();
        if (forceCreate) RefreshGUILayout();
    }
    private void RefreshGUILayout()
    {
        GUIUtility.keyboardControl = 0; // To Refresh GUILayoutFields https://answers.unity.com/questions/180659/editorgui-refresh.html
    }
    private void InitExportConfig()
    {
        exportPath = exportConfig.exportPath;
        exportFps = exportConfig.exportFps;
        materialName = exportConfig.materialName;
        rootBoneName = exportConfig.rootBoneName;
        vertShader = exportConfig.vertShader;
        rigShader = exportConfig.rigShader;
        exportPrefabOutside = exportConfig.exportPrefabOutside;
    }

    private void ApplyExportConfig()
    {
        exportConfig.exportPath = exportPath;
        exportConfig.exportFps = exportFps;
        exportConfig.materialName = materialName;
        exportConfig.rootBoneName = rootBoneName;
        exportConfig.vertShader = vertShader;
        exportConfig.rigShader = rigShader;
        exportConfig.exportPrefabOutside = exportPrefabOutside;
    }


    void OnGUI()
    {
        // FOR TEMP TEST ONLY
        //if (GUILayout.Button("因为修改了代码所以重新获取一下Style配置。")) InitConfig(true);


        InitConfig();
        GUILayout.Space(10f);

        GUILayout.BeginHorizontal();
        {
            GUILayout.Label("导出配置", titleStyle);
            if (GUILayout.Button("重置全部导出的配置")) CreateExportAsset(true);
        }
        GUILayout.EndHorizontal();

        GUILayout.Space(10f);
        // Export Settings
        GUILayout.BeginVertical();
        {
            EditorGUIUtility.labelWidth = 100f;
            GUI.enabled = modifiable_config;

            GUILayout.BeginHorizontal();
            {
                exportFps = EditorGUILayout.IntField("导出动画FPS", exportFps, GUILayout.Width(130));
                if (GUILayout.Button("重置", GUILayout.Width(50)))
                {
                    exportFps = GPUMecAnimExportData._DEFAULT_FPS;
                    RefreshGUILayout();
                }
            }
            GUILayout.EndHorizontal();

            GUILayout.Space(10f);

            GUILayout.BeginHorizontal();
            {
                exportPath = EditorGUILayout.TextField("导出路径", exportPath, GUILayout.Width(500));
                if (GUILayout.Button("重置", GUILayout.Width(50)))
                {
                    exportPath = GPUMecAnimExportData._DEFAULT_PATH;
                    RefreshGUILayout();
                }
            }
            GUILayout.EndHorizontal();

            GUILayout.Space(10f);

            EditorGUIUtility.labelWidth = 215f;
            GUILayout.BeginHorizontal();
            {
                materialName = EditorGUILayout.TextField("导出材质名（材质名_Mesh名_材质模式）", materialName, GUILayout.Width(430));
                if (GUILayout.Button("重置", GUILayout.Width(50)))
                {
                    materialName = GPUMecAnimExportData._DEFAULT_MAT_NAME;
                    RefreshGUILayout();
                }
            }
            GUILayout.EndHorizontal();

            GUILayout.Space(10f);

            GUILayout.BeginHorizontal();
            {
                vertShader = (Shader)EditorGUILayout.ObjectField("顶点动画材质Shader", vertShader, typeof(Shader), false, GUILayout.Width(430));
                if (GUILayout.Button("重置", GUILayout.Width(50)))
                {
                    vertShader = Shader.Find(GPUMecAnimExportData._DEFAULT_VERT_SHADER_NAME);
                    RefreshGUILayout();
                }
            }
            GUILayout.EndHorizontal();

            GUILayout.Space(10f);

            GUILayout.BeginHorizontal();
            {
                rigShader = (Shader)EditorGUILayout.ObjectField("骨骼动画材质Shader", rigShader, typeof(Shader), false, GUILayout.Width(430));
                if (GUILayout.Button("重置", GUILayout.Width(50)))
                {
                    rigShader = Shader.Find(GPUMecAnimExportData._DEFAULT_RIG_SHADER_NAME);
                    RefreshGUILayout();
                }
            }
            GUILayout.EndHorizontal();

            GUILayout.Space(10f);

            GUILayout.BeginHorizontal();
            {
                exportPrefabOutside = EditorGUILayout.Toggle("是否将Prefab单独导出到文件外部", exportPrefabOutside, GUILayout.Width(250));
                if (GUILayout.Button("重置", GUILayout.Width(50)))
                {
                    exportPrefabOutside = GPUMecAnimExportData._DEFAULT_EXPORT_OUTSIDE;
                    RefreshGUILayout();
                }
            }
            GUILayout.EndHorizontal();

            GUILayout.Space(10f);

            GUI.enabled = true;

            btnString = modifiable_config ? "确定" : "修改";
            if (GUILayout.Button(btnString, GUILayout.Width(100))) modifiable_config = !modifiable_config;
        }
        GUILayout.EndVertical();

        GUILayout.Space(20f);

        GUILayout.Label("烘培设置", titleStyle);

        GUILayout.Space(10f);

        // Import Settings
        GUILayout.BeginHorizontal();
        {
            EditorGUIUtility.labelWidth = 80f;
            //prefabPath = EditorGUILayout.TextField("Prefab路径", prefabPath, GUILayout.Width(500));
            //if (GUILayout.Button("手动导入", GUILayout.Width(100)))
            //{
            //    prefab = ImportPrefabAtPath(prefabPath);
            //    if(prefab != null) rootBone = prefab.transform.Find(rootBoneName);
            //}

            prefab = (GameObject)EditorGUILayout.ObjectField("Prefab", prefab, typeof(GameObject), false, GUILayout.Width(350));
            if (prefab != null)
            {
                ImportPrefab(prefab);
                if (rootBoneName.Length > 0) rootBone = prefab.transform.Find(rootBoneName);
                prefabPath = AssetDatabase.GetAssetPath(prefab);
            }
        }
        GUILayout.EndHorizontal();

        if (prefab == null) return;

        GUILayout.Space(10f);

        // ReadOnly infomation (Prefab,Mesh,Number of Vertice and Bones)
        GUI.enabled = false;
        {
            GUILayout.Space(10f);

            //prefab = (GameObject)EditorGUILayout.ObjectField("待Bake的Prefab", prefab, typeof(GameObject), false, GUILayout.Width(250));

            GUILayout.BeginVertical();
            {
                for (int i = 0; i < skinnedMeshRef.Length; i++)
                {
                    Mesh mesh = skinnedMeshRef[i];
                    int vertexCount = mesh.vertexCount;
                    int bonesCount = mesh.bindposes.Length;
                    vertexAble = vertexCount <= _MAX_VERTEX;
                    if (!vertexAble) bakeType = BakeType.RigAnimTex;
                    GUILayout.BeginHorizontal();
                    {
                        EditorGUIUtility.labelWidth = 80f;
                        mesh = (Mesh)EditorGUILayout.ObjectField($"Mesh #{i}", mesh, typeof(Mesh), false, GUILayout.Width(250));
                        EditorGUIUtility.labelWidth = 50f;
                        GUILayout.Space(10f);
                        vertexCount = EditorGUILayout.IntField("顶点数", vertexCount, GUILayout.Width(100));
                        GUILayout.Space(10f);
                        bonesCount = EditorGUILayout.IntField("骨骼数", bonesCount, GUILayout.Width(100));
                    }
                    GUILayout.EndHorizontal();
                }
            }
            GUILayout.EndVertical();
        }
        GUI.enabled = true;

        GUILayout.Space(10f);

        GUILayout.BeginHorizontal();
        {

            if (modifiable_rootBone)
            {
                EditorGUIUtility.labelWidth = 150f;

                GUILayout.BeginHorizontal();
                {
                    rootBoneName = EditorGUILayout.TextField("需要删除的骨骼根节点名", rootBoneName, GUILayout.Width(250));
                    if (GUILayout.Button("重置", GUILayout.Width(50)))
                    {
                        rootBoneName = GPUMecAnimExportData._DEFAULT_ROOTBONE_NAME;
                        RefreshGUILayout();
                    }

                    if (GUILayout.Button("搜索节点", GUILayout.Width(100)))
                    {
                        if (rootBoneName.Length > 0)
                        {
                            rootBone = prefab.transform.Find(rootBoneName);
                            if (rootBone != null) modifiable_rootBone = false;
                        }
                    }
                }
                GUILayout.EndHorizontal();
            }
            else
            {
                EditorGUIUtility.labelWidth = 80f;
                GUI.enabled = false;
                rootBone = (Transform)EditorGUILayout.ObjectField("RootBone", rootBone, typeof(Transform), false, GUILayout.Width(250));
                GUI.enabled = true;
                if (GUILayout.Button("修改需要删除的骨骼根节点", GUILayout.Width(200)))
                {
                    modifiable_rootBone = true;
                }
            }

        }
        GUILayout.EndHorizontal();

        GUILayout.Space(20f);

        // BakeType Setting and Bake Btn
        GUILayout.BeginHorizontal();
        {
            GUILayout.BeginVertical();
            {
                EditorGUIUtility.labelWidth = 100f;
                if (vertexAble)
                {
                    bakeType = (BakeType)EditorGUILayout.EnumPopup("贴图烘焙格式选择", bakeType, GUILayout.Width(230));
                }
                else
                {
                    EditorGUILayout.LabelField("贴图烘焙格式选择       RigAnimTex", GUILayout.Width(200));
                }
                GUILayout.Space(30f);

                btnString = "Bake";
                int width = 100;
                if (!vertexAble && bakeType != BakeType.RigAnimTex)
                {
                    btnString = $"顶点数过多无法使用顶点动画贴图,数量应小于{_MAX_VERTEX}";
                    width = CulcLabelWidth(btnString);
                    GUI.enabled = false;
                }
                else if (bakeType != BakeType.VertAnimTex)
                {
                    if (animator == null && prefab != null)
                    {
                        animator = prefab.GetComponent<Animator>();
                    }
                    if (animator.applyRootMotion)
                    {
                        btnString = "此Prefab的Animator启用了RootMotion，请关闭它。";
                        width = CulcLabelWidth(btnString);
                        GUI.enabled = false;
                    }
                    else
                    {
                        GUI.enabled = true;
                    }
                }
                else GUI.enabled = true;

                if (GUILayout.Button(btnString, GUILayout.Width(width), GUILayout.Height(50)))
                {
                    if (rootBone == null) rootBoneName = "";
                    BakeAnimationTexture();
                }

                GUI.enabled = true;

            }
            GUILayout.EndVertical();

            GUILayout.Space(20f);

            GUILayout.BeginVertical();
            {
                if (bakeType == BakeType.RigAnimTex || bakeType == BakeType.BakeBoth)
                {
                    // BoneNameList (Bone Animation Only)
                    Color colorBefore = GUI.backgroundColor;
                    GUI.backgroundColor = Color.grey;
                    scrollPos = EditorGUILayout.BeginScrollView(scrollPos, GUILayout.Width(430), GUILayout.Height(200));
                    {
                        SerializedProperty rigNamesProp = serializedObject.FindProperty("rigNames");
                        //SerializedProperty meshToRigNamesProp = serializedObject.FindProperty("meshRigNames");
                        EditorGUILayout.PropertyField(rigNamesProp, GUILayout.Width(300));
                        //EditorGUILayout.PropertyField(meshToRigNamesProp, GUILayout.Width(400));

                    }
                    EditorGUILayout.EndScrollView();
                    GUI.backgroundColor = colorBefore;
                }
            }
            GUILayout.EndVertical();
            GUILayout.FlexibleSpace();
        }
        GUILayout.EndHorizontal();



        serializedObject.ApplyModifiedProperties();
    }

    void ImportPrefab(GameObject prefab)
    {
        smrs = prefab.GetComponentsInChildren<SkinnedMeshRenderer>();
        skinnedMeshRef = new Mesh[smrs.Length];
        for (int i = 0; i < smrs.Length; i++)
        {
            skinnedMeshRef[i] = smrs[i].sharedMesh;
        }

        //SaveMeshRigName();
        //rigNames = new string[0];
        serializedObject = new SerializedObject(this);
    }

    void BakeAnimationTexture()
    {
        ApplyExportConfig();

        // rid of dup elem
        string[] tempRigNames = RemoveDupAndCheckExist(prefab,rigNames);
        exportConfig.SetRigNames(tempRigNames);
        //RemoveDupMeshRigName();
        //Dictionary<SkinnedMeshRenderer,string[]> smrToRigName = ConstructMeshRigNameToDic();       

        BakeGPUMecAnim.BakeAnimation(
            prefabPath,
            exportConfig,
            bakeType != BakeType.RigAnimTex,
            bakeType != BakeType.VertAnimTex
        );
    }
    static string[] RemoveDupAndCheckExist(GameObject prefab, string[] rigNames)
    {
        List<int> dupIds = new List<int>();
        List<string> rigNameList = new List<string>();
        for (int i = 0; i < rigNames.Length; i++)
        {
            if (dupIds.Contains(i + 1)) continue;
            for (int j = i + 1; j < rigNames.Length - i; j++)
            {
                if (rigNames[i] == rigNames[j])
                {
                    dupIds.Add(j);
                }
            }
            if (!dupIds.Contains(i) && rigNames[i] != "")
            {
                bool isFound = false;
                string name = rigNames[i];
                new List<Transform>(prefab.GetComponentsInChildren<Transform>()).ForEach
                ((trans) => 
                    { 
                        if (trans.name == rigNames[i]) { isFound = true; return; } 
                    }
                );

                if (isFound) rigNameList.Add(name);
                else Debug.LogError($"can't find joint named {name}");
            }
        }
        return rigNameList.ToArray();
    }

    static int CulcLabelWidth(string label, GUIStyle style = null)
    {
        // 12 is Default font size, to modify this with custom GUIStyle use {GUIStyle}.fontSize instead
        int fontSize = style == null ? 12 : style.fontSize;
        return label.Length * fontSize;
    }
    static GUILayoutOption GUILayoutWidth(int label, GUIStyle style = null) => GUILayoutWidth(label.ToString(), style);

    static GUILayoutOption GUILayoutWidth(string label, GUIStyle style = null)
    {
        int width = CulcLabelWidth(label, style);
        return GUILayout.Width(width);
    }
}
