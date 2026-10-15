"""File/CPU compositing evidence; never substitutes for Android device QA."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import numpy as np
from PIL import Image, ImageOps


def probe(path):
    return json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames',
        '-show_streams','-show_format','-of','json',str(path)]))


def check(folder):
    folder=Path(folder)
    paths=sorted((folder/'rgba').glob('frame_*.png'))
    assert len(paths)==360, f'Incomplete render: {len(paths)}/360'
    samples=[np.array(Image.open(folder/f'rgba/frame_{f:04}.png').convert('RGBA'))
             for f in [1,60,120,180,240,300,360]]
    height,width=samples[0].shape[:2]
    assert samples[0][:,:,3].max()==0, 'Opening must be transparent'
    assert samples[-1][:,:,3].max()==0, 'Ending must be transparent'
    frame=samples[4];alpha=frame[:,:,3]
    assert alpha.min()==0 and alpha.max()==255
    assert ((alpha>0)&(alpha<255)).sum()>100, 'Missing antialiased edges'
    motion=[float(np.abs(x.astype(float)-y.astype(float)).mean()) for x,y in zip(samples[1:-2],samples[2:-1])]
    assert min(motion)>.1, 'Repeated/unchanging sampled images'
    reports={}
    for name in ['golden_dragon_demo.mp4','golden_dragon_vap_candidate.mp4','golden_dragon_rgba.mkv']:
        p=folder/name;r=probe(p);v=r['streams'][0]
        assert len(r['streams'])==1 and v['codec_type']=='video', 'Expected silent video only'
        assert v['codec_name']==('ffv1' if name.endswith('.mkv') else 'h264'), 'Unexpected codec'
        expected_size=(((width+15)//16*32,(height+15)//16*16)
                       if 'vap_candidate' in name else (width,height))
        assert (v['width'],v['height'])==expected_size, 'Unexpected encoded dimensions'
        assert v['nb_read_frames']=='360', (name,v.get('nb_read_frames'))
        assert v['r_frame_rate']=='30/1'
        assert abs(float(r['format']['duration'])-12)<.04
        reports[name]={'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
            'codec':v['codec_name'],'pixel_format':v['pix_fmt'],'width':v['width'],'height':v['height'],'frames':360,'fps':30,'duration':r['format']['duration']}
    # Decode every lossless master frame to RGBA, with bounded memory.
    master=folder/'golden_dragon_rgba.mkv'
    stream=probe(master)['streams'][0]
    assert stream['codec_name']=='ffv1', 'Expected FFV1 lossless master'
    assert stream['pix_fmt'] in ('bgra','rgba'), 'Master must use an alpha-bearing pixel format'
    assert (stream['width'],stream['height'])==(width,height), 'RGBA master dimensions differ'
    decoder=subprocess.Popen(['ffmpeg','-v','error','-i',str(master),
        '-f','rawvideo','-pix_fmt','rgba','pipe:1'],stdout=subprocess.PIPE)
    try:
        for path in paths:
            raw_frame=decoder.stdout.read(width*height*4)
            assert len(raw_frame)==width*height*4, 'Truncated RGBA master decode'
            actual=np.frombuffer(raw_frame,dtype=np.uint8).reshape(height,width,4)
            with Image.open(path) as im:
                expected=np.array(im.convert('RGBA'))
            assert np.array_equal(actual,expected), f'RGBA master differs: {path.name}'
        assert decoder.stdout.read(1)==b'', 'Unexpected extra RGBA master frames'
        assert decoder.wait()==0, 'RGBA master decoder failed'
    finally:
        if decoder.poll() is None:
            decoder.kill();decoder.wait()
        decoder.stdout.close()
    # Decode actual packed H.264, reconstruct alpha and quantify lossy mask error.
    cfg=json.loads((folder/'vap-config.json').read_text())['info']
    data=(folder/'golden_dragon_vap_candidate.mp4').read_bytes();pos=0;found=None
    while pos+8<=len(data):
        size,kind=struct.unpack('>I4s',data[pos:pos+8]);assert size>=8
        if kind==b'vapc': found=json.loads(data[pos+8:pos+size])
        pos+=size
    assert found and found['info']==cfg
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(folder/'golden_dragon_vap_candidate.mp4'),
        '-vf',"select=eq(n\\,239)",'-frames:v','1','-f','rawvideo','-pix_fmt','rgb24','pipe:1'])
    packed=np.frombuffer(raw,dtype=np.uint8).reshape(cfg['videoH'],cfg['videoW'],3)
    mask=packed[:height,:width,0];offset=cfg['rgbFrame'][0]
    color=packed[:height,offset:offset+width,:]
    error=float(np.abs(mask.astype(float)-alpha.astype(float)).mean())
    assert error<3, f'Alpha mask error: {error}'
    visible=alpha>200
    color_error=float(np.abs(color[visible].astype(float)-frame[:,:,:3][visible].astype(float)).mean())
    assert color_error<20, f'Visible VAP color differs: {color_error}'
    decoded=np.dstack([color,mask]);Image.fromarray(decoded).save(folder/'vap_decoded_0240.png')
    for name,rgb in [('dark',(18,24,32)),('light',(239,242,245))]:
        bg=Image.new('RGBA',(width,height),(*rgb,255))
        bg.alpha_composite(Image.fromarray(frame));bg.convert('RGB').save(folder/f'alpha_{name}_original.png')
        bg=Image.new('RGBA',(width,height),(*rgb,255));bg.alpha_composite(Image.fromarray(decoded));bg.convert('RGB').save(folder/f'alpha_{name}_vap.png')
    # Existing checked-in NIMZO room golden; dark version is an explicitly
    # derived contrast stress test, not a claimed Android capture.
    room_path=Path(__file__).resolve().parents[2]/'nimzo/test/goldens/remaining/room.png'
    if room_path.exists():
        original=Image.open(room_path).convert('RGB')
        room=ImageOps.pad(original,(width,height),color=(245,245,245))
        for name,bg in [('light',room),('dark_derived',ImageOps.colorize(ImageOps.grayscale(room),(215,215,225),(18,24,32)))]:
            bg=bg.convert('RGBA');bg.save(folder/f'room_background_{name}.png')
            bg.alpha_composite(Image.fromarray(decoded));bg.convert('RGB').save(folder/f'room_alpha_{name}.png')
    report={'status':'REVIEW ONLY — premium art and Android device approval pending','rgba_dimensions':[width,height],
        'rgba_frame_count':len(paths),'lossless_rgba_frames_compared_exactly':len(paths),'edge_partial_alpha_pixels':int(((alpha>0)&(alpha<255)).sum()),
        'sample_frame_mean_absolute_differences':motion,'decoded_vap_alpha_mae_0_255':error,'decoded_vap_visible_rgb_mae_0_255':color_error,
        'media':reports,'android_device_tested':False,'vivox_coexistence_tested':False,
        'production_mapping_changed':False}
    (folder/'verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('folder');check(p.parse_args().folder)
