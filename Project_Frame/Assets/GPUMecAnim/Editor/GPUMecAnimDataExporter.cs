using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System;
using System.IO;
//using Unity.EditorCoroutines.Editor;

// animations are arranged in 
public abstract class GPUMecAnimDataExporterBase : UnityEngine.Object
{
    public const string TEX_FOLDER_NAME = "/animTex";

    protected int mFPS;
    protected bool mBakeVert;
    protected bool mBakeRig;
    protected int mVertexCount;
    protected int mRigCount;
    protected Material mVertMat;
    protected Material mRigMat;
    protected Material mJointMat;


    protected GPUMecAnimExportData mData;


    protected List<string> mAllRigNames = new List<string>();
    protected List<Transform> mAllBones = new List<Transform>();
    protected Transform[] mJointTransArr;
    protected int[] mJointToParentBoneID; // parent of Joint belongs to which bone
    protected Dictionary<SkinnedMeshRenderer, Dictionary<int, int>> mSmrToBonIdMap = new Dictionary<SkinnedMeshRenderer, Dictionary<int, int>>();
    protected Dictionary<SkinnedMeshRenderer, Vector3> mSmrToScale = new Dictionary<SkinnedMeshRenderer, Vector3>();

    protected List<SingleTextureDataWriterBase> vertexPosData;
    protected List<SingleTextureDataWriterBase> vertexNormalData;
    protected List<SingleTextureDataWriterBase> rigData;

    private Texture2DArray vertPosTex;
    private Texture2DArray vertNormTex;
    private Texture2D rigTex;



    public delegate void TryAddWriterFunc();
    public delegate void AddWriterFunc(SingleTextureDataWriterBase writer, Animator animator, SkinnedMeshRenderer smr, AnimationClip clip);

    public void ExportAnimData(string prefabPath, GPUMecAnimExportData data, bool bakeVert, bool bakeRig)
    {
        mData = data;
        mBakeVert = bakeVert;
        mBakeRig = bakeRig;

        // load prefab
        GameObject prefabGO = AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
        GameObject sceneGO = Instantiate(prefabGO);
        sceneGO.transform.SetPositionAndRotation(Vector3.zero, Quaternion.identity);

        // bake poses and fetch the vertex animation data
        Animator animator = sceneGO.GetComponentInChildren<Animator>();
        animator.updateMode = AnimatorUpdateMode.AnimatePhysics;
        animator.cullingMode = AnimatorCullingMode.AlwaysAnimate;
        animator.applyRootMotion = false; // should disable it mannually rather than use code

        RuntimeAnimatorController rac = animator.runtimeAnimatorController;
        AnimationClip[] clips = rac.animationClips;

        string fileName = Path.GetFileNameWithoutExtension(prefabPath);
        GPUMecAnimConfig allAnimConfigs = ScriptableObject.CreateInstance<GPUMecAnimConfig>();
        allAnimConfigs.modelName = fileName;
        string outDir = string.Format("{0}/{1}", mData.exportPath, fileName);
        CreateDirectory(outDir);

        SkinnedMeshRenderer[] smrs = sceneGO.GetComponentsInChildren<SkinnedMeshRenderer>(true);
        GetAllBones(smrs);

        List<Texture2D> textureList_vert = new List<Texture2D>();
        List<Texture2D> textureList_norm = new List<Texture2D>();

        //CheckMeshScale(smrs);
        foreach (var smr in smrs)
        {
            smr.transform.SetPositionAndRotation(Vector3.zero, Quaternion.identity);

            AddMeshRednerer(smr, outDir, out MeshFilter mf);
            if (mBakeRig)
            {
                SaveBoneToUV(smr, mf.sharedMesh);
            }
        }
        string animOutDir = outDir + TEX_FOLDER_NAME;
        CreateDirectory(animOutDir);

        CheckMeshScale(smrs);


        if (mBakeVert)
        {
            foreach (var smr in smrs)
            {
                try
                {
                    ProcessVertAnimations(animator, smr, clips, mData.exportFps, allAnimConfigs);
                    //SaveVertAnimData(smr, outDir, allAnimConfigs);
                    RecordTextureArrayData(textureList_vert, textureList_norm, allAnimConfigs);
                }
                catch (ArgumentException e)
                {
                    Debug.LogError(string.Format("error when proccesing file: {0}, {1}", prefabPath, e));
                }
            }
            SaveVertNormTextureArrayData(textureList_vert, textureList_norm, animOutDir, allAnimConfigs);
        }
        if (mBakeRig)
        {
            try
            {
                ProcessRigAnimations(animator, smrs, clips, mData.rigNames, mData.exportFps, allAnimConfigs);
                SaveRigAnimData("", outDir, allAnimConfigs);
            }
            catch (ArgumentException e)
            {
                Debug.LogError(string.Format("error when proccesing file: {0}, {1}", prefabPath, e));
            }
            //SaveRigTextureArrayData(textureList_rig, animOutDir, allAnimConfigs);
        }

        RevertMeshScale(smrs);
        // TODO: collect all the animation configs and orgnize them into a config file.
        SaveAnimConfig(outDir, allAnimConfigs);

        CreateGPUMaterialAtPath(smrs, outDir);

        ModifyComponent(sceneGO, smrs, animator, mData.rootBoneName, allAnimConfigs);

        SaveNewPrefab(sceneGO, fileName, outDir);

        DestroyImmediate(sceneGO);

        // save assets
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
    }

