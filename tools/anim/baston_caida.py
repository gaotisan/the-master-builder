"""EL BASTON EN LA CAIDA DEL CIELO (2026-10-28, Egipto; el usuario: "cuando
aterriza es cuando se tiene que poner el baston... coherente con la perspectiva
y movimiento"). La caida, tumbado y levantarse son de frente: el baston va por
detras del cuerpo, colocado en cada fotograma por la silueta (no a mano):
  - de pie / a cuatro patas: el pivote bajo la capucha y algo al lado, la garra
    asomando por encima del hombro, junto a la capucha;
  - tumbado (mas ancho que alto): apoyado en lo alto de la espalda (la joroba de
    la tunica), la garra asomando por encima;
  - mezclado entre las dos por lo tumbado que esta, y suavizado entre fotogramas;
  - la madera cortada donde sale de la silueta por abajo (si no, asomaba por los
    pies); antes del golpe (sprite 7 de caida), escondido.
Filas como baston_seguimiento.json: [x, y, giro, visible (0 detras, -1 no se
ve), corte (fraccion de la madera que se ve, desde arriba)].

Salida: assets/characters/baston/baston_caida.json (baston.gd, con en_caida).
Uso (desde el proyecto): python -I tools/anim/baston_caida.py [giro de pie] [bajo] [lado]
"""
import os, re, cv2, numpy as np, sys
S=os.path.join(os.environ.get('TEMP', '.'), '')   # las vistas (b_<anim>.png)
t=open('resources/characters/peregrino_frames.tres',encoding='utf-8').read()
ext=dict((i,p) for p,i in re.findall(r'path="res://([^"]+)" id="([^"]+)"',t))
sub={}
for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*atlas = ExtResource\("([^"]+)"\)\s*region = Rect2\(([^)]*)\)\s*margin = Rect2\(([^)]*)\)',t):
    sub[m.group(1)]=(ext[m.group(2)],[int(round(float(v))) for v in m.group(3).split(',')],[int(round(float(v))) for v in m.group(4).split(',')])
def frames(name):
    i=t.find('"name": &"%s"'%name); j=t.rfind('"frames": [',0,i)
    seg=t[j:i]
    sp=re.search(r'"speed": ([\d.]+)',t[i:i+200])
    return re.findall(r'SubResource\("([^"]+)"\)',seg), sp.group(1) if sp else None
cache={}
def img(sid):
    p,r,mg=sub[sid]
    if p not in cache: cache[p]=cv2.imread(p,-1)
    x,y,w,h=r; c=cache[p][y:y+h,x:x+w]
    W,H=w+mg[2],h+mg[3]
    o=np.zeros((H,W,4),np.uint8); o[mg[1]:mg[1]+h, mg[0]:mg[0]+w]=c
    return o
import re, cv2, numpy as np, json, math, sys
B=cv2.imread('assets/characters/baston/baston.png',-1)
print('baston',B.shape)
ROT=float(sys.argv[1]) if len(sys.argv)>1 else 0.5
BAJO=float(sys.argv[2]) if len(sys.argv)>2 else 45.0
LADO=float(sys.argv[3]) if len(sys.argv)>3 else 10.0
def anclas(p):
    a=p[...,3]>128
    rgb=p[...,:3].astype(int)
    mx=rgb.max(2); mn=rgb.min(2)
    gris=a&((mx-mn)<28)&(mx>110)   # capucha y barba (gris/blanco)
    ys,xs=np.nonzero(gris)
    # la capucha: lo gris mas alto
    top=ys.min(); sel=ys<top+40
    hx=xs[sel].mean()
    col=np.nonzero(a[:,int(hx)])[0]
    return hx, col.min()
