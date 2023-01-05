Shader "Unlit/OverlayFadeIn"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo (RGB)", 2D) = "white" {}
        _Filling("fill (range)", Range(0, 1)) = 0.5
        _Alpha("alpha cut (range)", Range(0, 1)) = 0.5
        _Multiplier("Multiplier", Range(1, 100)) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            float _Multiplier;
            fixed4 _Color;
            float _Filling;
            float _Alpha;
            float4 _MainTex_ST;

            float alphaCutOut(float x) {
                if (x < _Alpha) {
                    return 1;
                }
                return 0;
            }

            float fillCurve(float x) {
                if (x < 0) {
                    return 0;
                }
                if (x > 0.5) {
                    return 1;
                }
                return 2 * x;
            }

            float random(float3 coord, int resolution) {
                float s = sin(coord.z * resolution * resolution + coord.x * resolution + coord.y);
                return abs(frac(s * 6534.235476)); // range 0 -- 1
            }

            float quanticInterpolation(float t) {  // input range 0 -- 1
                return t * t * t * (t * (t * 6 - 15) + 10);
                //return t;
            }

            float getNoise(float2 uv, float res, float z) {
                float3 global_coord = float3(uv.x, uv.y, z) * res;

                float3 local_coord = float3(frac(global_coord.x), frac(global_coord.y), frac(global_coord.z));
                int3 global_square_coord = int3(floor(global_coord.x), floor(global_coord.y), floor(global_coord.z));

                float top_left_back = random(global_square_coord + float3(0, 0, 0), res);
                float top_right_back = random(global_square_coord + float3(1, 0, 0), res);
                float bot_left_back = random(global_square_coord + float3(0, 1, 0), res);
                float bot_right_back = random(global_square_coord + float3(1, 1, 0), res);

                float top_left_forward = random(global_square_coord + float3(0, 0, 1), res);
                float top_right_forward = random(global_square_coord + float3(1, 0, 1), res);
                float bot_left_forward = random(global_square_coord + float3(0, 1, 1), res);
                float bot_right_forward = random(global_square_coord + float3(1, 1, 1), res);

                local_coord = float3(quanticInterpolation(local_coord.x), quanticInterpolation(local_coord.y), quanticInterpolation(local_coord.z));

                float txb = lerp(top_left_back, top_right_back, local_coord.x);
                float bxb = lerp(bot_left_back, bot_right_back, local_coord.x);

                float txf = lerp(top_left_forward, top_right_forward, local_coord.x);
                float bxf = lerp(bot_left_forward, bot_right_forward, local_coord.x);

                float tbb = lerp(txb, bxb, local_coord.y);
                float tbf = lerp(txf, bxf, local_coord.y);

                float tb = lerp(tbb, tbf, local_coord.z);

                return tb;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float res1 = 2 * _Multiplier;
            float res2 = 4 * _Multiplier;
            float res3 = 8 * _Multiplier;
            float res4 = 16 * _Multiplier;

            float summary_octave_factor = 30;

            float2 uv = i.uv;

            // float time_factor = _Time[0] / _Multiplier * 2;
            float time_factor = 1;


            // MODELING NOISE
            float4 color_n = 2 * getNoise(uv, res1, time_factor) / summary_octave_factor;
            color_n += 4 * getNoise(uv, res2, time_factor) / summary_octave_factor;
            color_n += 8 * getNoise(uv, res3, time_factor) / summary_octave_factor;
            color_n += 16 * getNoise(uv, res4, time_factor) / summary_octave_factor;

            // fill modeling
            float fillColoumn = fillCurve(-_Filling + uv.x);

            float mask = color_n * fillColoumn;
                // sample the texture
                fixed4 col = (0, 0, 0, alphaCutOut(mask));
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
