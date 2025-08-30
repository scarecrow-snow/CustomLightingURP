
//#pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
//#pragma multi_compile _ PROBE_VOLUMES_L1 PROBE_VOLUMES_L2

#include "Packages/com.unity.render-pipelines.core/Runtime/Lighting/ProbeVolume/ProbeVolume.hlsl"
#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ProbeVolumeVariants.hlsl"

void MainLight_float(float3 worldPos, out float3 direction, out float3 color, out float shadowAtten)
{
	#ifdef SHADERGRAPH_PREVIEW
		direction = normalize(float3(-0.5,0.5,-0.5));
		color = float3(1,1,1);
		shadowAtten = 1;
	#else
		#if defined(UNIVERSAL_PIPELINE_CORE_INCLUDED)
			float4 shadowCoord = TransformWorldToShadowCoord(worldPos);
			Light mainLight = GetMainLight(shadowCoord);
			direction = mainLight.direction;
			color = mainLight.color;
			shadowAtten = mainLight.shadowAttenuation;
		#else
			direction = normalize(float3(-0.5, 0.5, -0.5));
			color = float3(1, 1, 1);
			shadowAtten = 1;
		#endif
	#endif
}



void AdditionalLights_float(float Smoothness, float3 WorldPosition, float3 WorldNormal, float3 WorldView, float MainDiffuse, float3 MainSpecular, float3 MainColor,
	out float Diffuse, out float3 Specular, out float3 Color)
{
	Diffuse = MainDiffuse;
	Specular = MainSpecular;
	Color = MainColor * (MainDiffuse + MainSpecular);

	#ifndef SHADERGRAPH_PREVIEW
		
		uint pixelLightCount = GetAdditionalLightsCount();

	#if USE_CLUSTER_LIGHT_LOOP
		// for Foward+ LIGHT_LOOP_BEGIN macro uses inputData.normalizedScreenSpaceUV and inputData.positionWS
		InputData inputData = (InputData)0;
		float4 screenPos = ComputeScreenPos(TransformWorldToHClip(WorldPosition));
		inputData.normalizedScreenSpaceUV = screenPos.xy / screenPos.w;
		inputData.positionWS = WorldPosition;
	#endif

		LIGHT_LOOP_BEGIN(pixelLightCount)
			// Convert the pixel light index to the light data index
			#if !USE_CLUSTER_LIGHT_LOOP
				lightIndex = GetPerObjectLightIndex(lightIndex);
			#endif
			// Call the URP additional light algorithm. This will not calculate shadows, since we don't pass a shadow mask value
			Light light = GetAdditionalPerObjectLight(lightIndex, WorldPosition);
			// Manually set the shadow attenuation by calculating realtime shadows
			light.shadowAttenuation = AdditionalLightRealtimeShadow(lightIndex, WorldPosition, light.direction);
			
			// Calculate diffuse and specular
			float NdotL = saturate(dot(WorldNormal, light.direction));
			float atten = light.distanceAttenuation * light.shadowAttenuation;
			float thisDiffuse = atten * NdotL;
			float3 thisSpecular = LightingSpecular(thisDiffuse, light.direction, WorldNormal, WorldView, 1, Smoothness);
			
			// Accumulate light
			Diffuse += thisDiffuse;
			Specular += thisSpecular;
			
			#if defined(_LIGHT_COOKIES)
				float3 cookieColor = SampleAdditionalLightCookie(lightIndex, WorldPosition);
				light.color *= cookieColor;
			#endif
			
			#if (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
				// Adaptive Probe Volume support (Unity 6 official implementation)
				float3 apvIndirectLighting;
				EvaluateAdaptiveProbeVolume(
					WorldPosition,                    // World space position
					WorldNormal,                      // World space normal  
					WorldView,                        // View direction
					inputData.normalizedScreenSpaceUV, // Screen space position (float2)
					apvIndirectLighting              // Output lighting
				);
				Color += apvIndirectLighting;
			#endif
			Color += light.color * (thisDiffuse + thisSpecular);
		LIGHT_LOOP_END
		
		float total = Diffuse + dot(Specular, float3(0.333, 0.333, 0.333));
		float safeTotal = max(total, 1e-5); // 0除算防止
		Color = Color / safeTotal * step(1e-5, total);
		//Color = total <= 0 ? MainColor : Color / total;
	#endif
}

