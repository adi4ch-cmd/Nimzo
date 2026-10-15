"""Encode 240 real RGBA car frames (8 seconds, 30fps). VAP candidate is NOT device-certified.
Layout: full-resolution alpha on left; straight RGB on right, 16px alignment.
VAP v2 metadata is appended after encoding so MP4 chunk offsets remain valid.
"""
import argparse
import json
from pathlib import Path
import struct
import subprocess


def config(width, height, frames, fps):
    if min(width, height, frames, fps) <= 0 or width % 2 or height % 2:
        raise ValueError('Positive frame count/rate and even YUV420 dimensions required')
    half = (width + 15) // 16 * 16
    return {'info': dict(v=2, f=frames, w=width, h=height,
        videoW=half*2, videoH=(height+15)//16*16, orien=0,
        fps=fps, isVapx=0, aFrame=[0,0,width,height],
        rgbFrame=[half,0,width,height])}



def h264_level(metadata):
    info=metadata['info']
    macroblocks=((info['videoW']+15)//16)*((info['videoH']+15)//16)
    rate=macroblocks*info['fps']
    if macroblocks<=8192 and rate<=245760:
        return '4.1'
    if macroblocks<=36864 and rate<=983040:
        return '5.1'
    raise ValueError('Packed stream exceeds supported H.264 level 5.1 limits')


def append_config(mp4, metadata):
    payload = json.dumps(metadata, separators=(',', ':')).encode('utf8')
    return mp4 + struct.pack('>I4s', len(payload)+8, b'vapc') + payload


def run(*args):
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y',*map(str,args)],check=True)


def encode(folder):
    from PIL import Image
    folder=Path(folder)
    paths=sorted((folder/'rgba').glob('frame_*.png'))
    if [p.name for p in paths] != [f'frame_{n:04}.png' for n in range(1,241)]:
        raise ValueError('Expected complete frame_0001.png through frame_0120.png')
    with Image.open(paths[0]) as im:
        width,height=im.size
        if im.mode != 'RGBA': raise ValueError('Render is not RGBA')
    metadata=config(width,height,len(paths),30)
    info=metadata['info']; half=info['videoW']//2; vh=info['videoH']
    inputs=['-framerate','30','-start_number','1','-i',folder/'rgba/frame_%04d.png']
    # Neutral background is explicit review media, never advertised as alpha.
    run(*inputs,'-f','lavfi','-i',f'color=c=0x17222c:s={width}x{height}:r=30',
        '-filter_complex','[1:v][0:v]overlay=shortest=1:format=auto,format=yuv420p[v]',
        '-map','[v]','-an','-c:v','libx264','-preset','medium','-crf','18','-movflags','+faststart',folder/'preview.mp4')
    # Lossless review master; RGBA remains independently recoverable.
    run(*inputs,'-an','-c:v','ffv1','-level','3','-pix_fmt','bgra',folder/'rgba_master.mkv')
    packed=folder/'packed.tmp.mp4'
    graph=(f'[0:v]split[c][a];[a]alphaextract,format=rgb24,pad={half}:{vh}:0:0:black[mask];'
           f'[c]format=rgb24,pad={half}:{vh}:0:0:black[color];[mask][color]hstack,format=yuv420p[v]')
    run(*inputs,'-filter_complex',graph,'-map','[v]','-an','-c:v','libx264',
        '-profile:v','high','-level:v',h264_level(metadata),'-crf','14','-preset','medium',
        '-movflags','+faststart',packed)
    (folder/'alpha_vap.mp4').write_bytes(append_config(packed.read_bytes(),metadata))
    packed.unlink()
    (folder/'vap-config.json').write_text(json.dumps(metadata,indent=2)+'\n')
    with Image.open(folder/'rgba/frame_0120.png') as im:
        im.save(folder/'poster.png')
        im.thumbnail((320,568));im.save(folder/'thumbnail.webp',lossless=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('folder');encode(parser.parse_args().folder)
