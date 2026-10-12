"""Capture cold starts on a dedicated disposable Android audit emulator.

Requires --device explicitly. Do not target the owner's daily device.
The tool uses installed bundled content offline and preserves screenshots.
"""
from pathlib import Path
import argparse
import json
import subprocess
import time

ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/'branding/validation'

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--adb',required=True)
    p.add_argument('--device',required=True)
    p.add_argument('--apk',type=Path,required=True)
    args=p.parse_args()
    OUTPUT.mkdir(parents=True,exist_ok=True)
    def adb(*cmd,**kwargs):
        return subprocess.run([args.adb,'-s',args.device,*cmd],check=True,**kwargs)
    adb('install','-r',str(args.apk),capture_output=True)
    # The explicit test device is a read-only AVD clone. No baseline data or
    # snapshot is overwritten; its transient user partition is discarded.
    adb('shell','cmd','connectivity','airplane-mode','enable')
    results=[]
    try:
        for mode in ['light','dark']:
            adb('shell','cmd','uimode','night','yes' if mode=='dark' else 'no')
            adb('shell','input','keyevent','KEYCODE_HOME')
            time.sleep(1)
            adb('shell','am','force-stop','by.mybrev.playtest2026')
            recording=subprocess.Popen([args.adb,'-s',args.device,'shell','screenrecord','--time-limit','8',f'/sdcard/brand-{mode}.mp4'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            time.sleep(.4)
            activity='by.mybrev.playtest2026/com.example.mybrev_flutter.MainActivity'
            launch=subprocess.Popen([args.adb,'-s',args.device,'shell','am','start','-n',activity],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
            started=time.monotonic()
            for index,offset in enumerate([.15,.4,.8,1.6,3.5]):
                time.sleep(max(0,offset-(time.monotonic()-started)))
                data=adb('exec-out','screencap','-p',capture_output=True).stdout
                (OUTPUT/f'android-{mode}-{index}.png').write_bytes(data)
            launch.wait(timeout=30)
            recording.wait(timeout=20)
            adb('pull',f'/sdcard/brand-{mode}.mp4',str(OUTPUT/f'android-{mode}.mp4'),capture_output=True)
            results.append({'theme':mode,'device':args.device,'frames':5,'recording':f'android-{mode}.mp4'})
        adb('shell','am','start','-a','android.settings.APPLICATION_DETAILS_SETTINGS','-d','package:by.mybrev.playtest2026',capture_output=True)
        time.sleep(1.5)
        (OUTPUT/'android-installed-icon.png').write_bytes(adb('exec-out','screencap','-p',capture_output=True).stdout)
        errors=adb('logcat','-d','-s','AndroidRuntime:E',capture_output=True,text=True).stdout
        (OUTPUT/'android-runtime.log').write_text(errors,encoding='utf-8')
        assert 'FATAL EXCEPTION' not in errors,errors
        (OUTPUT/'android-capture.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
        print('Captured two offline cold starts and installed launcher icon; no AndroidRuntime fatal error.')
    finally:
        adb('shell','cmd','uimode','night','auto')

if __name__=='__main__':main()
