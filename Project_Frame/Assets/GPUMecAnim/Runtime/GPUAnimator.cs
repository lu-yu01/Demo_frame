using System;
using System.Collections.Generic;
using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;
#endif

public enum FadeTimeType
{
    Time = 0,
    NormalizedTime,
}

[Serializable]
public struct MeshToJointName
{
    public string jointName;
    public MeshRenderer mr;
    
    public MeshToJointName(string name, MeshRenderer r) 
    {
        jointName = name;
        mr = r;
    }
}

[ExecuteAlways]
public class GPUAnimator : MonoBehaviour
{
    // =======Property======= //

    #region Static String(ShaderKeywords & ShaderPropNames)
    public const string kw_play = "ANIM_IS_PLAYING";
    public const string kw_blend = "ANIM_BLENDING";
    public static int pn_v2_range = Shader.PropertyToID("_PosRange");
    public static int pn_tex2d_vert = Shader.PropertyToID("_VertPosTex");
    public static int pn_tex2d_normal = Shader.PropertyToID("_NormTex");
    public static int pn_tex_rig = Shader.PropertyToID("_RigTex");
    public static int pn_int_texidx = Shader.PropertyToID("_TexArrayIdx");
    public static int pn_int_joint_boneid = Shader.PropertyToID("_JointBoneId");
    public static int pn_float_offsetX = Shader.PropertyToID("_OffsetX");
    public static int pn_float_offsetX_pre = Shader.PropertyToID("_PreOffsetX");
    public static int pn_float_sampleY = Shader.PropertyToID("_AnimY");
    public static int pn_float_sampleY_pre = Shader.PropertyToID("_PreAnimY");
    public static int pn_float_blendweight = Shader.PropertyToID("_BlendWeight");
    public static int pn_matrix_ls = Shader.PropertyToID("_LocalScaleMatrix");
    public static int pn_matrix_l2w_root = Shader.PropertyToID("_RootLocalToWorld");
    #endregion

    #region Debug ( move to 'Properties' and protect it if needed )
    [Header("Debug用参数")]
    public GPUMecAnimConfig mConfigFromAsset;
    public string CurAnimName;

    [HideInInspector] public Material vertAnimMat;
    public Material rigAnimMat;
    public Material jointAnimMat;

    #endregion

    #region Public Prop
    [Header("参数")]
    public float GlobalSpeed = 1;
    [HideInInspector] public bool RigMode = false;


    [HideInInspector] public bool baking = false;
    private bool lastRigMode = false;
    private float lastSpeed = 0;
    private float lastXOffset = 0;
    private float curXOffset = 0;
    #endregion

    #region Clip
    protected float animSpeed;
    protected float animDuration;
    protected float animTexYOffset;
    protected float animTexYLength;
    protected float preAnimTexYLength;
    protected float preAnimTexYOffset;
    protected bool loop;
    #endregion

    #region Properties
    private Transform trans;
    [HideInInspector] public int mConfigHash;
    [HideInInspector] public MeshRenderer[] mMRs;
    protected GPURuntimeAnimConfig_Prefab mPrefabAnimConfig;

    protected GPUAnimUpdater mUpdater;
    protected MaterialPropertyBlock mProps;
    protected Texture2DArray vertPosTex;
    protected Texture2DArray normTex;
    protected Texture2D rigTex;

    private float curT;
    private float preT;
    private float playWeight;
    private MeshRenderer[] availableJointMrArray;

    //public List<MeshToJointName> objMesh2JointNameList = new List<MeshToJointName>();
    public MeshToJointName[] objMesh2JointNameList;
    #endregion


    // =======Function======= //