    private void CheckMeshScale(SkinnedMeshRenderer[] smrs)
    {
        Vector3 scale = new Vector3(1 / smrs[0].transform.parent.localScale.x, 1 / smrs[0].transform.parent.localScale.y, 1 / smrs[0].transform.parent.localScale.z);

        smrs[0].transform.root.localScale = scale;
    }

    private void RevertMeshScale(SkinnedMeshRenderer[] smrs)
    {
        //foreach (var smr in smrs)
        //{
        //    //smr.transform.localScale = mSmrToScale[smr];
        //}
        //mSmrToScale.Clear();

        smrs[0].transform.root.localScale = Vector3.one;
    }

    private void GetAllBones(SkinnedMeshRenderer[] smrs)
    {
        foreach (var smr in smrs)
        {
            Transform[] bones = smr.bones;
            foreach (var bone in bones)
            {
                if (!mAllBones.Contains(bone)) mAllBones.Add(bone);
            }
        }
    }

    protected MeshRenderer AddMeshRednerer(SkinnedMeshRenderer smr, string outDir, out MeshFilter mf)
    {
        string animOutDir = outDir + "/mesh";
        CreateDirectory(animOutDir);
        Mesh bakeMesh = new Mesh();
        smr.BakeMesh(bakeMesh);

        Mesh mesh = Instantiate(smr.sharedMesh);
        mesh.bounds = bakeMesh.bounds;
        //Mesh mesh = Instantiate(bakeMesh);
        //mesh.vertices = smr.sharedMesh.vertices;

        string meshPath = string.Format("{0}/{1}.mesh", animOutDir, smr.sharedMesh.name);
        DeleteAsset(meshPath);
        AssetDatabase.CreateAsset(mesh, meshPath);

        GameObject meshRoot = smr.gameObject;
        mf = meshRoot.AddComponent<MeshFilter>();

        mf.sharedMesh = mesh;
        //mf.sharedMesh = smr.sharedMesh;

        MeshRenderer mr = meshRoot.AddComponent<MeshRenderer>();

        return mr;
    }

