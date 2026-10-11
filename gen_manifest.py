# Generate a binary AndroidManifest.xml for a static RRO overlay.
# usage: gen_manifest.py <out> <overlay package> <target package> <priority>
import struct, sys
ANDROID = "http://schemas.android.com/apk/res/android"
# (name, resid) for android attrs; order of resource map = string order
ATTRS = [("versionCode",0x0101021b),("versionName",0x0101021c),("extractNativeLibs",0x010104ea),
         ("priority",0x0101001c),("targetPackage",0x01010021),("isStatic",0x0101055a)]
def build(pkg, target, priority):
    strings = [a[0] for a in ATTRS] + ["android", ANDROID, "package", "manifest", "application", "overlay", "1.0", pkg, target]
    S = {s:i for i,s in enumerate(strings)}
    rid = dict(ATTRS)
    def sp():
        data=b""; offs=[]
        for s in strings:
            offs.append(len(data)); e=s.encode("utf-16-le"); data+=struct.pack("<H",len(s))+e+b"\0\0"
        while len(data)%4: data+=b"\0"
        start=28+4*len(strings)
        body=b"".join(struct.pack("<I",o) for o in offs)+data
        return struct.pack("<HHIIIIII",1,28,28+len(body),len(strings),0,0,start,0)+body
    def rmap():
        b=b"".join(struct.pack("<I",r) for _,r in ATTRS); return struct.pack("<HHI",0x180,8,8+len(b))+b
    TSTR,TINT,TBOOL=0x03,0x10,0x12
    def attr(name,typ,val,ns=True):
        raw = S[val] if typ==TSTR else 0xffffffff
        data = S[val] if typ==TSTR else val
        return (rid.get(name,0xffffffff if not ns else 0), struct.pack("<iIIHBBI", S[ANDROID] if ns else -1, S[name], raw, 8,0,typ,data & 0xffffffff))
    def start(name,line,attrs):
        attrs=sorted(attrs,key=lambda a:(a[0]==0xffffffff, a[0]))  # android attrs by resid, then others
        a=b"".join(x[1] for x in attrs)
        return struct.pack("<HHIIiiIHHHHHH",0x102,16,36+len(a),line,-1,-1,S[name],20,20,len(attrs),0,0,0)+a
    def end(name,line): return struct.pack("<HHIIiiI",0x103,16,24,line,-1,-1,S[name])
    body = sp()+rmap()
    body += struct.pack("<HHIIiII",0x100,16,24,1,-1,S["android"],S[ANDROID])
    body += start("manifest",1,[attr("versionCode",TINT,1),attr("versionName",TSTR,"1.0"),attr("package",TSTR,pkg,ns=False)])
    body += start("application",5,[attr("extractNativeLibs",TBOOL,0)]) + end("application",5)
    body += start("overlay",6,[attr("priority",TINT,priority),attr("targetPackage",TSTR,target),attr("isStatic",TBOOL,0xffffffff)]) + end("overlay",6)
    body += end("manifest",1)
    body += struct.pack("<HHIIiII",0x101,16,24,1,-1,S["android"],S[ANDROID])
    return struct.pack("<HHI",3,8,8+len(body))+body
if __name__=="__main__":
    open(sys.argv[1],"wb").write(build(sys.argv[2],sys.argv[3],int(sys.argv[4])))
