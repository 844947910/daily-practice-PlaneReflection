Shader "Study/VolumeFog"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _Density("Density", Range(0, 1)) = 0.03
        _StepCount("Step Count", Int) = 32
        _Softness("Edge Softness", Range(0, 1)) = 0.5
        _SoftParticleRange("Soft Particle Range", Float) = 0.1
        _FadeStart("Fade Start Distance", Float) = 5
        _FadeEnd("Fade End Distance", Float) = 1

    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent"
        }
        Pass
        {
            Name "Forward"
            Tags
            {
                "LightMode"="UniversalForward"
            }
            Cull Off
            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            //抄来的函数
            float2 rayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 rayDir)
            {
                float3 inv = 1.0 / rayDir;
                float3 t0 = (boundsMin - rayOrigin) * inv;
                float3 t1 = (boundsMax - rayOrigin) * inv;
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);
                float dstA = max(max(tmin.x, tmin.y), tmin.z);
                float dstB = min(min(tmax.x, tmax.y), tmax.z);
                float dstTo = max(0, dstA);
                float dstIn = max(0, dstB - dstTo);
                return float2(dstTo, dstIn);
            }

            struct VertexInput
            {
                float4 posOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID };

            struct VertexOutput
            {
                float4 posCS : SV_POSITION;
                float3 posWS : TEXCOORD0;
                float4 projPos : TEXCOORD1;
                float3 posOS : TEXCOORD2;
                UNITY_VERTEX_OUTPUT_STEREO
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float _Density;
                int _StepCount;
                float _Softness;
                float _SoftParticleRange;
                float _FadeStart;
                float _FadeEnd;
                float _CullMode;
            CBUFFER_END

            VertexOutput vert(VertexInput v)
            {
                VertexOutput o = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.posWS = TransformObjectToWorld(v.posOS.xyz);
                o.posCS = TransformWorldToHClip(o.posWS);
                o.projPos = ComputeScreenPos(o.posCS);
                o.posOS = v.posOS.xyz;
                return o;
            }

            half4 frag(VertexOutput IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                // 软粒子深度
                float2 uv = IN.projPos.xy / IN.projPos.w;
                float sceneD = LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
                float curD = -mul(UNITY_MATRIX_V, float4(IN.posWS, 1)).z;
                float softF = saturate((sceneD - curD) / _SoftParticleRange);

                // 体积步进
                float3 roOS = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)).xyz;
                float3 rdOS = normalize(mul((float3x3)unity_WorldToObject, normalize(IN.posWS - _WorldSpaceCameraPos)));
                float2 bi = rayBoxDst(float3(-0.5, -0.5, -0.5), float3(0.5, 0.5, 0.5), roOS, rdOS);
                float toB = bi.x, inB = bi.y;
                float lim = max(min(sceneD - toB, inB), 0);
                float totD = 0, trav = 0;
                float step = inB / _StepCount;

                for (int i = 0; i < _StepCount; i++)
                {
                    if (trav < lim)
                    {
                        float3 sp = roOS + rdOS * (toB + trav);
                        float3 dm = sp - float3(-0.5, -0.5, -0.5);
                        float3 dM = float3(0.5, 0.5, 0.5) - sp;
                        float md = min(min(dm.x, dm.y), min(dm.z, min(dM.x, min(dM.y, dM.z))));
                        float ef = smoothstep(0, _Softness, md * 2);
                        totD += step * _Density * saturate(ef);
                    }
                    trav += step;
                }

                totD *= softF;


                float dist = length(_WorldSpaceCameraPos - IN.posWS);
                float fadeF = 1 - saturate((dist - _FadeStart) / (_FadeEnd - _FadeStart));
                float a = (1 - exp(-totD)) * fadeF;

                half4 col = _Color;
                col.a = a;
                return col;
            }
            ENDHLSL
        }
    }
}