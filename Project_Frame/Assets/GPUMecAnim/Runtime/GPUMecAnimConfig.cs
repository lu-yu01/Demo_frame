using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;

public enum AnimUsage
{
    AnimUsage_VertexPos_FP16 = 0,
    AnimUsage_VertexPos_INT8 = 0,
    AnimUsage_VertexNormal_INT8,
    AnimUsage_RigMatrix_FP16,
}

public enum ConfigType
{
    Vert = 0,
    Normal,
    Rig,
}

[Serializable]
public class GPUMecAnimConfigElem   
{
    public string elemName; // for display in inspector
    public string meshName;
    public string animName;
    public ConfigType configType;
    public string animTexturePath;
    public int animTextureArrayIdx;
    public AnimUsage animUsage;
    public Vector2 vertPosRange;
    public int mTexDimensionX;

    public int dataElemCount;
    public float baseXPos;
    public float baseYPos;
    public float dataElemXOffset;

    public string[] rigNames;

    //public void Init(
    //    int inDataElemCount, int inFrameCount, float inDuration,
    //    float inBaseXPos, float inBaseYPos, float inDataElemXOffset, float inAnimYLength
    //)
    //{
    //    dataElemCount = inDataElemCount;
    //    frameCount = inFrameCount;
    //    duration = inDuration;
    //    baseXPos = inBaseXPos;
    //    baseYPos = inBaseYPos;
    //    dataElemXOffset = inDataElemXOffset;
    //    animTexYLength = inAnimYLength;
    //}
}

[Serializable]
public class ClipConfigElem
{
    public string animName;
    public int frameCount;
    public float speed;
    public float duration;
    public float animTexXOffset;
    public float animTexYOffset;
    public float animTexYLength;
    public bool loop;
}

public class GPUMecAnimConfig : ScriptableObject
{
    public string modelName;
    //public string vertArrayPath;
    //public string normArrayPath;
    //public string rigTexPath;
    public List<GPUMecAnimConfigElem> texConfigs = new List<GPUMecAnimConfigElem>();
    public List<ClipConfigElem> clipConfigs = new List<ClipConfigElem>();
    //public List<ClipMatrix> clipMatrices;
    public string[] allBones;
}


[Serializable]
public class ClipMatrix
{
    public string elemName;
    public string clipName;
    public string meshName;
    public int frameIdx;
    public Matrix4x4[] boneMat;

    public ClipMatrix(string clipName,string meshName, int frameIdx) {
        this.clipName = clipName;
        this.meshName = meshName;
        this.frameIdx = frameIdx;
        this.elemName = string.Format("{0}_{1}_Frame_{2}", clipName, meshName, frameIdx);
    }
}
