using System.Collections;
using System.Collections.Generic;
using UnityEngine;


public class GPURuntimeAnimConfig_Anim 
{
    // configType -> specificConfig (a specific config (might be two) which correspond to the type)
    private Dictionary<ConfigType, GPUMecAnimConfigElem> enum2Config = new Dictionary<ConfigType, GPUMecAnimConfigElem>();
    internal void AddConfigElem(GPUMecAnimConfigElem elem)
    {
        GPUMecAnimConfigElem config = null;
        bool hasKey = GetConfig(elem.configType, out config);
        if (!hasKey)
        {
            enum2Config.Add(elem.configType, elem);
        }
    }

    public bool GetConfig(ConfigType configType, out GPUMecAnimConfigElem outConfig)
    {
        bool hasKey = enum2Config.TryGetValue(configType, out outConfig);
        return hasKey;
    }

}
public class GPURuntimeAnimConfig_MeshOrRig
{
    // animName -> animConfig (might be a single config if it's Rig type, however it could be two configs(vert & normal) when it's Mesh type, so it's better to deal with it in next class)
    //private Dictionary<string, GPUMecAnimConfigElem> name2Anim = new Dictionary<string, GPUMecAnimConfigElem>();
    private Dictionary<string, GPURuntimeAnimConfig_Anim> name2Anim = new Dictionary<string, GPURuntimeAnimConfig_Anim>();

    internal void AddConfigElem(GPUMecAnimConfigElem elem)
    {
        GPURuntimeAnimConfig_Anim animConfig = null;
        bool hasKey = GetAnimConfig(elem.animName, out animConfig);
        if (!hasKey)
        {
            animConfig = new GPURuntimeAnimConfig_Anim();
            name2Anim.Add(elem.animName, animConfig);
        }

        animConfig.AddConfigElem(elem);
    }

    public bool GetAnimConfig(string animName, out GPURuntimeAnimConfig_Anim outConfig)
    {
        bool hasKey = name2Anim.TryGetValue(animName, out outConfig);
        return hasKey;
    }

}

public class GPURuntimeAnimConfig_Prefab
{
    // meshName -> meshConfig (includes all anim configs for a specific mesh)
    private Dictionary<string, GPURuntimeAnimConfig_MeshOrRig> name2Mesh = new Dictionary<string, GPURuntimeAnimConfig_MeshOrRig>();

    private Dictionary<string, ClipConfigElem> name2Clip = new Dictionary<string, ClipConfigElem>();

    internal void AddConfigElem(GPUMecAnimConfigElem elem)
    {
        GPURuntimeAnimConfig_MeshOrRig meshOrRigConfig = null;
        bool hasKey = GetMeshAnimConfig(elem.meshName, out meshOrRigConfig);
        if (!hasKey)
        {
            meshOrRigConfig = new GPURuntimeAnimConfig_MeshOrRig();
            name2Mesh.Add(elem.meshName, meshOrRigConfig);
        }

        meshOrRigConfig.AddConfigElem(elem);
    }

    internal void AddClipConfigElem(ClipConfigElem elem)
    {
        ClipConfigElem clipConfig = null;
        bool hasKey = GetClipConfig(elem.animName, out clipConfig);
        if (!hasKey)
        {
            name2Clip.Add(elem.animName, elem);
        }
    }

    public bool GetMeshAnimConfig(string meshName, out GPURuntimeAnimConfig_MeshOrRig outConfig)
    {
        bool hasKey = name2Mesh.TryGetValue(meshName, out outConfig);
        return hasKey;
    }
    public bool GetClipConfig(string animName, out ClipConfigElem outConfig)
    {
        bool hasKey = name2Clip.TryGetValue(animName, out outConfig);
        return hasKey;
    }

    public bool GetFirstMeshAnimConfig(out GPURuntimeAnimConfig_MeshOrRig outConfig)
    {
        outConfig = null;
        IEnumerator enumerator = name2Mesh.Keys.GetEnumerator();
        bool success = enumerator.MoveNext();
        return success ? GetMeshAnimConfig((string)enumerator.Current, out outConfig) : false;
    }

    public GPURuntimeAnimConfig_Anim GetAnimTexConfig(string meshName, string animName) 
    {
        bool configExist = GetMeshAnimConfig(meshName, out GPURuntimeAnimConfig_MeshOrRig meshAnimConfig);
        if (!configExist) throw new System.Exception(string.Format("mesh anim config for mesh {0} is missing", meshName));
        configExist = meshAnimConfig.GetAnimConfig(animName, out GPURuntimeAnimConfig_Anim animConfig);
        if (!configExist) throw new System.Exception(string.Format("anim config for anim {0} is missing", animName));
        return animConfig;
    }

}
public class GPURuntimeAnimConfig_Clip
{
    private Dictionary<string, ClipConfigElem> name2Config = new Dictionary<string, ClipConfigElem>();

