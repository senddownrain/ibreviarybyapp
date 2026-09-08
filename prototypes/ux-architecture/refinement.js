/* Refinement of the existing four-branch prototype; no production imports at runtime. */
(() => {
  const M=UXModel,C=UX_CALENDAR,F=UX_FIXTURES;
  let H;
  const periods={ordinary:'Звычайны перыяд',advent:'Адвэнт',christmas:'Божае Нараджэнне',lent:'Вялікі пост',holyweek:'Вялікі тыдзень',easter:'Велікодны перыяд'};
  const weekdays=['Нядзеля','Панядзелак','Аўторак','Серада','Чацвер','Пятніца','Субота'];
  const monthNames=['Студзень','Люты','Сакавік','Красавік','Май','Чэрвень','Ліпень','Жнівень','Верасень','Кастрычнік','Лістапад','Снежань'];
  const periodColors={ordinary:'#4D8A5B',advent:'#7A57A7',lent:'#6F4A92',holyweek:'#5B3B83',christmas:'#B07A1E',easter:'#BD8A24'};
  const templateNames={'blessed-virgin-mary':'Пра Найсвяцейшую Панну Марыю',pastors:'Пра пастыраў','works-of-mercy':'Пра справы міласэрнасці',apostles:'Апосталы','church-dedication':'Пра пасвячэнне касцёла','doctors-of-church':'Пра доктараў Касцёла',educators:'Пра выхавацеляў','holy-men':'Пра святых мужчынаў','holy-women':'Пра святых жанчынаў','martyr-one':'Пра аднаго мучаніка','martyrs-many':'Пра некалькіх мучанікаў',religious:'Пра законнікаў',virgins:'Пра паннаў'};
  const ranks={solemnitas:'Урачыстасць',solemnity:'Урачыстасць',festum:'Свята',feast:'Свята',memoria:'Успамін',memorial:'Успамін','memoria-ad-libitum':'Неабавязковы ўспамін'};
  const highlightColors={amber:'#E2AE34',rose:'#D37074',sky:'#4F9FC1',leaf:'#59A46B'};
  const highlightNames={amber:'Бурштынавы',rose:'Ружовы',sky:'Блакітны',leaf:'Зялёны'};
  const initialCategories=[{id:'morning',name:'Ранішняя малітва',system:false,members:['glory','benedictus']},{id:'canticles',name:'Евангельскія песні',system:true,members:['magnificat','benedictus']},{id:'daily',name:'Штодзённыя',system:true,members:['night','glory']},{id:'liturgical',name:'Літургічныя малітвы',system:true,members:['mary','peter']}];

  // Exact decision order of lib/utils/liturgical_theme.dart. Presentation intensity is separate.
  function liturgicalColor(day={},fallback='ordinary') {
    if(day.theme==='requiem'||day.kind==='office-for-dead')return '#67546B';
    const rank=(day.rankCode||'').trim().toLowerCase(),feast=(day.feast||'').toLowerCase().replace('feast-',''),template=(day.templates||[]).join(' ');
    const text=[day.title,day.currentVersion,template].join(' ').toLowerCase();
    if(['pentecost','heartofjesus'].includes(feast)||['мучан','апостал','martyr','apostle','святога духа','духа святога'].some(x=>text.includes(x))||(text.includes('сэрц')&&text.includes('езус')))return '#B33A3A';
    if(['solemnitas','solemnity','урачыстасць','ўрачыстасць'].includes(rank))return '#B88719';
    if(rank&&template.toLowerCase().includes('blessed-virgin-mary'))return '#5E9EC5';
    if(['festum','feast','свята','memoria','memoria-ad-libitum','memorial','memory','успамін'].includes(rank))return '#8F7D52';
    return periodColors[day.period||fallback]||'#55707C';
  }
  function hydrate(s) {
    s.categories??=JSON.parse(JSON.stringify(initialCategories));s.hiddenCategories??=[];s.nav??='auto';s.theme??='studio';s.prayers.filtersVisible??=false;s.bible.highlights??={};s.bible.selected??=[];s.bible.lastByTranslation??={};
    if(s.bible.book==='rm')s.bible.book='rom';
    if(s.hours.date&&!M.CALENDAR[s.hours.date]&&C.contexts[s.hours.date])ensureDate(s.hours.date);
    if(s.readings.date&&!M.CALENDAR[s.readings.date]&&C.contexts[s.readings.date])ensureDate(s.readings.date);
  }
  function navMode(s) {
    const override=H.app.navigation;
    if(override&&override!=='auto')return override;
    if(s.nav&&s.nav!=='auto')return s.nav;
    if(s.tab==='hours'&&s.hours.ora||s.tab==='prayers'&&s.prayers.detail||s.tab==='bible')return 'compact';
    if(s.tab==='readings'&&s.readings.started)return 'compact';
    return 'full';
  }
  function beforeRender(d) {
    hydrate(d.state);const mode=navMode(d.state);d.state.focus=mode==='hidden';d.state.compact=mode==='compact';
  }
  function applyAtmosphere(d) {
    const s=d.state;let day=s.tab==='hours'?M.CALENDAR[s.hours.date]?.[s.hours.choice]:M.CALENDAR[s.readings.date]?.[s.readings.group];
    const example=H.app.season||'auto';
    if(example!=='auto')day=example==='marian'?{rankCode:'festum',templates:['blessed-virgin-mary']}:example==='red'?{title:'Мучанік'}:example==='solemnity'?{rankCode:'solemnitas'}:example==='requiem'?{theme:'requiem'}:{period:example};
    const color=liturgicalColor(day||{},C.contexts[(s.tab==='hours'?s.hours:s.readings).date]?.periodType||'ordinary');
    d.el.style.setProperty('--season',color);d.el.classList.toggle('liturgical-context',['hours','readings'].includes(s.tab));
    if(s.theme!=='studio')d.el.classList.toggle('dark',s.theme==='dark'||s.theme==='system'&&matchMedia('(prefers-color-scheme:dark)').matches);
    d.el.dataset.navigation=navMode(s);
  }
  function alias(id){if(id?.startsWith('08-09-nativity-blessed'))return 'mary';if(id?.startsWith('09-09-sv-peter'))return 'peter';return id;}
  function normalizeOption(x) {return {...x,id:alias(x.id),fullId:x.id,rankCode:x.rank,rank:ranks[x.rank]||'Літургічны дзень',color:'neutral',source:x.source||'fixed',templates:x.templates||[]};}
  function ensureDate(date) {
    if(M.CALENDAR[date])return;
    const ctx=C.contexts[date];if(!ctx)return;
    const period={id:'ordinary',title:`${weekdays[ctx.dayOfWeek-1]} · ${periods[ctx.periodType]}${ctx.periodWeek>0?' · '+ctx.periodWeek+' тыдзень':''}`,period:ctx.periodType,rank:'Літургічны дзень',source:'period',order:1,templates:[]};
    const fixed=C.fixed.filter(x=>x.date===date).map(x=>({...normalizeOption(x),order:3}));
    const dynamic=C.dynamic.filter(x=>x.date===date).map(x=>({...normalizeOption(x),rankCode:['ashWednesday','palmSunday'].includes(x.id)?'':'solemnitas',rank:'Рухомае святкаванне',period:ctx.periodType,feast:x.id==='sacredHeartOfJesus'?'heartofjesus':x.id,order:2}));
    // Same fixture sorting rule as LiturgicalContentService: rank bucket, then source order.
    const priority=x=>['solemnitas','solemnity'].includes(x.rankCode)?0:['festum','feast'].includes(x.rankCode)?1:2;
    M.CALENDAR[date]=[period,...dynamic,...fixed].sort((a,b)=>priority(a)-priority(b)||a.order-b.order);
  }
  function chooseDate(d,branch,date,item) {
    ensureDate(date);M.dateChange(d.state,branch,date);
    if(item&&branch==='hours'){const index=(M.CALENDAR[date]||[]).findIndex(x=>x.id===alias(item.id));if(index>=0)d.state.hours.choice=index;}
    d.state.nav='auto';d.modal=null;H.render(d);
  }
  function categories(s){return s.categories.filter(c=>!s.hiddenCategories.includes(c.id));}
  function category(s,id){return s.categories.find(c=>c.id===id);}
  function filteredPrayers(s) {const p=s.prayers,q=p.query.toLocaleLowerCase('be'),cat=category(s,p.collection);return H.prayers.filter(x=>(!cat||cat.members.includes(x.id))&&(p.filter==='all'||p.filter==='favorites'&&s.favorites.includes(x.id)||category(s,p.filter)?.members.includes(x.id))&&(!q||(x.title+' '+x.sub+' '+String(x.html).replace(/<[^>]*>/g,' ')).toLocaleLowerCase('be').includes(q)));}
  function prayerRoot(s) {
    const {button,row,E,empty,prayerRow}=H,p=s.prayers;
    if(p.detail)return null;
    if(p.page!=='home'){const cat=category(s,p.collection),list=filteredPrayers(s);return `<div class="page"><h1>${E(cat?.name||'Усе малітвы')}</h1><p class="muted">${cat?'Малітвы гэтай катэгорыі':'Увесь малітоўнік адным спісам'}</p>${list.length?list.map(x=>prayerRow(s,x)).join(''):empty('Малітваў не знойдзена','Змяніце запыт або фільтр.','clear-prayer-filter','Скінуць фільтры','search')}</div>`;}
    const favorites=s.favorites.map(id=>H.prayers.find(p=>p.id===id)).filter(Boolean);
    return `<div class="page"><h1>Малітоўнік</h1><div class="section-heading"><h2>Абраныя</h2><span class="count">${favorites.length}</span></div>${favorites.length?favorites.map(p=>prayerRow(s,p)).join(''):empty('Тут будуць вашы малітвы','Дадайце малітву з поўнага каталога праз сэрца.','all-prayers','Адкрыць усе малітвы','heart')}<div class="section-heading"><h2>Катэгорыі</h2></div>${categories(s).map(c=>row('collection:'+c.id,c.name,'','folder')).join('')}${button('manage-categories','Кіраваць катэгорыямі',null)}<div class="section-heading"><h2>Усе малітвы</h2></div>${row('all-prayers','Адкрыць увесь малітоўнік',`${H.prayers.length} малітваў у дэманстрацыйным каталогу`)}<p class="muted">Абраныя і катэгорыі — дэманстрацыйныя даныя.</p></div>`;
  }
  function calendarView(d,branch){
    const {button,E,dateLabel}=H;d.calendarDate??=d.state[branch].date;d.calendarMonth??=d.calendarDate.slice(0,7);
    const [year,month]=d.calendarMonth.split('-').map(Number),offset=(new Date(year,month-1,1).getDay()+6)%7,count=new Date(year,month,0).getDate();
    return ['Выбраць дату',`<p class="calendar-selection">${E(dateLabel(d.calendarDate))}</p><div class="calendar-month">${button('calendar-month:-1','','back','plain','aria-label="Папярэдні месяц"')}<label class="sr-only" for="${d.id}-month">Месяц</label><select id="${d.id}-month" data-input="calendar-month-select">${monthNames.map((x,i)=>`<option value="${i+1}" ${i+1===month?'selected':''}>${x}</option>`).join('')}</select>${button('calendar-month:1','','chevron','plain','aria-label="Наступны месяц"')}</div><label for="${d.id}-calendar-year">Год</label><select id="${d.id}-calendar-year" data-input="calendar-year">${Array.from({length:12},(_,i)=>2019+i).map(y=>`<option ${y===year?'selected':''}>${y}</option>`).join('')}</select><div class="calendar-grid" role="group" aria-label="Каляндар">${['Пн','Аў','Ср','Чц','Пт','Сб','Нд'].map(x=>`<span>${x}</span>`).join('')}${Array.from({length:offset},()=>'<span></span>').join('')}${Array.from({length:count},(_,i)=>{const date=`${year}-${String(month).padStart(2,'0')}-${String(i+1).padStart(2,'0')}`;return button('calendar-day:'+date,String(i+1),null,(date===d.calendarDate?'selected-day ':'')+(date===M.TODAY?'current-day':''),`aria-label="${dateLabel(date)}" aria-pressed="${date===d.calendarDate}"`);}).join('')}</div>${button('calendar-apply:'+branch,'Адкрыць '+E(dateLabel(d.calendarDate)),null,'primary-button')}<p class="muted">Каляндар 2019–2030. Літургічныя даныя прыкладу разлічаныя для 2026.</p>`];
  }
  function explorerResults(d) {
    const {row,E,dateLabel,empty}=H,p=d.explorer,year=p.year;
    if(p.tab==='periods') {
      const date=year===2026?C.coordinates[`${p.period}:${p.week}:${p.day}`]:null;
      let result=date?row(`explorer-result:${date}`,`${weekdays[p.day-1]} · ${periods[p.period]} · ${p.week} тыдзень`,dateLabel(date),'calendar'):empty('Няма даты для гэтага выбару',year!==2026?'Лакальныя параметры гэтага года не ўключаныя ў прыклад.':'Гэты тыдзень не мае даты ў абраным годзе.',null,null,'calendar');
      const exact=year===2026?(C.exact[p.period]||[]):[];
      if(p.period==='christmas')result='';
      return `${result}${exact.length?`<h3 class="section-caption">${p.period==='advent'?'17–24 снежня':p.period==='lent'?'Пачатак Вялікага посту':'Ад Нараджэння да Хрышчэння Пана'}</h3>${exact.map(date=>row(`explorer-result:${date}`,dateLabel(date),'Каляндарны дзень','calendar')).join('')}`:''}`;
    }
    const q=p.query.toLocaleLowerCase(),all=[...C.fixed.map(f=>({...f,date:year+f.date.slice(4)})),...C.dynamic.map(f=>({...f,date:year===2026?f.date:null}))];
    const list=all.filter(x=>(p.kind==='all'||x.source===p.kind)&&(x.title+' '+(x.date?dateLabel(x.date):'')).toLocaleLowerCase().includes(q)).sort((a,b)=>(a.date||'9999').localeCompare(b.date||'9999'));
    return list.length?list.map(x=>row(`explorer-feast:${encodeURIComponent(x.id)}`,x.title,`${x.source==='dynamic'?'Рухомае':'Сталае'} · ${x.date?dateLabel(x.date):'Няма лакальных параметраў года'}`,x.date?'chevron':'info',x.date?'':'disabled')).join(''):empty('Нічога не знойдзена','Змяніце назву свята або святога.',null,null,'search');
  }
  function explorer(d,branch) {
    const {button,E}=H;d.explorer??={tab:'periods',year:2026,period:'ordinary',week:23,day:4,query:'',kind:'all'};const p=d.explorer;
    return ['Літургічны каляндар',`<label for="${d.id}-explorer-year">Год</label><select id="${d.id}-explorer-year" data-input="explorer-year">${Array.from({length:12},(_,i)=>2019+i).map(y=>`<option ${y===p.year?'selected':''}>${y}</option>`).join('')}</select><div class="segmented">${button('explorer-tab:periods','Перыяды',null,p.tab==='periods'?'active':'')}${button('explorer-tab:feasts','Святы і святыя',null,p.tab==='feasts'?'active':'')}</div>${p.tab==='periods'?`<label for="${d.id}-period">Літургічны перыяд</label><select id="${d.id}-period" data-input="explorer-period">${Object.entries(periods).map(([id,label])=>`<option value="${id}" ${id===p.period?'selected':''}>${label}</option>`).join('')}</select>${C.maxWeeks[p.period]>0?`<div class="two-fields"><div><label for="${d.id}-week">Тыдзень</label><select id="${d.id}-week" data-input="explorer-week">${Array.from({length:C.maxWeeks[p.period]},(_,i)=>`<option ${p.week===i+1?'selected':''}>${i+1}</option>`).join('')}</select></div><div><label for="${d.id}-weekday">Дзень</label><select id="${d.id}-weekday" data-input="explorer-day">${weekdays.map((x,i)=>p.period==='holyweek'&&i===0?'':`<option value="${i+1}" ${i+1===p.day?'selected':''}>${x}</option>`).join('')}</select></div></div>`:''}`:`<label for="${d.id}-feast-query">Назва свята або святога</label><input id="${d.id}-feast-query" data-input="explorer-query" type="search" value="${E(p.query)}" placeholder="Знайсці святкаванне" autofocus><div class="chips">${[['all','Усе'],['fixed','Сталыя'],['dynamic','Рухомыя']].map(([k,l])=>button('explorer-kind:'+k,l,null,'chip'+(p.kind===k?' active':''))).join('')}</div>`}<div data-results="explorer">${explorerResults(d)}</div>`];
  }
  function alternatives(d) {
    const {row,button,E}=H,s=d.state,options=M.CALENDAR[s.hours.date]||[],active=options[s.hours.choice];
    const groups=[['Святкаванні дня',x=>!x.place&&x.id!=='dead'],['Мясцовы каляндар',x=>!!x.place],['Іншы афіцый',x=>x.id==='dead']];
    return ['Іншыя літургічныя варыянты',`${groups.map(([title,predicate])=>{const list=options.map((c,i)=>({c,i})).filter(({c})=>predicate(c));return list.length?`<h3 class="section-caption">${title}</h3>${list.map(({c,i})=>row('preview-celebration:'+i,c.title,`${i===0?'Асноўны · ':''}${c.rank}${c.place?' · '+(Array.isArray(c.place)?c.place.join(', '):c.place):''}`,i===s.hours.choice?'check':'chevron',c.disabled?'disabled':'')).join('')}`:'';}).join('')}${active?.templates?.length>1?`<label>У межах святкавання</label><div class="chips">${active.templates.map(t=>button('office-template:'+t,E(templateNames[t]||t),null,'chip'+((s.hours.template||active.templates[0])===t?' active':''))).join('')}</div>`:''}<div class="alternative-preview"><p class="section-caption">Выбрана</p><strong>${E(active?.title)}</strong><p class="muted">${E(templateNames[s.hours.template]||'Тэксты выбранага святкавання')} · ${M.HOURS.length} гадзінаў у прыкладзе</p><div class="row">${button('adjacent-alternative:-1','Папярэдні','back')}${button('adjacent-alternative:1','Наступны','chevron')}</div></div>${button('close','Вярнуцца да гадзін',null,'primary-button')}`];
  }
  function bible(s) {
    const {button,E,source}=H,b=s.bible,book=F.bible[b.translation].find(x=>x.id===b.book)||F.bible[b.translation][0],verses=book.chapters[b.chapter-1]||[];
    return `<div class="reader-context"><div class="language-tabs chrome" role="group" aria-label="Пераклад Бібліі">${[['bel','БЕЛ'],['ru','РУС']].map(([id,label])=>button('translation:'+id,label,null,id===b.translation?'active':'',`aria-pressed="${id===b.translation}"`)).join('')}</div><p>${book.newTestament?'НОВЫ ЗАПАВЕТ':'СТАРЫ ЗАПАВЕТ'}</p><h1>${E(book.name)}</h1><div class="chapter-controls">${button('relative-chapter:-1','','back','plain','aria-label="Папярэдняя глава"')}${button('bible-picker','Раздзел '+b.chapter,'down','date-button')}${button('relative-chapter:1','','chevron','plain','aria-label="Наступная глава"')}</div></div><article class="reader" aria-label="Раздзел Бібліі">${verses.map(v=>{const key=`${b.translation}:${book.id}:${b.chapter}:${v.num}`,color=b.highlights[key];return `<p class="bible-verse ${b.selected.includes(v.num)?'verse-selected':''}" ${color?`style="--highlight:${highlightColors[color]}"`:''}>${button('select-verse:'+v.num,String(v.num),null,'verse-button',`aria-label="Выбраць верш ${v.num}" aria-pressed="${b.selected.includes(v.num)}"`)}${E(v.text)||'<span class="muted">[У крыніцы няма тэксту гэтага верша]</span>'}</p>`;}).join('')}<div class="chapter-navigation">${button('relative-chapter:-1','Папярэдні','back')}${button('relative-chapter:1','Наступны','chevron')}</div>${source('Поўны тэкст з лакальнага bible_seed. БЕЛ: А. Бокун · catholic.by. РУС: Синодальный перевод. Для каляровай пазнакі выберыце нумар верша.')}<div class="end-mark" aria-hidden="true">· · ·</div></article>`;
  }
  function biblePicker(d) {
    const {button,row,E}=H,b=d.state.bible;d.testament??=F.bible[b.translation].find(x=>x.id===b.book)?.newTestament??true;d.bookQuery??='';d.expandedBook??=b.book;
    const books=F.bible[b.translation].filter(x=>x.newTestament===d.testament&&x.name.toLocaleLowerCase().includes(d.bookQuery.toLocaleLowerCase()));
    return ['Кніга і раздзел',`<div class="segmented">${button('testament:old','Стары Запавет',null,!d.testament?'active':'')}${button('testament:new','Новы Запавет',null,d.testament?'active':'')}</div><label for="${d.id}-book-query">Знайсці кнігу</label><input id="${d.id}-book-query" data-input="book-query" type="search" value="${E(d.bookQuery)}" placeholder="Назва кнігі"><div data-results="books">${books.map(book=>`${row('expand-book:'+book.id,book.name,`${book.chapters.length} раздзелаў`,d.expandedBook===book.id?'down':'chevron')}${d.expandedBook===book.id?`<div class="chapter-grid">${book.chapters.map((_,i)=>button('chapter-choice:'+i,String(i+1),null,book.id===b.book&&i+1===b.chapter?'active':'',`aria-label="Раздзел ${i+1}"`)).join('')}</div>`:''}`).join('')||'<p class="muted">Кніг не знойдзена</p>'}</div>`];
  }
  function highlightDock(d) {
    const b=d.state.bible;if(d.state.tab!=='bible'||!b.selected.length)return null;
    const {button}=H;return `<footer class="nav-wrap"><div class="highlight-dock chrome"><span>${b.selected.length}</span>${Object.entries(highlightColors).map(([id,color])=>button('highlight:'+id,'',null,'color-dot',`aria-label="${highlightNames[id]}" style="--dot:${color}"`)).join('')}${button('highlight:clear','Сцерці',null,'plain')}${button('cancel-verse','','close','plain','aria-label="Скасаваць выбар"')}</div></footer>`;
  }
  function modal(d) {
    const {row,button,E,empty}=H,s=d.state,name=d.modal;
    if(name?.startsWith('calendar:'))return calendarView(d,name.split(':')[1]);
    if(name?.startsWith('liturgical:'))return explorer(d,name.split(':')[1]);
    if(name==='celebrations')return alternatives(d);
    if(name==='bible-picker')return biblePicker(d);
    if(name==='search-prayers')return ['Пошук малітваў',`<label for="${d.id}-prayer-query">Назва або тэкст малітвы</label><input id="${d.id}-prayer-query" data-input="prayer-query" type="search" value="${E(s.prayers.query)}" placeholder="Знайсці малітву" autofocus><div class="row">${button('clear-prayer-search','Ачысціць',null)}${button('prayer-filters','Фільтры','options')}</div>${s.prayers.filtersVisible?`<label for="${d.id}-prayer-filter">Катэгорыя${s.prayers.collection?' · '+E(category(s,s.prayers.collection)?.name):''}</label><select id="${d.id}-prayer-filter" data-input="prayer-filter">${[{id:'all',name:'Усе малітвы'},{id:'favorites',name:'Абраныя'},...s.categories].map(c=>`<option value="${c.id}" ${s.prayers.filter===c.id?'selected':''}>${E(c.name)}</option>`).join('')}</select>`:''}<div data-results="prayers" aria-live="polite">${H.searchPrayerResults(d)}</div>`];
    if(name==='menu'&&(s.tab==='bible'||s.tab==='readings'))return ['Меню',`${row('focus','Поўнаэкраннае чытанне','','expand')}${row('settings','Налады','','options')}${row('sync','Сінхранізацыя','','sync')}${row('about','Пра праграму','','info')}`];
    if(name==='appearance')return ['Памер тэксту',`<label for="${d.id}-reader-size">Памер тэксту: ${Math.round(s.readerScale*100)}%</label><input id="${d.id}-reader-size" type="range" min="0.7" max="1.8" step="0.1" value="${s.readerScale}" data-input="reader-size"><p class="reader-size-sample" style="font-size:${s.readerScale}em">Божа, прыйдзі мне на дапамогу.</p>`];
    if(name==='reader-menu')return ['Чытанне',`${row('focus','Поўнаэкраннае чытанне','Кіраванне можна вярнуць адным націскам','expand')}${row('show-full-nav','Усе раздзелы','','grid')}${row('menu','Меню праграмы','','menu')}`];
    if(name==='change-hour')return ['Літургія гадзінаў',M.HOURS.map(([id,label,sub])=>row('hour:'+id,label,sub,s.hours.ora===id?'check':'chevron')).join('')];
    if(name==='settings')return ['Налады',`<label for="${d.id}-theme">Выгляд</label><select id="${d.id}-theme" data-input="user-theme">${[['system','Сістэмны'],['light','Светлы'],['dark','Цёмны']].map(([v,l])=>`<option value="${v}" ${(s.theme==='studio'?'system':s.theme)===v?'selected':''}>${l}</option>`).join('')}</select><label for="${d.id}-start">Пры запуску адкрываць</label><select id="${d.id}-start" data-input="start">${[['last','Апошні адкрыты'],...H.tabs.map(x=>[x[0],x[1]])].map(([k,l])=>`<option value="${k}" ${s.start===k?'selected':''}>${l}</option>`).join('')}</select>${row('appearance','Памер тэксту','','options')}${row('manage-categories','Кіраваць катэгорыямі','','folder')}${row('sync','Сінхранізацыя і даныя','','sync')}`];
    if(name==='manage-categories')return ['Катэгорыі',`${s.categories.map((c,i)=>`<div class="category-manage"><div><strong>${E(c.name)}</strong><small>${c.system?'Стандартная катэгорыя':'Ваша катэгорыя'}</small></div><div class="category-actions">${button('category-up:'+c.id,'','back','plain',`aria-label="Падняць ${E(c.name)}" ${i===0?'disabled':''}`)}${c.system?button('category-visibility:'+c.id,s.hiddenCategories.includes(c.id)?'Паказаць':'Схаваць',null,'chip'):button('edit-category:'+c.id,'Змяніць',null,'chip')}</div></div>`).join('')}${button('new-category','Стварыць катэгорыю',null,'primary-button')}${button('restore-categories','Паказаць усе стандартныя',null)}`];
    if(name==='edit-category'){const draft=d.categoryDraft;return [draft.isNew?'Новая катэгорыя':'Змяніць катэгорыю',`<label for="${d.id}-category-name">Назва</label><input id="${d.id}-category-name" data-input="category-name" value="${E(draft.name)}" maxlength="80" placeholder="Назва катэгорыі" autofocus><label>Малітвы ў катэгорыі</label>${H.prayers.map(p=>row('category-member:'+p.id,p.title,'',draft.members.includes(p.id)?'check':'chevron')).join('')}<div class="button-stack">${button('save-category','Захаваць',null,'primary-button',draft.name.trim()?'':'disabled')}${!draft.isNew?button('delete-category','Выдаліць гэтую катэгорыю',null):''}</div>`];}
    return null;
  }
  function renderKeep(d) {H.render(d);}
  function action(d,value) {
    const s=d.state,[type,arg]=value.split(':'),{render,renderModal,notify}=H;
    if(['reader-menu','change-hour','manage-categories'].includes(type)){H.openModal(d,type,value);return true;}
    if(type==='focus'||type==='exit-focus'||type==='show-full-nav'||type==='expand-tabs'){s.nav=type==='focus'?'hidden':type==='exit-focus'?'auto':'full';H.app.navigation='auto';document.querySelector('#navigation').value='auto';d.modal=null;render(d);return true;}
    if(type==='calendar'){d.calendarDate=s[arg].date;d.calendarMonth=s[arg].date.slice(0,7);return false;}
    if(type==='calendar-month'){const [y,m]=d.calendarMonth.split('-').map(Number);const next=new Date(y,m-1+(+arg),1);if(next.getFullYear()<2019||next.getFullYear()>2030)return true;d.calendarMonth=`${next.getFullYear()}-${String(next.getMonth()+1).padStart(2,'0')}`;renderModal(d);return true;}
    if(type==='calendar-day'){d.calendarDate=arg;renderModal(d);return true;}
    if(type==='calendar-apply'){chooseDate(d,arg,d.calendarDate);return true;}
    if(type==='explorer-tab'||type==='explorer-kind'){d.explorer[type==='explorer-tab'?'tab':'kind']=arg;renderModal(d);return true;}
    if(type==='explorer-result'){chooseDate(d,d.modal.split(':')[1],arg);return true;}
    if(type==='explorer-feast'){const id=decodeURIComponent(arg),item=[...C.fixed,...C.dynamic].find(x=>x.id===id);if(item){const date=d.explorer.year+item.date.slice(4);chooseDate(d,d.modal.split(':')[1],date,item);}return true;}
    if(type==='preview-celebration'||type==='adjacent-alternative'){const opts=M.CALENDAR[s.hours.date];let idx=+arg;if(type==='adjacent-alternative'){idx=s.hours.choice;do{idx=(idx+(+arg)+opts.length)%opts.length;}while(opts[idx].disabled);}if(opts[idx]?.disabled)return true;s.hours.choice=idx;s.hours.template=null;s.hours.ora=null;renderKeep(d);return true;}
    if(type==='office-template'){s.hours.template=arg;renderKeep(d);return true;}
    if(type==='translation'){const b=s.bible;if(arg===b.translation)return true;b.lastByTranslation[b.translation]={book:b.book,chapter:b.chapter};const target=F.bible[arg].find(x=>x.id===b.book);const fallback=b.lastByTranslation[arg];b.translation=arg;b.book=target?.id||fallback?.book||F.bible[arg][0].id;const book=F.bible[arg].find(x=>x.id===b.book);b.chapter=Math.min(book.chapters.length,target?b.chapter:fallback?.chapter||1);b.selected=[];d.modal=null;render(d);return true;}
    if(type==='search-book'){d.expandedBook=arg;d.testament=F.bible[s.bible.translation].find(x=>x.id===arg)?.newTestament??true;d.bookQuery='';d.modal='bible-picker';H.renderModal(d);return true;}
    if(type==='search-verse'){s.bible.chapter=+arg;s.bible.selected=[];d.modal=null;render(d);d.el.querySelector(`[data-action="select-verse:${value.split(':')[2]}"]`)?.closest('p')?.scrollIntoView({block:'center'});return true;}
    if(type==='relative-chapter'){const books=F.bible[s.bible.translation],b=s.bible,i=books.findIndex(x=>x.id===b.book),next=b.chapter+(+arg);if(next<1&&i>0){b.book=books[i-1].id;b.chapter=books[i-1].chapters.length;}else if(next>books[i].chapters.length&&i<books.length-1){b.book=books[i+1].id;b.chapter=1;}else b.chapter=Math.max(1,Math.min(next,books[i].chapters.length));b.selected=[];render(d);return true;}
    if(type==='testament'){d.testament=arg==='new';d.expandedBook=null;d.bookQuery='';renderModal(d);return true;}
    if(type==='expand-book'){d.expandedBook=d.expandedBook===arg?null:arg;renderModal(d);return true;}
    if(type==='chapter-choice'){s.bible.book=d.expandedBook;s.bible.chapter=+arg+1;s.bible.selected=[];d.modal=null;render(d);return true;}
    if(type==='select-verse'){const n=+arg;s.bible.selected=s.bible.selected.includes(n)?s.bible.selected.filter(x=>x!==n):[...s.bible.selected,n];render(d);return true;}
    if(type==='cancel-verse'||type==='highlight'){if(type==='highlight')for(const v of s.bible.selected){const key=`${s.bible.translation}:${s.bible.book}:${s.bible.chapter}:${v}`;if(arg==='clear')delete s.bible.highlights[key];else s.bible.highlights[key]=arg;}s.bible.selected=[];render(d);return true;}
    if(type==='category-up'){const i=s.categories.findIndex(c=>c.id===arg);if(i>0)[s.categories[i],s.categories[i-1]]=[s.categories[i-1],s.categories[i]];render(d);return true;}
    if(type==='category-visibility'){s.hiddenCategories=s.hiddenCategories.includes(arg)?s.hiddenCategories.filter(x=>x!==arg):[...s.hiddenCategories,arg];render(d);return true;}
    if(type==='restore-categories'){s.hiddenCategories=[];render(d);return true;}
    if(type==='new-category'||type==='edit-category'){d.categoryDraft=type==='new-category'?{id:'user-'+Date.now(),name:'',members:[],system:false,isNew:true}:JSON.parse(JSON.stringify(category(s,arg)));d.modal='edit-category';renderModal(d);return true;}
    if(type==='category-member'){const draft=d.categoryDraft;draft.members=draft.members.includes(arg)?draft.members.filter(x=>x!==arg):[...draft.members,arg];renderModal(d);return true;}
    if(type==='save-category'){if(!d.categoryDraft.name.trim())return true;const {isNew,...cat}=d.categoryDraft;cat.name=cat.name.trim();if(isNew)s.categories.push(cat);else s.categories=s.categories.map(c=>c.id===cat.id?cat:c);d.modal='manage-categories';render(d);return true;}
    if(type==='delete-category'){s.categories=s.categories.filter(c=>c.id!==d.categoryDraft.id);if(s.prayers.collection===d.categoryDraft.id){s.prayers.collection=null;s.prayers.page='home';}d.modal='manage-categories';render(d);notify(d,'Выдалена толькі дэманстрацыйная катэгорыя');return true;}
    if(type==='prayer-filters'){s.prayers.filtersVisible=!s.prayers.filtersVisible;renderModal(d);return true;}
    if(['hour','back','ora-readings','prayer','search-prayer','tab','all-prayers','collection','today','day-prev','day-next'].includes(type))s.nav='auto';
    if(type==='bible-picker'){d.bookQuery='';d.expandedBook=s.bible.book;d.testament=F.bible[s.bible.translation].find(x=>x.id===s.bible.book)?.newTestament??true;}
    return false;
  }
  function input(d,el) {
    const type=el.dataset.input,s=d.state;
    if(type==='user-theme'){s.theme=el.value;H.render(d);return true;}
    if(type==='category-name'){d.categoryDraft.name=el.value;d.el.querySelector('[data-action="save-category"]').disabled=!el.value.trim();return true;}
    if(type==='calendar-month-select'||type==='calendar-year'){let [y,m]=d.calendarMonth.split('-').map(Number);if(type==='calendar-year')y=+el.value;else m=+el.value;d.calendarMonth=`${y}-${String(m).padStart(2,'0')}`;H.renderModal(d);return true;}
    if(type?.startsWith('explorer-')){const field=type.replace('explorer-','');d.explorer[field]=['year','week','day'].includes(field)?+el.value:el.value;if(field==='period'){d.explorer.week=1;d.explorer.day=d.explorer.period==='holyweek'?2:1;}if(field==='query')d.el.querySelector('[data-results=explorer]').innerHTML=explorerResults(d);else H.renderModal(d);return true;}
    if(type==='book-query'){d.bookQuery=el.value;const html=biblePicker(d)[1],doc=new DOMParser().parseFromString(html,'text/html');d.el.querySelector('[data-results=books]').innerHTML=doc.querySelector('[data-results=books]').innerHTML;return true;}
    return false;
  }
  function setup(helpers) {
    H=helpers;const mary=M.CALENDAR[M.TODAY][0];Object.assign(mary,{rankCode:'festum',source:'fixed',templates:['blessed-virgin-mary']});Object.assign(M.CALENDAR[M.TODAY][1],{source:'period',period:'ordinary',templates:[]});Object.assign(M.CALENDAR[M.TODAY][2],{source:'officeForDead',kind:'office-for-dead',templates:[]});
    const local=C.fixed.find(x=>x.id==='08-09-our-lady-braslau-vitebsk');if(local)M.CALENDAR[M.TODAY].push(normalizeOption(local));
    Object.assign(M.CALENDAR['2026-09-09'][0],{source:'period',period:'ordinary',templates:[]});Object.assign(M.CALENDAR['2026-09-09'][1],{source:'fixed',rankCode:'memoria-ad-libitum',templates:['pastors','works-of-mercy']});
    H.app.navigation='auto';H.app.season='auto';
    document.querySelector('#navigation').addEventListener('change',e=>{H.app.navigation=e.target.value;Object.values(H.app.devices).forEach(H.render);});
    document.querySelector('#season').addEventListener('change',e=>{H.app.season=e.target.value;Object.values(H.app.devices).forEach(H.render);});
  }
  globalThis.UXRefinement={setup,beforeRender,applyAtmosphere,modal,action,input,prayerRoot,filteredPrayers,bible,highlightDock,liturgicalColor,ensureDate,chooseDate,navMode,periodColors,category};
})();
