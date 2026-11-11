from pathlib import Path
import subprocess,json,wave
import numpy as np
ROOT=Path(__file__).parent
SR=44100

def decode(sid, filters='', start=None, end=None):
    p=next((ROOT/'sources').glob('fs_'+sid+'_*'))
    args=['ffmpeg','-v','error','-i',str(p),'-ac','1','-ar',str(SR)]
    if start is not None:
        filters=f'atrim=start={start}:end={end},asetpts=PTS-STARTPTS'+(','+filters if filters else '')
    if filters:args+=['-af',filters]
    return np.frombuffer(subprocess.check_output(args+['-f','f32le','-']),dtype=np.float32).astype(float)

def shape(x, level=1, fadein=.002, fadeout=.025):
    x=x.copy(); peak=max(abs(x));x*=level/max(peak,1e-10)
    n=min(len(x),int(fadein*SR));x[:n]*=np.linspace(0,1,n)
    n=min(len(x),int(fadeout*SR));x[-n:]*=np.linspace(1,0,n)
    return x

def mix(name,duration,layers):
    out=np.zeros(int(duration*SR))
    for at,x in layers:
        offset=int(at*SR);n=min(len(x),len(out)-offset)
        out[offset:offset+n]+=x[:n]
    rms=np.sqrt(np.convolve(out*out,np.ones(1764)/1764,mode='valid').max())
    gain=min(10**(-25/20)/max(rms,1e-10),10**(-12/20)/max(abs(out)))
    out*=gain
    folder=ROOT/'candidates';folder.mkdir(exist_ok=True)
    with wave.open(str(folder/name),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes((out*32767).astype('<i2').tobytes())
    return {'file':name,'duration':duration,'peak_dbfs':round(float(20*np.log10(max(abs(out)))),2),'gain_db':round(float(20*np.log10(gain)),2)}

# A: soften and stretch a reversed short whoosh into an approach, then catch it.
whoosh=shape(decode('585257','areverse,atempo=0.5,highpass=f=350,lowpass=f=3200',.135,.24),.30,.065,.025)
pickup=shape(decode('665183','asetrate=36162,aresample=44100,lowpass=f=3000'),1,.002,.025)
# B: keep the pouch contact and early settling texture; remove the initial silence.
pouch=shape(decode('575583','highpass=f=100,lowpass=f=2500',.145,.57),1,.003,.08)
# C: tuck two small pieces together before a quiet, lower landing.
small=shape(decode('563465','highpass=f=180,lowpass=f=2800',.03,.21),.32,.002,.06)
settle=shape(decode('665183','asetrate=33075,aresample=44100,lowpass=f=2300'),.75,.002,.03)
rows=[mix('01-drawn-in.wav',.38,[(0,whoosh),(.165,pickup)]),mix('02-pocket-landing.wav',.46,[(0,pouch)]),mix('03-gather-and-settle.wav',.36,[(0,small),(.065,small*.55),(.15,settle)])]
(ROOT/'processing.json').write_text(json.dumps(rows,indent=2))
for row in rows:print(row)
