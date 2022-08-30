Shader "Custom/ProcedualLandscape"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Multiplier("Multiplier", Range(1, 100)) = 1.0
        _Power("Power", Range(0.1, 2)) = 1.0

        _Resolution1("Resolution 1", Range(2, 128)) = 4.0
        _OctaveFactor1("Octave Factor 1", Range(0, 1)) = 0.5
        _Resolution2("Resolution 2", Range(2, 128)) = 8.0
        _OctaveFactor2("Octave Factor 2", Range(0, 1)) = 0.25
        _Resolution3("Resolution 3", Range(2, 128)) = 32.0
        _OctaveFactor3("Octave Factor 3", Range(0, 1)) = 0.125
        _Resolution4("Resolution 4", Range(2, 128)) = 64.0
        _OctaveFactor4("Octave Factor 4", Range(0, 1)) = 0.125
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
        };

        fixed4 _Color;
        float _Multiplier;
        float _Power;

        float _Resolution1;
        float _Resolution2;
        float _Resolution3;
        float _Resolution4;

        float _OctaveFactor1;
        float _OctaveFactor2;
        float _OctaveFactor3;
        float _OctaveFactor4;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        float random(float3 coord, int resolution) {
            float s = sin(coord.z * resolution * resolution + coord.x * resolution + coord.y);
            return abs(frac(s * 65364.2354768)); // range 0 -- 1
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

        float3 paint(float x) {
            if (x < 0.40) {
                return float3(0, 0, 40) / 255;
            }
            if (x < 0.60) {
                return float3(0, 0, 70) / 255;
            }
            if (x < 0.65) {
                return float3(255, 224, 66) / 255;
            }
            if (x < 0.75) {
                return float3(148, 255, 66) / 255;
            }
            if (x < 0.88) {
                return float3(7, 130, 39) / 255;
            }
                
            return float3(250, 250, 250) / 255;
                
        }

        void surf(Input IN, inout SurfaceOutputStandard o)
        {
            float global_multiplier = _Multiplier;

            float res1 = _Resolution1 * global_multiplier;
            float res2 = _Resolution2 * global_multiplier;
            float res3 = _Resolution3 * global_multiplier;
            float res4 = _Resolution4 * global_multiplier;

            float2 uv = IN.uv_MainTex;

            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D(_MainTex, uv) * _Color;

            float time_factor = _Time[0] / global_multiplier;

            float summary_octave_factor = _OctaveFactor1 + _OctaveFactor2 + _OctaveFactor3 + _OctaveFactor4;

            float4 color_out = _OctaveFactor1 * getNoise(uv, res1, time_factor) / summary_octave_factor;
            color_out += _OctaveFactor2 * getNoise(uv, res2, time_factor) / summary_octave_factor;
            color_out += _OctaveFactor3 * getNoise(uv, res3, time_factor) / summary_octave_factor;
            color_out += _OctaveFactor4 * getNoise(uv, res4, time_factor) / summary_octave_factor;

            o.Albedo = paint(pow(color_out, _Power));
                
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}