    private void CreateGPUMaterialAtPath(SkinnedMeshRenderer[] smrs, string outDir)
    {
        // {材质名}_{prefab名}_{shader类型}
        string matDir = string.Format("{0}/material", outDir);
        CreateDirectoryAfterDelete(matDir);
        string matPath = string.Format("{0}/{1}_{2}_", matDir, mData.materialName, smrs[0].transform.root.name);

        if (mBakeRig)
        {
            string rigMatPath = matPath + "rig.mat";
            mRigMat = new Material(mData.rigShader);
            //mRigMat.DisableKeyword("_ENABLE_JOINT");
            mRigMat.SetFloat("_EnableJoint", 1);// disable _ENABLE_JOINT
            Texture tex = smrs[0].sharedMaterial.mainTexture ?? smrs[0].sharedMaterial.GetTexture("_MainTex");
            mRigMat.mainTexture = tex;
            mRigMat.SetTexture(GPUAnimator.pn_tex_rig, rigTex);
            mRigMat.enableInstancing = true;
            AssetDatabase.CreateAsset(mRigMat, rigMatPath);

            mJointMat = new Material(mRigMat);
            //jointMat.EnableKeyword("_ENABLE_JOINT");
            mRigMat.SetFloat("_EnableJoint", 0);// enable _ENABLE_JOINT
            string jointMatPath = matPath + "joint.mat";
            AssetDatabase.CreateAsset(mJointMat, jointMatPath);
        }
        if (mBakeVert)
        {
            string vertMatPath = matPath + "vert.mat";
            mVertMat = new Material(mData.vertShader);
            Texture tex = smrs[0].sharedMaterial.mainTexture ?? smrs[0].sharedMaterial.GetTexture("_MainTex");
            mVertMat.mainTexture = tex;
            mVertMat.SetTexture(GPUAnimator.pn_tex2d_vert, vertPosTex);
            mVertMat.SetTexture(GPUAnimator.pn_tex2d_normal, vertNormTex);
            mVertMat.enableInstancing = true;
            AssetDatabase.CreateAsset(mVertMat, vertMatPath);
        }

        foreach (var smr in smrs)
        {
            MeshRenderer mr = smr.GetComponent<MeshRenderer>();
            mr.sharedMaterial = mRigMat == null ? mVertMat : mRigMat;
        }
    }
    private void ModifyComponent(GameObject sceneGO, SkinnedMeshRenderer[] smrs, Animator animator, string rootBoneName, GPUMecAnimConfig allAnimConfigs)
    {
        sceneGO.SetActive(false); //关闭GO，使其延迟调用Awake
        GPUAnimator ganimator = sceneGO.AddComponent<GPUAnimator>();
        ganimator.baking = true;
        ganimator.mConfigFromAsset = allAnimConfigs;
        ganimator.mConfigHash = allAnimConfigs.GetHashCode();
        ganimator.vertAnimMat = mVertMat;
        ganimator.rigAnimMat = mRigMat;
        ganimator.jointAnimMat = mJointMat;
        ganimator.SetRigMode(mBakeRig);
        ganimator.mMRs = new MeshRenderer[smrs.Length];

        if (rootBoneName != null && rootBoneName.Length > 0)
        {
            GameObject rootBone = FindBoneByName(animator.transform.root, rootBoneName);
            DestroyImmediate(rootBone);
        }
        for (int i = 0; i < smrs.Length; i++)
        {
            var smr = smrs[i];
            ganimator.mMRs[i] = smr.transform.GetComponent<MeshRenderer>();
            DestroyImmediate(smr);
        }

        DestroyImmediate(animator);

        sceneGO.SetActive(true); // 延迟调用Awake
        ganimator.baking = false;
    }
    protected Matrix4x4[] GetInverseBoneMatrix(SkinnedMeshRenderer[] smrs)
    {
        // get T-pose bone matrix
        Matrix4x4[] boneMatInverse_bone = GetBindPoseBaseOnGlobalBoneId(smrs);
        Matrix4x4[] boneMatInverse_joint = new Matrix4x4[mJointToParentBoneID.Length];

        //boneMatInverse_bone = smr.sharedMesh.bindposes;

        for (int i = 0; i < boneMatInverse_joint.Length; i++)
        {
            int boneId = mJointToParentBoneID[i];
            boneMatInverse_joint[i] = boneMatInverse_bone[boneId];// * Matrix4x4.TRS(joint.localPosition, joint.localRotation, joint.localScale);
        }

        Matrix4x4[] boneMatInverse = new Matrix4x4[mRigCount];
        for (int i = 0; i < boneMatInverse.Length; i++)
        {
            if (i < boneMatInverse_bone.Length)
            {
                boneMatInverse[i] = boneMatInverse_bone[i];
            }
            else
            {
                boneMatInverse[i] = boneMatInverse_joint[i - boneMatInverse_bone.Length];
            }
        }

        return boneMatInverse;
    }

    private GameObject FindBoneByName(Transform t, string name)
    {
        foreach (Transform trans in t.GetComponentsInChildren<Transform>())
        {
            if (trans.name == name)
            {
                return trans.gameObject;
            }
        }
        return null;
    }

    private Matrix4x4[] GetBindPoseBaseOnGlobalBoneId(SkinnedMeshRenderer[] smrs)
    {
        Matrix4x4[] globalBindPose = new Matrix4x4[mRigCount];
        foreach (var smr in smrs)
        {
            Dictionary<int, int> BoneIdMap = mSmrToBonIdMap[smr];
            var meshBindPoses = smr.sharedMesh.bindposes;
            for (int i = 0; i < meshBindPoses.Length; i++)
            {
                var bindPose = meshBindPoses[i];
                //var tempMatrix = globalBindPose[BoneIdMap[i]] == Matrix4x4.zero ? Matrix4x4.identity : globalBindPose[BoneIdMap[i]];
                //globalBindPose[BoneIdMap[i]] = bindPose;
                globalBindPose[BoneIdMap[i]] = globalBindPose[BoneIdMap[i]] == Matrix4x4.zero ? bindPose : globalBindPose[BoneIdMap[i]];
                //globalBindPose[BoneIdMap[i]] = tempMatrix * bindPose;
            }
        }
        return globalBindPose;
    }

