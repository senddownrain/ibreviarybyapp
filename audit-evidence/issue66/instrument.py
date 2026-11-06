import json, hashlib, re, sys
from pathlib import Path
base=Path('/workspace/issue66-diagnostics')
files=['test/content_offline_test.dart','lib/content/content_store.dart','lib/services/hive_service.dart']
roots=[Path('/workspace/ibreviarybyapp'),Path('/workspace/ibreviarybyapp-baseline')]
manifest=base/'instrumentation-backups.json'
if sys.argv[1]=='restore':
 for item in json.loads(manifest.read_text()):
  p=Path(item['path']);p.write_bytes(Path(item['backup']).read_bytes())
  assert hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256']
 print('Restored all original bytes')
 sys.exit()
def closing(s,start,op,cl):
 depth=0;i=start
 while i<len(s):
  if s.startswith('//',i):
   j=s.find('\n',i);i=len(s) if j<0 else j+1;continue
  if s.startswith('/*',i):
   i=s.index('*/',i+2)+2;continue
  if s[i] in "'\"":
   quote=s[i]*3 if s.startswith(s[i]*3,i) else s[i];i+=len(quote)
   while i<len(s) and not s.startswith(quote,i):
    i+=2 if s[i]=='\\' else 1
   i+=len(quote);continue
  if s[i]==op:depth+=1
  if s[i]==cl:
   depth-=1
   if depth==0:return i
  i+=1
 raise ValueError('unbalanced')
def wrap(s,anchor,label,kind):
 a=s.index(anchor)+len(anchor)-1;assert s[a]=='{';b=closing(s,a,'{','}')
 return s[:a+1]+f"\nreturn Issue66Probe.{kind}('{label}', () "+('async ' if kind=='future' else '')+'{'+s[a+1:b]+'\n});\n'+s[b:]
def awaits(s,variables):
 pattern=r'await ('+'|'.join(re.escape(v) for v in variables)+r')\.(putAll|put|flush|clear|deleteAll)\('
 for m in reversed(list(re.finditer(pattern,s))):
  a=m.end()-1;b=closing(s,a,'(',')')
  call=s[m.start()+6:b+1]
  label='hive.'+m[1].replace('!','')+'.'+m[2]
  s=s[:m.start()]+f"await Issue66Probe.future('{label}', () => {call})"+s[b+1:]
 return s
entries=[]
for n,root in enumerate(roots):
 for f in files:
  p=root/f;data=p.read_bytes();backup=base/f'original-{n}-{p.name}';backup.write_bytes(data)
  entries.append({'path':str(p),'backup':str(backup),'sha256':hashlib.sha256(data).hexdigest()})
manifest.write_text(json.dumps(entries,indent=2)+'\n')
for root in roots:
 for f in files:
  p=root/f;s=p.read_text();s="import 'file:///workspace/issue66-diagnostics/probe.dart';\n"+s
  if f.startswith('test/'):
   old='''  Map<String, String> _hashes(String name) => {
    for (final entry in collections[name]!.entries)
      entry.key: documentHash(entry.value),
  };'''
   new='''  Map<String, String> _hashes(String name) => Issue66Probe.sync('fake.hashes.$name', () => {
    for (final entry in collections[name]!.entries)
      entry.key: documentHash(entry.value),
  }, units: collections[name]!.length);'''
   assert old in s;s=s.replace(old,new)
   s=wrap(s,'Future<Map<String, dynamic>?> fetchCurrent() async {','fake.currentManifest','sync')
   s=wrap(s,'Future<Map<String, dynamic>?> fetchCollectionManifest(String name) async {','fake.collectionManifest.$name','sync')
   s=wrap(s,'Map<String, Map<String, dynamic>> bundled(String name) {','test.copyCollection.$name','sync')
   s=s.replace("    await HiveService.init(path: directory.path, loadBundle: true);", "    await Issue66Probe.future('bundle.init', () => HiveService.init(path: directory.path, loadBundle: true));")
   s=s.replace('    await ContentStore.instance.ensureLoaded(kContentCollections);',"    await Issue66Probe.future('bundle.ensureAll', () => ContentStore.instance.ensureLoaded(kContentCollections));")
   s=s.replace('  setUp(() async {\n    directory', '  setUp(() async {\n    Issue66Probe.begin();\n    directory',1)
   old='''  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });'''
   new='''  tearDown(() async {
    Issue66Probe.snapshot('teardown.begin');
    await Issue66Probe.future('teardown.hiveClose', Hive.close);
    Issue66Probe.snapshot('teardown.hiveClosed');
    await Issue66Probe.future('teardown.delete', () => directory.delete(recursive: true));
    Issue66Probe.finish();
  });'''
   assert old in s;s=s.replace(old,new)
   old='return updater.check().then((result) => updater.apply(result.plan!));'
   new="""return Issue66Probe.future('test.publish.$version', () async {
        final result = await Issue66Probe.future('updater.check.$version', updater.check);
        await Issue66Probe.future('updater.apply.$version', () => updater.apply(result.plan!));
      });"""
   assert old in s;s=s.replace(old,new)
   s=s.replace("      await days.debugReplaceBaseline(docs, {\n        for (final e in docs.entries) e.key: documentHash(e.value),\n      }, 102);", """      final replacementHashes = Issue66Probe.sync('test.replacementHashes', () => {
        for (final e in docs.entries) e.key: documentHash(e.value),
      }, units: docs.length);
      await Issue66Probe.future('store.replaceBaseline', () => days.debugReplaceBaseline(docs, replacementHashes, 102));""")
  elif f.endswith('content_store.dart'):
   s=s.replace('    return run;','    return Issue66Probe.future(\'store.commit.$version\', () => run);',1)
   s=wrap(s,'Future<void> _load(ContentCollection item) async {','bundle.load.${item.name}','future')
   s=s.replace("final data = await bundle.load('$kContentAssetDir/${item.name}.json.gz');", "final data = await Issue66Probe.future('bundle.read.${item.name}', () => bundle.load('$kContentAssetDir/${item.name}.json.gz'));")
   s=s.replace('final decoded = await compute(decodeContentCollection, bytes);',"final decoded = await Issue66Probe.future('bundle.decode.${item.name}', () => compute(decodeContentCollection, bytes));")
   s=awaits(s,['staging','overlay','_overlay!'])
  else:
   s=awaits(s,['settings'])
  p.write_text(s)
print('Instrumented both trees; originals recorded in',manifest)
