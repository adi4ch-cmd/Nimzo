"""Render the CC-BY Car Concept model, not procedurally built car geometry.
Blender 4.3: blender -b -t 3 -P car_scene.py -- --model CarConcept.glb --hdri studio.exr --out output --color red --frame 120
Omit --frame to render all 240 actual RGBA frames (8 sec at 30fps).
"""
import argparse, math, random, sys
from pathlib import Path
import bpy
from mathutils import Vector
p=argparse.ArgumentParser();p.add_argument('--model',required=True);p.add_argument('--hdri',required=True);p.add_argument('--out',required=True);p.add_argument('--color',choices=['red','black','gold','blue'],required=True);p.add_argument('--width',type=int,default=540);p.add_argument('--samples',type=int,default=32);p.add_argument('--frame',type=int);p.add_argument('--build-only',action='store_true');p.add_argument('--denoise',action='store_true');p.add_argument('--start',type=int,default=1);p.add_argument('--end',type=int,default=240)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=Path(a.out);(out/'rgba').mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(Path(a.model).resolve()));bpy.context.view_layer.update()
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=a.samples;s.cycles.use_denoising=a.denoise;s.cycles.max_bounces=4;s.cycles.volume_step_rate=8;s.cycles.adaptive_threshold=.05;s.cycles.adaptive_min_samples=4;s.cycles.transmission_bounces=4;s.cycles.transparent_max_bounces=8
s.cycles.film_transparent_glass=True;s.cycles.film_transparent_roughness=.1
s.render.film_transparent=True;s.render.resolution_x=a.width;s.render.resolution_y=round(a.width*16/9);s.render.resolution_percentage=100;s.render.fps=30;s.frame_start=1;s.frame_end=240
s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.filepath=str(out/'rgba/frame_');s.view_settings.view_transform='AgX'
# Delete excluded logo surfaces, including the steering badge and license plate.
for name in ['InteriorSteeringEmblem','License Plate']:
 ob=bpy.data.objects.get(name)
 if ob:bpy.data.objects.remove(ob,do_unlink=True)
objects=list(s.objects);root=bpy.data.objects.new('Vehicle driving rig',None);s.collection.objects.link(root)
for o in objects:
 if o.parent is None:
  mw=o.matrix_world.copy();o.parent=root;o.matrix_world=mw
points=[o.matrix_world@Vector(v) for o in objects if o.type=='MESH' for v in o.bound_box]
ground=min(v.z for v in points);center=Vector(((min(v.x for v in points)+max(v.x for v in points))/2,(min(v.y for v in points)+max(v.y for v in points))/2,ground))
# Preserve authored model pivots; center and ground with a wrapper, not remeshing.
normalizer=bpy.data.objects.new('Model placement',None);s.collection.objects.link(normalizer);normalizer.parent=root;normalizer.location=-center
for o in objects:
 if o.parent==root:o.parent=normalizer
bpy.context.view_layer.update()
colors={'red':(.48,.009,.018),'black':(.012,.016,.025),'gold':(.74,.40,.075),'blue':(.009,.075,.52)}
paint=colors[a.color]
for m in bpy.data.materials:
 if not m.use_nodes:continue
 n=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
 if not n:continue
 if m.name.startswith('Paint 1'):
  for link in list(n.inputs['Base Color'].links):m.node_tree.links.remove(link)
  n.inputs['Base Color'].default_value=(*paint,1);n.inputs['Metallic'].default_value=.78;n.inputs['Roughness'].default_value=.24;n.inputs['Coat Weight'].default_value=1;n.inputs['Coat Roughness'].default_value=.13
  # Keep a restrained fine-flake normal instead of oversized pixel sparkle.
  for link in list(n.inputs['Normal'].links):m.node_tree.links.remove(link)
  noise=m.node_tree.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=850
  bump=m.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.07;bump.inputs['Distance'].default_value=.001
  m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs['Normal'],n.inputs['Normal'])
 elif m.name.startswith('Interior 3'):
  n.inputs['Base Color'].default_value=(.025,.018,.018,1)
 elif m.name=='Headlight':
  n.inputs['Emission Color'].default_value=(.8,.9,1,1);n.inputs['Emission Strength'].default_value=5
 elif m.name=='Brakelight':
  n.inputs['Emission Color'].default_value=(1,.005,.003,1);n.inputs['Emission Strength'].default_value=3