    private void SaveBoneToUV(SkinnedMeshRenderer smr, Mesh meshNeedToSave)
    {
        Dictionary<int, int> boneIdMap = GetBoneIdMap(smr.bones);
        mSmrToBonIdMap.Add(smr, boneIdMap);
        Mesh mesh = smr.sharedMesh;
        int len = mesh.vertexCount;
        Vector4[] uv_boneIDs = new Vector4[len];
        Vector4[] uv_boneWeights = new Vector4[len];

        // Get the number of bone weights per vertex

        // Iterate over the vertices
        for (var vertIndex = 0; vertIndex < mesh.vertexCount; vertIndex++)
        {
            var bone = mesh.boneWeights[vertIndex];
            uv_boneIDs[vertIndex] = new Vector4(boneIdMap[bone.boneIndex0], boneIdMap[bone.boneIndex1], boneIdMap[bone.boneIndex2], boneIdMap[bone.boneIndex3]);
            uv_boneWeights[vertIndex] = new Vector4(bone.weight0, bone.weight1, bone.weight2, bone.weight3);
        }

        meshNeedToSave.SetUVs(1, uv_boneIDs);
        meshNeedToSave.SetUVs(2, uv_boneWeights);

        //meshNeedToSave.bindposes = mesh.bindposes;
        //meshNeedToSave.boneWeights = mesh.boneWeights;

        // for test so save UV to sharedMesh as well
        mesh.SetUVs(1, uv_boneIDs);
        mesh.SetUVs(2, uv_boneWeights);
    }

    private Dictionary<int, int> GetBoneIdMap(Transform[] bones)
    {
        Dictionary<int, int> boneIdMap = new Dictionary<int, int>();
        for (int i = 0; i < bones.Length; i++)
        {
            Transform bone = bones[i];
            int idx = mAllBones.IndexOf(bone);
            boneIdMap.Add(i, idx);
        }
        return boneIdMap;
    }

    protected void DeleteAsset(string path)
    {
        if (File.Exists(path))
        {
            AssetDatabase.DeleteAsset(path);
        }
    }

    protected void CreateDirectory(string path)
    {
        if (!Directory.Exists(path))
        {
            Directory.CreateDirectory(path);
        }
    }

    protected void CreateDirectoryAfterDelete(string path)
    {
        if (Directory.Exists(path))
        {
            Directory.Delete(path, true);
        }
        Directory.CreateDirectory(path);
    }

    protected void SaveNewPrefab(GameObject sceneGO, string fileName, string outDir)
    {
        //ganimator.mMeshRootName = MESH_ROOT_NAME;
        //sceneGO.AddComponent<GPUAnimPlayer>();
        if (mData.exportPrefabOutside)
        {
            string tempPath = string.Format("{0}/{1}.prefab", outDir, fileName);
            DeleteAsset(tempPath);
            outDir += "/..";
        }
        else
        {
            string tempPath = string.Format("{0}/../{1}.prefab", outDir, fileName);
            DeleteAsset(tempPath);
        }

        string savePath = string.Format("{0}/{1}.prefab", outDir, fileName);
        DeleteAsset(savePath);
        PrefabUtility.SaveAsPrefabAsset(sceneGO, savePath);
    }

    private void InitVertExporter(int fps, SkinnedMeshRenderer smr)
    {
        mFPS = fps;

        mVertexCount = smr.sharedMesh.vertexCount;

        vertexPosData = new List<SingleTextureDataWriterBase>();
        vertexNormalData = new List<SingleTextureDataWriterBase>();
        AddVertexPosDataWriter();
        AddVertexNormalDataWriter();
    }
    private void InitRigExporter(int fps, string[] rigNames)
    {
        mFPS = fps;

        mRigCount = mAllBones.Count + rigNames.Length;
        List<Transform> tempJointTransArr = new List<Transform>();
        List<int> tempJointToParentBoneID = new List<int>();
        for (int i = 0; i < rigNames.Length; i++)
        {
            Transform jointTrans = FindJointFromSMRBones(rigNames[i], out int parentBoneId);
            if (jointTrans == null) { Debug.LogError($"Can not find joint {rigNames[i]}"); mRigCount--; continue; }
            if (parentBoneId == -1) mRigCount--;
            else
            {
                tempJointTransArr.Add(jointTrans);
                tempJointToParentBoneID.Add(parentBoneId);
            }
        }
        mJointTransArr = tempJointTransArr.ToArray();
        mJointToParentBoneID = tempJointToParentBoneID.ToArray();

        rigData = new List<SingleTextureDataWriterBase>();
        AddRigDataWriter();
    }

    private Transform FindJointFromSMRBones(string rigName, out int boneId)
    {
        boneId = -1;
        Transform root = mAllBones[0].root;
        Transform jointTrans = FindTransFromPrefab(rigName, root);

        if (jointTrans != null) boneId = FindBoneId(jointTrans, mAllBones.ToArray());

        return jointTrans;
    }

    private Transform FindTransFromPrefab(string rigName, Transform root)
    {
        foreach (var trans in root.GetComponentsInChildren<Transform>(true))
        {
            if (trans.name == rigName) return trans;
        }
        return null;
    }

