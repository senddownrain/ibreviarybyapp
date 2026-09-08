/* A local interaction model. No Firebase, Flutter imports, analytics or network writes. */
(() => {
  'use strict';
  const M=UXModel, F=UX_FIXTURES, R=UXRefinement, $=(s,r=document)=>r.querySelector(s);
  const E=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const paths={
    clock:'<circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 2"/>',
    book:'<path d="M3 4h5a5 5 0 0 1 4 2 5 5 0 0 1 4-2h5v15h-5a5 5 0 0 0-4 2 5 5 0 0 0-4-2H3zM12 6v15"/>',
    prayers:'<path d="M6 3h12v18H6a3 3 0 0 1 0-6h12M6 3a3 3 0 0 0-3 3v12M12 6v6M9 9h6"/>',
    bible:'<path d="M6 3h13v18H6a3 3 0 0 1 0-6h13M6 3a3 3 0 0 0-3 3v12M12 6v6M9 9h6"/>',
    sun:'<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5"/>',
    sunrise:'<path d="M3 19h18M5 15a7 7 0 0 1 14 0M12 2v5M3 7l2 2m14 0 2-2M9 5l3-3 3 3"/>',
    sunset:'<path d="M3 19h18M5 15a7 7 0 0 1 14 0M12 2v5M3 7l2 2m14 0 2-2M9 4l3 3 3-3"/>',
    moon:'<path d="M20 15A9 9 0 0 1 9 3a9 9 0 1 0 11 12Z"/>',
    heart:'<path d="M12 20 3.5 12a5.2 5.2 0 0 1 8.5-6 5.2 5.2 0 0 1 8.5 6Z"/>',
    search:'<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/>',
    menu:'<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>',
    back:'<path d="m14 5-7 7 7 7"/>', arrow:'<path d="m10 5-7 7 7 7M3 12h18"/>',
    chevron:'<path d="m9 5 7 7-7 7"/>',down:'<path d="m6 9 6 6 6-6"/>',
    close:'<path d="m6 6 12 12M18 6 6 18"/>',check:'<path d="m5 12 4 4L19 6"/>',
    calendar:'<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 3v4m10-4v4M3 10h18m-13 5h2m4 0h2"/>',
    options:'<path d="M4 6h16M4 12h16M4 18h16"/><circle cx="9" cy="6" r="2"/><circle cx="15" cy="12" r="2"/><circle cx="9" cy="18" r="2"/>',
    folder:'<path d="M3 7V5h7l2 3h9v12H3z"/>',
    expand:'<path d="M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5"/>',
    grid:'<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
    wifi:'<path d="M3 8a15 15 0 0 1 18 0M6 12a10 10 0 0 1 12 0M9 16a5 5 0 0 1 6 0"/><circle cx="12" cy="20" r=".5"/>',
    battery:'<rect x="2" y="6" width="17" height="12" rx="3"/><path d="M22 10v4M5 9h11v6H5z"/>',
    sync:'<path d="M3 10a9 9 0 0 1 15-5l3 3M21 3v5h-5M21 14A9 9 0 0 1 6 19l-3-3M3 21v-5h5"/>',
    info:'<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7h.01"/>'
  };
  const icon=(name)=>`<svg viewBox="0 0 24 24" aria-hidden="true">${paths[name]||paths.book}</svg>`;
  const button=(action,label,ic,cls='text-action',extra='')=>`<button type="button" class="${cls}" data-action="${E(action)}" ${extra}>${ic?icon(ic):''}${label}</button>`;
  const round=(action,label,ic)=>button(action,'',ic,'round chrome',`aria-label="${E(label)}" title="${E(label)}"`);
  const strip=s=>String(s||'').replace(/<[^>]+>/g,' ').replace(/\s+/g,' ').trim();
  const cleanCache=new Map();
  function clean(html) {
    if(cleanCache.has(html)) return cleanCache.get(html);
    const doc=new DOMParser().parseFromString(String(html||''),'text/html');
    for(const el of [...doc.body.querySelectorAll('*')]) {
      if(!['P','BR','SPAN','EM','STRONG','B','I','HR','SUP'].includes(el.tagName)) {el.remove();continue;}
      const rubric=/color\s*:/i.test(el.getAttribute('style')||'');
      for(const a of [...el.attributes])el.removeAttribute(a.name);
      if(rubric)el.className='rubric';
    }
    const out=doc.body.innerHTML;cleanCache.set(html,out);return out;
  }
  const prayers=[
    {id:'magnificat',title:'Велічае душа мая Пана',sub:'Magnificat',category:'canticles',html:F.constants.Magnificat},
    {id:'benedictus',title:'Благаслаўлёны Пан',sub:'Benedictus',category:'canticles',html:F.constants.Benedictus},
    {id:'night',title:'На спакойную ноч',sub:'Благаслаўленне перад сном',category:'daily',html:F.constants.EndOfComplineBlessing},
    {id:'glory',title:'Хвала Айцу і Сыну',sub:'Пачатак малітвы',category:'daily',html:F.constants.StandardIntro},
    {id:'mary',title:'На Нараджэнне Панны Марыі',sub:'Літургічная малітва',category:'liturgical',html:F.feasts.mary.laudesPr||F.feasts.mary.officeOfReadingsPr},
    {id:'peter',title:'Малітва праз заступніцтва св. Пятра Клявэра',sub:'Літургічная малітва',category:'liturgical',html:F.feasts.peter.officeOfReadingsPr}
  ];
  const tabs=[['hours','Гадзіны','clock'],['readings','Чытанні','book'],['prayers','Малітоўнік','prayers'],['bible','Біблія','bible']];
  const categoryNames={all:'Усе малітвы',favorites:'Абраныя',canticles:'Евангельскія песні',daily:'Штодзённыя',liturgical:'Літургічныя малітвы',morning:'Ранішняя малітва'};
  const app={theme:'light',scale:1,devices:{}};
  function dateLabel(date) {const [year,month,day]=date.split('-').map(Number);const months=['студзеня','лютага','сакавіка','красавіка','мая','чэрвеня','ліпеня','жніўня','верасня','кастрычніка','лістапада','снежня'];return `${day} ${months[month-1]} ${year}`;}
  function dateBar(s,branch) {const date=s[branch].date;return `<div class="date-row">${button('date:'+branch,(date===M.TODAY?'Сёння · ':'')+E(dateLabel(date)),'down','date-button')}${date!==M.TODAY?button('today:'+branch,'Сёння',null,'today'):''}</div>`;}
  function row(action,title,sub,ic='chevron',extra='') {return button(action,`<span class="row-text"><strong>${E(title)}</strong>${sub?`<small>${E(sub)}</small>`:''}</span>${icon(ic)}`,null,'list-row',extra);}
  function source(text='Узор тэксту з рэпазіторыя. Набор і прывязка да даты — дэманстрацыйныя.') {return `<p class="source-note">${E(text)}</p>`;}
  function celebration(s) {return (M.CALENDAR[s.hours.date]||[])[s.hours.choice];}
  function hours(s) {
    const c=celebration(s),opts=M.CALENDAR[s.hours.date]||[];
    if(s.hours.ora)return ora(s);
    return `<div class="page"><h1>Гадзіны</h1>${dateBar(s,'hours')}${!c||s.mode==='empty-day'?empty('Няма варыянтаў на гэтую дату','Для гэтай даты няма даступнага набору. Параметры літургічнага года ў прыкладзе — 2026. Выберыце іншую дату.','date:hours','Выбраць дату','calendar'):`<section class="celebration ${c.color}"><span class="rank">${E(c.rank)}</span><h2>${E(c.title)}</h2><p>${s.hours.choice===0?'Асноўны варыянт дня':'Выбраны іншы варыянт'}</p></section>${opts.length>1?button('celebrations',`Іншыя літургічныя варыянты · ${opts.length-1}`,'options'):''}<div class="hours-heading"><h2>Літургія гадзінаў</h2></div>${M.HOURS.map(([id,title,sub,ic])=>button('hour:'+id,`<span class="hour-icon">${icon(ic)}</span><span class="row-text"><strong>${E(title)}</strong><small>${E(sub)}</small></span>${icon('chevron')}`,null,'list-row'+(id==='laudes'?' recommended':''))).join('')}`}</div>`;
  }
  function ora(s) {
    const c=celebration(s),hour=M.HOURS.find(h=>h[0]===s.hours.ora),h=s.hours.ora;
    const feast=F.feasts[c?.id==='peter'&&s.hours.template==='works-of-mercy'?'peterMercy':c?.id];
    const prefix={office:'officeOfReadings',laudes:'laudes',terce:'sext1',sext:'sext2',none:'sext3',vespers:'vesper2',compline:'completorium'}[h];
    let body=`<h2>${h==='invit'?'Заклік':'Уступ'}</h2>${clean(h==='invit'?F.constants.InvitIntro:F.constants.StandardIntro)}`;
    if(h==='invit'&&feast?.invitatoriumAnt)body+=`<h2>Антыфона</h2>${clean(feast.invitatoriumAnt)}`;
    if(feast&&prefix) {
      const blocks=[['Hymn','Гімн'],['R1','Першае чытанне'],['R2','Другое чытанне'],['R','Кароткае чытанне']];
      for(const [suffix,label] of blocks)if(feast[prefix+suffix])body+=`<h2>${label}</h2>${clean(feast[prefix+suffix])}`;
    }
    if(h==='laudes')body+=`<h2>Евангельская песня · Benedictus</h2>${clean(F.constants.Benedictus)}`;
    if(h==='vespers')body+=`<h2>Евангельская песня · Magnificat</h2>${clean(F.constants.Magnificat)}`;
    if(h==='compline')body+=`<h2>Благаслаўленне</h2>${clean(F.constants.EndOfComplineBlessing)}`;
    if(feast?.[prefix+'Pr'])body+=`<h2>Малітва</h2>${clean(feast[prefix+'Pr'])}`;
    if(['terce','sext','none'].includes(h))body+=`<h2>Заканчэнне</h2>${clean(F.constants.EndOfSext)}`;
    return `<div class="reader-context">${dateBar(s,'hours')}<p>${E(c?.title)}</p><h1>${button('change-hour',E(hour[1]),'down','hour-title')}</h1><div class="context-link">${button('ora-readings','Чытанні','book')}</div></div><article class="reader" aria-label="Тэкст Ora">${body}${source('Скарочаны ўзор Ora: агульныя часткі з Flutter і ўласныя тэксты з MyBrev. Гэта не поўны сабраны афіцый.')}<div class="end-mark" aria-hidden="true">· · ·</div></article>`;
  }
  function readingSelection(s) { const groups=M.readingGroups(s.readings.date),group=groups[s.readings.group];return {groups,group,cycle:s.readings.cycle}; }
  function readingText(s) {
    const {group,cycle}=readingSelection(s);if(!group)return '';
    let ref={book:'mt',chapter:1,start:18,end:23,label:'Мц 1, 18–23'};
    if(group.id==='ordinary')ref={book:'lk',chapter:6,start:cycle==='1'?12:20,end:cycle==='1'?19:26,label:cycle==='1'?'Лк 6, 12–19':'Лк 6, 20–26'};
    if(group.id==='ordinary'&&s.readings.date!==M.TODAY)ref={book:'lk',chapter:6,start:cycle==='1'?20:27,end:cycle==='1'?26:36,label:cycle==='1'?'Лк 6, 20–26':'Лк 6, 27–36'};
    if(group.id==='peter')ref={book:'mt',chapter:25,start:31,end:40,label:'Мц 25, 31–40'};
    if(group.id==='sunday')ref=cycle==='A'?{book:'mt',chapter:18,start:21,end:35,label:'Мц 18, 21–35'}:cycle==='B'?{book:'mk',chapter:8,start:27,end:35,label:'Мк 8, 27–35'}:{book:'lk',chapter:15,start:1,end:7,label:'Лк 15, 1–7'};
    const book=F.bible.bel.find(b=>b.id===ref.book),verses=book?.chapters[ref.chapter-1]?.filter(v=>v.num>=ref.start&&v.num<=ref.end)||[];
    return `<h2>Евангелле · ${ref.label}</h2><p class="rubric">${E(book?.name||'Тэкст не ўключаны ў прыклад')}</p>${verses.map(v=>`<p><span class="verse">${v.num}</span>${E(v.text)}</p>`).join('')}${source('Дэманстрацыйны набор чытанняў: паказаны евангельскі ўрывак з bible_seed_bel. Поўны набор Імшы і каляндарны resolver не падключаныя.')}`;
  }
  function readings(s) {
    const {group,groups,cycle}=readingSelection(s);
    return `<div class="reader-context">${dateBar(s,'readings')}<h1>Чытанні</h1>${group?`<p>${E(group.title)}${cycle?' · '+(cycle==='1'?'I':cycle==='2'?'II':cycle):''}</p>${s.readings.manual?`<p class="manual">Абрана ўручную</p>${button('readings-auto','Вярнуцца да аўтаматычнага выбару',null)}`:''}${groups.length>1||group.cycles.length>1?button('reading-options','Варыянты чытанняў','options'):''}`:''}</div>${group?`<article class="reader" aria-label="Тэкст чытанняў">${readingText(s)}<div class="end-mark" aria-hidden="true">· · ·</div></article>`:`<div class="page">${empty('Няма чытанняў на гэтую дату','У гэтым прыкладзе ёсць наборы на 8, 9 і 13 верасня.','date:readings','Выбраць дату','book')}</div>`}`;
  }
  function prayerRow(s,p) {return `<div class="favorite-row">${row('prayer:'+p.id,p.title,p.sub)}${button('favorite:'+p.id,'','heart','plain',`aria-label="${s.favorites.includes(p.id)?'Прыбраць з Абраных':'Дадаць у Абраныя'}: ${E(p.title)}" aria-pressed="${s.favorites.includes(p.id)}"`)}</div>`;}
  function filteredPrayers(s) {
    return R.filteredPrayers(s);
    /* Legacy fixture-only category filter retained below for source comparison.
    const p=s.prayers,q=p.query.toLocaleLowerCase('be');
    return prayers.filter(x=>(p.filter==='all'||(p.filter==='favorites'?s.favorites.includes(x.id):x.category===p.filter))&&(!p.collection||p.collection==='morning'?(!p.collection||['glory','benedictus'].includes(x.id)):x.category===p.collection)&&(!q||(x.title+' '+x.sub+' '+strip(x.html)).toLocaleLowerCase('be').includes(q)));
    */
  }
  function prayerPage(s) {
    const refined=R.prayerRoot(s);if(refined!==null)return refined;
    const p=s.prayers;
    if(p.detail) {const prayer=prayers.find(x=>x.id===p.detail);return `<div class="reader-context"><p>${E(categoryNames[p.collection]||'Малітоўнік')}</p><h1>${E(prayer.title)}</h1><p>${E(prayer.sub)}</p></div><article class="reader" aria-label="Тэкст малітвы">${clean(prayer.html)}${source('Тэкст з рэпазіторыя праекта. Дадаванне ў Абраныя змяняе толькі лакальны прататып.')}<div class="end-mark" aria-hidden="true">· · ·</div></article>`;}
    if(p.page!=='home') {const list=filteredPrayers(s);return `<div class="page"><h1>${E(categoryNames[p.collection]||'Усе малітвы')}</h1>${button('search-prayers','Пошук і фільтры','search')}${list.length?list.map(x=>prayerRow(s,x)).join(''):empty('Малітваў не знойдзена','Змяніце запыт або фільтр.','clear-prayer-filter','Скінуць фільтры','search')}</div>`;}
    const favorites=s.favorites.map(id=>prayers.find(p=>p.id===id)).filter(Boolean);
    return `<div class="page"><h1>Малітоўнік</h1><div class="section-heading"><h2>Абраныя</h2><span class="count">${favorites.length}</span></div>${favorites.length?favorites.map(p=>prayerRow(s,p)).join(''):empty('Тут будуць вашы малітвы','Націсніце сэрца каля малітвы, каб дадаць яе ў Абраныя.','all-prayers','Знайсці малітву','heart')}<div class="section-heading"><h2>Мае зборнікі</h2></div><div class="collection-group">${row('collection:morning','Ранішняя малітва','Дэманстрацыйны зборнік','folder')}</div><div class="section-heading"><h2>Малітвы і зборнікі</h2></div>${row('all-prayers','Усе малітвы','Пошук, катэгорыі і Абраныя')}${['canticles','daily','liturgical'].map(k=>row('collection:'+k,categoryNames[k],'Дэманстрацыйная катэгорыя','folder')).join('')}<p class="muted">Абраныя і зборнікі — прыклад, не вашы асабістыя даныя.</p></div>`;
  }
  function bible(s) {
    const b=s.bible,book=F.bible[b.translation].find(x=>x.id===b.book),chapter=book.chapters[b.chapter-1]||[];
    return `<div class="reader-context"><p>Біблія · ${b.translation==='bel'?'Беларускі пераклад':'Русский перевод'}</p>${button('bible-picker',`${E(book.name)} · ${b.chapter}`,'down','date-button')}<p>Раздзел ${b.chapter}</p></div><article class="reader" aria-label="Раздзел Бібліі">${chapter.map(v=>`<p id="${b.book}-${v.num}" class="${b.marks.includes(`${b.translation}:${b.book}:${b.chapter}:${v.num}`)?'marked':''}">${button('mark:'+v.num,String(v.num),null,'verse-button',`aria-label="Пазначыць верш ${v.num}" aria-pressed="${b.marks.includes(`${b.translation}:${b.book}:${b.chapter}:${v.num}`)}"`)}${E(v.text)}</p>`).join('')}<div class="chapter-navigation">${button('chapter-prev','Папярэдні','back','text-action',b.chapter===1?'disabled':'')}${button('chapter-next','Наступны','chevron','text-action',b.chapter===book.chapters.length?'disabled':'')}</div>${source('Поўны раздзел з bible_seed. У прататыпе даступныя Мц, Мк, Лк, Ян, Пс і Рым у двух перакладах. Націск на нумар верша пазначае яго.')}<div class="end-mark" aria-hidden="true">· · ·</div></article>`;
  }
  function empty(title,text,action,label,ic='info') {return `<section class="empty-state">${icon(ic)}<h2>${E(title)}</h2><p>${E(text)}</p>${action?button(action,E(label),null,'primary-button'):''}</section>`;}
  function content(s) {
    if(s.mode==='loading')return `<div class="page" role="status"><h1>Адкрываем тэксты</h1><p class="muted">Загрузка з лакальнай бібліятэкі…</p><div class="loading"></div><div class="loading"></div><div class="loading"></div>${button('ready','Завяршыць загрузку',null,'text-action')}</div>`;
    if(s.mode==='missing')return `<div class="page">${['hours','readings'].includes(s.tab)?dateBar(s,s.tab):''}${empty('Тэкст яшчэ не спампаваны','Гэтага тэксту няма ў лакальнай бібліятэцы. Спампуйце яго, калі будзе злучэнне.','sync','Адкрыць сінхранізацыю','book')}${button('ready','Паказаць даступны ўзор',null)}</div>`;
    return {hours,readings,prayers:prayerPage,bible:R.bible}[s.tab](s);
  }
  function isReader(s) {return s.tab==='readings'||s.tab==='bible'||(s.tab==='hours'&&s.hours.ora)||(s.tab==='prayers'&&s.prayers.detail);}
  function topbar(d) {
    const s=d.state,reader=isReader(s),label=tabs.find(x=>x[0]===s.tab)[1];
    let back=s.tab==='hours'&&s.hours.ora||s.tab==='prayers'&&(s.prayers.detail||s.prayers.page!=='home')||s.tab==='readings'&&s.readings.returnTo;
    return `<header class="topbar">${back?round('back',s.tab==='readings'?'Назад да Ora':'Назад',d.id==='ios'?'back':'arrow'):round('menu','Меню','menu')}<span class="chrome-spacer">${back&&s.tab==='readings'?'Да Ora':''}</span><div class="actions">${s.tab==='prayers'&&!s.prayers.detail?round('search-prayers','Пошук малітваў','search'):''}${s.tab==='bible'?round('search-bible','Пошук у Бібліі','search'):''}${s.tab==='prayers'&&s.prayers.detail?button('favorite:'+s.prayers.detail,'','heart','round chrome',`aria-label="Абраныя" aria-pressed="${s.favorites.includes(s.prayers.detail)}"`):''}${reader?button('appearance','Aa',null,'round chrome','aria-label="Памер тэксту"'):''}${reader&&back?round('reader-menu','Дзеянні чытання','menu'):''}</div></header>`;
  }
  function navigation(d) {
    const s=d.state;
    if(s.compact)return `<footer class="nav-wrap"><div class="compact-tabs chrome">${button('expand-tabs',tabs.find(x=>x[0]===s.tab)[1],tabs.find(x=>x[0]===s.tab)[2],'plain')}${round('expand-tabs','Паказаць усе раздзелы','grid')}</div></footer>`;
    return `<footer class="nav-wrap"><nav class="tabs chrome" role="tablist" aria-label="Асноўныя раздзелы">${tabs.map(([id,label,ic])=>button('tab:'+id,`<span class="tab-icon">${icon(ic)}</span><span>${label}</span>`,null,'',`role="tab" aria-selected="${s.tab===id}" aria-controls="${d.id}-content"`)).join('')}</nav></footer>`;
  }
  function render(d) {
    R.beforeRender(d);
    const s=d.state;d.key=M.key(s);
    d.el.className=`phone ${d.id} ${app.theme==='dark'?'dark':''} ${app.scale>=1.6?'large-text':''} ${s.focus?'focus-mode':''} ${s.reduceEffects?'reduce-effects':''}`;
    d.el.style.setProperty('--ui-scale',app.scale);d.el.style.setProperty('--reader-scale',s.readerScale);
    R.applyAtmosphere(d);
    d.el.innerHTML=`${s.focus?button('exit-focus','Вярнуць кіраванне','expand','focus-exit'):`<div class="status-bar" aria-hidden="true"><span>${d.id==='ios'?'9:41':'09:41'}</span><span class="status-icons">${icon('wifi')}${icon('battery')}</span></div>${topbar(d)}`}<div class="content" id="${d.id}-content" role="tabpanel" aria-label="${tabs.find(x=>x[0]===s.tab)[1]}">${content(s)}</div>${s.focus?'':R.highlightDock(d)||navigation(d)}<div class="modal-root"></div><div class="announcement" aria-live="polite"></div>`;
    const viewport=$('.content',d.el);viewport.scrollTop=s.scroll[d.key]||0;
    viewport.addEventListener('scroll',()=>{s.scroll[d.key]=viewport.scrollTop;if(s.tab==='readings'&&viewport.scrollTop>180&&!s.readings.started&&!d.modal&&!String(window.getSelection())&&s.nav==='auto'&&app.navigation==='auto'){s.readings.started=true;s.compact=true;const dock=$('.nav-wrap',d.el);if(dock)dock.outerHTML=navigation(d);d.el.dataset.navigation='compact';}save(d);},{passive:true});
    if(d.modal)renderModal(d);save(d);
  }
  function save(d) {try{localStorage.setItem('ibreviary-ux-prototype-v1:'+d.id,JSON.stringify(d.state));}catch{/* Storage is optional, including file:// privacy modes. */}}
  function openModal(d,name,trigger) {d.modal=name;d.trigger=trigger||document.activeElement?.dataset?.action;d.modalQuery='';d.modalBook=d.state.bible.book;renderModal(d);}
  function closeModal(d) {
    d.modal=null;$('.modal-root',d.el).innerHTML='';
    for(const el of d.el.children)el.inert=false;
    const target=[...d.el.querySelectorAll('[data-action]')].find(x=>x.dataset.action===d.trigger);target?.focus();
  }
  function searchPrayerResults(d) {const list=filteredPrayers(d.state);return list.length?list.map(p=>row('search-prayer:'+p.id,p.title,p.sub)).join(''):empty('Нічога не знойдзена','Паспрабуйце іншы запыт або змяніце фільтр.','clear-prayer-search','Ачысціць пошук','search');}
  function bibleSearchResults(d) {
    const s=d.state,b=s.bible,q=(d.modalQuery||'').toLocaleLowerCase(),books=F.bible[b.translation];
    if(!q)return `<p class="muted">${d.searchScope==='text'?'Пошук тэксту ва ўсіх раздзелах бягучай кнігі.':'Знайдзіце кнігу па назве.'}</p>`;
    if(d.searchScope!=='text') {const found=books.filter(x=>x.name.toLocaleLowerCase().includes(q));return found.length?found.map(x=>row('search-book:'+x.id,x.name,`${x.chapters.length} раздзелаў`)).join(''):empty('Кніг не знойдзена','Удакладніце назву кнігі або змяніце пераклад.',null,null,'search');}
    const book=books.find(x=>x.id===b.book),matches=[];
    book.chapters.forEach((c,ci)=>c.forEach(v=>{if(v.text.toLocaleLowerCase().includes(q))matches.push({chapter:ci+1,verse:v.num,text:v.text});}));
    return matches.length?`<p class="muted">Знойдзена: ${matches.length}${matches.length>80?' · паказаныя першыя 80, удакладніце запыт':''}</p>${matches.slice(0,80).map(x=>row(`search-verse:${x.chapter}:${x.verse}`,`${x.chapter}:${x.verse}`,x.text)).join('')}`:empty('Нічога не знойдзена','У бягучай кнізе няма такога тэксту.',null,null,'search');
  }
  function modalContents(d) {
    const refined=R.modal(d);if(refined)return refined;
    const s=d.state,name=d.modal;
    if(name.startsWith('date:')) {const branch=name.split(':')[1];return ['Дата',`${row('today:'+branch,'Сёння',dateLabel(M.TODAY),'sun')}${row('day-prev:'+branch,'Папярэдні дзень',dateLabel(M.plusDate(s[branch].date,-1)),'back')}${row('day-next:'+branch,'Наступны дзень',dateLabel(M.plusDate(s[branch].date,1)),'chevron')}${row('calendar:'+branch,'Выбраць дату','Каляндар','calendar')}${row('liturgical:'+branch,'Знайсці літургічны дзень / свята','Перыяд або назва свята','search')}`];}
    if(name.startsWith('calendar:')) {const branch=name.split(':')[1];return ['Выбраць дату',`<label for="${d.id}-date">Дата</label><input id="${d.id}-date" type="date" value="${s[branch].date}" data-input="date-value"><p class="muted">Узор календара: 8, 9 і 13 верасня 2026. Для астатніх дат паказваецца адсутнасць набору.</p>${button('apply-date:'+branch,'Адкрыць дату',null,'primary-button')}${row('liturgical:'+branch,'Знайсці літургічны дзень / свята','','search')}`];}
    if(name.startsWith('liturgical:')) return ['Літургічны каляндар',`<label for="${d.id}-liturgical">Дзень / свята</label><input id="${d.id}-liturgical" data-input="liturgical-query" type="search" placeholder="Назва дня або свята" autofocus><div class="chips">${button('period:all','Усе',null,'chip active')}${button('period:ordinary','Звычайны час',null,'chip')}${button('period:feasts','Святы',null,'chip')}</div><div data-results="liturgical">${liturgicalResults(d)}</div>`];
    if(name==='celebrations') return ['Літургічныя варыянты',(M.CALENDAR[s.hours.date]||[]).map((c,i)=>row('celebration:'+i,c.title,i===0?'Асноўны · першы пасля сартавання':c.rank,i===s.hours.choice?'check':'chevron',`${c.disabled?'disabled':''} ${i===s.hours.choice?'aria-current="true"':''}`)).join('')];
    if(name==='reading-options') {
      const {groups,group}=readingSelection(s);
      return ['Варыянты чытанняў',`${groups.map((g,i)=>row('reading-group:'+i,g.title,i===0?'Аўтаматычны набор':'Іншае святкаванне',s.readings.group===i?'check':'chevron')).join('')}${group?.cycles.length>1?`<label>Даступныя цыклы</label><div class="chips">${group.cycles.map(c=>button('reading-cycle:'+c,c==='1'?'I':c==='2'?'II':c,null,'chip'+(c===s.readings.cycle?' active':''),`aria-pressed="${c===s.readings.cycle}"`)).join('')}</div>`:''}${button('readings-auto','Аўтаматычны выбар','sync')}<p class="muted">Наборы тут дэманстрацыйныя. Пераход з Ora перадае дату; святкаванне Ora не вызначае набор чытанняў.</p>`];
    }
    if(name==='search-prayers') return ['Пошук малітваў',`<label for="${d.id}-prayer-query">Назва або тэкст малітвы</label><input id="${d.id}-prayer-query" data-input="prayer-query" type="search" value="${E(s.prayers.query)}" placeholder="Знайсці малітву" autofocus><label for="${d.id}-prayer-filter">Фільтр${s.prayers.collection?' · '+E(categoryNames[s.prayers.collection]):''}</label><select id="${d.id}-prayer-filter" data-input="prayer-filter">${['all','favorites','canticles','daily','liturgical'].map(x=>`<option value="${x}" ${s.prayers.filter===x?'selected':''}>${categoryNames[x]}</option>`).join('')}</select><div data-results="prayers">${searchPrayerResults(d)}</div>`];
    if(name==='bible-picker') {const books=F.bible[s.bible.translation],book=books.find(b=>b.id===d.modalBook)||books[0];return ['Кніга і раздзел',`<label for="${d.id}-translation">Пераклад</label><select id="${d.id}-translation" data-input="translation"><option value="bel" ${s.bible.translation==='bel'?'selected':''}>Беларускі · bible_seed_bel</option><option value="ru" ${s.bible.translation==='ru'?'selected':''}>Русский · bible_seed_ru</option></select><label for="${d.id}-book">Кніга</label><select id="${d.id}-book" data-input="book">${books.map(b=>`<option value="${b.id}" ${b.id===book.id?'selected':''}>${E(b.name)}</option>`).join('')}</select><label>Раздзел</label><div class="chapter-grid">${book.chapters.map((_,i)=>button('pick-chapter:'+i,String(i+1),null,s.bible.book===book.id&&s.bible.chapter===i+1?'active':'',`aria-label="Раздзел ${i+1}"`)).join('')}</div><p class="muted">Поўны корпус абранага перакладу, усе раздзелы.</p>`];}
    if(name==='search-bible')return ['Пошук у Бібліі',`<div class="chips">${button('bible-scope:books','Назвы кніг',null,'chip'+(d.searchScope!=='text'?' active':''))}${button('bible-scope:text','Тэкст бягучай кнігі',null,'chip'+(d.searchScope==='text'?' active':''))}</div><label for="${d.id}-bible-query">${d.searchScope==='text'?E(F.bible[s.bible.translation].find(b=>b.id===s.bible.book).name):'Назва кнігі'}</label><input id="${d.id}-bible-query" data-input="bible-query" type="search" value="${E(d.modalQuery)}" placeholder="Пошук" autofocus><div data-results="bible">${bibleSearchResults(d)}</div>`];
    if(name==='appearance')return ['Выгляд тэксту',`<label for="${d.id}-reader-size">Памер тэксту: ${Math.round(s.readerScale*100)}%</label><input id="${d.id}-reader-size" type="range" min="0.85" max="1.6" step="0.05" value="${s.readerScale}" data-input="reader-size">${row('reduce-effects',s.reduceEffects?'Эфекты выключаныя':'Паменшыць эфекты','Непразрыстае кіраванне',s.reduceEffects?'check':'chevron')}${isReader(s)?row('focus','Поўнаэкраннае чытанне','Кнопка вяртання заўсёды даступная','expand'):''}${d.id==='ios'&&isReader(s)?row('compact','Згарнуць панэль раздзелаў','Браузерная мадэль мінімізацыі iOS','grid'):''}`];
    if(name==='menu')return ['Меню',`${row('settings','Налады','Пачатковы раздзел і выгляд','options')}${row('sync','Сінхранізацыя',s.mode==='sync-error'?'Не ўдалося абнавіць тэксты':'Кіраванне лакальнымі тэкстамі','sync')}${row('about','Пра праграму','iBreviary','info')}`];
    if(name==='settings')return ['Налады',`<label for="${d.id}-start">Пры запуску адкрываць</label><select id="${d.id}-start" data-input="start">${[['last','Апошні адкрыты'],...tabs.map(x=>[x[0],x[1]])].map(([k,l])=>`<option value="${k}" ${s.start===k?'selected':''}>${l}</option>`).join('')}</select><p class="muted">Перавага захоўваецца лакальна для гэтага прататыпа і прымяняецца пасля перазагрузкі.</p>${row('appearance','Выгляд тэксту','','options')}`];
    if(name==='sync')return ['Сінхранізацыя',s.mode==='sync-error'?empty('Не ўдалося абнавіць тэксты','Захаваныя тэксты даступныя. Паўтарыце сінхранізацыю пазней.','retry-sync','Паўтарыць','sync'):`${empty('Тэксты даступныя offline','Лакальны ўзор гатовы да чытання. Прататып не падключаны да сервера сінхранізацыі.',null,null,'check')}${button('simulate-sync-error','Паказаць памылку сінхранізацыі',null)}`];
    return ['Пра прататып',`<p class="muted">Інтэрактыўная браузерная мадэль паводле UX handoff ад 08.09.2026. Чатыры раздзелы захоўваюць сваё месца.</p><p class="muted">Літургічныя наборы, Абраныя і зборнікі — fixtures. Тэксты — з праекта. Даныя Flutter і MyBrev не змяняюцца.</p><p class="muted">iOS: імітацыя матэрыялу. Android: непразрыстае tonal-кіраванне. Натыўныя жэсты і прадукцыйнасць патрабуюць праверкі на прыладах.</p>`];
  }
  function liturgicalResults(d) {const q=(d.modalQuery||'').toLocaleLowerCase(),branch=d.modal.split(':')[1];const list=Object.entries(M.CALENDAR).flatMap(([date,cs])=>cs.filter(c=>!c.disabled&&(!d.period||d.period==='all'||(d.period==='ordinary'?c.id==='ordinary'||c.id==='sunday':c.id==='mary'||c.id==='peter'))).map(c=>({date,c}))).filter(({c})=>c.title.toLocaleLowerCase().includes(q));return list.length?list.map(({date,c})=>row(`liturgical-date:${branch}:${date}`,c.title,dateLabel(date),'calendar')).join(''):empty('Нічога не знойдзена','У прыкладзе ёсць толькі дні 8, 9 і 13 верасня.',null,null,'search');}
  function renderModal(d) {
    const [title,html]=modalContents(d);
    for(const el of d.el.children)if(!el.classList.contains('modal-root'))el.inert=true;
    $('.modal-root',d.el).innerHTML=`<div class="overlay"><section class="sheet" role="dialog" aria-modal="true" aria-labelledby="${d.id}-dialog-title"><div class="sheet-heading"><h2 id="${d.id}-dialog-title">${title}</h2>${round('close','Закрыць','close')}</div>${html}</section></div>`;
    const focus=$('[autofocus]',d.el)||$('.sheet button',d.el);focus?.focus();
  }
  function notify(d,message) {const a=$('.announcement',d.el);a.innerHTML=`<div class="toast">${E(message)}</div>`;setTimeout(()=>{if(a.isConnected)a.innerHTML='';},2400);}
  function setDate(d,branch,date) {R.chooseDate(d,branch,date);}
  function action(d,value,trigger) {
    if(R.action(d,value))return;
    const s=d.state,[type,arg,arg2]=value.split(':');
    if(['menu','settings','about','appearance','sync','celebrations','reading-options','search-prayers','search-bible','bible-picker'].includes(type)){if(type==='search-bible')d.searchScope='books';openModal(d,type,value);return;}
    if(['date','calendar','liturgical'].includes(type)){d.period='all';openModal(d,value,value);return;}
    if(type==='close'){closeModal(d);return;}
    if(type==='tab'){s.tab=arg;s.focus=false;s.compact=false;d.modal=null;render(d);return;}
    if(type==='hour'){s.hours.ora=arg;}
    else if(type==='today'){setDate(d,arg,M.TODAY);return;}
    else if(type==='day-prev'||type==='day-next'){setDate(d,arg,M.plusDate(s[arg].date,type==='day-prev'?-1:1));return;}
    else if(type==='apply-date'){const v=$('[data-input=date-value]',d.el).value;if(!v)return;setDate(d,arg,v);return;}
    else if(type==='liturgical-date'){setDate(d,arg,arg2);return;}
    else if(type==='period'){d.period=arg;renderModal(d);return;}
    else if(type==='celebration'){if(M.CALENDAR[s.hours.date]?.[+arg]?.disabled)return;s.hours.choice=+arg;s.hours.ora=null;}
    else if(type==='ora-readings'){M.oraToReadings(s);}
    else if(type==='readings-auto'){const origin=s.readings.returnTo;M.resetReadings(s,s.readings.date);s.readings.returnTo=origin;}
    else if(type==='reading-group'){s.readings.group=+arg;s.readings.cycle=M.defaultCycle(s.readings.date,M.readingGroups(s.readings.date)[+arg]);s.readings.manual=true;render(d);return;}
    else if(type==='reading-cycle'){s.readings.cycle=arg;s.readings.manual=true;}
    else if(type==='prayer'||type==='search-prayer'){s.prayers.detail=arg;s.prayers.fromSearch=type==='search-prayer';}
    else if(type==='favorite'){M.toggleFavorite(s,arg);const modal=d.modal;render(d);if(!modal)notify(d,s.favorites.includes(arg)?'Дададзена ў Абраныя':'Прыбрана з Абраных');return;}
    else if(type==='all-prayers'){s.prayers.page='catalog';s.prayers.collection=null;s.prayers.query='';s.prayers.filter='all';}
    else if(type==='collection'){s.prayers.page='collection';s.prayers.collection=arg;s.prayers.query='';s.prayers.filter='all';}
    else if(type==='clear-prayer-filter'){s.prayers.query='';s.prayers.filter='all';}
    else if(type==='clear-prayer-search'){s.prayers.query='';s.prayers.filter='all';renderModal(d);save(d);return;}
    else if(type==='back'){
      if(s.tab==='hours')s.hours.ora=null;
      else if(s.tab==='readings')M.backToOra(s);
      else if(s.tab==='prayers'){if(s.prayers.detail){s.prayers.detail=null;if(s.prayers.fromSearch){d.modal='search-prayers';s.prayers.fromSearch=false;render(d);return;}}else{s.prayers.page='home';s.prayers.collection=null;}}
    }
    else if(type==='pick-chapter'){s.bible.book=d.modalBook;s.bible.chapter=+arg+1;}
    else if(type==='chapter-next'||type==='chapter-prev'){const book=F.bible[s.bible.translation].find(b=>b.id===s.bible.book);s.bible.chapter=Math.max(1,Math.min(book.chapters.length,s.bible.chapter+(type==='chapter-next'?1:-1)));}
    else if(type==='mark'){const id=`${s.bible.translation}:${s.bible.book}:${s.bible.chapter}:${arg}`;s.bible.marks=s.bible.marks.includes(id)?s.bible.marks.filter(x=>x!==id):[...s.bible.marks,id];}
    else if(type==='bible-scope'){d.searchScope=arg;d.modalQuery='';renderModal(d);return;}
    else if(type==='search-book'){d.modalBook=arg;d.modal='bible-picker';renderModal(d);return;}
    else if(type==='search-verse'){s.bible.chapter=+arg;d.modal=null;render(d);const v=d.el.querySelector(`[data-action="mark:${arg2}"]`);v?.closest('p')?.scrollIntoView({block:'center'});return;}
    else if(type==='reduce-effects'){s.reduceEffects=!s.reduceEffects;render(d);return;}
    else if(type==='focus'){s.focus=true;s.compact=false;}
    else if(type==='exit-focus'){s.focus=false;}
    else if(type==='compact'){s.compact=true;}
    else if(type==='expand-tabs'){s.compact=false;}
    else if(type==='ready'){s.mode='ready';}
    else if(type==='simulate-sync-error'){s.mode='sync-error';render(d);return;}
    else if(type==='retry-sync'){s.mode='ready';render(d);notify(d,'Дэманстрацыя: паўтор завершаны. Сервер не падключаны.');return;}
    else return;
    d.modal=null;render(d);
    if(['hour','prayer','search-prayer','back','ora-readings'].includes(type))$('.content',d.el).setAttribute('aria-live','polite');
  }
  function onInput(d,el) {
    if(R.input(d,el))return;
    const type=el.dataset.input,s=d.state;
    if(type==='prayer-query'){s.prayers.query=el.value;$('[data-results=prayers]',d.el).innerHTML=searchPrayerResults(d);}
    if(type==='prayer-filter'){s.prayers.filter=el.value;$('[data-results=prayers]',d.el).innerHTML=searchPrayerResults(d);}
    if(type==='bible-query'){d.modalQuery=el.value;$('[data-results=bible]',d.el).innerHTML=bibleSearchResults(d);}
    if(type==='liturgical-query'){d.modalQuery=el.value;$('[data-results=liturgical]',d.el).innerHTML=liturgicalResults(d);}
    if(type==='book'){d.modalBook=el.value;renderModal(d);}
    if(type==='translation'){s.bible.translation=el.value;render(d);}
    if(type==='reader-size'){s.readerScale=+el.value;d.el.style.setProperty('--reader-scale',s.readerScale);el.previousElementSibling.textContent=`Памер тэксту: ${Math.round(s.readerScale*100)}%`;}
    if(type==='start')s.start=el.value;
    save(d);
  }
  R.setup({E,icon,button,row,round,clean,prayers,tabs,app,dateLabel,source,empty,save,render,renderModal,openModal,closeModal,notify,prayerRow,searchPrayerResults});
  for(const id of ['ios','android']) {
    let state=M.createState();
    try {const saved=JSON.parse(localStorage.getItem('ibreviary-ux-prototype-v1:'+id));if(saved?.hours&&saved?.bible&&tabs.some(t=>t[0]===saved.tab)){state={...state,...saved,mode:'ready',focus:false,compact:false};if(state.start!=='last')state.tab=state.start;}}catch{/* Use fresh local fixtures. */}
    const d=app.devices[id]={id,el:document.getElementById(id),state,modal:null};
    d.el.addEventListener('click',e=>{const b=e.target.closest('[data-action]');if(b&&!b.disabled)action(d,b.dataset.action,b);else if(e.target.classList.contains('overlay'))closeModal(d);});
    d.el.addEventListener('input',e=>{if(e.target.matches('input[data-input]'))onInput(d,e.target);});
    d.el.addEventListener('change',e=>{if(e.target.matches('select[data-input]'))onInput(d,e.target);});
    d.el.addEventListener('keydown',e=>{if(e.key==='Escape'){if(d.modal){e.preventDefault();closeModal(d);}else if(d.state.focus){e.preventDefault();action(d,'exit-focus');}}if(e.key==='Tab'&&d.modal){const nodes=[...d.el.querySelectorAll('.sheet button:not(:disabled),.sheet input,.sheet select,.sheet a')];const first=nodes[0],last=nodes.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last?.focus();}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first?.focus();}}});
    render(d);
  }
  function scenario(name) {
    for(const d of Object.values(app.devices)) {
      d.state=M.createState();d.modal=null;const s=d.state;
      if(name==='alternative')d.modal='celebrations';
      if(name==='date')M.dateChange(s,'hours','2026-09-09');
      if(name==='ora'){M.dateChange(s,'hours','2026-09-09');s.hours.choice=1;s.hours.ora='laudes';}
      if(name==='readings')s.tab='readings';
      if(name==='reading-options'){s.tab='readings';M.resetReadings(s,'2026-09-13');d.modal='reading-options';}
      if(name==='prayers'||name==='prayer'){s.tab='prayers';if(name==='prayer')s.prayers.detail='magnificat';}
      if(name==='bible')s.tab='bible';
      render(d);
    }
    $('#state').value='ready';
    document.querySelectorAll('[data-scenario]').forEach(b=>b.classList.toggle('selected',b.dataset.scenario===name));
  }
  $('#scenarios').addEventListener('click',e=>{const b=e.target.closest('[data-scenario]');if(b)scenario(b.dataset.scenario);});
  $('#theme').addEventListener('change',e=>{app.theme=e.target.value;Object.values(app.devices).forEach(render);});
  $('#scale').addEventListener('change',e=>{app.scale=+e.target.value;Object.values(app.devices).forEach(render);});
  $('#platform').addEventListener('change',e=>{$('#studio').dataset.platform=e.target.value;});
  $('#state').addEventListener('change',e=>{for(const d of Object.values(app.devices)){const s=d.state;d.modal=null;s.mode=e.target.value;if(s.mode==='empty-day'){s.tab='hours';s.hours.ora=null;}if(s.mode==='empty-favorites'){s.mode='ready';s.tab='prayers';s.prayers.page='home';s.prayers.detail=null;s.favorites=[];}if(s.mode==='empty-search'){s.mode='ready';s.tab='prayers';s.prayers.detail=null;s.prayers.query='неіснуючая малітва';d.modal='search-prayers';}if(s.mode==='sync-error')d.modal='sync';render(d);}});
})();