void AdditionalLightsColorize_float(float Smoothness, float3 WorldPosition, float3 WorldNormal, float3 WorldView,
	float MainDiffuse, float3 MainSpecular, float3 MainColor,
	float2 ScreenPosition,
	out float Diffuse, out float3 Specular, out float3 Color, out float Atten)
{
	Diffuse = MainDiffuse;
	Specular = MainSpecular;
	Color = MainColor * (MainDiffuse + MainSpecular);
	Atten = 0;

	#ifndef SHADERGRAPH_PREVIEW
		
		uint pixelLightCount = GetAdditionalLightsCount();

	#if USE_CLUSTER_LIGHT_LOOP
		// for Foward+ LIGHT_LOOP_BEGIN macro uses inputData.normalizedScreenSpaceUV and inputData.positionWS
		InputData inputData = (InputData)0;
		inputData.normalizedScreenSpaceUV = ScreenPosition;
		inputData.positionWS = WorldPosition;
	#endif

		LIGHT_LOOP_BEGIN(pixelLightCount)
			// Convert the pixel light index to the light data index
			#if !USE_CLUSTER_LIGHT_LOOP
				lightIndex = GetPerObjectLightIndex(lightIndex);
			#endif
			// Call the URP additional light algorithm. This will not calculate shadows, since we don't pass a shadow mask value
			Light light = GetAdditionalPerObjectLight(lightIndex, WorldPosition);
			// Manually set the shadow attenuation by calculating realtime shadows
			light.shadowAttenuation = AdditionalLightRealtimeShadow(lightIndex, WorldPosition, light.direction);
			
			// Calculate diffuse and specular
			float NdotL = saturate(dot(WorldNormal, light.direction));
			float atten = light.distanceAttenuation * light.shadowAttenuation;
			float thisDiffuse = atten * NdotL;
			float3 thisSpecular = LightingSpecular(thisDiffuse, light.direction, WorldNormal, WorldView, 1, Smoothness);
			
			// Accumulate light
			Diffuse += thisDiffuse;
			Specular += thisSpecular;
			

			#if defined(_LIGHT_COOKIES)
				float3 cookieColor = SampleAdditionalLightCookie(lightIndex, WorldPosition);
				light.color *= cookieColor;
			#endif
			
			#if (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
				// Adaptive Probe Volume support (Unity 6 official implementation)
				float3 apvIndirectLighting;
				EvaluateAdaptiveProbeVolume(
					WorldPosition,                    // World space position
					WorldNormal,                      // World space normal  
					WorldView,                        // View direction
					inputData.normalizedScreenSpaceUV, // Screen space position (float2)
					apvIndirectLighting              // Output lighting
				);
				Color += apvIndirectLighting;
			#endif
			
			Color += light.color * (thisDiffuse + thisSpecular);
			Atten += atten;
		LIGHT_LOOP_END
		
		float total = Diffuse + dot(Specular, float3(0.333, 0.333, 0.333));
		float safeTotal = max(total, 1e-5); // 0除算防止
		Color = Color / safeTotal * step(1e-5, total);
		//Color = total <= 0 ? MainColor : Color / total;
	#endif
}