    private int FindBoneId(Transform jointTrans, Transform[] boneTrans, bool acceptExistBone = false)
    {
        if (!mAllBones.Contains(jointTrans))// We don't need to record original boneid
        {
            string jointParentName = jointTrans.parent.name;
            if (mAllBones.Contains(jointTrans.parent)) return BoneNameIndexOfBonTrans(boneTrans, jointParentName);
        }
        else
        {
            if (!acceptExistBone)
            {
                // Means trying to export existed bone as joint, in order to avoid calc in shader, so we need to export new line of pixels
                return -2;
            }
            else
            {
                return mAllBones.IndexOf(jointTrans);
            }
        }
        return -1;
    }
    /// <summary>
    /// Make sure if the joint is part of current mesh bones, return id if is, return -1 otherwise.
    /// </summary>
    /// <param name="jointName"></param>
    /// <param name="boneTrans"></param>
    /// <returns></returns>
    private int BoneNameIndexOfBonTrans(Transform[] boneTrans, string jointName)
    {
        for (int i = 0; i < boneTrans.Length; i++)
        {
            if (boneTrans[i].name == jointName) return i;
        }
        return -1;
    }
    public void SaveAnimConfig(string outDir, GPUMecAnimConfig config)
    {
        // TODO: collect all the animation configs and orgnize them into a config file.
        string configPath = string.Format("{0}/anim_config.asset", outDir);
        DeleteAsset(configPath);
        AssetDatabase.CreateAsset(config, configPath);
    }

    protected void SaveVertAnimData(string name, string outDir, GPUMecAnimConfig allAnimConfigs)
    {
        // texture name should be prefabName_[vert|norm|rig]_index.asset
        // anim config should be prefabName.json
        string animOutDir = outDir + TEX_FOLDER_NAME;

        CreateDirectory(animOutDir);
        animOutDir += "/" + name;

        WriteAnimDataIntoTexture(vertexPosData, allAnimConfigs, animOutDir + "_vert");
        WriteAnimDataIntoTexture(vertexNormalData, allAnimConfigs, animOutDir + "_norm");
    }

    protected void SaveRigAnimData(string name, string outDir, GPUMecAnimConfig allAnimConfigs)
    {
        // texture name should be prefabName_[vert|norm|rig]_index.asset
        // anim config should be prefabName.json
        string animOutDir = outDir + TEX_FOLDER_NAME;

        CreateDirectory(animOutDir);
        animOutDir += "/" + name;

        WriteAnimDataIntoTexture(rigData, allAnimConfigs, animOutDir + "_rig");

        rigTex = rigData[0].dataTexture;
    }

    private void ApplyAnimDataToWriter(List<SingleTextureDataWriterBase> writers, GPUMecAnimConfig allAnimConfigs)
    {
        for (int i = 0; i < writers.Count; ++i)
        {
            SingleTextureDataWriterBase writer = writers[i];
            writer.ApplyData();
            writer.AppendAnimConfigs(allAnimConfigs);
        }
    }

    private void WriteAnimDataIntoTexture(List<SingleTextureDataWriterBase> writers, GPUMecAnimConfig allAnimConfigs, string outPath)
    {
        for (int i = 0; i < writers.Count; ++i)
        {
            SingleTextureDataWriterBase writer = writers[i];
            writer.ApplyData();
            outPath = string.Format("{0}_{1}.asset", outPath, i);
            writer.SaveDataTexture(outPath);
            writer.AppendAnimConfigs(allAnimConfigs, outPath);
        }
        //allAnimConfigs.rigTexPath = outPath; // replacing
    }
    protected void RecordTextureArrayData(List<Texture2D> textureList_vert, List<Texture2D> textureList_norm, GPUMecAnimConfig allAnimConfigs)
    {

        ApplyAnimDataToWriter(vertexPosData, allAnimConfigs);
        ApplyAnimDataToWriter(vertexNormalData, allAnimConfigs);

        for (int i = 0; i < vertexPosData.Count; ++i)
        {
            SingleTextureDataWriterBase writer = vertexPosData[i];

            writer.RecordTextureToArray(textureList_vert);
        }

        for (int i = 0; i < vertexNormalData.Count; ++i)
        {
            SingleTextureDataWriterBase writer = vertexNormalData[i];

            writer.RecordTextureToArray(textureList_norm);
        }
    }

