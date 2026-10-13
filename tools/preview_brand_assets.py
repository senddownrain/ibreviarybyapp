"""Show real exported assets; simulate launcher cropping and system tint."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'branding/validation/export-preview.png'
f=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',22)
fb=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',30)
im=Image.new('RGB',(1200,620),'#F5F1E8');d=ImageDraw.Draw(im)
d.text((32,24),'Малітоўнік · выбранная иконка',fill='#292722',font=fb)
paths=[('AppIcon · 1024','branding/exports/app-icon-1024.png'),('Adaptive · маска ОС','android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png'),('Themed · системный тон','android/app/src/main/res/drawable-nodpi/ic_launcher_monochrome.png')]
for i,(label,p) in enumerate(paths):
    x=32+i*298
    icon=Image.open(ROOT/p).convert('RGBA')
    if i:
        # A 108 dp layer is shown through the central 72 dp launcher viewport.
        icon=icon.crop((72,72,360,360))
    icon=icon.resize((240,240),Image.Resampling.LANCZOS)
    if i==2:
        tint=Image.new('RGBA',icon.size,'#242522');tint.putalpha(icon.getchannel('A'));icon=tint
    im.paste(icon,(x,100),icon);d.text((x,354),label,fill='#292722',font=f)
for j,size in enumerate([60,48,32]):
    icon=Image.open(ROOT/'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png').convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
    im.paste(icon,(40+j*150,440),icon);d.text((40+j*150,525),f'{size} px',fill='#292722',font=f)
for y,t in [(440,'Непрозрачный фон iOS/PWA.'),(478,'Отдельные слои Android.'),(516,'В favicon 16/32 — оптическая микроверсия.')]:d.text((628,y),t,fill='#292722',font=f)
OUT.parent.mkdir(parents=True,exist_ok=True);im.save(OUT)
print(OUT)