void AdditionalLightsBasic_float(float3 WorldPosition, float3 WorldNormal, float3 WorldView, float MainDiffuse, float3 MainColor, float2 ScreenPosition,
	out float Diffuse, out float3 Color)
{
	Diffuse = MainDiffuse;
	Color = MainColor * MainDiffuse;

	#ifndef SHADERGRAPH_PREVIEW
		
		uint pixelLightCount = GetAdditionalLightsCount();

	#if USE_CLUSTER_LIGHT_LOOP
		// for Foward+ LIGHT_LOOP_BEGIN macro uses inputData.normalizedScreenSpaceUV and inputData.positionWS
		InputData inputData = (InputData)0;
		inputData.normalizedScreenSpaceUV = ScreenPosition;
		inputData.positionWS = WorldPosition;
	#endif

		LIGHT_LOOP_BEGIN(pixelLightCount)
			// Convert the pixel light index to the light data index
			#if !USE_CLUSTER_LIGHT_LOOP
				lightIndex = GetPerObjectLightIndex(lightIndex);
			#endif
			// Call the URP additional light algorithm. This will not calculate shadows, since we don't pass a shadow mask value
			Light light = GetAdditionalPerObjectLight(lightIndex, WorldPosition);
			
			// Calculate diffuse and specular
			float NdotL = saturate(dot(WorldNormal, light.direction));
			float thisDiffuse = light.distanceAttenuation * NdotL;
						
			// Accumulate light
			Diffuse += thisDiffuse;
			
			#if (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
				// Adaptive Probe Volume support (Unity 6 official implementation)
				float3 apvIndirectLighting;
				EvaluateAdaptiveProbeVolume(
					WorldPosition,                    // World space position
					WorldNormal,                      // World space normal  
					WorldView,                        // View direction
					inputData.normalizedScreenSpaceUV, // Screen space position (float2)
					apvIndirectLighting              // Output lighting
				);
				Color += apvIndirectLighting;
			#endif
			
			Color += light.color * thisDiffuse;
		LIGHT_LOOP_END
		
		float total = Diffuse;
		float safeTotal = max(total, 1e-5); // 0除算防止
		Color = Color / safeTotal * step(1e-5, total);
		//Color = total <= 0 ? MainColor : Color / total;
	#endif
}

void AdditionalLightsBasic_half(half3 WorldPosition, half3 WorldNormal, half3 WorldView, half MainDiffuse, half3 MainColor, half2 ScreenPosition,
	out half Diffuse, out half3 Color)
{
	Diffuse = MainDiffuse;
	Color = MainColor * MainDiffuse;

	#ifndef SHADERGRAPH_PREVIEW
		
		uint pixelLightCount = GetAdditionalLightsCount();

	#if USE_CLUSTER_LIGHT_LOOP
		// for Foward+ LIGHT_LOOP_BEGIN macro uses inputData.normalizedScreenSpaceUV and inputData.positionWS
		InputData inputData = (InputData)0;
		inputData.normalizedScreenSpaceUV = ScreenPosition;
		inputData.positionWS = WorldPosition;
	#endif

		LIGHT_LOOP_BEGIN(pixelLightCount)
			// Convert the pixel light index to the light data index
			#if !USE_CLUSTER_LIGHT_LOOP
				lightIndex = GetPerObjectLightIndex(lightIndex);
			#endif
			// Call the URP additional light algorithm. This will not calculate shadows, since we don't pass a shadow mask value
			Light light = GetAdditionalPerObjectLight(lightIndex, WorldPosition);
			
			// Calculate diffuse and specular
			half NdotL = saturate(dot(WorldNormal, light.direction));
			half thisDiffuse = light.distanceAttenuation * NdotL;
						
			// Accumulate light
			Diffuse += thisDiffuse;
			
			#if (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
				// Adaptive Probe Volume support (Unity 6 official implementation)
				half3 apvIndirectLighting;
				EvaluateAdaptiveProbeVolume(
					WorldPosition,                    // World space position
					WorldNormal,                      // World space normal  
					WorldView,                        // View direction
					inputData.normalizedScreenSpaceUV, // Screen space position (float2)
					apvIndirectLighting              // Output lighting
				);
				Color += apvIndirectLighting;
			#endif
			
			Color += light.color * thisDiffuse;
		LIGHT_LOOP_END
		
		half total = Diffuse;
		half safeTotal = max(total, 1e-5); // 0除算防止
		Color = Color / safeTotal * step(1e-5, total);
		//Color = total <= 0 ? MainColor : Color / total;
	#endif
}

