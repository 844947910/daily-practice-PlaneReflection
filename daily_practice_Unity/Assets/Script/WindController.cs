using UnityEngine;

[ExecuteInEditMode]
public class WindController : MonoBehaviour
{
    public enum WindType
    {
        Off,
        On,
        Wave
    }

    [Header("风系统设置")]
    [SerializeField] private WindType windType = WindType.On;
    
    [Header("风的基本参数")]
    [SerializeField] private Vector2 windDirection = new Vector2(1, 0);
    [SerializeField] private float windSpeed = 1.0f;
    [SerializeField] private float windIntensity = 1.0f;
    
    [Header("波浪风参数")]
    [Range(0.01f, 100.0f)] public float waveSize = 20.0f;
    [Range(0.0f, 10.0f)] public float waveIntensity = 1.0f;
    [SerializeField] private Texture2D waveMap;
    
    [Header("调试选项")]
    [SerializeField] private bool autoUpdateInEditMode = true;
    

    private static readonly int WIND_PARAMETER_PROP_ID = Shader.PropertyToID("_G_WindParameter");
    private static readonly int WIND_WAVE_PARAMS_PROP_ID = Shader.PropertyToID("_G_WindWavePrams");
    private static readonly int WIND_WAVE_MAP_PROP_ID = Shader.PropertyToID("_G_WindWaveMap");
    
    // 属性访问器
    public WindType CurrentWindType
    {
        get => windType;
        set
        {
            windType = value;
            UpdateWindSettings();
        }
    }
    
    public Vector2 WindDirection
    {
        get => windDirection;
        set
        {
            windDirection = value.normalized;
            UpdateWindSettings();
        }
    }
    
    public float WindSpeed
    {
        get => windSpeed;
        set
        {
            windSpeed = value;
            UpdateWindSettings();
        }
    }
    
    public float WindIntensity
    {
        get => windIntensity;
        set
        {
            windIntensity = value;
            UpdateWindSettings();
        }
    }

    private void OnEnable()
    {
        UpdateWindSettings();
    }

    private void OnValidate()
    {
        if (autoUpdateInEditMode && (Application.isPlaying || Application.isEditor))
        {
            UpdateWindSettings();
        }
    }

#if UNITY_EDITOR
    private void Update()
    {
        if (autoUpdateInEditMode && !Application.isPlaying)
        {
            UpdateWindSettings();
        }
    }
#endif

    [ContextMenu("更新风设置")]
    public void UpdateWindSettings()
    {
        switch (windType)
        {
            case WindType.Off:
                DisableWind();
                break;
            case WindType.On:
                SetupBasicWind();
                break;
            case WindType.Wave:
                SetupWaveWind();
                break;
        }
    }

    private void DisableWind()
    {
        Shader.EnableKeyword("_USE_WIND_OFF");
        Shader.DisableKeyword("_USE_WIND_ON");
        Shader.DisableKeyword("_USE_WIND_WAVE");
        
        Debug.Log("风系统已关闭", this);
    }

    private void SetupBasicWind()
    {
        Shader.DisableKeyword("_USE_WIND_OFF");
        Shader.EnableKeyword("_USE_WIND_ON");
        Shader.DisableKeyword("_USE_WIND_WAVE");
        
        Vector2 normalizedDirection = windDirection.normalized;
        Shader.SetGlobalVector(WIND_PARAMETER_PROP_ID, new Vector4(normalizedDirection.x, normalizedDirection.y, windSpeed, 0.02f * windIntensity));
        
        Debug.Log($"基本风已启用 - 方向: {normalizedDirection}, 速度: {windSpeed}, 强度: {windIntensity}", this);
    }

    private void SetupWaveWind()
    {
        Shader.DisableKeyword("_USE_WIND_OFF");
        Shader.DisableKeyword("_USE_WIND_ON");
        Shader.EnableKeyword("_USE_WIND_WAVE");
        
        // 设置基本风参数
        Vector2 normalizedDirection = windDirection.normalized;
        Shader.SetGlobalVector(WIND_PARAMETER_PROP_ID, 
            new Vector4(normalizedDirection.x, normalizedDirection.y, windSpeed, 0.02f * windIntensity));
        
        // 设置波浪参数
        Shader.SetGlobalVector(WIND_WAVE_PARAMS_PROP_ID, 
            new Vector4(waveSize, 1.0f / waveSize, waveIntensity));
        
        // 设置波浪贴图
        Shader.SetGlobalTexture(WIND_WAVE_MAP_PROP_ID, 
            waveMap == null ? Texture2D.blackTexture : waveMap);
        
        Debug.Log($"波浪风已启用 - 波浪大小: {waveSize}, 波浪强度: {waveIntensity}", this);
    }

    [ContextMenu("重置风参数")]
    public void ResetWindParameters()
    {
        windType = WindType.On;
        windDirection = new Vector2(1, 0);
        windSpeed = 1.0f;
        windIntensity = 1.0f;
        waveSize = 10.0f;
        waveIntensity = 1.0f;
        waveMap = null;
        
        UpdateWindSettings();
    }
    
    // 辅助方法：通过代码设置风
    public void SetWind(WindType type, Vector2 direction, float speed, float intensity)
    {
        windType = type;
        windDirection = direction;
        windSpeed = speed;
        windIntensity = intensity;
        UpdateWindSettings();
    }
    
    // 辅助方法：设置波浪风
    public void SetWaveWind(Vector2 direction, float speed, float intensity, float waveSize, float waveIntensity, Texture2D waveTexture = null)
    {
        windType = WindType.Wave;
        windDirection = direction;
        windSpeed = speed;
        windIntensity = intensity;
        this.waveSize = waveSize;
        this.waveIntensity = waveIntensity;
        waveMap = waveTexture;
        UpdateWindSettings();
    }
}