    #region Public Function
    public void Play(string animName, float fadeTime = 0f, FadeTimeType fadeTimeType = FadeTimeType.NormalizedTime)
    {
        SaveClipInfo(animName);

        ResetMaterialProperty(animName);

        if (mUpdater.IsPlaying && fadeTime > 0)
        {
            fadeTime *= fadeTimeType == FadeTimeType.NormalizedTime ? animDuration : 1;
            SetKeywordEnableOnCurMeshRenderer(kw_blend, true);
            mUpdater.SetFadeCallback(() => SetKeywordEnableOnCurMeshRenderer(kw_blend, false));
        }
        bool isLoop = loop;
        float startTime = 0;
        mUpdater.Play(startTime, animDuration, animSpeed, isLoop, fadeTime);
        UpdatePropToMat();

        SetKeywordEnable(kw_play, true);
    }
    public void PlayOnce(string animName)
    {
        Play(animName);
        mUpdater.Stop();
    }

    public void Stop()
    {
        mUpdater.Stop();
    }
    public void Pause()
    {
        lastSpeed = GlobalSpeed;
        GlobalSpeed = 0;
        mUpdater.Pause();
    }
    public void Resume()
    {
        GlobalSpeed = lastSpeed;
        mUpdater.Resume();
    }
    public void SetRigMode(bool rigmode)
    {
        RigMode = rigmode;
        lastRigMode = RigMode;
    }
    public void ResetRigModeAndMat(bool rigmode)
    {
        SetRigMode(rigmode);
#if UNITY_EDITOR
        if (!Application.isPlaying) ResetMaterialPropertyInEditor(CurAnimName);
        else
#endif
            ResetMaterialProperty(CurAnimName);
    }
    #endregion



    #region Core
    /// <summary>
    /// Update is called once per frame
    /// </summary>
    public void UpdateAnimator(float deltaTime)
    {
        if (!mUpdater.IsPlaying)
        {
            UpdatePropToJointMat(false); // Only Update Joint position
            return;
        }
        if (RigMode != lastRigMode) ResetRigModeAndMat(RigMode);
        deltaTime *= GlobalSpeed;
        mUpdater.Update(deltaTime);
        UpdatePropToMat();
    }

    private void InitProperties()
    {
        if (vertAnimMat == null && rigAnimMat == null) Debug.LogError("没有材质，检查一下导出是否成功，再导出一次");

        if (Application.isPlaying && !GPUAnimatorMgr.instance())
        {
            GameObject go = new GameObject("GPUAnimatorMgr");
            go.AddComponent<GPUAnimatorMgr>();
        }

        mUpdater = new GPUAnimUpdater();
        mProps = new MaterialPropertyBlock();
        if (rigAnimMat != null)
        {
            rigTex = (Texture2D)rigAnimMat.GetTexture(pn_tex_rig);
        }
        if (vertAnimMat != null)
        {
            vertPosTex = (Texture2DArray)vertAnimMat.GetTexture(pn_tex2d_vert);
            normTex = (Texture2DArray)vertAnimMat.GetTexture(pn_tex2d_normal);
        }

#if UNITY_EDITOR
        if (!Application.isPlaying)
        {
            animNameList.Clear();
            for (int i = 0; i < mConfigFromAsset.clipConfigs.Count; i++)
            {
                string name = mConfigFromAsset.clipConfigs[i].animName;
                animNameList.Add(name);
            }
        }
        else
#endif
        {
            mConfigHash = mConfigFromAsset.GetHashCode();
            GPUAnimatorMgr.instance().AddGpuAnimator(mConfigHash, this);
            var configExist = GPUAnimatorMgr.instance().GetPrefabAnimConfig(mConfigHash, out mPrefabAnimConfig);

            if (!configExist) throw new System.Exception(string.Format("prefab anim config for prefab {0} is missing", mConfigHash));
        }
    }

