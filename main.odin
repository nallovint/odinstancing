package odinstancing

import rl "vendor:raylib"
import "core:fmt"

MAX_INSTANCES:= 100000
MAX_LIGHTS:= 4

Light :: struct {
	type: i8,
	enabled: bool,
	position: rl.Vector3,
	target: rl.Vector3,
	color: rl.Color,
	attenuation: f32,
	// Shader locations
    
    // Shader locations
    enabledLoc: i8,
    typeLoc: i8,
    positionLoc: i8,
    targetLoc: i8,
    colorLoc: i8,
    attenuationLoc: i8,

	
}

LightType :: enum {
	LIGHT_DIRECTIONAL = 0,
	LIGHT_POINT
}

lightsCount:= 0

CreateLight :: proc(type: i8, position: rl.Vector3, target: rl.Vector3, color: rl.Color, shader: rl.Shader) -> Light {


    light: Light

    if (lightsCount < MAX_LIGHTS)
    {
        light.enabled = true
        light.type = type
        light.position = position
        light.target = target
        light.color = color

        // NOTE: Lighting shader naming must be the provided ones
        light.enabledLoc = i8(rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].enabled", lightsCount)))
        light.typeLoc = i8(rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].type", lightsCount)))
        light.positionLoc = i8(rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].position", lightsCount)))
        light.targetLoc = i8(rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].target", lightsCount)))
        light.colorLoc = i8(rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].color", lightsCount)))

        UpdateLightValues(shader, light)
        
        lightsCount +=1
    }

    return light
}



UpdateLightValues :: proc(shader: rl.Shader, light: Light) {
	enabled:= light.enabled
	type := light.type
	rl.SetShaderValue(shader, rl.ShaderLocationIndex(light.enabledLoc), &enabled, rl.ShaderUniformDataType.INT)
    rl.SetShaderValue(shader, rl.ShaderLocationIndex(light.typeLoc), &type, rl.ShaderUniformDataType.INT)

    // Send to shader light position values
    position: [3]f32 = { light.position.x, light.position.y, light.position.z }
    rl.SetShaderValue(shader, rl.ShaderLocationIndex(light.positionLoc), &position, rl.ShaderUniformDataType.VEC3)

    // Send to shader light target position values
    target: [3]f32 = { light.target.x, light.target.y, light.target.z }
    rl.SetShaderValue(shader, rl.ShaderLocationIndex(light.targetLoc), &target, rl.ShaderUniformDataType.VEC3)

    // Send to shader light color values
    color: [4]f32 = { f32(light.color.r)/255.0, f32(light.color.g)/255.0, 
                       f32(light.color.b)/255.0, f32(light.color.a)/255.0 }
    rl.SetShaderValue(shader, rl.ShaderLocationIndex(light.colorLoc), &color, rl.ShaderUniformDataType.VEC4)

}



main::proc() {
	
		screenWidth  :i32= 800   // Framebuffer width
        screenHeight :i32= 450
        fps:= 60
        speed := 30
        groups := 2
        amp : f32 = 10.0
        variance: f32 = 0.8
		

	rl.InitWindow(screenWidth, screenHeight, "raylib [shaders] example - mesh instancing")

	// Define the camera to look into our 3d world
	camera :  rl.Camera3D
	camera.fovy = 45.0
	camera.position = rl.Vector3({-125.0, 125.0, -125.0})
	camera.target = rl.Vector3(0)
	camera.up = rl.Vector3({0.0, 1.0, 0.0})
	

    

	cube := rl.GenMeshCube(1.0, 1.0, 1.0)

	rotations := make([]rl.Matrix, MAX_INSTANCES)    // Rotation state of instances
	rotationsInc := make([]rl.Matrix, MAX_INSTANCES) // Per-frame rotation animation of instances
	translations := make([]rl.Matrix, MAX_INSTANCES) // Locations of instances
	transforms := make([]rl.Matrix, MAX_INSTANCES)   // Combined transformations of instances

	// Scatter random cubes around
	for i in 0..<MAX_INSTANCES {
		x := f32(rl.GetRandomValue(-50, 50))
		y := f32(rl.GetRandomValue(-50, 50))
		z := f32(rl.GetRandomValue(-50, 50))
		translations[i] = rl.MatrixTranslate(x, y, z)

		x = f32(rl.GetRandomValue(0, 360))
		y = f32(rl.GetRandomValue(0, 360))
		z = f32(rl.GetRandomValue(0, 360))
		axis := rl.Vector3Normalize(rl.Vector3({x, y, z}))
		angle := f32(rl.GetRandomValue(0, 10)) * rl.DEG2RAD

		rotationsInc[i] = rl.MatrixRotate(axis, angle)
		rotations[i] = rl.Matrix(1)
		transforms[i] = rotations[i] * translations[i]

	}

	shader := rl.LoadShader("lighting_instancing.vs", "lighting.fs")

	shader.locs[rl.ShaderLocationIndex.MATRIX_MVP] = i32(rl.GetShaderLocation(shader, "mvp"))
	shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = i32(rl.GetShaderLocation(shader, "viewPos"))
	shader.locs[rl.ShaderLocationIndex.MATRIX_MODEL] = i32(rl.GetShaderLocationAttrib(shader,"instanceTransform"))

	
	// ambient light level
	ambientLoc := rl.GetShaderLocation(shader, "ambient")
	ambientCols : [4]f32 = {0.2,0.2,0.2,1.0}
	rl.SetShaderValue(shader, ambientLoc, &ambientCols, rl.ShaderUniformDataType.VEC4)
	
	CreateLight(i8(LightType.LIGHT_DIRECTIONAL), rl.Vector3({50.0, 50.0, 0.0}), rl.Vector3(0), rl.WHITE, shader)

	material := rl.LoadMaterialDefault()
	material.shader = shader
	mmap := material.maps[rl.MaterialMapIndex.ALBEDO]
	mmap.color = rl.RED

	// rl.SetTargetFPS(int32(fps))
	for !rl.WindowShouldClose() {
		// Update
		//----------------------------------------------------------------------------------

		
		// Update the light shader with the camera view position

		cameraPosition : [3]f32 = {camera.position.x, camera.position.y, camera.position.z}
		rl.SetShaderValue(
			shader,
			rl.ShaderLocationIndex(shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW]), &cameraPosition,rl.ShaderUniformDataType.VEC3)
		
		rl.BeginDrawing()
		{
			
			rl.ClearBackground(rl.RAYWHITE)

			rl.BeginMode3D(camera)
			//rl.DrawMesh(cube, material, rl.MatrixIdentity())
			thisTransforms := transforms
			rl.DrawMeshInstanced(cube, material, raw_data(thisTransforms), i32(MAX_INSTANCES))
			rl.DrawGrid(10, 1)
			rl.EndMode3D()

			

			rl.DrawFPS(10, 10)
		}
		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.CloseWindow() // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}

