
public class BakeGPUMecAnim
{    
    public static void BakeAnimation(string prefabPath, GPUMecAnimExportData data, bool bakeVert, bool bakeRig)
    {
        var animExporter = new GPUMecAnimDataExporter_FP16();
        animExporter.ExportAnimData(prefabPath, data, bakeVert, bakeRig);
    }
}