    /// <summary>
    /// pass properties to Instancing Material via MaterialPropertyBlock 
    /// </summary>
    private void ResetMaterialProperty(string animName)
    {
        for (int i = 0; i < mMRs.Length; i++)
        {
            mMRs[i].sharedMaterial = RigMode ? rigAnimMat : vertAnimMat;
        }
        curXOffset = 0;
        for (int i = 0; i < mMRs.Length; i++)
        {
            MeshRenderer mr = mMRs[i];
            mr.GetPropertyBlock(mProps);
            {
                if (RigMode)
                {
                    GPURuntimeAnimConfig_Anim animConfig = mPrefabAnimConfig.GetAnimTexConfig("", animName);
                    animConfig.GetConfig(ConfigType.Rig, out GPUMecAnimConfigElem rigConfig);
                    curXOffset = rigConfig.baseXPos;
                }
                else
                {
                    GPURuntimeAnimConfig_Anim animConfig = mPrefabAnimConfig.GetAnimTexConfig(mr.name, animName);
                    animConfig.GetConfig(ConfigType.Vert, out GPUMecAnimConfigElem vertPosConfig);
                    curXOffset = vertPosConfig.baseXPos;

                    // Texture2DArray
                    mProps.SetInt(pn_int_texidx, vertPosConfig.animTextureArrayIdx);
                    // combine basePos and posRange, save memory
                    mProps.SetVector(pn_v2_range, new Vector4(vertPosConfig.vertPosRange.x, vertPosConfig.vertPosRange.y, 0, 0));
                }
                lastXOffset = lastXOffset == 0 ? curXOffset : lastXOffset;
                mProps.SetFloat(pn_float_offsetX, curXOffset);
                mProps.SetFloat(pn_float_offsetX_pre, lastXOffset);
            }
            mr.SetPropertyBlock(mProps);
        }
        ResetJointMaterialProperty();
        lastXOffset = curXOffset;
    }

    private void ResetJointMaterialProperty()
    {
        List<MeshRenderer> tempList = new List<MeshRenderer>();
        for (int i = 0; i < objMesh2JointNameList.Length; i++)
        {
            if (objMesh2JointNameList[i].mr == null || objMesh2JointNameList[i].jointName.Length == 0) continue;
            if (RigMode)
            {
                objMesh2JointNameList[i].mr.GetPropertyBlock(mProps);
                {
                    int jointBoneId = GetJointBoneId(objMesh2JointNameList[i].jointName);
                    objMesh2JointNameList[i].mr.sharedMaterial.SetTexture(pn_tex_rig, rigTex);
                    mProps.SetInt(pn_int_joint_boneid, jointBoneId);
                    mProps.SetFloat(pn_float_offsetX, curXOffset);
                    mProps.SetFloat(pn_float_offsetX_pre, lastXOffset);
                    mProps.SetMatrix(pn_matrix_ls, GetLocalMatrix(objMesh2JointNameList[i].mr.transform));
                }
                objMesh2JointNameList[i].mr.SetPropertyBlock(mProps);
            }
            tempList.Add(objMesh2JointNameList[i].mr);
        }
        availableJointMrArray = tempList.ToArray();
    }

