(function (root) {
  'use strict';
  const TODAY = '2026-09-08'; // Frozen review clock; never replaces a reader at midnight.
  const HOURS = [
    ['invit', 'Заклік', 'Пачатак малітвы дня', 'sunrise'],
    ['office', 'Гадзіна чытанняў', 'Псальмы і чытанні', 'book'],
    ['laudes', 'Ютрань', 'Ранішняя малітва', 'sun'],
    ['terce', 'Малая гадзіна · раніцай', 'Малітва ўдзень', 'sun'],
    ['sext', 'Малая гадзіна · апоўдні', 'Малітва ўдзень', 'sun'],
    ['none', 'Малая гадзіна · пасля поўдня', 'Малітва ўдзень', 'sun'],
    ['vespers', 'Нешпары', 'Вячэрняя малітва', 'sunset'],
    ['compline', 'Камплеторый', 'Малітва перад сном', 'moon']
  ];
  const CALENDAR = {
    [TODAY]: [
      {id:'mary', title:'Нараджэнне Найсвяцейшай Панны Марыі', rank:'Свята', color:'gold'},
      {id:'ordinary', title:'Аўторак XXIII звычайнага тыдня', rank:'Літургічны дзень', color:'green'},
      {id:'dead', title:'Афіцый за памерлых', rank:'Няма лакальнага тэксту ў прыкладзе', color:'violet', disabled:true}
    ],
    '2026-09-09': [
      {id:'ordinary', title:'Серада XXIII звычайнага тыдня', rank:'Літургічны дзень · III тыдзень псалтыра', color:'green'},
      {id:'peter', title:'Святы Пётр Клявэр, прэзбітэр', rank:'Успамін', color:'gold'}
    ],
    '2026-09-13': [{id:'sunday', title:'XXIV звычайная нядзеля', rank:'Нядзеля · IV тыдзень псалтыра', color:'green'}]
  };
  function plusDate(date, n) { const d = new Date(date+'T12:00:00'); d.setDate(d.getDate()+n); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`; }
  function cycles(date) {
    const d = new Date(date+'T12:00:00'), year = d.getFullYear();
    const advent = new Date(year, 11, 25, 12); advent.setDate(25 - ((advent.getDay()+6)%7+1)%7 - 21);
    const liturgicalYear = d >= advent ? year+1 : year;
    return {sunday:['C','A','B'][((liturgicalYear-2025)%3+3)%3], weekday:((liturgicalYear-2025)%2+2)%2===0?'1':'2'};
  }
  function readingGroups(date) {
    if (!CALENDAR[date]) return [];
    if (date === TODAY) return [
      {id:'mary', title:CALENDAR[TODAY][0].title, cycles:[], references:['Мц 1, 18–23']},
      {id:'ordinary', title:CALENDAR[TODAY][1].title, cycles:['1','2'], references:['Лк 6, 12–19','Лк 6, 20–26']}
    ];
    if (date === '2026-09-13') return [{id:'sunday', title:CALENDAR[date][0].title, cycles:['A','B','C'], references:['Мц 18, 21–35','Мк 8, 27–35','Лк 15, 1–7']}];
    return [
      {id:'ordinary', title:CALENDAR[date][0].title, cycles:['1','2'], references:['Лк 6, 20–26','Лк 6, 27–36']},
      {id:'peter', title:CALENDAR[date][1].title, cycles:[], references:['Мц 25, 31–40']}
    ];
  }
  function defaultCycle(date, group) { const c = cycles(date); return group.cycles.find(x=>x===(group.cycles.some(x=>['A','B','C'].includes(x))?c.sunday:c.weekday)) || group.cycles[0] || ''; }
  function resetReadings(state, date) { const groups = readingGroups(date); state.readings={date,group:0,cycle:groups[0]?defaultCycle(date,groups[0]):'',manual:false,returnTo:null}; }
  function createState() {
    const s = {tab:'hours', hours:{date:TODAY,choice:0,ora:null}, prayers:{page:'home',detail:null,query:'',filter:'all',collection:null}, bible:{book:'jn',chapter:1,translation:'bel',marks:[]}, favorites:['magnificat','benedictus','night','glory','mary','peter'], scroll:{}, mode:'ready',focus:false,compact:false,readerScale:1,start:'last'};
    resetReadings(s,TODAY); return s;
  }
  function dateChange(s, branch, date) {
    if (branch==='hours') s.hours={date,choice:0,ora:null};
    else resetReadings(s,date);
    s.focus=false; s.compact=false;
  }
  function oraToReadings(s) {
    const origin=JSON.parse(JSON.stringify(s.hours)); resetReadings(s,origin.date);
    s.readings.returnTo=origin; s.tab='readings'; s.focus=false; s.compact=false;
  }
  function backToOra(s) { if(s.readings.returnTo) {s.hours=s.readings.returnTo; s.readings.returnTo=null; s.tab='hours';} }
  function toggleFavorite(s,id) { s.favorites=s.favorites.includes(id)?s.favorites.filter(x=>x!==id):[...s.favorites,id]; }
  function key(s) {
    if(s.tab==='hours') return `hours:${s.hours.date}:${s.hours.choice}:${s.hours.ora||'root'}`;
    if(s.tab==='readings') return `readings:${s.readings.date}:${s.readings.group}:${s.readings.cycle}`;
    if(s.tab==='prayers') return `prayers:${s.prayers.detail||s.prayers.page}:${s.prayers.collection||''}:${s.prayers.query}:${s.prayers.filter}`;
    return `bible:${s.bible.translation}:${s.bible.book}:${s.bible.chapter}`;
  }
  const api={TODAY,HOURS,CALENDAR,plusDate,cycles,readingGroups,defaultCycle,resetReadings,createState,dateChange,oraToReadings,backToOra,toggleFavorite,key};
  root.UXModel=api; if(typeof module!=='undefined') module.exports=api;
})(globalThis);
