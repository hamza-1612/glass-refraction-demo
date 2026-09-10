"""Execute the bundled GLSL on headless Mesa/EGL, not Flutter/Impeller.
Requires: pip install moderngl numpy Pillow
Usage: python tool/verify_shader.py --output /path/to/evidence
Only the Flutter header/coordinate intrinsic is adapted for this host harness.
"""
import argparse
import json
from pathlib import Path
import moderngl
import numpy as np
from PIL import Image, ImageDraw

parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
args.output.mkdir(parents=True,exist_ok=True)
ctx=moderngl.create_standalone_context(backend='egl',require=330)
source=(Path(__file__).resolve().parents[1]/'shaders/glass_refraction.frag').read_text()
source=source.replace('#version 460 core','#version 330 core').replace('#include <flutter/runtime_effect.glsl>','vec4 FlutterFragCoord() { return gl_FragCoord; }')
vertex='''#version 330 core
in vec2 position;
void main() { gl_Position=vec4(position,0.0,1.0); }
'''
quad=ctx.buffer(np.array([-1,-1,1,-1,-1,1,1,1],dtype='f4').tobytes())
programs={}
for flipped in [False,True]:
    code=source.replace('#version 330 core','#version 330 core\n#define IMPELLER_TARGET_OPENGLES') if flipped else source
    prog=ctx.program(vertex_shader=vertex,fragment_shader=code)
    programs[flipped]=(prog,ctx.simple_vertex_array(prog,quad,'position'))

def render(data,radius=40,band=22,strength=7,frost=0,flipped=False):
    h,w,_=data.shape
    prog,vao=programs[flipped]
    upload=np.flipud(data).copy() if flipped else data
    texture=ctx.texture((w,h),4,upload.tobytes())
    texture.filter=(moderngl.LINEAR,moderngl.LINEAR)
    texture.repeat_x=texture.repeat_y=False
    output=ctx.simple_framebuffer((w,h),components=4)
    output.use();ctx.viewport=(0,0,w,h)
    texture.use(0)
    prog['uSize'].value=(w,h)
    prog['uBackdrop'].value=0
    for name,value in [('uRadius',radius),('uBand',band),('uStrength',strength),('uFrost',frost)]:
        prog[name].value=value/min(w,h)
    vao.render(moderngl.TRIANGLE_STRIP)
    result=np.frombuffer(output.read(components=4,alignment=1),dtype='u1').reshape(h,w,4).copy()
    output.release();texture.release()
    return result

def pattern(w,h,phase=0,dark=False):
    y,x=np.mgrid[:h,:w]
    value=((x+phase)//12%2)*.25+(y//12%2)*.2
    a=np.empty((h,w,4),dtype='u1')
    for c,base in enumerate(([12,30,38] if dark else [142,175,177])):
        a[:,:,c]=np.clip(base+value*145+40*np.sin((x+phase)/36+c),0,255)
    a[:,:,3]=255
    return a

checks=[]
def check(name,condition):
    if not bool(condition): raise AssertionError(name)
    checks.append(name)

for w,h,r in [(320,120,40),(340,72,36),(72,72,36),(180,200,28)]:
    a=pattern(w,h)
    identity=render(a,radius=r,strength=0)
    check(f'identity {w}x{h}',np.abs(identity.astype(int)-a).max()<=1)
    b=render(a,radius=r)
    check(f'edge displacement {w}x{h}',np.abs(b[3:16,w//3:2*w//3,:3].astype(int)-a[3:16,w//3:2*w//3,:3]).mean()>4)
    check(f'calm center {w}x{h}',np.abs(b[h//2-3:h//2+3,w//2-3:w//2+3].astype(int)-a[h//2-3:h//2+3,w//2-3:w//2+3]).mean()<1)
    check(f'outside corners unchanged {w}x{h}',np.abs(b[:3,:3].astype(int)-a[:3,:3]).max()<=1)
    check(f'opaque input alpha preserved {w}x{h}',np.all(b[:,:,3]==255))
    flipped=render(a,radius=r,flipped=True)
    check(f'GLES orientation branch {w}x{h}',np.abs(flipped.astype(int)-b).max()<=1)
    shifted=render(pattern(w,h,phase=27),radius=r)
    check(f'updated backdrop {w}x{h}',np.abs(shifted.astype(int)-b).mean()>12)

# Move the pane over a fixed larger scene: the shader receives the corresponding crop.
scene=pattern(500,240)
a=render(scene[40:160,20:340]);b=render(scene[60:180,80:400])
check('moving pane updates sampled scene',np.abs(a.astype(int)-b).mean()>12)
# Normalized inputs preserve device-pixel-ratio scaling (allow subpixel antialias differences).
base=pattern(320,120)
big=np.repeat(np.repeat(base,2,axis=0),2,axis=1)
small=render(base)
large=render(big,radius=80,band=44,strength=14)
large_down=np.array(Image.fromarray(large).resize((320,120),Image.Resampling.BOX))
check('DPR scaling interior',np.abs(large_down[4:-4,4:-4].astype(int)-small[4:-4,4:-4]).mean()<4)
# Premultiplied translucent samples remain valid with the five-tap frost kernel.
a=pattern(320,120);a[:,:,:3]//=2;a[:,:,3]=128
b=render(a,frost=.65)
check('premultiplied alpha preserved',np.all(b[:,:,:3]<=b[:,:,3:4]))

# Contact sheet: identical raw scene and shader output, both light and dark.
preview=Image.new('RGB',(720,400),'#ffffff')
draw=ImageDraw.Draw(preview)
for row,dark in enumerate([False,True]):
    raw=pattern(320,120,dark=dark)
    result=render(raw,frost=.65)
    for col,pixels in enumerate([raw,result]):
        x=20+col*360;y=48+row*184
        preview.paste(Image.fromarray(pixels).convert('RGB'),(x,y))
        draw.text((x,y-22),('DARK' if dark else 'LIGHT')+(' / source' if col==0 else ' / GLSL refraction'),fill='black')
        if col:
            draw.line((x+150,y+60,x+170,y+60),fill='white',width=3)
            draw.line((x+160,y+50,x+160,y+70),fill='white',width=3)
preview.save(args.output/'shader-preview.png')
report={'runtime':'Headless OpenGL via EGL; NOT Flutter/Impeller','renderer':ctx.info.get('GL_RENDERER'),'passed':len(checks),'checks':checks,'not_run':['Flutter analyze/build/widget tests','Flutter shader compiler','Native Impeller coordinate mapping and clipping','Real-device frame timing'],'adaptation':'Only GLSL version/header and FlutterFragCoord mapped to gl_FragCoord; GLES macro branch exercised with inverted texture.'}
(args.output/'shader-results.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