    private void UpdatePropToMat()
    {
        curT = mUpdater.GetNormalizedCurTime() * animTexYLength + animTexYOffset;
        if (mUpdater.IsFading)
        {
            preT = mUpdater.GetPreNormalizedTime() * preAnimTexYLength + preAnimTexYOffset;
            playWeight = mUpdater.GetFadeWeight();
        }
        for (int i = 0; i < mMRs.Length; i++)
        {
            MeshRenderer mr = mMRs[i];
            mr.GetPropertyBlock(mProps);
            {
                mProps.SetFloat(pn_float_sampleY, curT);
                if (mUpdater.IsFading)
                {
                    mProps.SetFloat(pn_float_sampleY_pre, preT);
                    mProps.SetFloat(pn_float_blendweight, playWeight);
                }
            }
            mr.SetPropertyBlock(mProps);

        }
        if (RigMode)
        {
            UpdatePropToJointMat();
        }
    }
    private void UpdatePropToJointMat(bool isUpdating = true)
    {
        //Matrix4x4 matrix = trans.localToWorldMatrix;
        for (int i = 0; i < availableJointMrArray.Length; i++)
        {
            availableJointMrArray[i].GetPropertyBlock(mProps);
            {
                // 【*性能隐患】如果挂点的数量很多（≥3），可能需要考虑用Vector设置
                mProps.SetMatrix(pn_matrix_l2w_root, trans.localToWorldMatrix);

                if (!Application.isPlaying)
                {
                    mProps.SetMatrix(pn_matrix_ls, GetLocalMatrix(availableJointMrArray[i].transform));
                }
                if (isUpdating)
                {
                    mProps.SetFloat(pn_float_sampleY, curT);
                    if (mUpdater.IsFading)
                    {
                        mProps.SetFloat(pn_float_sampleY_pre, preT);
                        mProps.SetFloat(pn_float_blendweight, playWeight);
                    }
                }
            }
            availableJointMrArray[i].SetPropertyBlock(mProps);
        }
    }
    #endregion


    #region Public For Test
    public void ToggleRigMode()
    {
        if (RigMode && rigAnimMat == null || !RigMode && vertAnimMat == null) return;
        ResetRigModeAndMat(!RigMode);
    }
    #endregion




    #region Private Part
    // Start is called before the first frame update
    void Awake()
    {
        trans = transform;
        InitProperties();
#if UNITY_EDITOR
        if (!Application.isPlaying)
        {
            if (baking) return;
            if (gameObject.scene.name != trans.root.name && !updateInOtherScene) PlayInEditorOnce();
            else PlayInEditor();
        }
        else
#endif
        {
            PlayOnce(mConfigFromAsset.clipConfigs[0].animName);
        }
    }

    void OnDestroy()
    {
        if (mUpdater == null) return;
        Stop();
        mProps.Clear();
#if UNITY_EDITOR
        if (Application.isPlaying)
#endif
        {
            // due to order issues  this OnDestroy is usually only used when GPUAnimator is manually destroyed
            // when game is quit, GPUAnimatorMgr will invoke OnDestroy to destroy all the animator stored in GPUAnimatorMgr
            if (GPUAnimatorMgr.instance()) GPUAnimatorMgr.instance().DelGpuAnimator(this);
        }
    }

    private int GetJointBoneId(string jointName)
    {
        for (int i = 0; i < mConfigFromAsset.allBones.Length; i++)
        {
            if (jointName == mConfigFromAsset.allBones[i])
            {
                return i;
            }
        }
        return -1;
    }

    /// <summary>
    /// init basic clip properties
    /// </summary>
    /// <param name="animName"></param>
    private void SaveClipInfo(string animName)
    {
        if (animName == null)
        {
            Debug.LogError("animName is null");
        }
        mPrefabAnimConfig.GetClipConfig(animName, out ClipConfigElem clipConfig);
        if (clipConfig == null)
        {
            Debug.Log("");
        }
        preAnimTexYLength = animTexYLength;
        preAnimTexYOffset = animTexYOffset;
        loop = clipConfig.loop;
        animSpeed = clipConfig.speed;
        animDuration = clipConfig.duration;
        animTexYOffset = clipConfig.animTexYOffset;
        animTexYLength = clipConfig.animTexYLength;
        CurAnimName = animName;
    }
    private void SetKeywordEnableOnCurMeshRenderer(string keyword, bool enabled)
    {
        for (int i = 0; i < mMRs.Length; i++)
        {
            SetKeywordEnable(mMRs[i].sharedMaterial, keyword, enabled);
        }
    }

    private void SetKeywordEnable(string keyword, bool enabled)
    {
        if (enabled) Shader.EnableKeyword(keyword);
        else Shader.DisableKeyword(keyword);

    }