    protected void SaveVertNormTextureArrayData(List<Texture2D> textureList_vert, List<Texture2D> textureList_norm, string outDir, GPUMecAnimConfig allAnimConfigs)
    {
        string outPath;
        TextureFormat format;

        outPath = string.Format("{0}/mesh_vert_Array.asset", outDir);
        format = vertexPosData[0].GetTextureFormat();
        vertPosTex = WriteDataToTextureArray(textureList_vert, outPath, format);
        //allAnimConfigs.vertArrayPath = outPath;

        outPath = string.Format("{0}/mesh_norm_Array.asset", outDir);
        format = vertexNormalData[0].GetTextureFormat();
        vertNormTex = WriteDataToTextureArray(textureList_norm, outPath, format, FilterMode.Point);//avoid Quaternion interpolation issues
        //allAnimConfigs.normArrayPath = outPath;

        foreach (var texConfig in allAnimConfigs.texConfigs)
        {
            if (texConfig.configType == ConfigType.Rig) continue;
            float arrayWidth = texConfig.configType == ConfigType.Vert ? vertPosTex.width : vertNormTex.width;
            float ratio = texConfig.mTexDimensionX / arrayWidth;
            texConfig.baseXPos *= ratio;
            texConfig.dataElemXOffset *= ratio;
        }
    }
    protected void SaveRigTextureArrayData(List<Texture2D> textureList_rig, string outDir, GPUMecAnimConfig allAnimConfigs)
    {
        string outPath;
        TextureFormat format;

        outPath = string.Format("{0}/mesh_rig_Array.asset", outDir);
        format = rigData[0].GetTextureFormat();
        Texture2DArray texArr_rig = WriteDataToTextureArray(textureList_rig, outPath, format);
        //allAnimConfigs.rigTexPath = outPath;

        foreach (var texConfig in allAnimConfigs.texConfigs)
        {
            if (texConfig.configType != ConfigType.Rig) continue;
            float arrayWidth = texArr_rig.width;
            float ratio = texConfig.mTexDimensionX / arrayWidth;
            texConfig.baseXPos *= ratio;
            texConfig.dataElemXOffset *= ratio;
        }
    }

    protected Texture2DArray SaveTextureArrayData(List<Texture2D> textureList, string outPath, GPUMecAnimConfig allAnimConfigs)
    {
        TextureFormat format = vertexPosData[0].GetTextureFormat();
        Texture2DArray texArr = WriteDataToTextureArray(textureList, outPath, format);
        //allAnimConfigs.vertArrayPath = outPath;
        return texArr;
    }
    protected Texture2DArray WriteDataToTextureArray(List<Texture2D> dataTextureList, string outPath, TextureFormat format, FilterMode filterMode = FilterMode.Bilinear, TextureWrapMode wrapMode = TextureWrapMode.Repeat)
    {
        int maxWidth = 0;
        int maxHeight = 0;
        foreach (var tex in dataTextureList)
        {
            maxWidth = Mathf.Max(maxWidth, tex.width);
            maxHeight = Mathf.Max(maxHeight, tex.height);
        }

        Texture2DArray dataTextureArray = new Texture2DArray(maxWidth, maxHeight, dataTextureList.Count, format, false, true);
        dataTextureArray.filterMode = filterMode;
        dataTextureArray.wrapMode = wrapMode;
        for (int i = 0; i < dataTextureList.Count; i++)
        {
            Texture2D tex = dataTextureList[i];

            // have to check whether they are in the same size
            int oriWidth = tex.width;
            int oriHeight = tex.height;
            if (oriWidth != maxWidth || oriHeight != maxHeight)
            {
                Texture2D tempTex = new Texture2D(maxWidth, maxHeight, format, false, true);
                Color[] tempCols = new Color[maxWidth * maxHeight];
                for (int j = 0; j < oriWidth * oriHeight; j++)
                {
                    int row = (int)Mathf.Floor(j / oriWidth);
                    int col = j - row * oriWidth;
                    int tempIdx = row * maxWidth + col;
                    tempCols[tempIdx] = tex.GetPixel(col, row);
                }
                tempTex.SetPixels(tempCols);
                tex = tempTex;
            }

            dataTextureArray.SetPixels(tex.GetPixels(0), i, 0);
        }
        dataTextureArray.Apply();

        AssetDatabase.CreateAsset(dataTextureArray, outPath);

        return dataTextureArray;
    }


    private void ProcessRigAnimations(Animator animator, SkinnedMeshRenderer[] smrs, AnimationClip[] clips, string[] rigNames, int fps, GPUMecAnimConfig allAnimConfigs)
    {
        InitRigExporter(fps, rigNames);
        SaveAllBones(allAnimConfigs);
        Matrix4x4[] boneMatInverse = GetInverseBoneMatrix(smrs);

        for (int i = 0; i < clips.Length; ++i)
        {
            var clip = clips[i];
            TryAddAnimation(rigData, AddRigDataWriter, clip.length);
        }
        for (int i = 0; i < rigData.Count; ++i)
        {
            rigData[i].AllocateData();
            rigData[i].BeginAddFrames();
        }

        for (int i = 0; i < clips.Length; ++i)
        {
            var clip = clips[i];
            // add data frames for these two lists
            AddRigAnimation(animator, smrs, clip, boneMatInverse, allAnimConfigs);
        }

    }

