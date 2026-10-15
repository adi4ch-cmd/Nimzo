"""Original NIMZO procedural dragon study. Blender 4.3+, no external assets.
blender -b -t 3 -P tools/golden_dragon/scene.py -- --out /path --width 540 --samples 16
Use --frame 210 for a still; otherwise renders all 360 RGBA frames.
This is a review candidate, not a claim of production art acceptance.
"""
import argparse, math, random, sys
from pathlib import Path
import bpy
from mathutils import Vector
p=argparse.ArgumentParser(); p.add_argument('--out',required=True);p.add_argument('--width',type=int,default=540);p.add_argument('--samples',type=int,default=16);p.add_argument('--frame',type=int);p.add_argument('--denoise',action='store_true');p.add_argument('--build-only',action='store_true')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=Path(a.out);(out/'rgba').mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
random.seed(1947)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=a.samples;s.cycles.use_denoising=a.denoise;s.cycles.max_bounces=4;s.cycles.transparent_max_bounces=4
s.render.resolution_x=a.width;s.render.resolution_y=round(a.width*16/9);s.render.resolution_percentage=100;s.render.fps=30;s.frame_start=1;s.frame_end=360;s.render.film_transparent=True
s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.image_settings.color_depth='8';s.render.filepath=str(out/'rgba'/'frame_')
s.view_settings.view_transform='AgX';s.world.color=(.25,.25,.25)
def mat(name,color,metal=0,rough=.3,emit=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*color,1);n.inputs['Metallic'].default_value=metal;n.inputs['Roughness'].default_value=rough
 if emit:n.inputs['Emission Color'].default_value=(*color,1);n.inputs['Emission Strength'].default_value=emit
 return m
gold=mat('Champagne gold scales',(.53,.255,.045),.82,.34);edge=mat('Pale gold ridge',(.72,.46,.16),.76,.30);skin=mat('Deep bronze under scales',(.18,.065,.012),.8,.32);ivory=mat('Warm ivory horn',(.76,.55,.24),.52,.25);black=mat('Obsidian eye',(.004,.008,.006),.25,.12);eye=mat('Amber iris',(1,.32,.025),.4,.14,2);mane=mat('Silken pale gold',(.58,.30,.08),.75,.33);mouth=mat('Mouth shadow',(.025,.006,.003),.1,.45);dustmat=mat('Gold dust',(.95,.54,.1),.5,.23,3)
# Subtle microscopic irregularity on real metallic geometry.
for m in [gold,edge,skin,ivory]:
 nt=m.node_tree;n=nt.nodes.new('ShaderNodeTexNoise');n.inputs['Scale'].default_value=95;n.inputs['Detail'].default_value=3;b=nt.nodes.new('ShaderNodeBump');b.inputs['Strength'].default_value=.18;b.inputs['Distance'].default_value=.025;nt.links.new(n.outputs['Fac'],b.inputs['Height']);nt.links.new(b.outputs['Normal'],nt.nodes.get('Principled BSDF').inputs['Normal'])
def mesh(name,verts,faces,material,parent=None):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new(name,me);s.collection.objects.link(ob);ob.data.materials.append(material);ob.parent=parent
 for f in me.polygons:f.use_smooth=True
 return ob
def sphere(name,loc,scale,material,parent=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(material);o.parent=parent
 for f in o.data.polygons:f.use_smooth=True
 return o
def tube(name,points,radii,material,parent=None,sides=8):
 vs=[];fs=[]
 for i,pt in enumerate(points):
  tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)]);tangent.normalize();v=tangent.cross(Vector((0,1,0)))
  if v.length<.01:v=tangent.cross(Vector((1,0,0)))
  v.normalize();w=tangent.cross(v).normalized()
  for j in range(sides):vs.append(Vector(pt)+radii[i]*(math.cos(j*math.tau/sides)*v+math.sin(j*math.tau/sides)*w))
 for i in range(len(points)-1):
  for j in range(sides):u=i*sides+j;v=i*sides+(j+1)%sides;fs.append((u,v,v+sides,u+sides))
 fs.extend([tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+j for j in range(sides))]);return mesh(name,vs,fs,material,parent)
def empty(name,parent=None):
 o=bpy.data.objects.new(name,None);s.collection.objects.link(o);o.parent=parent;return o
root=empty('Flight');segments=[]
# Dragon local longitudinal axis is +X. All scales are raised individual geometry.
for i in range(64):
 q=i/63;r=.34*(1-q*.78)+.015;bone=empty('Body_%02d'%i,root);segments.append(bone)
 sphere('Bronze flexible skin', (0,0,0),(.125,r,r),skin,bone)
 vs=[];fs=[]
 for j in range(12):
  angle=j*math.tau/12+(i%2)*math.pi/12
  # Overlapping convex shield with a sculpted central crest, tangent to body.
  c=Vector((0,math.cos(angle)*r,math.sin(angle)*r));along=Vector((1,0,0));across=Vector((0,-math.sin(angle),math.cos(angle)));normal=Vector((0,math.cos(angle),math.sin(angle)))
  w=r*.29;L=.14;idx=len(vs)
  for x,y,h in [(-L,0,0),(-L*.35,-w,0),(L*.7,-w*.7,0),(L,0,0),(L*.7,w*.7,0),(-L*.35,w,0),(0,0,.035)]:vs.append(c+along*x+across*y+normal*h)
  for k in range(6):fs.append((idx+k,idx+(k+1)%6,idx+6))
 mesh('Twelve raised overlapping gold scales',vs,fs,gold,bone)
 # Ventral articulated plates.
 sphere('Belly plate',(.01,0,-r*.94),(.13,r*.65,.035),edge,bone)
 if i%2==0:tube('Dorsal horn',[(0,0,r),(-.10,0,r+.15),(-.25,0,r+.24)],[.065,.045,.001],ivory,bone)
