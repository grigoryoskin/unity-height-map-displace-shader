/**
 * This shader applied to a default cube will render a surface inside it.
 * All positions and directions are in object space, so displacement will transform with the cube.
 * Raymarching algorythm is used with bounds given by a intersections of the ray with carrier cube.
 */
Shader "Unlit/RayMarchShader"
{
    Properties
    {
        _HeightMap ("Height Map", 2D) = "white" {}
        _Offset ("Offset", float) = 1
        _Scale ("Scale", float) = 1
        _BlueNoise ("Blue noise", 2D) = "white" {}
        
        _AlbedoTint ("Albedo Tint", Color) = (1, 1, 1, 1)
        _AlbedoMap ("Albedo", 2D) = "white" {}
        _RoughnessMap ("Roughness", 2D) = "white" {}
        _NormalMap ("Normal", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1
        _Metallic ("Metallic", Float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" 
               "Queue" = "Geometry +10" 
               "LightMode" = "ForwardBase"}
        LOD 100

        Pass
        {
            ZWrite On
            
            CGPROGRAM
            
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"

            sampler2D _HeightMap;
            float4 _HeightMap_ST;
            float _Offset;
            float _Scale;
            sampler2D _BlueNoise;
            float4 _AlbedoTint;
            sampler2D _AlbedoMap;
            float4 _AlbedoMap_ST;
            sampler2D _RoughnessMap;
            float4 _RoughnessMap_ST;
            sampler2D _NormalMap;
            float4 _NormalMap_ST;
            float _BumpScale;
            float _Metallic;
           
            struct ray {
                float3 origin;
                float3 direction;
                float  minmumT;                         
                float  maximumT;
            };
            
            struct hit {                               
                float  t;                               
                float3 p;                               
            };
            
            struct v2f
            {
                float4 localPos  : TEXCOORD1;
                float4 vertex    : SV_POSITION;
                float4 worldPos : TEXCOORD2;
                float4 screenPos : TEXCOORD3;
            };
            
            UnityLight CreateLight (float3 p) {
                UnityLight light;
                float3 objectLight = mul(unity_WorldToObject, _WorldSpaceLightPos0).xyz;
                #if defined(POINT) || defined(SPOT)
                    light.dir = normalize(objectLight - p);
                #else
                    light.dir = objectLight;
                #endif
                UNITY_LIGHT_ATTENUATION(attenuation, 0, p);
                light.color = _LightColor0.rgb;
                return light;
            }
            
            UnityIndirect CreateIndirectLight () {
                UnityIndirect indirectLight;
                indirectLight.diffuse = 0;
                indirectLight.specular = 0;
                return indirectLight;
            }

            float4 getAlbedo(float2 uv) {
                uv = (TRANSFORM_TEX(uv, _AlbedoMap) + 0.5);
                return tex2D(_AlbedoMap, uv);
            }
            
            float getRoughness(float2 uv) {
                uv = (TRANSFORM_TEX(uv, _RoughnessMap) + 0.5);
                return tex2D(_RoughnessMap, uv).r;
            }
            
            float3 getLocalNormal(float2 uv) {
                uv = (TRANSFORM_TEX(uv, _NormalMap) + 0.5);
                return UnpackScaleNormal(tex2D(_NormalMap, uv), _BumpScale).xzy; 
            }
          
            // Surface height from a height map. Can be made procedural.
            float SurfaceHeight(float2 uv) {
                uv = TRANSFORM_TEX(uv, _HeightMap) + 0.5;
                return _Offset + length(tex2Dlod(_HeightMap, float4(uv,0,0)))*_Scale;
            }
            
            // Returns true if hits surface. Hit position is put into hitInfo. 
            bool castRay(const ray InRay, out hit hitInfo, float dta) {              
                      float dt   =  dta;
                      float mint =  InRay.minmumT; 
                      float maxt =  InRay.maximumT; 
                      float lh   =  0.0f; 
                      float ly   =  0.0f;
                        int i    =  0;

                for (float t = mint; t < maxt; t += dt)                             
                {
                    i++;                                                             
                    if (i > 100) break; // A loop needs to have a hard limit to be compiled.                                             

                    const float3  p = InRay.origin + normalize(InRay.direction) * t;
                    const float h = SurfaceHeight(p.xz) - 0.5;
                    if (p.y < h )
                    {
                       hitInfo.t = t - dt + dt * (lh - ly) / (p.y - ly - h + lh); // Interpolating to get a more accurate result.
                       hitInfo.p = p;
                       return true;
                    }
                   
                    dt = dta *t; // Decreasing resolution with distance along the ray.                                                
                    lh = h;
                    ly = p.y;
                }
                return false;
           }

           float3 getNormal(const float3 p) {
                float3 worldScale = float3(
                    length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x)), // scale x axis
                    length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y)), // scale y axis
                    length(float3(unity_ObjectToWorld[0].z, unity_ObjectToWorld[1].z, unity_ObjectToWorld[2].z))  // scale z axis
                   );      
                    
                float3 mainNormal = 0;
                
                float  eps = 0.01;
                float2 e = float2(0,eps);
                mainNormal.x = SurfaceHeight(p.xz - e.xy)  - SurfaceHeight(p.xz + e.xy);
                mainNormal.y = 2.0f*eps;
                mainNormal.z = SurfaceHeight(p.xz - e.yx) - SurfaceHeight(p.xz + e.yx);
                mainNormal = normalize(mainNormal); 
                
                float3 tangent = cross(float3(0,1,0), mainNormal);
                float3 bitangent = cross(mainNormal, tangent);
                
                float3 localNormal = getLocalNormal(p.xz);
                
                return normalize(tangent * localNormal.x +
                                 mainNormal * localNormal.y +
                                 bitangent * localNormal.z) * worldScale; 
                
            }
            
            ray GenerateRay(const float3 cameraPos, const float3 localPos) {
                ray r;
                r.origin    = cameraPos;
                r.direction = normalize(localPos - cameraPos);
                return r;
            }
            
            v2f vert(float4 vertex : POSITION)
            {
                v2f o;
                o.vertex      = UnityObjectToClipPos(vertex);
                o.localPos    = vertex;
                o.worldPos    = mul(unity_ObjectToWorld, vertex);
                o.screenPos   = ComputeScreenPos(o.vertex);              
                return o;
            }
            
            // Finding intersections with a box to find correct minimum and maximum t.
            bool BBoxIntersect(const ray r, out float mint, out float maxt) {
                float3 boxMin = -0.5;
                float3 boxMax = 0.5;
                float3 invDir = 1 / r.direction;
                float3 tbot = invDir * (boxMin - r.origin);
                float3 ttop = invDir * (boxMax - r.origin);
                float3 tmin = min(ttop, tbot);
                float3 tmax = max(ttop, tbot);
                float2 t = max(tmin.xx, tmin.yz);
                float t0 = max(t.x, t.y);
                t = min(tmax.xx, tmax.yz);
                float t1 = min(t.x, t.y);
                mint = t0;
                maxt = t1;
                return t1 > max(t0, 0.0);
            }
            
            fixed4 frag (v2f i, out float depth:DEPTH) : SV_Target {
                float2 screenUV     = i.screenPos.xy / i.screenPos.w;
                float blueNoise     = tex2D(_BlueNoise, screenUV*12.);
                blueNoise           = frac(blueNoise + 0.61803398875 * float(_Time.y % 16))/20;
                
                float3 ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos,1)).xyz;
                // Generating ray in object space to make displacement transform with the carrier cube.
                ray r = GenerateRay(ro, i.localPos);
                
                // Finding minumum and maximum t as intesections with the front and back faces of the cube.
                hit hitInfo;
                float mint;
                float maxt;
                bool intersectsBox = BBoxIntersect(r, mint, maxt);
                r.minmumT = mint + blueNoise;
                r.maximumT = maxt;
                
                // This value was used for debugging, can be made 0 or anything else;
                float4 col = mint/maxt;
               
                if (!castRay(r, hitInfo, 0.01)) {
                      // If ray missed the surface don't render this fragment.
                      discard;
                } else {
                      // If ray hit the surface, shade the fragment and write to z buffer.
                      float3 n = getNormal(hitInfo.p);
                      float4 albedo = getAlbedo(hitInfo.p.xz);
                      float3 specularTint = albedo * _Metallic;
                      float oneMinusReflectivity;
                      albedo = float4(DiffuseAndSpecularFromMetallic(albedo, _Metallic, specularTint, oneMinusReflectivity),1);
                      albedo *= _AlbedoTint;
                      float roughness = getRoughness(hitInfo.p.xz);
                      col = UNITY_BRDF_PBS(
                                albedo, specularTint,
                                oneMinusReflectivity, roughness,
                                n, r.direction,
                                CreateLight(hitInfo.p), CreateIndirectLight()
                            );
                      
                      // Setting depth buffer to allow other objects render correctly.            
                      float4 pInScreenSpace = mul(UNITY_MATRIX_VP, float4(hitInfo.p.xyz, 1.));
                      depth = pInScreenSpace.z/pInScreenSpace.w;
                }
                
                return col;
            }
            ENDCG
        }
    }
}
