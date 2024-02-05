using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public class PlanarShadowData
{
    public float shadowFalloff = 1.35f;
    public float shadowPlanHeightFix = 0.02f;
    public Vector4 shadowPlanVector = new Vector4(0.0f, 1.0f, 0.0f, 0.1f);
    public Vector4 shadowFadeParams = new Vector4(0.0f, 1.5f, 0.7f, 0.0f);
    public Color shadowColor = new Vector4(0f, 0f, 0f, 0.3f);
}

public class PlanarShadowSceneSettings : MonoBehaviour
{
    public static PlanarShadowSceneSettings instance
    {
        get;
        private set;
    }

    public PlanarShadowData planarShadowData;

    private static PlanarShadowData defualt_planarShadowData = new PlanarShadowData();

    private void Awake()
    {
        instance = this;
        if(planarShadowData == null)
        {
            planarShadowData = new PlanarShadowData();
        }
    }

    public static void SetInstance(PlanarShadowSceneSettings instance)
    {
        PlanarShadowSceneSettings.instance = instance;
    }

    public static PlanarShadowData GetData()
    {
        if(instance != null)
        {
            return instance.planarShadowData;
        }
        return defualt_planarShadowData;
    }
}
