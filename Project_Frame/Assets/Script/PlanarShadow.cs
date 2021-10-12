using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PlanarShadow : MonoBehaviour
{
    /// <summary>
    /// 是否启用平面阴影
    /// </summary>
    public static bool useShadow = true;
    public static Light lightMain;
    private List<Material> listMat = new List<Material>();

    //参数先全部放到场景配置中
    //public float shadowFalloff = 1.35f;
    //public float shadowPlanHeightFix = 0.02f;
    //public Vector4 shadowPlanVector = new Vector4(0.0f, 1.0f, 0.0f, 0.1f);
    //public Vector4 shadowFadeParams = new Vector4(0.0f, 1.5f, 0.7f, 0.0f);
    //public Color shadowColor = Color.black;

    public static float s_fMaxDistanceToClose = 25.0f;
    public const string c_namePass = "Always";

    void Start()
    {
        CheckMainLight();
        if (lightMain == null)
        {
            return;
        }

        SkinnedMeshRenderer[] listRends = GetComponentsInChildren<SkinnedMeshRenderer>();
        foreach (var rend in listRends)
        {
            if (rend == null)
                continue;
            rend.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;

            //眼睛过滤掉
            if (rend.name.Contains("eye"))
                continue;

            this.listMat.Add(rend.material);
        }
    }

    void Update()
    {
        if(!useShadow)
        {
            return;
        }
        CheckMainLight();
        if (lightMain == null)
        {
            return;
        }
        updateShader();
    }

    private PlanarShadowData data;
    private Vector4 posWorld;
    private Vector4 shadowPlanVector;
    private Vector4 dirProj;
    private bool renderShadow;
    private Material mat;
    private Vector3 cameraPos;
    private void updateShader()
    {
        data = PlanarShadowSceneSettings.GetData();
        posWorld = transform.position;
        shadowPlanVector = data.shadowPlanVector;
        shadowPlanVector.w = posWorld.y + data.shadowPlanHeightFix;
        dirProj = lightMain.transform.forward;
        renderShadow = true;
        //if (CameraFollow.Instance != null &&
        //    CameraFollow.Instance.targetTrans != null &&
        //    CameraFollow.Instance.targetTrans != transform)
        //{
        //    cameraPos = CameraFollow.Instance.targetTrans.position;
        //    float fDis2 = (cameraPos.x - transform.position.x) * (cameraPos.x - transform.position.x) +
        //                 (cameraPos.z - transform.position.z) * (cameraPos.z - transform.position.z);
        //    if (fDis2 >= s_fMaxDistanceToClose * s_fMaxDistanceToClose)
        //        renderShadow = false;
        //}

        int count = this.listMat.Count;
        for (int i = 0; i < count; i++)
        {
            mat = this.listMat[i];
            if (mat == null)
                continue;
            if (!renderShadow)
            {
                mat.SetShaderPassEnabled(c_namePass, false);
                continue;
            }
            else
            {
                mat.SetShaderPassEnabled(c_namePass, true);
            }

            mat.SetVector("_WorldPos", posWorld);
            mat.SetVector("_ShadowProjDir", dirProj);
            mat.SetVector("_ShadowPlane", shadowPlanVector);
            mat.SetVector("_ShadowFadeParams", data.shadowFadeParams);
            mat.SetFloat("_ShadowFalloff", data.shadowFalloff);
            mat.SetColor("_ShadowColor", data.shadowColor);
        }
    }

    private static int checkFrameCount = -1;
    private static GameObject[] objs;
    private static GameObject go;
    private static Light tempLight = null;
    private static void CheckMainLight()
    {
        if(checkFrameCount == Time.frameCount)
        {
            return;
        }
        checkFrameCount = Time.frameCount;

        if (lightMain != null &&
            lightMain.gameObject.activeInHierarchy &&
            lightMain.enabled)
        {
            return;
        }

        lightMain = null;
        objs = GameObject.FindGameObjectsWithTag("MainLight");
        if (objs == null || objs.Length < 1)
        {
            return;
        }
        for (int i = 0; i < objs.Length; i++)
        {
            go = objs[i];
            if (go != null)
            {
                tempLight = objs[i].GetComponent<Light>();
                if (tempLight != null &&
                    tempLight.gameObject.activeInHierarchy && 
                    tempLight.enabled)
                {
                    lightMain = tempLight;
                    break;
                }
            }
        }
    }
}
