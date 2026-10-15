"""Run in Blender after loading the saved .blend; export measured animation state.
blender -b golden_dragon.blend -P audit_scene.py -- output.json
"""
import json
import sys
from pathlib import Path
import bpy

scene=bpy.context.scene
snapshots=[]
for f in [60,120,180,240,300]:
    scene.frame_set(f)
    bpy.context.view_layer.update()
    body=[bpy.data.objects[f'Body_{i:02}'].matrix_world.translation for i in range(64)]
    snapshots.append({'frame':f,'head_world':list(body[0]),'mid_world':list(body[24]),
        'tail_world':list(body[-1]),'head_mid_distance':float((body[0]-body[24]).length),
        'jaw_rotation':list(bpy.data.objects['Roaring jaw'].rotation_euler),
        'head_rotation':list(bpy.data.objects['Head articulation'].rotation_euler),
        'limb_rotation':list(bpy.data.objects['Shoulder hip 7 -1'].rotation_euler)})
assert len({round(x['head_mid_distance'],3) for x in snapshots})>1, 'Body moved only as a rigid object'
assert len({round(x['limb_rotation'][0],3) for x in snapshots})>1, 'No limb articulation'
assert len({round(x['jaw_rotation'][1],3) for x in snapshots})>1, 'No jaw articulation'
report={'source':'actual saved Blender scene','objects':len(bpy.data.objects),
    'mesh_polygons':sum(len(o.data.polygons) for o in bpy.data.objects if o.type=='MESH'),
    'film_transparent':scene.render.film_transparent,
    'camera':scene.camera.data.type,'render_samples':scene.cycles.samples,
    'external_images':[im.filepath for im in bpy.data.images if im.source=='FILE'],
    'snapshots':snapshots,
    'art_quality_accepted':False,
    'note':'Measured articulation is not evidence of physically realistic or premium animation quality.'}
Path(sys.argv[sys.argv.index('--')+1]).write_text(json.dumps(report,indent=2)+'\n')
print('Articulation verified from saved scene; premium art acceptance remains pending')
