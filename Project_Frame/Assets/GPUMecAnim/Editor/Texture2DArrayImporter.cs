using UnityEngine;
using UnityEditor;
using UnityEditor.AssetImporters;
using System.Collections;
using System.Collections.Generic;
using System.IO;

[CanEditMultipleObjects]
[ScriptedImporter(c_VersionNumber, Texture2DArrayImporter.c_FileExtension)]
public class Texture2DArrayImporter : ScriptedImporter
{
    public const string c_FileExtension = "texture2darray";
    public const int c_VersionNumber = 202010;

    [Tooltip("Selects how the Texture behaves when tiled !")]
    [SerializeField]
    TextureWrapMode wrapMode = TextureWrapMode.Repeat;

    [Tooltip("Selects how the Texture is filtered when it gets stretched by 3D transformations !")]
    [SerializeField]
    FilterMode filterMode = FilterMode.Bilinear;

    [Tooltip("Increases Texture quality when viewing the texture at a steep angle.\n0 = Disabled for all textures\n1 = Enabled for all textures in Quality Settings\n2..16 = Anisotropic filtering level !")]
    [Range(0, 16)]
    [SerializeField]
    int anisoLevel = 1;

    [Tooltip("A list of textures that are added to the texture array !")]
    [SerializeField]
    List<Texture2D> listTextures = new List<Texture2D>();

    public enum VerifyResult
    {
        Valid,
        Null,
        MasterNull,
        WidthMismatch,
        HeightMismatch,
        FormatMismatch,
        MipmapMismatch,
        SRGBTextureMismatch,
        NotAnAsset,
        MasterNotAnAsset,
    }

    public Texture2D[] Textures
    {
        get { return this.listTextures.ToArray(); }
        set
        {
            if (value == null)
                throw new System.NotSupportedException("Texture2DArrayImporter.Textures: Textures must not be set to null !");

            for (var n = 0; n < value.Length; ++n)
            {
                if (value[n] == null)
                    throw new System.NotSupportedException(string.Format("Texture2DArrayImporter.Textures: The texture at array index '{0}' must not be 'null' !", n));

                if (string.IsNullOrEmpty(AssetDatabase.GetAssetPath(value[n])))
                    throw new System.NotSupportedException(string.Format("Texture2DArrayImporter.Textures: The texture '{1}' at array index '{0}' does not exist on disk. Only texture assets can be added !", n, value[n].name));
            }
            this.listTextures = new List<Texture2D>(value);
        }
    }

    public TextureWrapMode WrapMode
    {
        get { return this.wrapMode; }
        set { this.wrapMode = value; }
    }

    public FilterMode FilterMode
    {
        get { return this.filterMode; }
        set { this.filterMode = value; }
    }

    public int AnisoLevel
    {
        get { return this.anisoLevel; }
        set { this.anisoLevel = value; }
    }


