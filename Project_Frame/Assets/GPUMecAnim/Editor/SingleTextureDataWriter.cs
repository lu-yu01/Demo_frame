using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.Linq;
using System;
using System.IO;

// animations are arranged in 
public abstract class SingleTextureDataWriterBase
{
    public int mMaxWidthPOTSize;        // 1024, 2048
    public int mMaxHeightPOTSize;       // 1024, 2048
    public int mColElementCount;
    public int mColPixelSize;

    public List<GPUMecAnimConfigElem> texConfigs;
    public List<ClipConfigElem> animConfigs;

    public ConfigType mConfigType;
    public Texture2D dataTexture { get { return mDataTexture; } }

    // how many animations
    protected int[] mCurPixelPosInCol;

    // maximum tracks along the horizontal direction.
    protected int mMaxColCount;
    protected TextureFormat mTextureFormat;
    protected Texture2D mDataTexture;
    protected List<Texture2D> mDataTextureList;
    protected Texture2DArray mDataTextureArray;

    protected Vector2Int mTexDimension;
    protected Color[] mData;

    private Vector3Int mLastColAndFrameRange;

    abstract public int GetPixelCountPerElement();

    abstract public AnimUsage GetAnimUsage();

    public void SetConfigType(ConfigType configType)
    {
        mConfigType = configType;
    }
    public TextureFormat GetTextureFormat() { return mTextureFormat; }

    public void Init(int inMaxWidthPOTSize, int inMaxHeightPOTSize, int inColElementCount, TextureFormat textureFormat)
    {
        if (inMaxHeightPOTSize < inColElementCount)
        {
            Debug.LogError("inColElement is even bigger than texture POT size.");
            throw new ArgumentException("inColElement is even bigger than texture POT size.");
        }
        mDataTextureList = new List<Texture2D>();

        mMaxWidthPOTSize = inMaxWidthPOTSize;
        mMaxHeightPOTSize = inMaxHeightPOTSize;
        mColElementCount = inColElementCount;

        mColPixelSize = mColElementCount * GetPixelCountPerElement();
        mMaxColCount = mMaxWidthPOTSize / mColPixelSize;
        mCurPixelPosInCol = Enumerable.Repeat(0, mMaxColCount).ToArray();

        mTextureFormat = textureFormat;

        BeginAddFrames();
    }

    public void BeginAddFrames()
    {
        mCurPixelPosInCol = Enumerable.Repeat(0, mMaxColCount).ToArray();
    }

    public bool TryAddFrames(bool addConfig, string meshName, string animName, float duration, int fps, bool isloop = false)
    {
        int frameCount = (int)Math.Ceiling(duration * fps);
        if (frameCount > mMaxHeightPOTSize)
        {
            Debug.LogError("animation length is too big, cannot be fit into one column.");
            throw new ArgumentException("animation length is too big, cannot fit into one column.");
        }

        bool addSuccess = false;

        for (int colIndex = 0; colIndex < mCurPixelPosInCol.Length; ++colIndex)
        {
            if (mCurPixelPosInCol[colIndex] + frameCount <= mMaxHeightPOTSize)
            {
                mLastColAndFrameRange.x = colIndex;
                mLastColAndFrameRange.y = mCurPixelPosInCol[colIndex];
                mLastColAndFrameRange.z = mCurPixelPosInCol[colIndex] + frameCount;
                mCurPixelPosInCol[colIndex] = mLastColAndFrameRange.z;
                addSuccess = true;

                if (addConfig)
                {
                    AddConfig(meshName, animName, duration, fps, isloop);                    
                }
                break;
            }
        }
        return addSuccess;
    }

