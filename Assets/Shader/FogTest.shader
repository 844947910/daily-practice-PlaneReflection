Shader "Study/HGSphereFog"
{
    Properties
    {
        _Radius("雾效半径", Float) = 1
        [Toggle]_UseColorEnd("边缘颜色", Float) = 0
        [HDR]_Color("中心颜色", Color) = (0.1815592,0.6622906,0.9433962,1)
        [HDR]_ColorEnd("边缘颜色", Color) = (0.5301531,0.8027155,0.9622642,1)
        _FogDensity("雾浓度", Range(0 , 1)) = 1
        _DepthFade("深度衰减", Float) = 1
        [HideInInspector] _StartDis("_StartDis", Float) = 0
        [HideInInspector] _ClipDepth("ClipDepth", Float) = 10000
        [Toggle]_USE_NOISE("噪声", Float) = 0
        _NoiseTex("_NoiseTex", 2D) = "white" {}
        _TexScale("_TexScale", Float) = 1
        _TexFlowSpeed("TexFlowSpeed", Float) = 0
        _NoiseMin("NoiseMin", Float) = 0
        _ClipDistance("Clip Distance", float) = 10000
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
        }
        Pass
        {
            Name "Forward"
            Tags
            {
                "LightMode"="UniversalForward"
            }

            Blend SrcAlpha OneMinusSrcAlpha
            Cull Front
            ZTest Off
            ZWrite Off
            HLSLPROGRAM
            #pragma target 3.0
            // -------------------------------------
            // Shader Stages
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
            #pragma shader_feature_local _USE_NOISE_ON

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct AttributesParticle
            {
                half4 positionOS : POSITION;
                half4 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VaryingsParticle
            {
                half4 clipPos : SV_POSITION;
                half4 texcoord : TEXCOORD0;
                float3 pivortRWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                half3 viewDirWS : TEXCOORD3;
                float objectScale : TEXCOORD4; //用于传递物体缩放信息

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _ColorEnd;
                float _UseColorEnd;
                float _Radius;
                float _DepthFade;
                float _StartDis;
                float _ClipDepth;
                float _FogDensity;
                float _NoiseMin;
                float _ClipDistance;
                float _TexScale;
                float _TexFlowSpeed;
                float4 _EmissionColor;
                half _SurfaceType;
            CBUFFER_END

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

        
            float GetObjectScale()
            {
                // 从模型矩阵中提取缩放信息
                float4x4 objectToWorld = GetObjectToWorldMatrix();

                float3 scale;
                scale.x = length(float3(objectToWorld[0].x, objectToWorld[1].x, objectToWorld[2].x));
                scale.y = length(float3(objectToWorld[0].y, objectToWorld[1].y, objectToWorld[2].y));
                scale.z = length(float3(objectToWorld[0].z, objectToWorld[1].z, objectToWorld[2].z));
                //返回平均缩放值
                return (scale.x + scale.y + scale.z) / 3.0;
            }

            ///////////////////////////////////////////////////////////////////////////////
            //                  Vertex and Fragment functions                            //
            ///////////////////////////////////////////////////////////////////////////////

            VaryingsParticle vert(AttributesParticle input)
            {
                VaryingsParticle output = (VaryingsParticle)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                // position ws is used to compute eye depth in vertFading
                output.positionWS = vertexInput.positionWS;
                output.pivortRWS = TransformObjectToWorld(0) - GetCurrentViewPosition();
                output.clipPos = vertexInput.positionCS;
                output.viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
                output.texcoord = input.texcoord;

                //获取并传递物体缩放信息
                output.objectScale = GetObjectScale();

                return output;
            }

            float LoadCameraDepth(uint2 pixelCoords)
            {
                return LOAD_TEXTURE2D_X_LOD(_CameraDepthTexture, pixelCoords, 0).r;
            }

            half4 frag(VaryingsParticle input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                half pivortDis = length(input.pivortRWS);
                if (_ClipDistance < pivortDis)
                {
                    clip(-1);
                    return 0;
                }

                half4 finalColor = 1;
                half2 uv = input.texcoord.xy;
                half2 screenUV = input.clipPos * _ScreenSize.zw;
                // float linearDepth = LinearEyeDepth(LoadCameraDepth1(input.clipPos), _ZBufferParams);
                float sceneDepth = LoadCameraDepth(input.clipPos.xy);
                float linearDepth = LinearEyeDepth(sceneDepth, _ZBufferParams);

                float depthLen = linearDepth / dot(-input.viewDirWS, GetViewForwardDir());
                half dotPV = dot(input.pivortRWS, -input.viewDirWS);

                float rawDepth = sceneDepth;
                bool isSkybox = (rawDepth == 0.0); // 或者接近0的值
                // 如果背后没有物体，使用一个合理的最大深度值
                float maxReasonableDepth = 1000.0; // 根据场景调整
                float effectiveDepth = isSkybox ? maxReasonableDepth : linearDepth;

                // 使用物体缩放来调整雾效半径
                float scaledRadius = _Radius * input.objectScale;

                float dist2 = max(0.1, pivortDis * pivortDis - dotPV * dotPV);
                float dist = sqrt(dist2);
                float halfThroughInSphereDis = sqrt(0.01 + scaledRadius * scaledRadius - dist2);
                float farDis = step(dist, scaledRadius) * max(0, dotPV + halfThroughInSphereDis);
                float nearDis = step(dist, scaledRadius) * max(0, dotPV - halfThroughInSphereDis);

                half travelDis01 = (min(depthLen, farDis) - min(depthLen, nearDis)) / (2 * scaledRadius);

                // 特别处理天空盒情况
                half depthBehind01;
                if (isSkybox)
                {
                    //当背后是天空盒时使用固定的深度贡献
                    depthBehind01 = 1.0; // 或者根据距离计算
                }
                // else
                // {
                //     depthBehind01 = max(0, depthLen - farDis) / (2 * scaledRadius);
                //     depthBehind01 = saturate(depthBehind01 + 1 - 0.5 * _StartDis) *
                //         smoothstep(_ClipDepth, _ClipDepth - 0.1, depthBehind01);
                // }

                // half travelDis01 = (min(depthLen, farDis) - min(depthLen, nearDis)) / (2 * scaledRadius);
                // half depthBehind01 = max(0, depthLen - farDis) / (2 * scaledRadius);
                // depthBehind01 = saturate(depthBehind01 + 1 - 0.5 * _StartDis) * smoothstep(_ClipDepth, _ClipDepth - 0.1, depthBehind01);
                half newTravelDis = exp(log(travelDis01) * (1 + 2 * _DepthFade));
                half dis01 = sqrt(1 - travelDis01 * travelDis01) - (1 - saturate(pivortDis / scaledRadius));

                finalColor.rgb = _Color;
                if (_UseColorEnd == 1)
                {
                    finalColor.rgb = lerp(_Color, _ColorEnd, dis01);
                }

                finalColor.a = newTravelDis * depthBehind01 * _FogDensity;

                #ifdef _USE_NOISE_ON
                half noiseVal = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, uv * _TexScale - _Time.y * half2(0, _TexFlowSpeed)).r;
                noiseVal = lerp(_NoiseMin, 1, noiseVal);
                half2 uvEdgeMask = smoothstep(1, 0.5, abs(2 * uv - 1));
                finalColor.a *= lerp(1, noiseVal, uvEdgeMask.x * uvEdgeMask.y);
                #endif

                // finalColor.rgb *= finalColor.a;

                return finalColor;
            }
            ENDHLSL
        }
    }
}