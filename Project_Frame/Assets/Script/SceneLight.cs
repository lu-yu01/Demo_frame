//using Sirenix.OdinInspector;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SceneLight : MonoBehaviour
{

   // [FoldoutGroup("ambient"), ColorUsage(false, true), OnValueChanged("UpdataLightSeting")]
    public Color SceneSkyColor;
    //[FoldoutGroup("ambient"), ColorUsage(false, true), OnValueChanged("UpdataLightSeting")]
    public Color SceneEquatorColor;
    //[FoldoutGroup("ambient"), ColorUsage(false, true), OnValueChanged("UpdataLightSeting")]
    public Color SceneGroundColor;
    //[FoldoutGroup("ambient"), ColorUsage(false, false), OnValueChanged("UpdataLightSeting")]
    public Color SceneShadowColor = Color.black;
    //[FoldoutGroup("ambient"), ColorUsage(false, false), OnValueChanged("UpdataLightSeting")]
    public Color SceneFringeShadowColor = Color.black;
    //[FoldoutGroup("ambient"), Range(5, 200), OnValueChanged("UpdataLightSeting")]
    public float SceneShadowDistance = 30;
   // [FoldoutGroup("ambient")]
    public Material SkyBoxMaterial;
   // [ReadOnly]
   // [FoldoutGroup("ambient")]
    public Vector4 _LightShadowData;
    // 场景的主灯光
  //  [OnValueChanged("UpdataLightSeting")]
    public Light ScaneMainLight = null;


   // [LabelText("场景CubeMap"), OnValueChanged("UpdataLightSeting")]
    public Cubemap SceneCubeMap;
    //[LabelText("场景CubeMap亮度"), Range(0, 1), OnValueChanged("UpdataLightSeting")]
    public float SceneReflectionIntensity = 1;

    private void Update()
    {
        UpdataLightSeting();
    }

    void UpdataLightSeting()
    {
        if (SkyBoxMaterial != null)
        {
            RenderSettings.skybox = SkyBoxMaterial;
        }
        RenderSettings.ambientSkyColor = SceneSkyColor;
        RenderSettings.ambientEquatorColor = SceneEquatorColor;
        RenderSettings.ambientGroundColor = SceneGroundColor;
        RenderSettings.customReflection = SceneCubeMap;
        RenderSettings.reflectionIntensity = SceneReflectionIntensity;
        Shader.SetGlobalVector("_PBRShadowColor", SceneShadowColor);
        Shader.SetGlobalVector("_PBRFringeShadowColor", SceneFringeShadowColor);
        UpdateLight();
    }

    void UpdateLight()
    {
        //Debug.Log("222222222");
        // 设置场景灯光信息
        _LightShadowData = Shader.GetGlobalVector("_LightShadowData");
        if (true)
        {
            Vector4 LightColor = new Vector4();
            Vector3 LightDir = new Vector3();
            if (ScaneMainLight != null)
            {
                var c = ScaneMainLight.color * ScaneMainLight.intensity;
                LightColor.x = c.r;
                LightColor.y = c.g;
                LightColor.z = c.b;
                LightDir = ScaneMainLight.transform.rotation * Vector3.back;
                _LightShadowData.x = 1.0f - ScaneMainLight.shadowStrength;
                Shader.SetGlobalVector("_LightShadowData", _LightShadowData);
            }
            else
            {
                //OwenrEngine.LightSolidImageSceneCubeSider.x = 0;
            }

            Shader.SetGlobalVector("MainSceneLightColor", LightColor);
            Shader.SetGlobalVector("MainSceneLightDir", LightDir);
            //Debug.Log(DDEngine._DDEngine.LightSolidImageSceneCubeSider);
            QualitySettings.shadowDistance = SceneShadowDistance;
        }
    }
}
