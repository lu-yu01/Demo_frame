using Sirenix.OdinInspector;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LuEngine : MonoBehaviour
{
    // 角色的主灯光
    public Light PlayerPBRLight;
    //[OnValueChanged("OnSetProcessPross")]
    public Light PlayerViewScanePBRLight;
    // 卡通着色部分的灯光位置
    public Transform PlayerCartoolLight;
    public Transform PlayerEyeLight;
    public Transform FarRootScane;

    [HideInInspector]
    public Vector4 LightSolidImageSceneCubeSider = new Vector4(0, 0, 0, 0);

    [FoldoutGroup("角色相关"), LabelText("角色CubeMap")]
    public Cubemap PlayerCubeMap;
    [FoldoutGroup("角色相关"), LabelText("角色CubeMap亮度"), Range(0, 4.6f)]
    public float PlayerCubeMapLit = 0.5f;

    // 玩家位置
    [FoldoutGroup("角色相关"), LabelText("角色位置")]
    public Transform PlayerPos;

    void Update()
    {
        UpdataLightSeting();
    }

    void UpdataLightSeting()
    {
        Vector4 LightColor = new Vector4();
        Vector3 LightDir = new Vector3();
        if (PlayerCartoolLight)
        {

            LightDir = PlayerCartoolLight.rotation * Vector3.back;
        }
        Shader.SetGlobalVector("PlayerCartoolLightDir", LightDir);

        if (PlayerPBRLight != null)
        {
            var c = PlayerPBRLight.color * PlayerPBRLight.intensity;
            LightColor.x = c.r;
            LightColor.y = c.g;
            LightColor.z = c.b;
            LightDir = PlayerPBRLight.transform.rotation * Vector3.back;
            LightSolidImageSceneCubeSider.y = 1;
            if (PlayerCartoolLight == null)
            {
                Shader.SetGlobalVector("PlayerCartoolLightDir", LightDir);
            }
        }
        else
        {
            LightSolidImageSceneCubeSider.y = 0;
        }
        Shader.SetGlobalVector("MainPlayerLightColor", LightColor);
        Shader.SetGlobalVector("MainPlayerLightDir", LightDir);
        //// 设置眼镜的定光方向
        //if (PlayerEyeLight != null)
        //{
        //    LightDir = PlayerEyeLight.transform.rotation * Vector3.back;

        //}
        //Shader.SetGlobalVector("MainPlayerEyeLightDir", LightDir);
        if (PlayerViewScanePBRLight != null)
        {
            var c = PlayerViewScanePBRLight.color * PlayerViewScanePBRLight.intensity;
            LightColor.x = c.r;
            LightColor.y = c.g;
            LightColor.z = c.b;
            LightDir = PlayerViewScanePBRLight.transform.rotation * Vector3.back;
        }
        Shader.SetGlobalVector("PlayerViewScanePBRLightColor", LightColor);
        Shader.SetGlobalVector("PlayerViewScanePBRLightDir", LightDir);
        LightSolidImageSceneCubeSider.x = 1;
        Shader.SetGlobalVector("LightSolidImageSceneCubeSider", LightSolidImageSceneCubeSider);
        //Debug.Log(LightSolidImageSceneCubeSider);

        // 指定的反射球
        if (PlayerCubeMap != null)
        {
            Shader.SetGlobalTexture("PlayerCubeMap", PlayerCubeMap);
        }
        Shader.SetGlobalVector("PlayerCubeMap_HDR", new Vector4(PlayerCubeMapLit, 1, 0, 0));
        Shader.SetGlobalVector("unity_4LightAtten0", Vector4.zero);
        UpdatePlayerPosition();
    }


    void UpdatePlayerPosition()
    {
        if (PlayerPos != null)
        {
            Shader.SetGlobalVector("MainPlayerPos", PlayerPos.position);

        }
        else
        {
            if (Camera.current != null)
            {
                Shader.SetGlobalVector("MainPlayerPos", Camera.current.transform.position);
            }
            else
            {
                Shader.SetGlobalVector("MainPlayerPos", Camera.main.transform.position);
            }

        }
    }

}