    private void SaveAllBones(GPUMecAnimConfig allAnimConfigs)
    {
        string[] allbones = new string[mRigCount];
        for (int i = 0; i < mRigCount; i++)
        {
            if (i < mAllBones.Count) allbones[i] = mAllBones[i].name;
            else
            {
                //int id = mRigCount - i - 1;
                int id = i - (mRigCount - mJointTransArr.Length);

                Transform trans = mJointTransArr[id];
                if (mJointToParentBoneID[id] == -2)
                {
                    // recover to existBoneId
                    mJointToParentBoneID[id] = FindBoneId(trans, mAllBones.ToArray(), true);
                }
                allbones[i] = trans.name + "_joint";
            }
        }
        allAnimConfigs.allBones = allbones;
    }

    //animator, smr, clips, rigNames, fps
    protected void ProcessVertAnimations(Animator animator, SkinnedMeshRenderer smr, AnimationClip[] clips, int fps, GPUMecAnimConfig allAnimConfigs)
    {
        InitVertExporter(fps, smr);

        // bake poses and fetch the vertex animation data
        Mesh mesh = smr.sharedMesh;

        // try add all animation, calculate how many animation textures we need.
        // and the size of each animation textures
        for (int i = 0; i < clips.Length; ++i)
        {
            var clip = clips[i];
            TryAddAnimation(vertexPosData, AddVertexPosDataWriter, clip.length);
            TryAddAnimation(vertexNormalData, AddVertexNormalDataWriter, clip.length);

        }

        if (vertexPosData.Count != vertexNormalData.Count)
        {
            Debug.LogError("vertexPosData and vertexNormalData are supposed to have the same size.");
            throw new ArgumentException("vertexPosData and vertexNormalData are supposed to have the same size.");
        }

        for (int i = 0; i < vertexPosData.Count; ++i)
        {
            vertexPosData[i].AllocateData();
            vertexNormalData[i].AllocateData();

            vertexPosData[i].BeginAddFrames();
            vertexNormalData[i].BeginAddFrames();
        }

        for (int i = 0; i < clips.Length; ++i)
        {
            var clip = clips[i];
            // add data frames for these two lists
            AddVertAnimation(animator, smr, clip, allAnimConfigs);
        }
    }