    private void SetKeywordEnable(Material mat, string keyword, bool enabled)
    {
        if (enabled) mat.EnableKeyword(keyword);
        else mat.DisableKeyword(keyword);
    }
    private Matrix4x4 GetLocalMatrix(Transform t)
    {
        return Matrix4x4.TRS(t.localPosition, t.localRotation, t.localScale);
    }

    #endregion



    #region For Editor
#if UNITY_EDITOR

    private float lastTimeSinceStartup;
    private const int _MAX_EDITOR_FPS = 60;
    private List<string> animNameList = new List<string>();
    private bool assignedUpdate = false;
    [Header("编辑器设置")]
    [Tooltip("在除了prefab的场景之外也可以播放【编辑器内】")]
    public bool updateInOtherScene = false;

    [Dropdown("animNameList")]
    public string CurEditorAnimName;

    private void OnEnable()
    {
        if (!Application.isPlaying)
        {
            lastTimeSinceStartup = Time.realtimeSinceStartup;
            EditorApplication.update += OnUpdateInEditor;
            assignedUpdate = true;
        }
    }
    private void OnDisable()
    {
        if (assignedUpdate)
        {
            EditorApplication.update -= OnUpdateInEditor;
            assignedUpdate = false;
        }
    }
    private void OnValidate()
    {
        if (mProps == null || mUpdater == null) return;
        if (!Application.isPlaying) ResetMaterialPropertyInEditor(CurEditorAnimName);
        else ResetMaterialProperty(CurAnimName);
    }
    private void PlayInEditor()
    {
        CurEditorAnimName = CurEditorAnimName.Length > 0 ? CurEditorAnimName : animNameList[0];
        ResetMaterialPropertyInEditor(CurEditorAnimName);

        ClipConfigElem clipConfig = FindClipConfigInEditor();
        if (clipConfig == null) return;
        preAnimTexYLength = animTexYLength;
        preAnimTexYOffset = animTexYOffset;
        //loop = clipConfig.loop;
        loop = true;
        animSpeed = clipConfig.speed;
        animDuration = clipConfig.duration;
        animTexYOffset = clipConfig.animTexYOffset;
        animTexYLength = clipConfig.animTexYLength;
        CurAnimName = CurEditorAnimName;


        bool isLoop = loop;
        float startTime = 0;
        float fadeTime = 0;
        mUpdater.Play(startTime, animDuration, animSpeed, isLoop, fadeTime);
        enabled = true;
        UpdatePropToMat();

        SetKeywordEnable(kw_play, true);
    }

    private void PlayInEditorOnce()
    {
        PlayInEditor();
        mUpdater.Stop();
    }

