//
//  GameViewController.m
//  SFOpenGLESPanorama
//
//  Created by Jagie on 8/23/15.
//  Copyright (c) 2015 Jagie. All rights reserved.
//

#import "GameViewController.h"
#import <OpenGLES/ES2/glext.h>
@import CoreMotion;



@interface GameViewController () {
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
@property (strong, nonatomic) EAGLContext *context;

@property (nonatomic, strong) CMMotionManager * motionManager;

@property(nonatomic,strong)  CMAttitude *lastAttitude;

@end

@implementation GameViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [self setupGL];
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(rotatePanGestureRecognizer:)];
    [self.view addGestureRecognizer:panGestureRecognizer];
    
    
    
    // 2.1 Create a CMMotionManager instance and store it in the property "motionManager"
    self.motionManager = [[CMMotionManager alloc] init];
    
    // 2.1 Set the motion update interval to 1/60
    self.motionManager.deviceMotionUpdateInterval = 1.0 / self.preferredFramesPerSecond;
    
    // 2.1 Start updating the motion using the reference frame CMAttitudeReferenceFrameXArbitraryCorrectedZVertical
    [self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical];
}

- (IBAction)onClose:(id)sender {
    [self  dismissViewControllerAnimated:YES completion:nil];
}


- (void)rotatePanGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer
{
   
    CGPoint p = [panGestureRecognizer translationInView:self.view];
   
    _rotateX += -p.y * 0.01;
    _rotateY += -p.x * 0.01;
    

    [panGestureRecognizer setTranslation:CGPointZero inView:self.view];
}

- (void)dealloc
{    
    [self tearDownGL];
    [self.motionManager stopDeviceMotionUpdates];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }

    // Dispose of any resources that can be recreated.
}






- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
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
    
     glEnable(GL_CULL_FACE);
     glEnable(GL_DEPTH_TEST);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBufferID);
    glDeleteVertexArraysOES(1, &_vertexArrayID);
    glDeleteTextures(1, &_textureID);
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    CMDeviceMotion *deviceMotion = self.motionManager.deviceMotion;
    
    
    CMAttitude *attitude = deviceMotion.attitude;
//Pitch: A pitch is a rotation around a lateral (X) axis that passes through the device from side to side
//Roll: A roll is a rotation around a longitudinal (Y) axis that passes through the device from its top to bottom
//Yaw: A yaw is a rotation around an axis (Z) that runs vertically through the device. It is perpendicular to the body of the device, with its origin at the center of gravity and directed toward the bottom of the device
    
    if (self.lastAttitude != nil) {
        
        float roll = attitude.roll ;
        //float pitch = attitude.pitch;
        float yaw = attitude.yaw;
        
        //NSLog(@"%f,%f,%f",GLKMathRadiansToDegrees(roll), GLKMathRadiansToDegrees(pitch),GLKMathRadiansToDegrees(yaw));
        
        
        _rotateX -= roll - self.lastAttitude.roll;
        _rotateY -= yaw - self.lastAttitude.yaw;
        
      
    }
    
    self.lastAttitude = attitude;
 
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    
    glClearColor(1.0, 1.0f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    
    
    const GLfloat  aspectRatio =
    (GLfloat)view.drawableWidth / (GLfloat)view.drawableHeight;
    
    GLKMatrix4 projectionMatrix =
    GLKMatrix4MakePerspective(
                              GLKMathDegreesToRadians(50),// a suitable value
                              aspectRatio,
                              0.1f,   // Don't make near plane too close
                              20.0f); // Far arbitrarily far enough to contain scene
    
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeRotation(_rotateX, 1.0f, 0.0f, 0.0f);
    
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix,_rotateY, 0.0f, 1.0f, 0.0f);
    

    
   
    GLKMatrix4 skyboxModelView = modelViewMatrix;
    
    GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply( projectionMatrix, skyboxModelView);

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
