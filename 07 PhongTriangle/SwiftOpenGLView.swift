//
//  SwiftOpenGLView.swift
//  SwiftOpenGL
//
//  Created by Myles La Verne Schultz on 10/23/15.
//  Copyright © 2015 MyKo. All rights reserved.
//
//  Ver. 7:  Draws a textured and colored triangle using a single Phong area light
//


import Cocoa
import OpenGL.GL3


final class SwiftOpenGLView: NSOpenGLView {
    
    fileprivate var programID: GLuint = 0
    fileprivate var vaoID: GLuint = 0
    fileprivate var vboID: GLuint = 0
    fileprivate var tboID: GLuint = 0
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        let attrs: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAAccelerated),
            UInt32(NSOpenGLPFAColorSize), UInt32(32),
            UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core),
            UInt32(0)
        ]
        guard let pixelFormat = NSOpenGLPixelFormat(attributes: attrs) else {
            Swift.print("pixelFormat could not be constructed")
            return
        }
        self.pixelFormat = pixelFormat
        guard let context = NSOpenGLContext(format: pixelFormat, share: nil) else {
            Swift.print("context could not be constructed")
            return
        }
        self.openGLContext = context
    }
    
    override func prepareOpenGL() {
        
        super.prepareOpenGL()
        
        glClearColor(0.0, 0.0, 0.0, 1.0)
        
        programID = glCreateProgram()
        
        //format: x,    y,    r,   g,   b,    s,   t,    nx,   ny,   nz
        let data: [GLfloat] = [-1.0, -1.0,  1.0, 0.0, 1.0,  0.0, 2.0,  -1.0, -1.0, 0.0001,
                                0.0,  1.0,  0.0, 1.0, 0.0,  1.0, 0.0,   0.0,  1.0, 0.0001,
                                1.0, -1.0,  0.0, 0.0, 1.0,  2.0, 2.0,   1.0, -1.0, 0.0001]
        
        let fileURL = Bundle.main.url(forResource: "Texture", withExtension: "png")
        
        let dataProvider = CGDataProvider(url: fileURL! as CFURL)
        let image = CGImage(pngDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: false, intent: CGColorRenderingIntent.defaultIntent)
        
        let textureData = UnsafeMutableRawPointer.allocate(bytes: 256 * 4 * 256, alignedTo: MemoryLayout<GLint>.alignment)
        
        let context = CGContext(data: textureData, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 4 * 256, space: CGColorSpace(name: CGColorSpace.genericRGBLinear)!,  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        context?.draw(image!, in: CGRect(x: 0.0, y: 0.0, width: 256.0, height: 256.0))
        
        glGenTextures(1, &tboID)
        glBindTexture(GLenum(GL_TEXTURE_2D), tboID)
        
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT)
        
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, 256, 256, 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), textureData)
        
        free(textureData)
        
        glGenBuffers(1, &vboID)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vboID)
        glBufferData(GLenum(GL_ARRAY_BUFFER), data.count * MemoryLayout<GLfloat>.size, data, GLenum(GL_STATIC_DRAW))
        
        glGenVertexArrays(1, &vaoID)
        glBindVertexArray(vaoID)
        
        glVertexAttribPointer(0, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 40, UnsafePointer<GLuint>(bitPattern: 0))
        glEnableVertexAttribArray(0)
        
        glVertexAttribPointer(1, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 40, UnsafePointer<GLuint>(bitPattern: 8))
        glEnableVertexAttribArray(1)
        
        glVertexAttribPointer(2, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 40, UnsafePointer<GLuint>(bitPattern: 20))
        glEnableVertexAttribArray(2)
        
        glVertexAttribPointer(3, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 40, UnsafePointer<GLuint>(bitPattern:28))
        glEnableVertexAttribArray(3)
        
        glBindVertexArray(0)
        
        let vs = glCreateShader(GLenum(GL_VERTEX_SHADER))
        var source = "#version 330 core                     \n" +
            "layout (location = 0) in vec2 position;        \n" +
            "layout (location = 1) in vec3 color;           \n" +
            "layout (location = 2) in vec2 texturePosition; \n" +
            "layout (location = 3) in vec3 normal;          \n" +
            "out vec3 passPosition;                         \n" +
            "out vec3 passColor;                            \n" +
            "out vec2 passTexturePosition;                  \n" +
            "out vec3 passNormal;                           \n" +
            "void main()                                    \n" +
            "{                                              \n" +
            "     gl_Position = vec4(position, 0.0, 1.0);   \n" +
            "     passPosition = vec3(position, 0.0);       \n" +
            "     passColor = color;                        \n" +
            "     passTexturePosition = texturePosition;    \n" +
            "     passNormal = normal;                      \n" +
            "}                                              \n"
        let vss = source.cString(using: String.Encoding.ascii)
        var vssptr = UnsafePointer<GLchar>(vss)
        glShaderSource(vs, 1, &vssptr, nil)
        glCompileShader(vs)
        var compiled: GLint = 0
        glGetShaderiv(vs, GLbitfield(GL_COMPILE_STATUS), &compiled)
        if compiled <= 0 {
            Swift.print("Could not compile vertex, getting log")
            var logLength: GLint = 0
            glGetShaderiv(vs, GLenum(GL_INFO_LOG_LENGTH), &logLength)
            Swift.print(" logLength = \(logLength)")
            if logLength > 0 {
                let cLog = UnsafeMutablePointer<GLchar>.allocate(capacity: Int(logLength))
                glGetShaderInfoLog(vs, GLsizei(logLength), &logLength, cLog)
                Swift.print(" log = \n\t\(String.init(cString: cLog))")
                free(cLog)
            }
        }
        
        let fs = glCreateShader(GLenum(GL_FRAGMENT_SHADER))
        source = "#version 330 core                                                                                     \n" +
            "uniform sampler2D sample;                                                                                  \n" +
            //  The Light uniform Struct allows us to more convenietly access the light attributes
            "uniform struct Light {                                                                                     \n" +
            "    vec3 color;                                                                                            \n" +
            "    vec3 position;                                                                                         \n" +
            "    float ambient;                                                                                         \n" +
            "    float specStrength;                                                                                    \n" +
            "    float specHardness;                                                                                    \n" +
            "} light;                                                                                                   \n" +
            "in vec3 passPosition;                                                                                      \n" +
            "in vec3 passColor;                                                                                         \n" +
            "in vec2 passTexturePosition;                                                                               \n" +
            "in vec3 passNormal;                                                                                        \n" +
            "out vec4 outColor;                                                                                         \n" +
            "void main()                                                                                                \n" +
            "{                                                                                                          \n" +
            "     vec3 normal = normalize(passNormal);                                                                  \n" +
            "     vec3 lightRay = normalize(light.position - passPosition);                                             \n" +
            "     float intensity = dot(normal, lightRay);                                                              \n" +
            "     intensity = clamp(intensity, 0, 1);                                                                   \n" +
            //  viewer is the vector pointing from the fragment to the viewer
            "     vec3 viewer = normalize(vec3(0.0, 0.0, 0.2) - passPosition);                                          \n" +
            //  reflect() calculates the reflection vector
            //      first parameter is the incident ray
            //      second parameter is the normal
            //  we do not negate the lightRay because it is already pointing from the surface to the viewer
            //  negating the vector would cause the reflection vector to point away from the viewer and no
            //  highlight would seen.
            "     vec3 reflection = reflect(lightRay, normal);                                                          \n" +
            //  specular is calculated by taking the dot product of the viewer and reflection vectors,
            //  ensuring those vectors are >=0.0 with max(), and then raising that value by the value
            //  of hardness to adjust the hardness of the edge of the highlight.
            "     float specular = pow(max(dot(viewer, reflection), 0.0), light.specHardness);                          \n" +
            //  The specular component casts light so it must also be multiplied by the .color component.
            "     vec3 light = light.ambient + light.color * intensity + light.specStrength * specular * light.color;   \n" +
            "     vec3 surface = texture(sample, passTexturePosition).rgb * passColor;                                  \n" +
            "     vec3 rgb = surface * light;                                                                           \n" +
            "     outColor = vec4(rgb, 1.0);                                                                            \n" +
            "}                                                                                                          \n"
        let fss = source.cString(using: String.Encoding.ascii)
        var fssptr = UnsafePointer<GLchar>(fss)
        glShaderSource(fs, 1, &fssptr, nil)
        glCompileShader(fs)
        compiled = 0
        glGetShaderiv(fs, GLbitfield(GL_COMPILE_STATUS), &compiled)
        if compiled <= 0 {
            Swift.print("Could not compile fragement, getting log")
            var logLength: GLint = 0
            glGetShaderiv(fs, GLbitfield(GL_INFO_LOG_LENGTH), &logLength)
            Swift.print(" logLength = \(logLength)")
            if logLength > 0 {
                let cLog = UnsafeMutablePointer<GLchar>.allocate(capacity: Int(logLength))
                glGetShaderInfoLog(fs, GLsizei(logLength), &logLength, cLog)
                Swift.print(" log = \n\t\(String.init(cString: cLog))")
                free(cLog)
            }
        }
        
        glAttachShader(programID, vs)
        glAttachShader(programID, fs)
        glLinkProgram(programID)
        var linked: GLint = 0
        glGetProgramiv(programID, UInt32(GL_LINK_STATUS), &linked)
        if linked <= 0 {
            Swift.print("Could not link, getting log")
            var logLength: GLint = 0
            glGetProgramiv(programID, UInt32(GL_INFO_LOG_LENGTH), &logLength)
            Swift.print(" logLength = \(logLength)")
            if logLength > 0 {
                let cLog = UnsafeMutablePointer<GLchar>.allocate(capacity: Int(logLength))
                glGetProgramInfoLog(programID, GLsizei(logLength), &logLength, cLog)
                Swift.print(" log: \(String.init(cString: cLog))")
                free(cLog)
            }
        }
        
        glDeleteShader(vs)
        glDeleteShader(fs)
        
        let sampleLocation = glGetUniformLocation(programID, "sample")
        glUniform1i(sampleLocation, GL_TEXTURE0)
        
        glUseProgram(programID)
        
        //  Uniforms for the light struct.  Each component is accessed using dot notation.
        glUniform3fv(glGetUniformLocation(programID, "light.color"), 1, [1.0, 1.0, 1.0])
        glUniform3fv(glGetUniformLocation(programID, "light.position"), 1, [0.0, 1.0, 0.1])
        glUniform1f(glGetUniformLocation(programID, "light.ambient"), 0.25)
        glUniform1f(glGetUniformLocation(programID, "light.specStrength"), 1.0)
        glUniform1f(glGetUniformLocation(programID, "light.specHardness"), 32)
        
        drawView()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Drawing code here.
        
        drawView()
        
    }
    
    fileprivate func drawView() {
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        glUseProgram(programID)
        glBindVertexArray(vaoID)
        
        glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        
        glBindVertexArray(0)
        
        glFlush()
    }
    
    deinit {
        glDeleteVertexArrays(1, &vaoID)
        glDeleteBuffers(1, &vboID)
        glDeleteProgram(programID)
        glDeleteTextures(1, &tboID)
    }
    
}