# Expressive sculpted layered head; head frame follows neck tangent.
head=empty('Head articulation',segments[0]);head.location=(.20,0,.03)
sphere('Cranium',(.12,0,.10),(.50,.35,.33),gold,head)
sphere('Nasal bridge',(.52,0,.015),(.42,.25,.19),gold,head)
sphere('Muzzle',(.78,0,-.04),(.23,.29,.14),edge,head)
sphere('Mouth cavity',(.56,0,-.16),(.44,.23,.10),mouth,head)
jaw=empty('Roaring jaw',head);jaw.location=(.16,0,-.16);sphere('Lower jaw',(.35,0,-.055),(.43,.235,.095),gold,jaw)
for side in [-1,1]:
 sphere('Nostril',(.86,side*.19,.025),(.083,.045,.045),mouth,head)
 sphere('Eye socket',(.28,side*.29,.23),(.18,.07,.14),skin,head)
 sphere('Eye',(.32,side*.342,.24),(.10,.035,.084),eye,head)
 sphere('Vertical pupil',(.34,side*.37,.24),(.026,.012,.07),black,head)
 tube('Swept brow',[(.49,side*.30,.31),(.27,side*.36,.39),(-.06,side*.33,.37)],[.07,.085,.006],edge,head)
 # Branched swept antlers.
 tube('Antler',[(-.10,side*.23,.30),(-.30,side*.37,.64),(-.46,side*.45,.94),(-.34,side*.53,1.18)],[.12,.09,.055,.001],ivory,head,12)
 tube('Antler tine',[(-.31,side*.38,.65),(-.59,side*.41,.75),(-.72,side*.36,.98)],[.065,.04,.001],ivory,head)
 for j in range(7):
  x=.29+j*.085
  tube('Upper ivory teeth',[(x,side*.20,-.12),(x+.018,side*.19,-.23)],[.027,.001],ivory,head)
 whisker=empty('Whisker sway',head);whisker.location=(.67,side*.23,-.04)
 pts=[(0,0,0),(.15,side*.24,-.06),(.03,side*.54,.02),(-.35,side*.75,.14),(-.73,side*.78,.29),(-1.1,side*.65,.44)]
 tube('Long tactile whisker',pts,[.025,.022,.018,.012,.007,.001],edge,whisker)
 for f in range(1,361,6):whisker.rotation_euler.x=.13*math.sin(f*.045+side);whisker.keyframe_insert('rotation_euler',frame=f)
 # Layered cheek fins and dozens of flowing mane locks, actual tapered 3D curves.
 for j in range(26):
  z=random.uniform(-.18,.36);y=side*random.uniform(.18,.32);x=random.uniform(-.28,.05);L=random.uniform(.48,.95)
  tube('Cheek mane lock',[(x,y,z),(x-.23,y+side*.11,z+.10),(x-L*.7,y+side*.18,z+.14),(x-L,y+side*.10,z+.32)],[.045,.035,.018,.001],mane,head)
for j in range(20):
 x=random.uniform(.18,.59);y=random.uniform(-.15,.15)
 tube('Silken beard',[(x,y,-.22),(x-.15,y,-.48),(x-.38,y*.8,-.65)],[.018,.013,.001],edge,jaw)
# Raised cranial shields follow the sculpted forehead rather than a flat decal.
for row in range(6):
 for col in range(-2,3):
  x=.12+row*.08;y=col*.065;z=.33-.14*(row/6)**2-.08*abs(col)/2
  sphere('Forehead overlapping shield',(x,y,z),(.07,.042,.018),edge,head)
for j in range(18):
 theta=j*math.tau/18
 tube('Flowing tail tuft',[(0,0,0),(-.15,.10*math.cos(theta),.10*math.sin(theta)),(-.5,.20*math.cos(theta),.20*math.sin(theta)),(-.8,.12*math.cos(theta),.12*math.sin(theta))],[.025,.02,.01,.001],mane,segments[-1])