    public override void OnImportAsset(AssetImportContext ctx)
    {
        var width = 64;
        var height = 64;
        var mipmapEnabled = true;
        var textureFormat = TextureFormat.ARGB32;
        var srgbTexture = true;

        //1> Check if the input textures are valid to be used to build the texture array.
        var isValid = Verify(ctx, false);
        if (isValid)
        {
            // Use the texture assigned to the first slice as "master".
            // This means all other textures have to use same settings as the master texture.
            var sourceTexture = this.listTextures[0];
            width = sourceTexture.width;
            height = sourceTexture.height;
            textureFormat = sourceTexture.format;

            var sourceTexturePath = AssetDatabase.GetAssetPath(sourceTexture);
            var textureImporter = (TextureImporter)AssetImporter.GetAtPath(sourceTexturePath);
            mipmapEnabled = textureImporter.mipmapEnabled;
            srgbTexture = textureImporter.sRGBTexture;
        }

        // Create the texture array.
        // When the texture array asset is being created, there are no input textures added yet,
        // thus we do Max(1, Count) to make sure to add at least 1 slice.
        var texture2DArray = new Texture2DArray(width, height, Mathf.Max(1, this.listTextures.Count), textureFormat, mipmapEnabled, !srgbTexture);
        texture2DArray.wrapMode = this.WrapMode;
        texture2DArray.filterMode = this.FilterMode;
        texture2DArray.anisoLevel = this.AnisoLevel;

        if (isValid)
        {
            // If everything is valid, copy source textures over to the texture array.
            for (var n = 0; n < this.listTextures.Count; ++n)
            {
                var source = this.listTextures[n];
                Graphics.CopyTexture(source, 0, texture2DArray, n);
            }
        }
        else
        {
            // If there is any error, copy a magenta colored texture into every slice.
            // I was thinking to only make the invalid slice magenta, but then it's way less obvious that
            // something isn't right with the texture array. Thus I mark the entire texture array as broken.
            var errorTexture = new Texture2D(width, height, textureFormat, mipmapEnabled);
            try
            {
                var errorPixels = errorTexture.GetPixels32();
                for (var n = 0; n < errorPixels.Length; ++n)
                    errorPixels[n] = Color.magenta;
                errorTexture.SetPixels32(errorPixels);
                errorTexture.Apply();

                for (var n = 0; n < texture2DArray.depth; ++n)
                    Graphics.CopyTexture(errorTexture, 0, texture2DArray, n);
            }
            finally
            {
                DestroyImmediate(errorTexture);
            }
        }

        // Mark all input textures as dependency to the texture array.
        // This causes the texture array to get re-generated when any input texture changes or when the build target changed.
        for (var n = 0; n < this.listTextures.Count; ++n)
        {
            var source = this.listTextures[n];
            if (source != null)
            {
                var path = AssetDatabase.GetAssetPath(source);
                ctx.DependsOnArtifact(path);
            }
        }

        ctx.AddObjectToAsset("Texture2DArray", texture2DArray);
        ctx.SetMainObject(texture2DArray);

        if (!isValid)
        {
            // Run the verify step again, but this time we have the main object asset.
            // Console logs should ping the asset, but they don't in 2019.3 beta, bug?
            Verify(ctx, true);
        }
    }
    
    bool Verify(AssetImportContext ctx, bool logToConsole)
    {
        if (!SystemInfo.supports2DArrayTextures)
        {
            if (logToConsole)
                ctx.LogImportError(string.Format("Texture2DArrayImporter.Verify: Import failed '{0}'. Your system does not support texture arrays !", ctx.assetPath), ctx.mainObject);

            return false;
        }

        if (this.listTextures.Count > 0)
        {
            if (this.listTextures[0] == null)
            {
                if (logToConsole)
                    ctx.LogImportError(string.Format("Texture2DArrayImporter.Verify: Import failed '{0}'. The first element in the 'Textures' list must not be 'None' !", ctx.assetPath), ctx.mainObject);

                return false;
            }
        }

        var result = this.listTextures.Count > 0;
        for (var n = 0; n < this.listTextures.Count; ++n)
        {
            var valid = Verify(n);
            if (valid != VerifyResult.Valid)
            {
                result = false;
                if (logToConsole)
                {
                    var error = GetVerifyString(n);
                    if (!string.IsNullOrEmpty(error))
                    {
                        var msg = string.Format("Texture2DArrayImporter.Verify: Import failed '{0}'. {1}", ctx.assetPath, error);
                        ctx.LogImportError(msg, ctx.mainObject);
                    }
                }
            }
        }

        return result;
    }

   
    public VerifyResult Verify(int slice)
    {
        Texture2D master = (this.listTextures.Count > 0) ? this.listTextures[0] : null;
        Texture2D texture = (slice >= 0 && this.listTextures.Count > slice) ? this.listTextures[slice] : null;

        if (texture == null)
            return VerifyResult.Null;

        var textureImporter = AssetImporter.GetAtPath(AssetDatabase.GetAssetPath(texture)) as TextureImporter;
        if (textureImporter == null)
            return VerifyResult.NotAnAsset;

        if (master == null)
            return VerifyResult.MasterNull;

        var masterImporter = AssetImporter.GetAtPath(AssetDatabase.GetAssetPath(master)) as TextureImporter;
        if (masterImporter == null)
            return VerifyResult.MasterNotAnAsset;

        if (texture.width != master.width)
            return VerifyResult.WidthMismatch;

        if (texture.height != master.height)
            return VerifyResult.HeightMismatch;

        if (texture.format != master.format)
            return VerifyResult.FormatMismatch;

        if (texture.mipmapCount != master.mipmapCount)
            return VerifyResult.MipmapMismatch;

        if (textureImporter.sRGBTexture != masterImporter.sRGBTexture)
            return VerifyResult.SRGBTextureMismatch;

        return VerifyResult.Valid;
    }
    
