using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GPUAnimatorMgr : MonoBehaviour
{
    private static GPUAnimatorMgr mInst;
    private HashSet<GPUAnimator> mAllGpuAnimators = new HashSet<GPUAnimator>();
    private GPURuntimeAnimConfigs mAnimConfigs = new GPURuntimeAnimConfigs();

    static public GPUAnimatorMgr instance()
    {
        return mInst;
    }

    // Start is called before the first frame update
    void Awake()
    {
        if (mInst)
        {
            throw new System.Exception("there should be only one GPUAnimatorMgr instance!");
        }
        mInst = this;
    }

    // Update is called once per frame
    void Update()
    {
        float deltaTime = Time.deltaTime;
        foreach (var gpuAnimator in mAllGpuAnimators)
        {
            gpuAnimator.UpdateAnimator(deltaTime);
        }
    }

    private void OnDestroy()
    {
        //foreach (var gpuAnimator in mAllGpuAnimators)
        //{
        //    DelGpuAnimator(gpuAnimator);
        //}
        mInst = null;
    }

    public void AddGpuAnimator(int configHash, GPUAnimator gpuAnimator)
    {
        mAllGpuAnimators.Add(gpuAnimator);
        mAnimConfigs.AddGPUMecAnimConfig(configHash, gpuAnimator.mConfigFromAsset);
    }

    public void DelGpuAnimator(GPUAnimator gpuAnimator)
    {
        mAllGpuAnimators.Remove(gpuAnimator);
    }

    public bool GetPrefabAnimConfig(int configHash, out GPURuntimeAnimConfig_Prefab outConfig)
    {
        return mAnimConfigs.GetPrefabAnimConfig(configHash, out outConfig);
    }
}
