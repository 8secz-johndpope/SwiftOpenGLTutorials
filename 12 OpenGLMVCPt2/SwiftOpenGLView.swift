//
//  SwiftOpenGLView.swift
//  SwiftOpenGL
//
//  Created by Myles Schultz on 10/5/16.
//  Copyright © 2016 MyKo. All rights reserved.
//

import Cocoa
import OpenGL.GL3


enum RenderElementType: UInt32 {
    case points = 0
    case lines = 1
    case triangles = 4
}
protocol Renderer {
    func render(_ elementCount: Int32, as elementType: RenderElementType)
}
extension NSOpenGLContext: Renderer {
    func render(_ elementCount: Int32, as elementType: RenderElementType) {
        glDrawArrays(elementType.rawValue, 0, elementCount)
    }
}
final class SwiftOpenGLView: NSOpenGLView {
    var scene: SceneName?
    var displayLink: DisplayLink?
    var renderDelegate: RenderDelegate?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    
        let attrs: [NSOpenGLPixelFormatAttribute] = [
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAAllRenderers),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADoubleBuffer),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAColorSize), 32,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAOpenGLProfile), NSOpenGLPixelFormatAttribute(NSOpenGLProfileVersion3_2Core),
            0
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
        
        //  Set the context's swap interval parameter to 60Hz (i.e. 1 frame per swamp)
        self.openGLContext?.setValues([1], for: .swapInterval)
        
        displayLink = DisplayLink(forView: self)
    }
    
    override func prepareOpenGL() {
        super.prepareOpenGL()
        
        glClearColor(0.5, 0.5, 0.5, 1.0)
        
        renderDelegate?.loadScene()
        displayLink?.start()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        _ = drawView()
    }
    
    func drawView() -> CVReturn {
        guard let context = self.openGLContext else {
            print("Could not acquire an OpenGL context")
            return kCVReturnError
        }
        
        context.makeCurrentContext()
        context.lock()
        
        if let time = displayLink?.currentTime {
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            glEnable(GLenum(GL_CULL_FACE))
            
            if let scene = scene {
                renderDelegate?.prepareToRender(scene, for: time)
                
                renderDelegate?.render(scene, with: context)
            }
        }
        
        context.flushBuffer()
        context.unlock()
        
        return kCVReturnSuccess
    }
    
    deinit {
        displayLink?.stop()
    }
}