# Spin tires, rims and discs at real authored wheel centers. Calipers stay fixed.
spins=[];fronts=[]
for name in ['WheelFrontL','WheelFrontR','WheelRearL','WheelRearR']:
 wheel=bpy.data.objects[name];spin=bpy.data.objects.new(name+' rolling axle',None);s.collection.objects.link(spin);spin.parent=wheel
 bpy.context.view_layer.update()
 for child in list(wheel.children):
  if child==spin or 'BrakePad' in child.name:continue
  mw=child.matrix_world.copy();child.parent=spin;child.matrix_world=mw
 spins.append(spin)
 if 'Front' in name:fronts.append(wheel)
# Real environment lighting, hidden only from the camera by film transparency.
w=bpy.data.worlds.new('CC0 photographic studio');s.world=w;w.use_nodes=True;nt=w.node_tree;env=nt.nodes.new('ShaderNodeTexEnvironment');env.image=bpy.data.images.load(str(Path(a.hdri).resolve()));nt.links.new(env.outputs['Color'],nt.nodes['Background'].inputs['Color']);nt.nodes['Background'].inputs['Strength'].default_value=.45
for name,loc,power,size in [('Key softbox',(1,-3,6),850,5),('Side strip',(-5,0,3),650,4),('Rim strip',(4,3,4),1000,4)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.shape='RECTANGLE';o.data.size=size;o.data.size_y=size*.35;o.rotation_euler=(Vector((0,0,.7))-o.location).to_track_quat('-Z','Y').to_euler()
# No floor: a finite shadow catcher produced a rectangular alpha edge during exit.
# Gift geometry and volumetric haze composite directly over the room.
# Soft volumetric tire haze is real participating media, never an opaque card.
random.seed(91)
smokes=[]
for i in range(2):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1);o=bpy.context.object;o.name='Tire vapor %02d'%i
 m=bpy.data.materials.new(o.name);m.use_nodes=True;nodes=m.node_tree.nodes;nodes.clear();vol=nodes.new('ShaderNodeVolumePrincipled');vol.inputs['Color'].default_value=(.52,.56,.60,1)
 tex=nodes.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=3;tex.inputs['Detail'].default_value=3
 mult=nodes.new('ShaderNodeMath');mult.operation='MULTIPLY';mult.inputs[1].default_value=.22
 output=nodes.new('ShaderNodeOutputMaterial');coord=nodes.new('ShaderNodeTexCoord');sub=nodes.new('ShaderNodeVectorMath');sub.operation='SUBTRACT';sub.inputs[1].default_value=(.5,.5,.5);length=nodes.new('ShaderNodeVectorMath');length.operation='LENGTH';edge=nodes.new('ShaderNodeMath');edge.operation='MULTIPLY_ADD';edge.inputs[1].default_value=-2;edge.inputs[2].default_value=1;edge.use_clamp=True;soft=nodes.new('ShaderNodeMath');soft.operation='MULTIPLY';m.node_tree.links.new(coord.outputs['Generated'],sub.inputs[0]);m.node_tree.links.new(sub.outputs['Vector'],length.inputs[0]);m.node_tree.links.new(length.outputs['Value'],edge.inputs[0]);m.node_tree.links.new(edge.outputs[0],soft.inputs[0]);m.node_tree.links.new(tex.outputs['Fac'],soft.inputs[1]);m.node_tree.links.new(soft.outputs[0],mult.inputs[0]);m.node_tree.links.new(mult.outputs[0],vol.inputs['Density']);m.node_tree.links.new(vol.outputs['Volume'],output.inputs['Volume']);o.data.materials.append(m);smokes.append((o,mult,random.random()))
