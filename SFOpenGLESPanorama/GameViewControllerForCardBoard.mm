//
//  GameViewController.m
//  SFOpenGLESPanorama
//
//  Created by Jagie on 8/23/15.
//  Copyright (c) 2015 Jagie. All rights reserved.
//

#import "GameViewControllerForCardBoard.h"
#import <OpenGLES/ES2/glext.h>
#import "GLHelpers.h"

@interface GameViewControllerForCardBoard () {
    GLuint _program;
    
    GLuint _vertexBufferID;
    GLuint _indexBufferID;
    GLuint _vertexArrayID;
    
    
    
    GLint _u_mvpMatrix;
    GLint _u_cubemap;
    GLuint _textureID;
    GLint _a_position;
    

    CGFloat _rotateX;
    CGFloat _rotateY;

}

@property(nonatomic,strong)  CMAttitude *lastAttitude;

@end

@implementation GameViewControllerForCardBoard

-(instancetype)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if (!self) {return nil; }
    
    self.stereoRendererDelegate = self;
    
    return self;
}


- (IBAction)onClose:(id)sender {
    [self  dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - CBDStereoRendererDelegate delegate methods
- (void)setupRendererWithView:(GLKView *)glView{
    [EAGLContext setCurrentContext:glView.context];
    
    [self loadShaders];
    
    
    
    // The 8 corners of a cube
    const float vertices[24] = {
        -0.5, -0.5,  0.5,
        0.5, -0.5,  0.5,
        -0.5,  0.5,  0.5,
        0.5,  0.5,  0.5,
        -0.5, -0.5, -0.5,
        0.5, -0.5, -0.5,
        -0.5,  0.5, -0.5,
        0.5,  0.5, -0.5,
    };
    
    glGenBuffers(1, &_vertexBufferID);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferID);
    glBufferData(GL_ARRAY_BUFFER,
                 sizeof(vertices),
                 vertices,
                 GL_STATIC_DRAW);
    
    
    const GLubyte indices[36] = {
        0,2,1, //front
        2,3,1,
        
        1,3,7,//right
        1,7,5,
        
        0,6,2,//left
        0,4,6,
        
        0,1,4,//bottom
        1,5,4,
        
        4,5,6,//back
        5,7,6,
        
        3,6,7,//top
        3,2,6
    };
    glGenBuffers(1, &_indexBufferID);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferID);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER,
                 sizeof(indices),
                 indices,
                 GL_STATIC_DRAW);
    
    
    glGenVertexArraysOES(1, &_vertexArrayID);
    glBindVertexArrayOES(_vertexArrayID);
    
    glEnableVertexAttribArray(_a_position);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferID);
    glVertexAttribPointer(_a_position,
                          3,
                          GL_FLOAT,
                          GL_FALSE,
                          0,
                          NULL);
    glBindVertexArrayOES(0);
    
    
    //texture
    
    NSMutableArray *pics = [NSMutableArray array];
    //    faces.push_back("right.jpg");
    //    faces.push_back("left.jpg");
    //    faces.push_back("top.jpg");
    //    faces.push_back("bottom.jpg");
    //    faces.push_back("back.jpg");
    //    faces.push_back("front.jpg");
    
    NSArray *names = @[@"right",@"left",@"top",@"bottom",@"back",@"front"];
    
    for (NSString *n in names) {
        NSString *path = [[NSBundle mainBundle]
                          pathForResource:n ofType:@"jpeg"];
        [pics addObject:path];
    }
    
    
    NSError *error = nil;
    GLKTextureInfo * textInfo = [GLKTextureLoader
                                 cubeMapWithContentsOfFiles:pics
                                 options:nil
                                 error:&error];
    
    _textureID = textInfo.name;
    

    glEnable(GL_DEPTH_TEST);
    glClearColor(0.2f, 0.2f, 0.2f, 0.5f); // Dark background so text shows up well.
    GLCheckForError();
    
}
- (void)shutdownRendererWithView:(GLKView *)glView{
    [EAGLContext setCurrentContext:glView.context];
    
    glDeleteBuffers(1, &_vertexBufferID);
    glDeleteVertexArraysOES(1, &_vertexArrayID);
    glDeleteTextures(1, &_textureID);
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
    
}
- (void)renderViewDidChangeSize:(CGSize)size{
    
}

- (void)prepareNewFrameWithHeadViewMatrix:(GLKMatrix4)headViewMatrix{
   
    if (self.lastAttitude != nil) {
        
        float roll = self.attitude.roll ;
        //float pitch = self.attitude.pitch;
        float yaw =  self.attitude.yaw;
        
        //NSLog(@"%f,%f,%f",GLKMathRadiansToDegrees(roll), GLKMathRadiansToDegrees(pitch),GLKMathRadiansToDegrees(yaw));
        
        
        _rotateX -= roll - self.lastAttitude.roll;
        _rotateY -= yaw - self.lastAttitude.yaw;
        
        
    }
    
    self.lastAttitude = self.attitude;
    
}

- (void)drawEyeWithEye:(CBDEye *)eye{
    [EAGLContext setCurrentContext:self.view.context];
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
   
    
    const float zNear = 0.1f;
    const float zFar = 100.0f;
    
    GLKMatrix4 _camera = GLKMatrix4MakeLookAt(0, 0, 0.01,
                                   0, 0, 0,
                                   0, 1.0f, 0);
    
    GLKMatrix4  eyeView = GLKMatrix4Multiply([eye eyeViewMatrix], _camera);
    
    GLKMatrix4 eyePerspective = [eye perspectiveMatrixWithZNear:zNear zFar:zFar];

    
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeRotation(_rotateX, 1.0f, 0.0f, 0.0f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix,_rotateY, 0.0f, 1.0f, 0.0f);
  

    GLKMatrix4 modelViewProjectionMatrix =GLKMatrix4Multiply(eyePerspective, GLKMatrix4Multiply( eyeView, modelViewMatrix));
    
    
    glUseProgram(_program);                    // Step 1
    glUniformMatrix4fv(_u_mvpMatrix, 1, 0,
                       modelViewProjectionMatrix.m);
    
   
    glUniform1i(_u_cubemap, 0);
    glBindVertexArrayOES(_vertexArrayID);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferID);
    glBindTexture(GL_TEXTURE_CUBE_MAP,
                  _textureID);
    
    
    glDrawElements(GL_TRIANGLES,
                   36,
                   GL_UNSIGNED_BYTE,
                   NULL);
    GLCheckForError();
    glBindVertexArrayOES(0);
    
    
}
- (void)finishFrameWithViewportRect:(CGRect)viewPort{
    
}





#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    _u_mvpMatrix = glGetUniformLocation(_program, "u_mvpMatrix");
    _u_cubemap = glGetUniformLocation(_program,"u_cubemap");
    _a_position = glGetAttribLocation(_program,"a_position");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}


@end