    private void ResetMaterialPropertyInEditor(string animName)
    {
        for (int i = 0; i < mMRs.Length; i++)
        {
            mMRs[i].sharedMaterial = RigMode ? rigAnimMat : vertAnimMat;
        }
        float offsetX = 0;
        for (int i = 0; i < mMRs.Length; i++)
        {
            MeshRenderer mr = mMRs[i];
            mr.GetPropertyBlock(mProps);
            {
                GPUMecAnimConfigElem texConfig = FindTexConfigInEditor(mr.name, animName, RigMode);
                offsetX = texConfig.baseXPos;

                if (RigMode)
                {
                    //mr.sharedMaterial.SetTexture(pn_tex_rig, rigTex);
                }
                else
                {
                    // Texture2DArray
                    //mr.sharedMaterial.SetTexture(pn_tex2d_vert, vertPosTex);
                    //mr.sharedMaterial.SetTexture(pn_tex2d_normal, normTex);
                    mProps.SetInt(pn_int_texidx, texConfig.animTextureArrayIdx);
                    // combine basePos and posRange, save memory
                    mProps.SetVector(pn_v2_range, new Vector4(texConfig.vertPosRange.x, texConfig.vertPosRange.y, 0, 0));

                }
                lastXOffset = lastXOffset == 0 ? offsetX : lastXOffset;
                mProps.SetFloat(pn_float_offsetX, offsetX);
                mProps.SetFloat(pn_float_offsetX_pre, lastXOffset);

            }
            mr.SetPropertyBlock(mProps);
        }


        List<MeshRenderer> tempList = new List<MeshRenderer>();
        for (int i = 0; i < objMesh2JointNameList.Length; i++)
        {
            if (objMesh2JointNameList[i].mr == null || objMesh2JointNameList[i].jointName.Length == 0) continue;
            if (objMesh2JointNameList[i].mr.sharedMaterial != jointAnimMat) objMesh2JointNameList[i].mr.sharedMaterial = jointAnimMat;
            if (RigMode)
            {
                objMesh2JointNameList[i].mr.GetPropertyBlock(mProps);
                {
                    int jointBoneId = GetJointBoneId(objMesh2JointNameList[i].jointName);
                    objMesh2JointNameList[i].mr.sharedMaterial.SetTexture(pn_tex_rig, rigTex);
                    mProps.SetInt(pn_int_joint_boneid, jointBoneId);
                    mProps.SetFloat(pn_float_offsetX, offsetX);
                    mProps.SetFloat(pn_float_offsetX_pre, lastXOffset);
                    mProps.SetMatrix(pn_matrix_ls, GetLocalMatrix(objMesh2JointNameList[i].mr.transform));
                }
                objMesh2JointNameList[i].mr.SetPropertyBlock(mProps);
                tempList.Add(objMesh2JointNameList[i].mr);
                //SetKeywordEnable(mr.sharedMaterial, kw_play, true);
            }
            else
            {
                //SetKeywordEnable(mr.sharedMaterial, kw_play, false);
            }

        }
        availableJointMrArray = tempList.ToArray();
        lastXOffset = offsetX;
    }

    private void OnUpdateInEditor()
    {
        if (Application.isPlaying)
        {
            OnDisable();
            return;
        }
        if (RigMode && rigAnimMat == null) RigMode = false;
        else if (!RigMode && vertAnimMat == null) RigMode = true;
        float deltaTime = Time.realtimeSinceStartup - lastTimeSinceStartup;
        if (deltaTime < 1 / _MAX_EDITOR_FPS) { UpdatePropToJointMat(); return; }
        lastTimeSinceStartup = Time.realtimeSinceStartup;

        if (gameObject.scene.name != trans.root.name)
        {
            if (!updateInOtherScene)
            {
                if (CurAnimName == CurEditorAnimName) { UpdatePropToJointMat(); return; }
                else PlayInEditorOnce();
            }
            else if (CurAnimName != CurEditorAnimName)
            {
                PlayInEditor();
            }
        }
        else if (CurAnimName != CurEditorAnimName || !mUpdater.IsPlaying)
        {
            PlayInEditor();
        }

        UpdateAnimator(deltaTime);
    }

    private ClipConfigElem FindClipConfigInEditor()
    {
        ClipConfigElem clipConfig = null;

        if (CurEditorAnimName.Length == 0) clipConfig = mConfigFromAsset.clipConfigs[0];
        else
        {
            for (int i = 0; i < mConfigFromAsset.clipConfigs.Count; i++)
            {
                var config = mConfigFromAsset.clipConfigs[i];
                if (config.animName == CurEditorAnimName)
                {
                    clipConfig = config;
                    break;
                }
            }
        }
        return clipConfig;
    }
    private GPUMecAnimConfigElem FindTexConfigInEditor(string mrName, string animName, bool rigMode)
    {
        for (int i = 0; i < mConfigFromAsset.texConfigs.Count; i++)
        {
            var config = mConfigFromAsset.texConfigs[i];
            if (config.animName == animName)
            {
                if (rigMode && config.configType == ConfigType.Rig || !rigMode && config.meshName == mrName && config.configType == ConfigType.Vert)
                {
                    return config;
                }
            }
        }

        return null;
    }
#endif
    #endregion

}