# Camera sees actual perspective change while the car drives on an arc.
bpy.ops.object.camera_add(location=(6,-9,3.6));cam=bpy.context.object;cam.data.lens=48;s.camera=cam
# Distances drive wheel angular displacement, rather than arbitrary spinning.
def path(t):
 keys=[(0,(-5,3,0),-.50),(1.7,(-.8,.65,0),-.12),(3,(0,0,0),0),(5,(.25,-.15,0),.10),(6,(1,-.7,0),.40),(8,(6,-4.5,0),.65)]
 for (ta,pa,ra),(tb,pb,rb) in zip(keys,keys[1:]):
  if t<=tb:
   u=max(0,min(1,(t-ta)/(tb-ta)));u=u*u*(3-2*u);return Vector(pa).lerp(Vector(pb),u),ra*(1-u)+rb*u
 return Vector(keys[-1][1]),keys[-1][2]
previous=path(0)[0];distance=0
for f in range(1,241):
 t=(f-1)/30;pos,heading=path(t);distance+=(pos-previous).length;previous=pos.copy();root.location=pos;root.location.z=.012*math.sin(t*8)*min(1,(pos-path(max(0,t-.03))[0]).length*15);root.rotation_euler.z=heading;root.keyframe_insert('location',frame=f);root.keyframe_insert('rotation_euler',frame=f)
 for spin in spins:spin.rotation_euler.x=distance/.36;spin.keyframe_insert('rotation_euler',frame=f)
 for wheel in fronts:wheel.rotation_euler.y=.08*math.sin(t*.9);wheel.keyframe_insert('rotation_euler',frame=f)
 cam.location=(6+.8*math.sin(t*.35),-9+.4*math.sin(t*.5),3.6-.25*math.sin(t*.3));cam.rotation_euler=(Vector((.15,0,.65))-cam.location).to_track_quat('-Z','Y').to_euler();cam.keyframe_insert('location',frame=f);cam.keyframe_insert('rotation_euler',frame=f)
 for i,(smoke,density,seed) in enumerate(smokes):
  age=(t*.38+seed)%1;trail,_=path(max(0,t-age*.9));smoke.location=trail+Vector((((i%2)*2-1)*.9,.9+age*.9,.12+age*.35));smoke.scale=(.35+age*.7,.5+age,.16+age*.4);density.inputs[1].default_value=.09*math.sin(math.pi*age)**2
  smoke.keyframe_insert('location',frame=f);smoke.keyframe_insert('scale',frame=f);density.inputs[1].keyframe_insert('default_value',frame=f)
# Fade the completed premultiplied RGBA, avoiding material-bounce artifacts.
s.use_nodes=True;nt=s.node_tree;nt.nodes.clear();rl=nt.nodes.new('CompositorNodeRLayers');fade=nt.nodes.new('CompositorNodeSetAlpha');fade.mode='APPLY';comp=nt.nodes.new('CompositorNodeComposite');nt.links.new(rl.outputs['Image'],fade.inputs['Image']);nt.links.new(fade.outputs['Image'],comp.inputs['Image'])
for f,value in [(1,0),(20,1),(215,1),(240,0)]:fade.inputs['Alpha'].default_value=value;fade.inputs['Alpha'].keyframe_insert('default_value',frame=f)
for o in bpy.data.objects:
 if o.animation_data and o.animation_data.action:
  for fc in o.animation_data.action.fcurves:
   for key in fc.keyframe_points:key.interpolation='LINEAR'
s.frame_set(a.frame or 120);bpy.context.view_layer.update()
for spin in spins:
 wheel=spin.parent
 for mesh in spin.children:
  if mesh.type!='MESH':continue
  centroid=sum((mesh.matrix_world@Vector(c) for c in mesh.bound_box),Vector())/8
  assert (centroid-wheel.matrix_world.translation).length<.85, 'Wheel geometry detached from its rolling axle: '+mesh.name
bpy.data.orphans_purge(do_recursive=True);bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(out/(a.color+'_luxury_supercar.blend')))
if not a.build_only:
 if a.frame:s.render.filepath=str(out/('diagnostic_%04d.png'%a.frame));bpy.ops.render.render(write_still=True)
 else:
  s.frame_start=a.start;s.frame_end=a.end;bpy.ops.render.render(animation=True)