# Four jointed limbs, claws and individual digits.
for index in [7,25]:
 for side in [-1,1]:
  limb=empty('Shoulder hip %s %s'%(index,side),segments[index]);limb.location=(0,side*.22,0)
  tube('Upper limb',[(0,0,0),(.02,side*.18,-.17),(.15,side*.32,-.36)],[.14,.13,.10],gold,limb,12)
  fore=empty('Elbow articulation',limb);fore.location=(.15,side*.32,-.36)
  tube('Forelimb',[(0,0,0),(.13,side*.02,-.17),(.30,side*.07,-.22)],[.10,.085,.065],gold,fore,12)
  sphere('Palm',(.31,side*.07,-.22),(.12,.12,.07),gold,fore)
  for d in range(4):
   y=side*.07+(d-1.5)*.065
   tube('Finger',[(.32,y,-.22),(.45,y*1.2,-.21),(.52,y*1.3,-.29)],[.04,.03,.015],edge,fore)
   tube('Hooked claw',[(.50,y*1.3,-.27),(.57,y*1.3,-.31),(.56,y*1.3,-.40)],[.028,.02,.001],ivory,fore)
  for f in range(1,361,6):
   limb.rotation_euler.x=.25*math.sin(f*.035-index*.2+side);limb.rotation_euler.z=.20*math.sin(f*.028+index);limb.keyframe_insert('rotation_euler',frame=f);fore.rotation_euler.y=.2*math.sin(f*.04+index);fore.keyframe_insert('rotation_euler',frame=f)
# Animated flight path: traveling waves deform the entire body in 3D, head leads.
def center(u,t):
 # Hero coil tightens at 5-8 seconds; shoulders lead the serpentine wave.
 phase=u*math.tau*1.16-t*.47;curl=.72+.27*math.sin(t*.48)
 return Vector((1.66*math.sin(phase)*curl,.52*math.cos(phase)+.18*math.sin(u*11+t),2.7-4.6*u+.37*math.cos(phase*1.3)))
for f in range(1,361,3):
 t=(f-1)/30
 for i,bone in enumerate(segments):
  u=i/63;pos=center(u,t);tangent=(center(u-.003,t)-center(u+.003,t)).normalized();bone.location=pos;bone.rotation_mode='QUATERNION';bone.rotation_quaternion=tangent.to_track_quat('X','Z');bone.keyframe_insert('location',frame=f);bone.keyframe_insert('rotation_quaternion',frame=f)
 # Emerge from depth, hero hold, retreat; actual perspective changes.
 k=min(1,t/1.7)*min(1,max(0,(12-t)/1.6));root.scale=(k,k,k);root.location=(.22*math.sin(t*.65),.7*(1-k),0);root.rotation_euler.z=.07*math.sin(t*.5);root.keyframe_insert('scale',frame=f);root.keyframe_insert('location',frame=f);root.keyframe_insert('rotation_euler',frame=f)
 head.rotation_euler.x=.12*math.sin(t*1.7);head.rotation_euler.y=.14*math.sin(t*.9);head.keyframe_insert('rotation_euler',frame=f)
 jaw.rotation_euler.y=.07+.25*math.exp(-((t-8.7)/.65)**2);jaw.keyframe_insert('rotation_euler',frame=f)
# Fine dust motes move independently behind the path, no opaque glow plane.
for j in range(100):
 u=random.random();o=sphere('Fine airborne gold',center(u,3),(.008,)*3,dustmat);seed=random.random()*math.tau
 for f in range(1,361,9):
  t=(f-1)/30;v=(u+t*.045)%1;o.location=center(v,t-.5)+Vector((.35*math.sin(seed+t),.18*math.cos(seed),.22*math.sin(seed+t*2)));k=.35+.65*math.sin(math.pi*v)**2;o.scale=(.009*k,)*3;o.keyframe_insert('location',frame=f);o.keyframe_insert('scale',frame=f)
# Film alpha fades every surface, including fine dust, without a background plane.
for material in [gold,edge,skin,ivory,black,eye,mane,mouth,dustmat]:
 alpha=material.node_tree.nodes.get('Principled BSDF').inputs['Alpha']
 for f,v in [(1,0),(30,1),(316,1),(360,0)]:
  alpha.default_value=v;alpha.keyframe_insert('default_value',frame=f)
# Camera and photographic softboxes: broad warm key, cool rim, white overhead.
bpy.ops.object.camera_add(location=(8,-14,7));cam=bpy.context.object;target=Vector((0,0,.25));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=8.1;s.camera=cam
# Perspective lens, same portrait coverage.
cam.data.type='PERSP';cam.data.lens=55
for name,loc,power,color,size in [('Warm key',(1,-5,7),850,(1,.84,.62),5),('Cool rim',(-4,2,4),1300,(.52,.72,1),4),('Gold rim',(4,3,1),1000,(1,.58,.20),3),('Face fill',(3,-4,1),600,(1,.94,.8),3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.color=color;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
# Linear animation interpolation prevents overshoot at entry/exit boundaries.
for o in bpy.data.objects:
 if o.animation_data and o.animation_data.action:
  for fc in o.animation_data.action.fcurves:
   for k in fc.keyframe_points:k.interpolation='LINEAR'
s.frame_set(a.frame or 210);bpy.ops.wm.save_as_mainfile(filepath=str(out/'golden_dragon.blend'))
if not a.build_only:
 if a.frame:s.render.filepath=str(out/('still_%04d.png'%a.frame));bpy.ops.render.render(write_still=True)
 else:bpy.ops.render.render(animation=True)