def pegar(p, x, y, rot):
    H,W=p.shape[:2]; cx,cy=W/2,H/2
    h,w=B.shape[:2]
    # pivote a 40 px de la punta, en el eje
    M=cv2.getRotationMatrix2D((w/2,40),-math.degrees(rot),1.0)
    M[0,2]+=cx+x-w/2; M[1,2]+=cy+y-40
    capa=cv2.warpAffine(B,M,(W,H),flags=cv2.INTER_LINEAR,borderValue=(0,0,0,0))
    fondo=np.full((H,W,3),200,np.float32)
    a=capa[...,3:]/255.; out=capa[...,:3]*a+fondo*(1-a)
    b=p[...,3:]/255.; out=p[...,:3]*b+out*(1-b)
    return out.astype(np.uint8)
GOLPE=7          # el sprite de caida en que se estampa: antes, sin baston
def corte(p, x, y, rot):
    """Hasta donde se ve la madera por debajo del pivote sin salir de la silueta
    por abajo (fraccion de la textura, desde arriba)."""
    a=p[...,3]>100; H,W=a.shape; cx,cy=W/2,H/2
    d=(math.sin(rot), math.cos(rot))     # hacia abajo por el baston (giro horario)
    dentro=False; ultimo=0
    for L in range(0, 190):
        px=int(round(cx+x-d[0]*-L if False else cx+x-L*math.sin(-rot))); py=int(round(cy+y+L*math.cos(rot)))
        if 0<=px<W and 0<=py<H and a[py,px]:
            dentro=True; ultimo=L
        elif dentro:
            break
    return round(min((40+max(ultimo-14,0))/229.0,1.0),3)
datos={}
for n in ['caida','tumbado','levantarse']:
    fr,_=frames(n)
    filas=[]
    for s in fr:
        p=img(s); hx,ty=anclas(p)
        a=p[...,3]>128; ys=np.nonzero(a.any(1))[0]
        gris_top=ty
        # tumbado: lo alto del cuerpo (la joroba) muy por encima de la capucha
        rgb=p[...,:3].astype(int); g=a&((rgb.max(2)-rgb.min(2))<28)&(rgb.max(2)>110)
        xs=np.nonzero(a.any(0))[0]
        alto=ys.max()-ys.min(); ancho=xs.max()-xs.min()
        # tumbado (mas ancho que alto): apoyado en lo alto de la espalda (la
        # joroba de la tunica), la garra asomando por encima
        tumb=float(np.clip((0.62-alto/ancho)/0.2,0,1))
        H,W=p.shape[:2]
        jy=ys.min(); jx=np.nonzero(a[jy+3])[0].mean()
        de_pie=(hx+LADO, ty+BAJO)
        tumbado=(jx+18, jy+22)
        x=de_pie[0]*(1-tumb)+tumbado[0]*tumb; y=de_pie[1]*(1-tumb)+tumbado[1]*tumb
        rot=ROT*(1-tumb)+0.35*tumb
        filas.append([x-W/2, y-H/2, rot])
    arr=np.array(filas); k=5
    if len(arr)>k:
        pad=np.pad(arr,((k//2,k//2),(0,0)),mode='edge')
        arr=np.array([pad[i:i+k].mean(0) for i in range(len(arr))])
    rows=[]
    for i,(x,y,r) in enumerate(arr):
        c=corte(img(fr[i]),x,y,r)
        vis = 0 if (n!='caida' or i>=GOLPE) else -1
        rows.append([round(float(x),1),round(float(y),1),round(float(r),3),vis,c])
    datos[n]=rows
    sel=list(range(0,len(fr),max(1,len(fr)//7)))[:8]
    ims=[]
    for j in sel:
        x,y,r,v,c=rows[j]
        q=img(fr[j])
        if v<0:
            a=q[...,3:]/255.; ims.append((q[...,:3]*a+200*(1-a)).astype(np.uint8)); continue
        Bc=B.copy(); Bc[int(c*229):,:,3]=0
        globals()['B0']=B; globals()['B']=Bc
        ims.append(pegar(q,x,y,r)); globals()['B']=B0
    cv2.imwrite(S+'b_%s.png'%n, np.hstack(ims))
json.dump(datos,open('assets/characters/baston/baston_caida.json','w'))
print({k:len(v) for k,v in datos.items()}, datos['tumbado'])
