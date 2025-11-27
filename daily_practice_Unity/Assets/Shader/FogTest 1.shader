Shader "HG/HGSphereFog"
{
    Properties
    {
        //        _AlphaCutoff("Alpha Cutoff ", Range(0, 1)) = 0.5
        _Radius("雾效半径", Float) = 1
        [Toggle]_UseColorEnd("UseColorEnd", Float) = 0
        [HDR]_Color("中心颜色", Color) = (0.1815592,0.6622906,0.9433962,1)
        [HDR]_ColorEnd("边缘颜色", Color) = (0.5301531,0.8027155,0.9622642,1)
        _FogDensity("雾浓度", Range(0 , 10)) = 1
        _DepthFade("深度衰减", Float) = 1
        _StartDis("_StartDis", Float) = 0
        _ClipDepth("ClipDepth", Float) = 10000
        [Toggle]_USE_NOISE("噪声贴图",Float) = 0
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
            "RenderPipeline" = "UniversalPipeline"
        }
        Pass
        {
            Name "Forward"
            Tags
            {
                "LightMode" = "UniversalForward"
            }


            Blend SrcAlpha OneMinusSrcAlpha

            Cull Front
            ZTest Off
            ZWrite Off

            HLSLPROGRAM
            #pragma target 2.0

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

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            // NOTE: Do not ifdef the properties here as SRP batcher can not handle different layouts.
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


            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

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

                return output;
            }

            float LoadCameraDepth1(uint2 pixelCoords)
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
                // half2 screenUV = input.clipPos * _ScreenSize.zw;

                float linearDepth = LinearEyeDepth(LoadCameraDepth1(input.clipPos), _ZBufferParams);
                //float linearDepth = LinearEyeDepth(SampleCameraDepth(screenUV), _ZBufferParams);
                float depthLen = linearDepth / dot(-input.viewDirWS, GetViewForwardDir());
                half dotPV = dot(input.pivortRWS, -input.viewDirWS);
                float dist2 = max(0.1, pivortDis * pivortDis - dotPV * dotPV);
                float dist = sqrt(dist2);

                float halfThroughInSphereDis = sqrt(0.01 + _Radius * _Radius - dist2);
                float farDis = step(dist, _Radius) * max(0, dotPV + halfThroughInSphereDis);
                float nearDis = step(dist, _Radius) * max(0, dotPV - halfThroughInSphereDis);

                half travelDis01 = (min(depthLen, farDis) - min(depthLen, nearDis)) / (2 * _Radius);

                half depthBehind01 = max(0, depthLen - farDis) / (2 * _Radius);
                depthBehind01 = saturate(depthBehind01 + 1 - 0.5 * _StartDis) * smoothstep(_ClipDepth, _ClipDepth - 0.1, depthBehind01);
                
                // half newTravelDis = exp(log(travelDis01) * (1 + 2 * _DepthFade));
                half newTravelDis = pow(travelDis01, (1 + 2 * _DepthFade));
                // half newTravelDis = lerp(travelDis01, travelDis01 * travelDis01, _DepthFade);
      
                half dis01 = sqrt(1 - travelDis01 * travelDis01) - (1 - saturate(pivortDis / _Radius));
                finalColor.rgb = _Color;
                if (_UseColorEnd == 1)
                {
                    finalColor.rgb = lerp(_Color, _ColorEnd, dis01);
                }
                // finalColor.rgb *= GetCurrentExposureMultiplier();
                finalColor.a = newTravelDis * depthBehind01 * _FogDensity;
                #ifdef _USE_NOISE_ON
                half noiseVal = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, uv * _TexScale - _Time.y * half2(0, _TexFlowSpeed)).r;
                noiseVal = lerp(_NoiseMin, 1, noiseVal);
                half2 uvEdgeMask = smoothstep(1, 0.5, abs(2 * uv - 1));
                finalColor.a *= lerp(1, noiseVal, uvEdgeMask.x * uvEdgeMask.y);
                #endif
                finalColor.rgb *= finalColor.a;

                // #ifdef DEBUG_DISPLAY
                // 	finalColor = float4(0, 0, 0, 0);
                // 	if (_DebugFullScreenMode == FULLSCREENDEBUGMODE_TRANSPARENCY_OVERDRAW)
                // 	{
                // 		float4 result = _DebugTransparencyOverdrawWeight * float4(TRANSPARENCY_OVERDRAW_COST, TRANSPARENCY_OVERDRAW_COST, TRANSPARENCY_OVERDRAW_COST, TRANSPARENCY_OVERDRAW_A);
                // 		finalColor = result;
                // 	}
                // #endif

                 return pow(finalColor, 2.2);
                  // return finalColor;
            }
            ENDHLSL
        }
    }
    
}