//
//  Shader.fsh
//  SFOpenGLESPanorama
//
//  Created by Jagie on 8/23/15.
//  Copyright (c) 2015 Jagie. All rights reserved.
//

//
//  SkyboxShader.fsh
//
//



uniform samplerCube     u_cubemap;

/////////////////////////////////////////////////////////////////
// Varyings
/////////////////////////////////////////////////////////////////
varying lowp vec3       textureDir;


void main()
{
    lowp vec3 newVar = textureDir;
    gl_FragColor =  textureCube(u_cubemap,textureDir);
}