    internal void AddConfigElem(ClipConfigElem elem)
    {
        bool hasKey = GetClipConfig(elem.animName, out ClipConfigElem clipConfig);
        if (!hasKey)
        {
            name2Config.Add(elem.animName, elem);
        }
    }

    public bool GetClipConfig(string animName, out ClipConfigElem outConfig)
    {
        bool hasKey = name2Config.TryGetValue(animName, out outConfig);
        return hasKey;
    }
}


public class GPURuntimeAnimConfigs
{
    // prefabName -> prefabConfig (includes mesh configs)
    private Dictionary<int, GPURuntimeAnimConfig_Prefab> hash2PrefabConfig = new Dictionary<int, GPURuntimeAnimConfig_Prefab>();

    private Dictionary<string, Dictionary<string, List<Dictionary<int, Matrix4x4[]>>>> clipToMeshToFrameToMatrix = new Dictionary<string, Dictionary<string, List<Dictionary<int, Matrix4x4[]>>>>();


    public void AddGPUMecAnimConfig(int configHash, GPUMecAnimConfig assetConfig)
    {
        GPURuntimeAnimConfig_Prefab prefabConfig = null;
        bool hasKey = GetPrefabAnimConfig(configHash, out prefabConfig);
        if (!hasKey)
        {
            prefabConfig = new GPURuntimeAnimConfig_Prefab();
            hash2PrefabConfig.Add(configHash, prefabConfig);
        }
        foreach (var elemConfig in assetConfig.texConfigs)
        {
            prefabConfig.AddConfigElem(elemConfig);
        }

        foreach (var elemConfig in assetConfig.clipConfigs)
        {
            prefabConfig.AddClipConfigElem(elemConfig);
        }
    }

    public bool GetPrefabAnimConfig(int configHash, out GPURuntimeAnimConfig_Prefab outConfig)
    {
        bool hasKey = hash2PrefabConfig.TryGetValue(configHash, out outConfig);
        return hasKey;
    }

    private void SaveMatrixData(ClipMatrix matConfig) 
    {
        string clipName = matConfig.clipName;
        string meshName = matConfig.meshName;
        int frameIdx = matConfig.frameIdx;

        clipToMeshToFrameToMatrix.TryGetValue(clipName, out Dictionary<string, List<Dictionary<int, Matrix4x4[]>>> meshToFrameToMatrix);
        if (meshToFrameToMatrix == null)
        {
            meshToFrameToMatrix = new Dictionary<string, List<Dictionary<int, Matrix4x4[]>>>();
            List<Dictionary<int, Matrix4x4[]>> frameToMatList = new List<Dictionary<int, Matrix4x4[]>>();
            Dictionary<int, Matrix4x4[]> frameToMatrix = new Dictionary<int, Matrix4x4[]>();
            frameToMatrix.Add(frameIdx, matConfig.boneMat);
            meshToFrameToMatrix.Add(meshName, frameToMatList);
            frameToMatList.Add(frameToMatrix);
            clipToMeshToFrameToMatrix.Add(clipName, meshToFrameToMatrix);
        }
        else 
        {
            Dictionary<int, Matrix4x4[]> frameToMatrix = new Dictionary<int, Matrix4x4[]>();
            frameToMatrix.Add(frameIdx, matConfig.boneMat);
            meshToFrameToMatrix.TryGetValue(meshName,out List<Dictionary<int, Matrix4x4[]>> frameToMatList);
            if (frameToMatList == null)
            {
                frameToMatList = new List<Dictionary<int, Matrix4x4[]>>();
                meshToFrameToMatrix.Add(meshName, frameToMatList);
            }
            frameToMatList.Add(frameToMatrix);
        }
    }

    public Matrix4x4[] GetBoneMat(string clipName,string meshName, int frameIdx) 
    {
        clipToMeshToFrameToMatrix.TryGetValue(clipName, out Dictionary<string, List<Dictionary<int, Matrix4x4[]>>> meshToFrameToMatrix);
        meshToFrameToMatrix.TryGetValue(meshName, out List <Dictionary<int, Matrix4x4[]>> frameToMatrixList);
        foreach (var frameToMatrix in frameToMatrixList)
        {
            frameToMatrix.TryGetValue(frameIdx, out Matrix4x4[] boneMat);
            if (boneMat != null) return boneMat;
        }
        return new Matrix4x4[0];
    }

}
