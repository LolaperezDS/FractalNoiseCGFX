Shader "Custom/FadeInNoise"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Filling ("fill (range)", Range(0, 1)) = 0.5
        _Alpha("alpha cut (range)", Range(0, 1)) = 0.5
        _Multiplier("Multiplier", Range(1, 100)) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 0

        CGPROGRAM
        #pragma surface surf Standard alpha
        // #pragma Standard alpha
        #pragma target 3.0

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
        };

        float _Multiplier;
        fixed4 _Color;
        float _Filling;
        float _Alpha;


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

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float res1 = 2 * _Multiplier;
            float res2 = 4 * _Multiplier;
            float res3 = 8 * _Multiplier;
            float res4 = 16 * _Multiplier;

            float summary_octave_factor = 30;

            float2 uv = IN.uv_MainTex;
            fixed4 c = tex2D(_MainTex, uv) * _Color;

            // float time_factor = _Time[0] / _Multiplier * 2;
            float time_factor = 1;


            // MODELING NOISE
            float4 color_n = 2 * getNoise(uv, res1, time_factor) / summary_octave_factor;
            color_n += 4 * getNoise(uv, res2, time_factor) / summary_octave_factor;
            color_n += 8 * getNoise(uv, res3, time_factor) / summary_octave_factor;
            color_n += 16 * getNoise(uv, res4, time_factor) / summary_octave_factor;

            // fill modeling
            float fillColoumn = fillCurve(- _Filling + uv.x);

            float mask = c.rgb * color_n * fillColoumn;

            o.Albedo = (0, 0, 0);
            o.Alpha = alphaCutOut(mask);
        }
        ENDCG
    }
    FallBack "Diffuse"
}
