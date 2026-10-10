"""Verify the concrete Java callback survived R8 in the release APK itself."""
import struct,sys,zipfile

def callbacks(apk):
 found=[]
 with zipfile.ZipFile(apk) as archive:
  for name in archive.namelist():
   if not name.endswith('.dex'): continue
   data=archive.read(name)
   def uint(offset): return struct.unpack_from('<I',data,offset)[0]
   def uleb(offset):
    result=0
    for shift in range(0,35,7):
     byte=data[offset];offset+=1;result|=(byte&127)<<shift
     if byte<128:return result,offset
    raise ValueError('Invalid DEX integer')
   def string(index):
    start=uint(uint(60)+index*4);_,start=uleb(start)
    return data[start:data.index(0,start)].decode('utf-8',errors='replace')
   def type_name(index):return string(uint(uint(68)+index*4))
   def method(index):
    cls,proto,text=struct.unpack_from('<HHI',data,uint(92)+index*8)
    offset=uint(76)+proto*12;params=uint(offset+8)
    types=[] if not params else [type_name(struct.unpack_from('<H',data,params+4+i*2)[0]) for i in range(uint(params))]
    return type_name(cls),string(text),'('+''.join(types)+')'+type_name(uint(offset+4))
   for i in range(uint(96)):
    cursor=uint(uint(100)+i*32+24)
    if not cursor:continue
    counts=[]
    for _ in range(4):n,cursor=uleb(cursor);counts.append(n)
    for _ in range(counts[0]+counts[1]):
     _,cursor=uleb(cursor);_,cursor=uleb(cursor)
    for count in counts[2:]:
     index=0
     for _ in range(count):
      delta,cursor=uleb(cursor);index+=delta
      _,cursor=uleb(cursor);code,cursor=uleb(cursor)
      owner,label,signature=method(index)
      if code and owner.startswith('Lio/nimzo/app/MainActivity$') and label=='onVivoxEvent' and signature=='(Ljava/lang/String;ILjava/lang/String;)V':found.append(owner)
 if not found:raise ValueError('Vivox JNI callback implementation was removed/renamed; release blocked')
 return found
if __name__=='__main__':
 print('Concrete Vivox JNI callback retained in APK:',', '.join(callbacks(sys.argv[1])))