    public void AddConfig(string meshName, string animName, float duration, int fps, bool isloop = false)
    {
        int colIndex = mLastColAndFrameRange.x;
        int frameCount = (int)Math.Ceiling(duration * fps);
        // add animation config
        GPUMecAnimConfigElem texConfig = new GPUMecAnimConfigElem();
        texConfig.meshName = meshName;
        texConfig.animName = animName;
        texConfig.animUsage = GetAnimUsage();
        texConfig.configType = mConfigType;
        texConfig.dataElemCount = mColElementCount;
        texConfig.elemName = mConfigType.ToString() + "_" + meshName + "_" + animName;
        //texConfig.frameCount = (int)Math.Ceiling(duration * fps);
        //texConfig.duration = duration;
        texConfig.mTexDimensionX = mTexDimension.x;
        float pixelXSize = 1.0f / mTexDimension.x;
        float dataColXSize = mColPixelSize * pixelXSize;
        texConfig.baseXPos = colIndex * dataColXSize + pixelXSize * 0.5f;

        float pixelYSize = 1.0f / mTexDimension.y;
        texConfig.baseYPos = mLastColAndFrameRange.y * pixelYSize + pixelYSize * 0.5f;

        texConfig.dataElemXOffset = dataColXSize;

        //texConfig.animTexYLength = pixelYSize * frameCount - pixelYSize; // we only need to consider top center to bottom center, so subtract 1 pixel. Otherwise it will be messed up by the last frame.
        texConfigs.Add(texConfig);
        
        ClipConfigElem animConfig = new ClipConfigElem();
        animConfig.animName = animName;
        animConfig.frameCount = frameCount;
        animConfig.speed = 1f;
        animConfig.duration = duration;
        animConfig.animTexYLength = pixelYSize * frameCount - pixelYSize; // we only need to consider top center to bottom center, so subtract 1 pixel. Otherwise it will be messed up by the last frame.
        animConfig.animTexYOffset = texConfig.baseYPos;
        animConfig.loop = isloop;

        animConfigs.Add(animConfig);
    }

    public void AddRigNames(Transform[] mJointTransArr)
    {
        string[] rigNames = new string[mJointTransArr.Length];
        for (int i = 0; i < mJointTransArr.Length; i++)
        {
            rigNames[i] = mJointTransArr[i].name;
        }
        foreach (var texConfig in texConfigs)
        {
            texConfig.rigNames = rigNames;
        }
    }

    public Vector2Int GetRealDataDimension()
    {
        int usedCol = 0;
        int maxRows = 0;
        for (usedCol = 0; usedCol < mCurPixelPosInCol.Length; ++usedCol)
        {
            if (mCurPixelPosInCol[usedCol] <= 0)
            {
                break;
            }
            maxRows = Math.Max(maxRows, mCurPixelPosInCol[usedCol]);
        }
        return new Vector2Int(usedCol * mColPixelSize, maxRows);
    }

    public int GetNextPOT(int val)
    {
        if (val <= 2)
        {
            return 2;
        }
        // decrement `n` (to handle the case when `n` itself
        // is a power of 2)
        val = val - 1;
        // calculate the position of the last set bit of `n`
        int lg = (int)Math.Floor(Math.Log10(val) / Math.Log10(2.0f));
        // next power of two will have a bit set at position `lg+1`.
        return 1 << lg + 1;
    }

    public void AllocateData()
    {
        Vector2Int realDataDimension = GetRealDataDimension();
        //mTexDimension = new Vector2Int(GetNextPOT(realDataDimension.x), GetNextPOT(realDataDimension.y));
        mTexDimension = new Vector2Int(realDataDimension.x, realDataDimension.y);
        mData = new Color[mTexDimension.x * mTexDimension.y];
        texConfigs = new List<GPUMecAnimConfigElem>();
        animConfigs = new List<ClipConfigElem>();
    }

    public void ApplyData()
    {
        mDataTexture = new Texture2D(mTexDimension.x, mTexDimension.y, mTextureFormat, false, true);
        mDataTexture.SetPixels(mData);
        mDataTexture.Apply();
        mDataTextureList.Add(mDataTexture);
    }

    public void ApplyDataTextureArray()
    {
        mDataTextureArray = new Texture2DArray(mDataTextureList[0].width, mDataTextureList[0].height, mDataTextureList.Count, mTextureFormat, false, true);
        mDataTextureArray.filterMode = FilterMode.Bilinear;
        mDataTextureArray.wrapMode = TextureWrapMode.Repeat;
        for (int i = 0; i < mDataTextureList.Count; i++)
        {
            mDataTextureArray.SetPixels(mDataTextureList[i].GetPixels(0),
                i, 0);
        }
        mDataTextureArray.Apply();
    }

    public void SaveDataTexture(string path)
    {
        if (File.Exists(path))
        {
            AssetDatabase.DeleteAsset(path);
        }
        AssetDatabase.CreateAsset(mDataTexture, path);
    }

    public void SaveDataTextureArray(string path)
    {
        AssetDatabase.CreateAsset(mDataTextureArray, path);
    }
    public void AppendAnimConfigs(GPUMecAnimConfig outConfigs)
    {
        outConfigs.texConfigs.AddRange(texConfigs);
        if (outConfigs.clipConfigs.Count == 0) outConfigs.clipConfigs.AddRange(animConfigs);
    }

