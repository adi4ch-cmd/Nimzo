#!/usr/bin/env python3
"""Extract local, timestamp-addressable UI evidence without committing video art.

Requires ffmpeg/ffprobe. The source video and generated images stay outside git.
Quarter-second frames cover taps/scroll/motion; scene detection supplies extra
frames for short transitions. Both are aids to manual review, not proof that
all interactions or all animation frames have been identified.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def run(*args):
    subprocess.run(args, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('video', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    source = args.video.resolve()
    out = args.output.resolve()
    if source == out or out in source.parents:
        parser.error('Use a separate output directory, outside the source file.')
    out.mkdir(parents=True, exist_ok=True)
    for folder in ('frames', 'transitions', 'overview'):
        (out / folder).mkdir(exist_ok=True)
    metadata = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_format', '-show_streams',
        '-of', 'json', str(source)], text=True))
    digest = hashlib.sha256()
    with source.open('rb') as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b''):
            digest.update(chunk)
    metadata['source_sha256'] = digest.hexdigest()
    metadata['sample_interval_seconds'] = .25
    (out / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
    common = ['ffmpeg', '-hide_banner', '-nostdin', '-n', '-i', str(source)]
    run(*common, '-vf', 'fps=4,scale=540:-1', '-q:v', '4',
        str(out / 'frames/frame-%05d.jpg'))
    with (out / 'transitions.log').open('w') as log:
        subprocess.run([*common, '-vf',
            "scale=180:-1,select='gt(scene,0.08)',showinfo", '-fps_mode', 'vfr',
            '-q:v', '3', str(out / 'transitions/state-%05d.jpg')],
            stderr=log, check=True)
    transitions = []
    for line in (out / 'transitions.log').read_text().splitlines():
        match = re.search(r'\bn:\s*(\d+).*?pts_time:([\d.]+)', line)
        if match:
            transitions.append({'seconds': float(match[2]),
                'frame': f'transitions/state-{int(match[1]) + 1:05d}.jpg'})
    samples = [{'seconds': (i - 1) / 4, 'frame': f'frames/{p.name}'}
        for i, p in enumerate(sorted((out / 'frames').glob('frame-*.jpg')), 1)]
    (out / 'index.json').write_text(json.dumps({
        'samples': samples, 'transition_candidates': transitions}, indent=2) + '\n')
    run(*common, '-vf',
        'fps=1/4,scale=216:-1,drawtext=text=%{pts\\:hms}:x=4:y=4:'
        'fontsize=14:fontcolor=white:box=1:boxcolor=black@0.7,tile=8x4',
        str(out / 'overview/sheet-%02d.jpg'))
    print(f'{len(samples)} samples; {len(transitions)} transition candidates. Review manually.')


if __name__ == '__main__':
    main()