void AdditionalLightsHalfLambert_float(float Smoothness, float3 WorldPosition, float3 WorldNormal, float3 WorldView, float MainDiffuse, float3 MainSpecular, float3 MainColor,
	out float Diffuse, out float3 Specular, out float3 Color)
{
	Diffuse = MainDiffuse;
	Specular = MainSpecular;
	Color = MainColor * (MainDiffuse + MainSpecular);

	#ifndef SHADERGRAPH_PREVIEW
		
		uint pixelLightCount = GetAdditionalLightsCount();

	#if USE_CLUSTER_LIGHT_LOOP
		// for Foward+ LIGHT_LOOP_BEGIN macro uses inputData.normalizedScreenSpaceUV and inputData.positionWS
		InputData inputData = (InputData)0;
		float4 screenPos = ComputeScreenPos(TransformWorldToHClip(WorldPosition));
		inputData.normalizedScreenSpaceUV = screenPos.xy / screenPos.w;
		inputData.positionWS = WorldPosition;
	#endif

		LIGHT_LOOP_BEGIN(pixelLightCount)
			// Convert the pixel light index to the light data index
			#if !USE_CLUSTER_LIGHT_LOOP
				lightIndex = GetPerObjectLightIndex(lightIndex);
			#endif
			// Call the URP additional light algorithm. This will not calculate shadows, since we don't pass a shadow mask value
			Light light = GetAdditionalPerObjectLight(lightIndex, WorldPosition);
			// Manually set the shadow attenuation by calculating realtime shadows
			light.shadowAttenuation = AdditionalLightRealtimeShadow(lightIndex, WorldPosition, light.direction);
			
			// Calculate diffuse and specular
			float NdotL = saturate(dot(WorldNormal, light.direction) * 0.5 + 0.5);
			float atten = light.distanceAttenuation * light.shadowAttenuation;
			float thisDiffuse = atten * NdotL;
			float3 thisSpecular = LightingSpecular(thisDiffuse, light.direction, WorldNormal, WorldView, 1, Smoothness);
			
			// Accumulate light
			Diffuse += thisDiffuse;
			Specular += thisSpecular;
			
			#if defined(_LIGHT_COOKIES)
				float3 cookieColor = SampleAdditionalLightCookie(lightIndex, WorldPosition);
				light.color *= cookieColor;
			#endif
			
			#if (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
				// Adaptive Probe Volume support (Unity 6 official implementation)
				float3 apvIndirectLighting;
				EvaluateAdaptiveProbeVolume(
					WorldPosition,                    // World space position
					WorldNormal,                      // World space normal  
					WorldView,                        // View direction
					inputData.normalizedScreenSpaceUV, // Screen space position (float2)
					apvIndirectLighting              // Output lighting
				);
				Color += apvIndirectLighting;
			#endif
			
			Color += light.color * (thisDiffuse + thisSpecular);
		LIGHT_LOOP_END
		
		float total = Diffuse + dot(Specular, float3(0.333, 0.333, 0.333));
		float safeTotal = max(total, 1e-5); // 0除算防止
		Color = Color / safeTotal * step(1e-5, total);
		//Color = total <= 0 ? MainColor : Color / total;
	#endif
}



void GetSSAO_float(float2 ScreenPos, out float DirectAO, out float IndirectAO)
{
	#if defined(_SCREENSPACE_OCCLUSION) && !defined(_SURFACE_TYPE_TRANSPARENT) && !defined(SHADERGRAPH_PREVIEW)
		float ssao = saturate(SampleScreenSpaceOcclusion(ScreenPos) + (1.0 - _AmbientOcclusionParam.x));
		IndirectAO = ssao;

		// _AmbientOcclusionParam.wはDirect Lighting Strengthのスライダーで設定した値
		DirectAO = lerp(1.0, ssao, _AmbientOcclusionParam.w);
		#else
		DirectAO = 1.0;
		IndirectAO = 1.0;
	#endif
}

void GetSSAO_half(half2 ScreenPos, out half DirectAO, out half IndirectAO)
{
	#if defined(_SCREENSPACE_OCCLUSION) && !defined(_SURFACE_TYPE_TRANSPARENT) && !defined(SHADERGRAPH_PREVIEW)
		half ssao = saturate(SampleScreenSpaceOcclusion(ScreenPos) + (1.0 - _AmbientOcclusionParam.x));
		IndirectAO = ssao;

		// _AmbientOcclusionParam.wはDirect Lighting Strengthのスライダーで設定した値
		DirectAO = lerp(1.0, ssao, _AmbientOcclusionParam.w);
		#else
		DirectAO = 1.0;
		IndirectAO = 1.0;
	#endif
}