    public void AppendAnimConfigs(GPUMecAnimConfig outConfigs, string animTexturePath)
    {
        foreach (var config in texConfigs)
        {
            config.animTexturePath = animTexturePath;
        }
        AppendAnimConfigs(outConfigs);
    }

    public void RecordTextureToArray(List<Texture2D> textureArray)
    {
        textureArray.Add(mDataTexture);
        int idx = textureArray.Count - 1;
        foreach (var config in texConfigs)
        {
            config.animTextureArrayIdx = idx;
        }
    }

    public void SetPosRangeToConfigByAnimName(Vector2 range, string animName) 
    {
        foreach (var config in texConfigs)
        {
            if (config.animName == animName) 
            {
                config.vertPosRange = range;
            }
        }
    }

    public void EncodeFloatTo2Bytes(float value, ref Vector2 res)
    {
        // value needs to be in [0, 1]
        float lowBits = Mathf.Repeat(value * 255.0f, 1.0f);
        float highBits = value - lowBits / 255.0f;
        res.Set(highBits, lowBits);
    }
    public void AddDataFrame(int frameIndex, Vector3[] normals, Vector4[] tangents)
    {
        AddDataFrame(mLastColAndFrameRange.x, mLastColAndFrameRange.y + frameIndex, normals, tangents);
    }
    public void AddDataFrame(int frameIndex, Vector3[] data, Vector2 constraintRange)
    {
        AddDataFrame(mLastColAndFrameRange.x, mLastColAndFrameRange.y + frameIndex, data, constraintRange);
    }
    public void AddDataFrame(int frameIndex, Vector4[] data)
    {
        AddDataFrame(mLastColAndFrameRange.x, mLastColAndFrameRange.y + frameIndex, data);
    }
    public void AddDataFrame(int frameIndex, Matrix4x4[] data)
    {
        AddDataFrame(mLastColAndFrameRange.x, mLastColAndFrameRange.y + frameIndex, data);
    }

    virtual protected void AddDataFrame(int dataCol, int dataRow, Vector3[] normals, Vector4[] tangents)
    {

    }

    virtual protected void AddDataFrame(int dataCol, int dataRow, Vector3[] data, Vector2 constraintRange)
    {

    }


    virtual protected void AddDataFrame(int dataCol, int dataRow, Vector4[] data)
    {

    }
    
    virtual protected void AddDataFrame(int dataCol, int dataRow, Matrix4x4[] data)
    {

    }
   
}

// 1 pixel (4 channels) per element.
// float data should be in [-1, +1] and they need to be remapped to [0, 1] of 1 byte data.
// this is for low precision data e.g. vertex normals (rg) and tangents (ba)
public class SingleTextureDataWriter1PPE_INT8_4C1P : SingleTextureDataWriterBase
{
    override public int GetPixelCountPerElement()
    {
        return 1;
    }

    override public AnimUsage GetAnimUsage()
    {
        return AnimUsage.AnimUsage_VertexNormal_INT8;
    }

    public SingleTextureDataWriter1PPE_INT8_4C1P(int inMaxWidthPOTSize, int inMaxHeightPOTSize, int inColElementCount)
    {
        Init(inMaxWidthPOTSize, inMaxHeightPOTSize, inColElementCount, TextureFormat.RGBA32);
    }

    override protected void AddDataFrame(int dataCol, int dataRow, Vector3[] normals, Vector4[] tangents)
    {
        int pixelRow = dataRow;
        int pixelCol = dataCol * mColPixelSize;
        for (int i = 0; i < normals.Length; ++i)
        {
            int dataIndex = pixelRow * mTexDimension.x + (pixelCol + i);

            Vector3 nrmData = normals[i].normalized;
            Vector3 tangentData = tangents[i].normalized;

            Quaternion q = Quaternion.LookRotation(nrmData,tangentData);
            // RGBA32 + A
            //mData[dataIndex].r = (nrmData.x + 1.0f) * 0.5f;
            //mData[dataIndex].g = (nrmData.y + 1.0f) * 0.5f;
            //mData[dataIndex].b = (tangentData.x + 1.0f) * 0.5f;
            //mData[dataIndex].a = (tangentData.y + 1.0f) * 0.5f;

            // RGBA32 in Quaternion
            mData[dataIndex].r = (q.x + 1.0f) * 0.5f;
            mData[dataIndex].g = (q.y + 1.0f) * 0.5f;
            mData[dataIndex].b = (q.z + 1.0f) * 0.5f;
            mData[dataIndex].a = (q.w + 1.0f) * 0.5f;

            // RGBAHalf in Quaternion 
            //mData[dataIndex].r = q.x;
            //mData[dataIndex].g = q.y;
            //mData[dataIndex].b = q.z;
            //mData[dataIndex].a = q.w;
        }
    }
}

