Shader "Ocean"
{
    Properties
    {
        _Depth("水深度", Float) = 1
        _DepthOffset("深度方向" , Float) =1.5
        _Alpha("透明度",Range(0,1)) = 0.8
        //[Space(10)][Header(Metallic Roughness)][Space(10)]
      //  [NoScaleOffset]_MRA("MRA", 2D) = "white" {}
        // _MetallicPower("金属度参数", Range( 0 , 1)) = 1
        // _RoughnessPower("粗糙度参数", Range( 0 , 1)) = 1

        [Space(10)][Header(Water Surface)][Space(10)]
        _Normal("Normal", 2D) = "bump" {}
        [HDR]_DepthColor1("浅水颜色", Color) = (0,0.6810271,0.6886792,1)
        [HDR]_DepthColor("深水颜色", Color) = (0,0.6810271,0.6886792,1)
        _NormalPower("法线强度1", Range( 0 , 1)) = 1
        _NormalPower2("法线强度2", Range( 0 , 1)) = 0.2
        _NormalScale("法线密度", Float) = 1
        _NormalSpeed("法线流动速度", Float) = 0.1
        _NormalDirection("法线流动方向", Vector) = (1,0,-1,0.2)

        [Space(10)][Header(Foam)][Space(10)]
        [NoScaleOffset]_FoamMask("泡沫Mask", 2D) = "white" {}
        _FoamDistance("泡沫距离", Float) = 1
        _FoamPower("泡沫强度", Range( 0 , 5)) = 0
        _Foamlevel("泡沫层次", Range( 0 , 100)) = 1
        _FoamScale("泡沫密度", Float) = 1
        _FoamContrast("泡沫对比度", Float) = 0
        _FoamSpeed("泡沫速度", Float) = 0.1
        _EdgesFade("泡沫深度", Float) = 0.1

        [Space(10)][Header(Caustics)][Space(10)]
        [Toggle(_CAUSTICS_ON)] _Caustics("Caustics", Float) = 1
        [HDR]_CausticsColor("焦散颜色", Color) = (0.5404058,0.8679245,0.8414827,1)
        _CausticsSpeed("焦散速度", Float) = 2
        _CausticsScale("焦散密度", Float) = 0.5
        _CausticsScale2("焦散层次", Range( 0 , 1)) = 0.5


        [Space(10)][Header(ReflectionMap)][Space(10)]
        [Toggle(_USEREFLECTIONMAP_ON)] _USEReflectionMap("使用反射", Float) = 0
        [Space(10)]
        [NoScaleOffset] _CubMap("反射贴图CubMap", CUBE) = "white" {}
        _ReflectionIntensity("反射强度", Range( 0 , 1)) = 0

        [Space(10)][Header(Subsurface Scattering)][Space(10)]
        [Toggle(_SUBSURFACE_ON)] _UseSubsurface("启用次表面散射", Float) = 1
        [HDR]_SubsurfaceColor("次表面颜色", Color) = (0.2, 0.8, 0.8, 1)
        _SubsurfacePower("次表面强度", Range(0, 10)) = 3
        _SubsurfaceDistortion("次表面扭曲", Range(0, 2)) = 0.5
        _SubsurfaceScale("次表面范围", Range(0, 5)) = 1
        _SubsurfaceThickness("厚度", Range(0, 1)) = 0.5

    }

    SubShader
    {

         Tags{ "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" "Queue"="Transparent"}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        ENDHLSL

        Pass
        {

            Name "Universal Forward"

            Tags
            {
                "LightMode" = "UniversalForward"
            }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Offset 0 , 0
            ColorMask RGBA

            HLSLPROGRAM
            #pragma multi_compile_instancing

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            #pragma shader_feature_local _USEREFLECTIONMAP_ON
            #pragma shader_feature_local _CAUSTICS_ON
            #pragma shader_feature_local _SUBSURFACE_ON
            #pragma shader_feature_local _WAVES_ON
           // #pragma shader_feature_local  _EDGMASK_ON

            #pragma vertex vert
            #pragma fragment frag


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
            #include  "Assets/Shader/OceanNoise.hlsl"


            // ═══════════════════════════════════════════════════════════════════════════════════
            // 顶点输入结构体 - 从网格获取的原始顶点数据
            // ═══════════════════════════════════════════════════════════════════════════════════
            struct VertexInput
            {
                float4 posOS : POSITION;        // 模型空间顶点位置
                float3 normalOS : NORMAL;       // 模型空间法线
                float4 tangentOS : TANGENT;     // 模型空间切线 (xyz=方向, w=副切线方向符号)
                float2 uv1 : TEXCOORD0;         // 第一套UV坐标（用于法线贴图等）
                float2 uv2 : TEXCOORD1;         // 第二套UV坐标（用于光照贴图）
                float4 vertexColor : COLOR;     // 顶点颜色
                UNITY_VERTEX_INPUT_INSTANCE_ID  // GPU实例化ID
            };

            // ═══════════════════════════════════════════════════════════════════════════════════
            // 顶点输出结构体 - 传递给片段着色器的插值数据
            // ═══════════════════════════════════════════════════════════════════════════════════
            struct VertexOutput
            {
                float4 posCS : SV_POSITION;                 // 裁剪空间位置（必需，用于光栅化）
                float4 lightmapUVOrVertexSH : TEXCOORD0;    // xy=光照贴图UV, xyz=球谐光照系数
                float4 fogFactorAndVertexLight : TEXCOORD1; // x=雾效因子, yzw=顶点光照
                float3 positionWS:TEXCOORD2;                // 世界空间位置
                float4 normalWS : TEXCOORD3;                // xyz=世界法线, w=世界位置X
                float4 tangentWS : TEXCOORD4;               // xyz=世界切线, w=世界位置Y
                float4 bitangentWS : TEXCOORD5;             // xyz=世界副切线, w=世界位置Z
                float4 screenPos : TEXCOORD6;               // 屏幕空间位置（用于深度/颜色采样）
                float2 uv : TEXCOORD7;                      // UV坐标
                float4 vc :COLOR;                           // 顶点颜色
                UNITY_VERTEX_INPUT_INSTANCE_ID              // GPU实例化ID
                UNITY_VERTEX_OUTPUT_STEREO                  // VR立体渲染支持
            };

            // ═══════════════════════════════════════════════════════════════════════════════════
            // 材质属性常量缓冲区 - SRP Batcher兼容
            // 所有材质属性必须放在这个CBUFFER中以支持SRP批处理
            // ═══════════════════════════════════════════════════════════════════════════════════
            CBUFFER_START(UnityPerMaterial)
                // --- 水深相关 ---
                float _DepthOffset;             // 深度偏移系数
                float _Depth;                   // 水深颜色过渡距离
                
                // --- 颜色 ---
                float4 _DepthColor;             // 深水颜色 (RGBA)
                float4 _DepthColor1;            // 浅水颜色 (RGBA)
                float4 _CausticsColor;          // 焦散颜色 (RGBA)
                float4 _SubsurfaceColor;        // 次表面散射颜色 (RGBA)
                
                // --- 法线贴图 ---
                float4 _NormalDirection;        // 法线流动方向 (xy=第一层, zw=第二层)
                float4 _Normal_ST;              // 法线贴图的Tiling(xy)和Offset(zw)
                float _NormalPower;             // 第一层法线强度
                float _NormalPower2;            // 第二层法线强度
                float _NormalScale;             // 法线贴图密度/缩放
                float _NormalSpeed;             // 法线流动速度
                
                // --- 泡沫效果 ---
                float _FoamPower;               // 泡沫整体强度
                float _FoamSpeed;               // 泡沫流动速度
                float _Foamlevel;               // 泡沫层次/细分度
                float _FoamScale;               // 泡沫贴图缩放
                float _FoamDistance;            // 泡沫出现的深度距离
                float _EdgesFade;               // 边缘软过渡距离（控制透明度渐变）
                float _FoamContrast;            // 泡沫对比度
                
                // --- 焦散效果 ---
                float _CausticsSpeed;           // 焦散动画速度
                float _CausticsScale;           // 焦散图案大小
                float _CausticsScale2;          // 焦散层次（第二层缩放）
                
                // --- 波浪（顶点动画，当前未启用）---
                float _WavesSpeed;              // 波浪速度
                float _WavesHeight;             // 波浪高度
                float _WavesScale;              // 波浪大小
                
                // --- 其他 ---
                float _Alpha;                   // 整体透明度
                float _ReflectionIntensity;     // 反射强度
                float _BlendMode;               // 混合模式（预留）
                
                // --- 次表面散射 ---
                float _SubsurfacePower;         // 次表面散射集中度
                float _SubsurfaceDistortion;    // 次表面光线扭曲度
                float _SubsurfaceScale;         // 次表面散射范围
                float _SubsurfaceThickness;     // 水体厚度/透光度
            CBUFFER_END

            // ═══════════════════════════════════════════════════════════════════════════════════
            // 纹理声明 - 使用TEXTURE2D宏支持跨平台
            // ═══════════════════════════════════════════════════════════════════════════════════
            TEXTURE2D(_FoamMask);               // 泡沫遮罩贴图
            SAMPLER(sampler_FoamMask);          // 泡沫贴图采样器

            TEXTURE2D(_Normal);                 // 法线贴图（水面波纹）
            SAMPLER(sampler_Normal);            // 法线贴图采样器

            TEXTURECUBE(_CubMap);               // 立方体贴图（环境反射）
            SAMPLER(sampler_CubMap);            // 立方体贴图采样器

            // ═══════════════════════════════════════════════════════════════════════════════════
            // 顶点着色器 - 处理每个顶点的位置、法线等数据
            // ═══════════════════════════════════════════════════════════════════════════════════
            VertexOutput vert(VertexInput v)
            {
                // 初始化输出结构体为0
                VertexOutput o = (VertexOutput)0;
                
                // GPU实例化设置（允许同一材质渲染多个对象）
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);   // VR立体渲染支持

                // === 传递基础数据 ===
                o.uv = v.uv1;           // 第一套UV坐标（用于法线贴图等）
                o.vc = v.vertexColor;   // 顶点颜色（可用于自定义遮罩）
                
                // === 空间变换 ===
                // 将顶点从模型空间转换到世界空间
                o.positionWS = TransformObjectToWorld(v.posOS.xyz);
                
                // 转换到视图空间（相机空间）- 这里计算但未使用
                float3 positionVS = TransformWorldToView(o.positionWS);
                
                // 转换到裁剪空间（用于光栅化）
                float4 positionCS = TransformWorldToHClip(o.positionWS);

                // === 法线/切线/副切线计算 ===
                // GetVertexNormalInputs 计算世界空间的TBN矩阵
                VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                
                // 将TBN向量和世界位置打包到float4中（节省插值器）
                // xyz = 向量, w = 世界位置分量
                o.normalWS = float4(normalInput.normalWS, o.positionWS.x);      // 法线 + 世界X
                o.tangentWS = float4(normalInput.tangentWS, o.positionWS.y);    // 切线 + 世界Y
                o.bitangentWS = float4(normalInput.bitangentWS, o.positionWS.z);// 副切线 + 世界Z
                
                // === 光照贴图和球谐光照 ===
                // 输出光照贴图UV（用于烘焙光照）
                OUTPUT_LIGHTMAP_UV(v.uv2, unity_LightmapST, o.lightmapUVOrVertexSH.xy);
                // 输出球谐光照系数（用于环境光照）
                OUTPUT_SH(normalInput.normalWS.xyz, o.lightmapUVOrVertexSH.xyz);
                
                // === URP 雾效 ===
                // 根据深度计算雾效因子（用于片段着色器中的雾效混合）
                half fogFactor = ComputeFogFactor(positionCS.z);
                o.fogFactorAndVertexLight = half4(fogFactor, 0, 0, 0);  // x=雾效, yzw=顶点光照（未使用）
                
                // === 输出位置 ===
                o.posCS = positionCS;                       // 裁剪空间位置（光栅化用）
                o.screenPos = ComputeScreenPos(positionCS); // 屏幕空间位置（用于深度采样等）

                return o;
            }


            float4 frag(VertexOutput IN) : SV_Target
            {
                // ═══════════════════════════════════════════════════════════════════════
                // 初始化设置
                // ═══════════════════════════════════════════════════════════════════════
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                // ═══════════════════════════════════════════════════════════════════════
                // 基础向量计算
                // ═══════════════════════════════════════════════════════════════════════
                float3 posWS = IN.positionWS;                                           // 世界空间位置
                float3 viewDirWS = SafeNormalize(_WorldSpaceCameraPos.xyz - posWS);     // 视线方向（归一化）
                float viewDirVertical = abs(viewDirWS.y);                               // 视线垂直分量（俯视=1，平视=0）

                // ═══════════════════════════════════════════════════════════════════════
                // 深度计算 - 获取水面与水底物体之间的深度差
                // ═══════════════════════════════════════════════════════════════════════
                float2 screenUV = IN.screenPos.xy / IN.screenPos.w;                     // 归一化屏幕UV (0-1)
                float sceneDepthRaw = SampleSceneDepth(screenUV);                       // 采样深度缓冲区
                float waterSurfaceDepth = LinearEyeDepth(IN.posCS.z, _ZBufferParams);   // 水面线性深度
                float underwaterObjDepth = LinearEyeDepth(sceneDepthRaw, _ZBufferParams); // 水底物体线性深度
                float waterToBottomDist = underwaterObjDepth - waterSurfaceDepth;       // 水面到水底的距离

                // ═══════════════════════════════════════════════════════════════════════
                // 边缘软过渡 & 泡沫效果计算
                // ═══════════════════════════════════════════════════════════════════════
                
                // --- 边缘软过渡透明度 ---
                float edgeDepthGradient = abs(waterToBottomDist / _EdgesFade) * viewDirVertical;  // 边缘深度梯度
                float edgeFadeOpacity = saturate(edgeDepthGradient);                              // 边缘透明度 (边缘=0, 深水=1)
                 
                // --- 泡沫深度遮罩 ---
                float foamShoreDepthMask = abs(waterToBottomDist / (_FoamDistance * 0.1));        // 近岸泡沫深度遮罩（敏感）
                float foamDepthMask = abs(waterToBottomDist / _FoamDistance);                     // 泡沫深度遮罩
                float foamEdgeFalloff = 1.0 - (viewDirVertical * foamDepthMask);                  // 泡沫边缘衰减

                // --- 泡沫纹理采样 ---
                float2 foamUV_Static = posWS.xz * (_FoamScale / _Foamlevel);                      // 静态泡沫UV
                float2 foamUV_Animated = _Time.y * (_FoamSpeed / _Foamlevel).xx + (1.0 - foamUV_Static); // 动态泡沫UV
                
                // --- 泡沫强度计算 ---
                float foamTexStatic = SAMPLE_TEXTURE2D(_FoamMask, sampler_FoamMask, foamUV_Static).r;
                float foamTexAnimated = SAMPLE_TEXTURE2D(_FoamMask, sampler_FoamMask, foamUV_Animated).r;
                float foamTextureMask = foamTexStatic * foamTexAnimated;                          // 泡沫纹理混合
                float foamEdgeBase = 1.0 - viewDirVertical * foamShoreDepthMask;                  // 基础边缘泡沫
                float foamTextureDetail = foamEdgeFalloff * pow(foamEdgeFalloff * foamTextureMask, 0.5); // 纹理泡沫细节
                float foamIntensity = edgeDepthGradient * (foamEdgeBase + foamTextureDetail) * _FoamPower;
                float4 foamColor = saturate(CalculateContrast(_FoamContrast, foamIntensity.xxxx)); // 最终泡沫颜色

                // ═══════════════════════════════════════════════════════════════════════
                // 法线贴图计算 - 创造水面波纹效果
                // ═══════════════════════════════════════════════════════════════════════
                
                float2 normalBaseUV = IN.uv.xy * _Normal_ST.xy + _Normal_ST.zw;                   // 基础法线UV
                float2 normalFlowDir1 = float2(_NormalDirection.x, _NormalDirection.y);           // 第一层流动方向
                float2 normalFlowDir2 = float2(_NormalDirection.z, _NormalDirection.w);           // 第二层流动方向

                // --- 第一层法线 (主要波纹) ---
                float2 normalUV_Layer1 = _Time.y * (normalFlowDir1 * _NormalSpeed / 100) + (normalBaseUV / 100.0 * _NormalScale);
                float3 normalLayer1 = UnpackNormalScale(SAMPLE_TEXTURE2D(_Normal, sampler_Normal, normalUV_Layer1), _NormalPower);

                // --- 第二层法线 (次要波纹，速度10倍，密度1.2倍) ---
                float2 normalUV_Layer2 = _Time.y * normalFlowDir2 * (_NormalSpeed / 100 * 10) + normalBaseUV / 100.0 * _NormalScale * (_NormalScale * 1.2);
                float3 normalLayer2 = UnpackNormalScale(SAMPLE_TEXTURE2D(_Normal, sampler_Normal, normalUV_Layer2), _NormalPower2);
                
                // --- 泡沫区域法线（与第一层相同）---
                float3 normalFoamArea = UnpackNormalScale(SAMPLE_TEXTURE2D(_Normal, sampler_Normal, normalUV_Layer1), _NormalPower);

                // --- 法线Z分量修正 ---
                normalLayer2.z = lerp(1, normalLayer2.z, saturate(_NormalPower2));
                normalLayer1.z = lerp(1, normalLayer1.z, saturate(_NormalPower));
                normalFoamArea.z = lerp(1, normalFoamArea.z, saturate(_NormalPower));
                
                // --- 法线混合：水面区域混合两层，泡沫区域用单独法线 ---
                float3 finalNormalTS = lerp(BlendNormal(normalLayer1, normalLayer2), normalFoamArea, foamColor.rgb);
                
                // --- 切线空间转世界空间 ---
                float3 finalNormalWS = normalize(
                    finalNormalTS.x * IN.tangentWS.xyz +
                    finalNormalTS.y * IN.bitangentWS.xyz +
                    finalNormalTS.z * IN.normalWS.xyz
                );

                // ═══════════════════════════════════════════════════════════════════════
                // 水深颜色计算 - 浅水到深水的颜色渐变
                // ═══════════════════════════════════════════════════════════════════════
                
                float waterDepthNormalized = saturate(abs(waterToBottomDist / _Depth));           // 归一化水深 (0-1)
                float waterDepthVisual = (1.0 - waterDepthNormalized * (1 - viewDirVertical)) * _DepthOffset; // 视觉水深（含视角修正）
                float4 waterBaseColor = lerp(_DepthColor1, _DepthColor, (1.0 - waterDepthVisual)); // 深浅水颜色混合

                // ═══════════════════════════════════════════════════════════════════════
                // 焦散效果 (Caustics) - 模拟水底光线折射图案
                // ═══════════════════════════════════════════════════════════════════════
                
                float causticsTime = _Time.y * _CausticsSpeed;                                    // 焦散动画时间
                float2 causticsUV = posWS.xz * (_CausticsScale * _CausticsScale2);               // 焦散UV坐标
                
                float2 voronoiCellId = 0;
                float2 voronoiCellUV = 0;
                float2 voronoiSmoothId = 0;
                float voronoiPattern = voronoi(causticsUV, causticsTime, voronoiCellId, voronoiCellUV, 0, voronoiSmoothId);
                
                #ifdef _CAUSTICS_ON
                float causticsIntensity = saturate(voronoiPattern);
                #else
                float causticsIntensity = 0.0;
                #endif
                
                float4 waterColorWithCaustics = lerp(waterBaseColor, _CausticsColor, causticsIntensity * waterBaseColor.a);

                // ═══════════════════════════════════════════════════════════════════════
                // 环境反射 - CubeMap反射贴图
                // ═══════════════════════════════════════════════════════════════════════
                #ifdef _USEREFLECTIONMAP_ON
                float3 reflectionDir = reflect(-viewDirWS, finalNormalTS);
                float4 reflectionColor = SAMPLE_TEXTURECUBE(_CubMap, sampler_CubMap, reflectionDir) * _ReflectionIntensity;
                #else
                float4 reflectionColor = 0;
                #endif

                // ═══════════════════════════════════════════════════════════════════════
                // 次表面散射 (SSS) - 模拟光线穿透水体的效果
                // ═══════════════════════════════════════════════════════════════════════
                float3 sssColor = 0;
                #ifdef _SUBSURFACE_ON
                    Light mainLight = GetMainLight();
                    float3 lightDir = normalize(mainLight.direction);
                    float3 lightColor = mainLight.color;
                    
                    // === 背光透射 (Translucency) ===
                    float3 distortedHalfVector = normalize(lightDir + finalNormalWS * _SubsurfaceDistortion);
                    float backlightDot = pow(saturate(dot(viewDirWS, -distortedHalfVector)), _SubsurfacePower);
                    float backlightIntensity = backlightDot * _SubsurfaceScale;
                    
                    // === 包裹光照 (Wrap Lighting) ===
                    float normalDotLight = dot(finalNormalWS, lightDir);
                    float wrapLightingDot = saturate((normalDotLight + _SubsurfaceDistortion) / (1.0 + _SubsurfaceDistortion));
                    float wrapLightIntensity = pow(wrapLightingDot, 0.5) * 0.5;
                    
                    // === 透光率（浅水更透光）===
                    float sssTransmittance = (1.0 - saturate(waterDepthNormalized * 2.0)) * _SubsurfaceThickness + 0.2;
                    
                    // === 综合SSS ===
                    float sssIntensity = (backlightIntensity + wrapLightIntensity) * sssTransmittance;
                    sssColor = lightColor * _SubsurfaceColor.rgb * sssIntensity;
                #endif

                // ═══════════════════════════════════════════════════════════════════════
                // 最终颜色合成
                // ═══════════════════════════════════════════════════════════════════════
                
                float3 finalAlbedo = saturate(foamColor.rgb + waterColorWithCaustics.rgb);        // 基础颜色 = 泡沫 + 水体
                float3 finalColor = finalAlbedo + reflectionColor.rgb + sssColor;                 // 最终颜色 = 基础 + 反射 + SSS
                float finalAlpha = edgeFadeOpacity * _Alpha;                                      // 最终透明度
                
                // === 雾效混合 ===
                float fogFactor = IN.fogFactorAndVertexLight.x;
                finalColor = MixFog(finalColor, fogFactor);

                return float4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
 
    }


}