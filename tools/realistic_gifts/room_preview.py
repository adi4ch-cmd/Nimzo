"""Composite decoded VAP motion over checked-in room screenshot backgrounds.
These are desktop review composites, not recordings of native Android playback.
Run after verify.py has generated the light and derived-dark backgrounds.
"""
import argparse
import json
from pathlib import Path
import subprocess


def make(folder):
    folder=Path(folder)
    info=json.loads((folder/'vap-config.json').read_text())['info']
    width,height=info['w'],info['h'];x=info['rgbFrame'][0]
    graph=(f'[0:v]format=rgb24,split[a][c];'
        f'[a]crop={width}:{height}:0:0,extractplanes=r[mask];'
        f'[c]crop={width}:{height}:{x}:0[color];'
        '[color][mask]alphamerge[rgba];'
        '[1:v][rgba]overlay=shortest=1:format=auto,format=yuv420p[v]')
    for name in ['light','dark_derived']:
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(folder/'alpha_vap.mp4'),
            '-loop','1','-framerate','30','-i',str(folder/f'room_background_{name}.png'),
            '-filter_complex',graph,'-map','[v]','-an','-t','8','-c:v','libx264',
            '-crf','18','-movflags','+faststart',str(folder/f'room_{name}.mp4')],check=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('folder');make(p.parse_args().folder)