// 2 pixel (6 channels) per element.
// float data should be in [0, 1] and they need to be mapped to 2 byte data, 
// x,y,z together will take 6 byte data.
//===================================================================//
// data need to be decoded:  |  X  |  Y  |  Z  | // Original version //
// data in texture           | r g   b|r   g b | // Original version //
//===================================================================//
// data need to be decoded:  |       X      |       Y      |       Z      |    // rgb_low means first pixel, rgb_high means second pixel. 
// data in texture           | r_low r_high | g_low g_high | g_low g_high |    // Such separation can reduce sample in case we want a lower precision of animation.
// this is for high precision data e.g. vertex positions
public class SingleTextureDataWriter2PPE_INT8_6C2P : SingleTextureDataWriterBase
{
    override public int GetPixelCountPerElement()
    {
        return 2;
    }
    override public AnimUsage GetAnimUsage()
    {
        return AnimUsage.AnimUsage_VertexPos_INT8;
    }
    public SingleTextureDataWriter2PPE_INT8_6C2P(int inMaxWidthPOTSize, int inMaxHeightPOTSize, int inColElementCount)
    {
        Init(inMaxWidthPOTSize, inMaxHeightPOTSize, inColElementCount, TextureFormat.RGB24);
    }

    override protected void AddDataFrame(int dataCol, int dataRow, Vector3[] data, Vector2 constraintRange)
    {
        int pixelRow = dataRow;
        int pixelCol = dataCol * mColPixelSize;
        Vector2 tmp = Vector2.zero;
        float min_range = constraintRange[0];
        float diff = constraintRange[1] - constraintRange[0];
        for (int i = 0; i < data.Length; ++i)
        {
            int dataIndex = pixelRow * mTexDimension.x + pixelCol + i * 2;

            float x = ConstraintPosition(data[i].x, min_range, diff);
            EncodeFloatTo2Bytes(x, ref tmp);
            mData[dataIndex].r = tmp.x;
            mData[dataIndex + 1].r = tmp.y;

            //mData[dataIndex].r = tmp.x;
            //mData[dataIndex].g = tmp.y;

            float y = ConstraintPosition(data[i].y, min_range, diff);
            EncodeFloatTo2Bytes(y, ref tmp);
            mData[dataIndex].g = tmp.x;
            mData[dataIndex + 1].g = tmp.y;

            //mData[dataIndex].b = tmp.x;
            //mData[dataIndex + 1].r = tmp.y;


            float z = ConstraintPosition(data[i].z, min_range, diff);
            EncodeFloatTo2Bytes(z, ref tmp);
            mData[dataIndex].b = tmp.x;
            mData[dataIndex + 1].b = tmp.y;

            //mData[dataIndex + 1].g = tmp.x;
            //mData[dataIndex + 1].b = tmp.y;

            //int dataIndex = pixelRow * mTexDimension.x + (pixelCol + i);
            //float x = ConstraintPosition(data[i].x, min_range, diff);
            //float y = ConstraintPosition(data[i].y, min_range, diff);
            //float z = ConstraintPosition(data[i].z, min_range, diff);
            //mData[dataIndex] = new Color(x,y,z);
        }
    }

    // store normal and tangent z axis's sign
    //              normal+                  normal-
    //  tangent+  3(11 in binary)       1(01 in binary)
    //  tangent-  2(10 in binary)       0(00 in binary)
    override protected void AddDataFrame(int dataCol, int dataRow, Vector3[] normals, Vector4[] tangents)
    {
        int pixelRow = dataRow;
        int pixelCol = dataCol * mColPixelSize;
        for (int i = 0; i < normals.Length; ++i)
        {
            int dataIndex = pixelRow * mTexDimension.x + pixelCol + i * 2;

            float nsign = normals[i].z > 0 ? 1 : 0;
            float tsign = tangents[i].z > 0 ? 1 : 0;

            // convert 0,1,2,3 to 0, 0.1, 0.2, 0.3
            mData[dataIndex].a = (nsign*2+tsign) * 0.1f;
        }
    }
    private static float ConstraintPosition(float position,float min, float diff)
    {
        return (position - min) / diff;
        
    }
}