    public string GetVerifyString(int slice)
    {
        var result = Verify(slice);
        switch (result)
        {
            case VerifyResult.Valid:
                {
                    return "";
                }

            case VerifyResult.MasterNull:
                {
                    return "The texture for slice 0 must not be 'None'.";
                }

            case VerifyResult.Null:
                {
                    return string.Format("The texture for slice {0} must not be 'None'.", slice);
                }

            case VerifyResult.FormatMismatch:
                {
                    var master = this.listTextures[0];
                    var texture = this.listTextures[slice];

                    return string.Format("Texture '{0}' uses '{1}' as format, but must be using '{2}' instead, because the texture for slice 0 '{3}' is using '{2}' too.",
                        texture.name, texture.format, master.format, master.name);
                }

            case VerifyResult.MipmapMismatch:
                {
                    var master = this.listTextures[0];
                    var texture = this.listTextures[slice];

                    return string.Format("Texture '{0}' has '{1}' mipmap(s), but must have '{2}' instead, because the texture for slice 0 '{3}' is having '{2}' mipmap(s). Please check if the 'Generate Mip Maps' setting for both textures is the same.",
                        texture.name, texture.mipmapCount, master.mipmapCount, master.name);
                }

            case VerifyResult.SRGBTextureMismatch:
                {
                    var master = this.listTextures[0];
                    var texture = this.listTextures[slice];

                    return string.Format("Texture '{0}' uses different 'sRGB' setting than slice 0 texture '{1}'.",
                        texture.name, master.name);
                }

            case VerifyResult.WidthMismatch:
            case VerifyResult.HeightMismatch:
                {
                    var master = this.listTextures[0];
                    var texture = this.listTextures[slice];

                    return string.Format("Texture '{0}' is {1}x{2} in size, but must be using the same size as the texture for slice 0 '{3}', which is {4}x{5}.",
                        texture.name, texture.width, texture.height, master.name, master.width, master.height);
                }

            case VerifyResult.MasterNotAnAsset:
            case VerifyResult.NotAnAsset:
                {
                    var texture = this.listTextures[slice];

                    return string.Format("Texture '{0}' is not saved to disk. Only texture assets that exist on disk can be added to a Texture2DArray asset.",
                        texture.name);
                }
        }

        return "Unhandled validation issue.";
    }


    [MenuItem("Assets/Create/Texture2D Array", priority = 310)]
    static void CreateTexture2DArrayMenuItem()
    {
        string directoryPath = "Assets";
        foreach (Object obj in Selection.GetFiltered(typeof(Object), SelectionMode.Assets))
        {
            directoryPath = AssetDatabase.GetAssetPath(obj);
            if (!string.IsNullOrEmpty(directoryPath) && File.Exists(directoryPath))
            {
                directoryPath = Path.GetDirectoryName(directoryPath);
                break;
            }
        }
        directoryPath = directoryPath.Replace("\\", "/");
        if (directoryPath.Length > 0 && directoryPath[directoryPath.Length - 1] != '/')
            directoryPath += "/";
        if (string.IsNullOrEmpty(directoryPath))
            directoryPath = "Assets/";

        var fileName = string.Format("New Texture2DArray.{0}", c_FileExtension);
        directoryPath = AssetDatabase.GenerateUniqueAssetPath(directoryPath + fileName);
        ProjectWindowUtil.CreateAssetWithContent(directoryPath, "This file represents a Texture2DArray asset for Unity.\nYou need the 'Texture2DArray Import Pipeline' package available at https://github.com/pschraut/UnityTexture2DArrayImportPipeline to properly import this file in Unity.");
    }
}