    protected void AddRigAnimationClipToWriter(int rigWriterIndex, Animator animator, AnimationClip clip, Matrix4x4[] boneMatInverse)
    {
        animator.Play(clip.name, 0, 0);
        animator.Update(0);
        float animationDeltaTime = 1f / mFPS;
        int frameCount = (int)Math.Ceiling(clip.length * mFPS);
        // Write data(animation info per frame) to color 
        //animator.Update(0);
        for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex)
        {

            Matrix4x4[] rigs = new Matrix4x4[mRigCount];
            // add all rigs to rigData List
            for (int i = 0; i < rigs.Length; i++)
            {
                int boneLen = mAllBones.Count;
                if (i <= boneLen - 1) // means is real bone
                {
                    rigs[i] = mAllBones[i].localToWorldMatrix * boneMatInverse[i];
                }
                else // means is joint
                {
                    int idx = i - boneLen;
                    rigs[i] = mJointTransArr[idx].localToWorldMatrix;
                }
            }
            rigData[rigWriterIndex].AddDataFrame(frameIndex, rigs);

            animator.Update(animationDeltaTime);
        }

    }
    protected void AddVertAnimationClipToWriter(int animWriterIndex, Animator animator, SkinnedMeshRenderer smr, AnimationClip clip)
    {
        animator.Play(clip.name, 0, 0);
        animator.Update(0);
        float animationDeltaTime = 1f / mFPS;
        int frameCount = (int)Math.Ceiling(clip.length * mFPS);
        Mesh meshFrame = new Mesh();

        float range_max = Mathf.NegativeInfinity;
        float range_min = Mathf.Infinity;
        // Calc the range in first loop which will be used to constraint vert pos in the second loop
        for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex)
        {
            smr.BakeMesh(meshFrame);
            //meshFrame = smr.sharedMesh;
            // calc the range of pos 
            foreach (var vert in meshFrame.vertices)
            {
                range_max = Mathf.Max(range_max, Mathf.Max(vert.x, Mathf.Max(vert.y, vert.z)));
                range_min = Mathf.Min(range_min, Mathf.Min(vert.x, Mathf.Min(vert.y, vert.z)));
            }

            animator.Update(animationDeltaTime);
        }
        Vector2 posRange = new Vector2(Mathf.Floor(range_min), Mathf.Ceil(range_max));

        // Save the range in animConfig for use by shaders

        for (int i = 0; i < vertexPosData.Count; ++i)
        {
            vertexPosData[i].SetPosRangeToConfigByAnimName(posRange, clip.name);
        }

        // Write data(animation info per frame) to color 
        animator.Update(0);
        for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex)
        {
            smr.BakeMesh(meshFrame);
            //meshFrame = smr.sharedMesh;

            vertexNormalData[animWriterIndex].AddDataFrame(frameIndex, meshFrame.normals, meshFrame.tangents);
            vertexPosData[animWriterIndex].AddDataFrame(frameIndex, meshFrame.vertices, posRange);
            //vertexPosData[animWriterIndex].AddDataFrame(frameIndex, meshFrame.normals, meshFrame.tangents); // RGBA + A

            animator.Update(animationDeltaTime);
        }

        //DestroyImmediate(meshFrame);       
    }
    protected bool AddRigAnimation(Animator animator, SkinnedMeshRenderer[] smrs, AnimationClip clip, Matrix4x4[] boneMatInverse, GPUMecAnimConfig allAnimConfigs)
    {
        bool addSuccess = false;
        int rigDataIndex = 0;
        for (rigDataIndex = 0; rigDataIndex < rigData.Count; ++rigDataIndex)
        {
            addSuccess = rigData[rigDataIndex].TryAddFrames(true, null, clip.name, clip.length, mFPS, clip.isLooping);
            //foreach (var smr in smrs)
            //{
            //string meshName = "";
            //addSuccess = rigData[rigDataIndex].TryAddFrames(true, smr.sharedMesh.name, clip.name, clip.length, mFPS);
            //rigData[rigDataIndex].AddConfig(meshName, clip.name, clip.length, mFPS, clip.isLooping);
            rigData[rigDataIndex].AddRigNames(mJointTransArr);
            //}
            if (addSuccess) break;
        }

        // if the animation cannot fit into all textures, there must be a problem somewhere!!!
        if (!addSuccess)
        {
            Debug.LogError("if the animation cannot fit into all textures, there must be a problem somewhere!!!");
            throw new ArgumentException("if the animation cannot fit into all textures, there must be a problem somewhere!!!");
        }
        else
        {
            AddRigAnimationClipToWriter(rigDataIndex, animator, clip, boneMatInverse);
        }

        return addSuccess;
    }
    protected bool AddVertAnimation(Animator animator, SkinnedMeshRenderer smr, AnimationClip clip, GPUMecAnimConfig allAnimConfigs)
    {
        bool addSuccess = false;
        int animDataIndex = 0;
        for (animDataIndex = 0; animDataIndex < vertexPosData.Count; ++animDataIndex)
        {
            addSuccess = vertexPosData[animDataIndex].TryAddFrames(true, smr.sharedMesh.name, clip.name, clip.length, mFPS);
            vertexNormalData[animDataIndex].TryAddFrames(true, smr.sharedMesh.name, clip.name, clip.length, mFPS);
            if (addSuccess) break;
        }

        // if the animation cannot fit into all textures, there must be a problem somewhere!!!
        if (!addSuccess)
        {
            Debug.LogError("if the animation cannot fit into all textures, there must be a problem somewhere!!!");
            throw new ArgumentException("if the animation cannot fit into all textures, there must be a problem somewhere!!!");
        }
        else
        {
            AddVertAnimationClipToWriter(animDataIndex, animator, smr, clip);

        }

        return addSuccess;
    }

    protected bool TryAddAnimation(List<SingleTextureDataWriterBase> toDataList, TryAddWriterFunc addFunc, float duration)
    {
        bool addSuccess = false;
        for (int i = 0; i < toDataList.Count; ++i)
        {
            SingleTextureDataWriterBase writer = toDataList[i];
            addSuccess = writer.TryAddFrames(false, null, null, duration, mFPS);
            if (addSuccess)
            {
                break;
            }
        }

        // if the animation cannot fit into all textures, create a new texture.
        if (!addSuccess)
        {
            addFunc();
            var writer = toDataList[toDataList.Count - 1];
            addSuccess = writer.TryAddFrames(false, null, null, duration, mFPS);
        }

        return addSuccess;
    }

    abstract protected void AddVertexPosDataWriter();
    abstract protected void AddVertexNormalDataWriter();
    abstract protected void AddRigDataWriter();
}


public class GPUMecAnimDataExporter_FP16 : GPUMecAnimDataExporterBase
{
    override protected void AddVertexPosDataWriter()
    {
        //vertexPosData.Add(new SingleTextureDataWriter1PPE_FP16_4C1P(1024, 1024, mVertexCount));
        var writer = new SingleTextureDataWriter2PPE_INT8_6C2P(2048, 2048, mVertexCount);
        writer.SetConfigType(ConfigType.Vert);
        vertexPosData.Add(writer);
    }

    override protected void AddVertexNormalDataWriter()
    {
        var writer = new SingleTextureDataWriter1PPE_INT8_4C1P(2048, 2048, mVertexCount);
        writer.SetConfigType(ConfigType.Normal);
        vertexNormalData.Add(writer);
    }

    override protected void AddRigDataWriter()
    {
        var writer = new SingleTextureDataWriter3PPE_FP16_4C3P(2048, 2048, mRigCount);
        writer.SetConfigType(ConfigType.Rig);
        rigData.Add(writer);
    }
}