// 3 pixel (12 channels fp16) per element.
// this is for orientation matrices.
public class SingleTextureDataWriter3PPE_FP16_4C3P : SingleTextureDataWriterBase
{
    override public int GetPixelCountPerElement()
    {
        return 3;
    }
    override public AnimUsage GetAnimUsage()
    {
        return AnimUsage.AnimUsage_RigMatrix_FP16;
    }
    public SingleTextureDataWriter3PPE_FP16_4C3P(int inMaxWidthPOTSize, int inMaxHeightPOTSize, int inColElementCount)
    {
        Init(inMaxWidthPOTSize, inMaxHeightPOTSize, inColElementCount, TextureFormat.RGBAHalf);
    }

    override protected void AddDataFrame(int dataCol, int dataRow, Matrix4x4[] data)
    {
        int pixelRow = dataRow;
        int pixelCol = dataCol * mColPixelSize;
        Vector2 tmp = Vector2.zero;
        for (int i = 0; i < data.Length; ++i)
        {
            int dataIndex = pixelRow * mTexDimension.x + (pixelCol + i * 3);
            mData[dataIndex] = data[i].GetRow(0);
            mData[dataIndex + 1] = data[i].GetRow(1);
            mData[dataIndex + 2] = data[i].GetRow(2);

            // only need to constrain transilation
            //Matrix4x4 copyData = data[i];
            //copyData.SetColumn(0, ConstraintFromMinMaxTo01(copyData.GetColumn(0), 0.1f));
            //copyData.SetColumn(1, ConstraintFromMinMaxTo01(copyData.GetColumn(1), 0.1f));
            //copyData.SetColumn(2, ConstraintFromMinMaxTo01(copyData.GetColumn(2), 0.1f));
            //copyData.SetColumn(3, ConstraintFromMinMaxTo01(copyData.GetColumn(3), 5));
            //mData[dataIndex] = copyData.GetRow(0);
            //mData[dataIndex + 1] = copyData.GetRow(1);
            //mData[dataIndex + 2] = copyData.GetRow(2);

            //mData[dataIndex] = ConstraintFromMinMaxTo01(data[i].GetRow(0), 1); 
            //mData[dataIndex + 1] = ConstraintFromMinMaxTo01(data[i].GetRow(1), 1); 
            //mData[dataIndex + 2] = ConstraintFromMinMaxTo01(data[i].GetRow(2), 1);
        }
    }

    private static Vector4 ConstraintFromMinMaxTo01(Vector4 vec, float range)
    {
        return ConstraintFromMinMaxTo01(vec, -range , range);
    }

    private static Vector4 ConstraintFromMinMaxTo01(Vector4 vec,float min,float max) 
    {
        if (min > max) Debug.LogError($"Min should less than Max where min is {min} , max is {max}");
        float diff = max - min;
        Vector4 minVec = min * Vector4.one;
        if (diff == 0) return minVec;
        return (vec - minVec) / diff;
    }
}

// 3 pixel (12 channels fp16) per element.
// this is for vertex position data.
public class SingleTextureDataWriter1PPE_FP16_4C1P : SingleTextureDataWriterBase
{
    override public int GetPixelCountPerElement()
    {
        return 1;
    }
    override public AnimUsage GetAnimUsage()
    {
        return AnimUsage.AnimUsage_VertexPos_FP16;
    }
    public SingleTextureDataWriter1PPE_FP16_4C1P(int inMaxWidthPOTSize, int inMaxHeightPOTSize, int inColElementCount)
    {
        Init(inMaxWidthPOTSize, inMaxHeightPOTSize, inColElementCount, TextureFormat.RGBAHalf);
    }

    override protected void AddDataFrame(int dataCol, int dataRow, Vector4[] data)
    {
        int pixelRow = dataRow;
        int pixelCol = dataCol * mColPixelSize;
        Vector2 tmp = Vector2.zero;
        for (int i = 0; i < data.Length; ++i)
        {
            int dataIndex = pixelRow * mTexDimension.x + (pixelCol + i);
            mData[dataIndex] = data[i];
        }
    }
}