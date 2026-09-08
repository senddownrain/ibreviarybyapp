// Read-only export using the original pure MyBrev calendar implementation.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
const reference=path.resolve(here,'../../../mybrev');
const calendar=await import(pathToFileURL(path.join(reference,'src/utils/liturgicalCalendar.js')));
const {default:moment}=await import(pathToFileURL(path.join(reference,'src/utils/moment-be.js')));
const options={year:2026,easterSunday:'2026-04-05',pentecost:'2026-05-24',firstAdventSunday:'2026-11-29',ashWednesday:'2026-02-18',ordintaryWeeks1:6,ordintaryWeeks2:9}; // test/liturgical_calendar_test.dart
const maxWeeks={ordinary:34,advent:3,christmas:0,lent:5,holyweek:1,easter:7};
const coordinates={},contexts={},fixed=[];
for(const [period,max] of Object.entries(maxWeeks))for(let week=1;week<=max;week++)for(let day=period==='holyweek'?2:1;day<=7;day++)coordinates[`${period}:${week}:${day}`]=calendar.calculateDateForContext(2026,period,week,day,options,null);
for(let date=moment('2026-01-01');date.year()===2026;date.add(1,'day'))contexts[date.format('YYYY-MM-DD')]=calendar.computeLiturgicalContext(date,options,null,{});
const seen=new Set();
for(const filename of fs.readdirSync(path.join(reference,'patchs/db-feasts')).filter(x=>x.endsWith('.json'))){
  const d=JSON.parse(fs.readFileSync(path.join(reference,'patchs/db-feasts',filename),'utf8').replace(/^\uFEFF/,''));
  if(!d._date||!d._feastName)continue;
  const [day,month]=d._date.split('.').map(Number),key=[d._date,d._feastName,d._rank].join('|');
  let item=fixed.find(x=>x.key===key);
  if(!item){item={key,id:d._id||filename.replace('.json',''),title:d._feastName,date:`2026-${String(month).padStart(2,'0')}-${String(day).padStart(2,'0')}`,rank:d._rank||'',place:d._place||null,templates:[],source:'fixed'};fixed.push(item);}
  for(const template of d._templates||[])if(!item.templates.includes(template))item.templates.push(template);
}
fixed.sort((a,b)=>a.date.localeCompare(b.date)||a.title.localeCompare(b.title));
const easter=moment(options.easterSunday),pentecost=moment(options.pentecost);
const dynamic=[['easterSunday','Вялікдзень',easter],['pentecost','Спасланне Святога Духа',pentecost],['ashWednesday','Попельная серада',moment(options.ashWednesday)],['palmSunday','Нядзеля Пальмовая',easter.clone().subtract(7,'days')],['ascension','Узнясенне',pentecost.clone().subtract(7,'days')],['holyTrinity','Найсвяцейшая Тройца',pentecost.clone().add(7,'days')],['corpusChristi','Божае Цела',pentecost.clone().add(11,'days')],['sacredHeartOfJesus','Найсвяцейшае Сэрца Езуса',pentecost.clone().add(19,'days')],['immaculateHeartOfMary','Беззаганнае Сэрца Марыі',pentecost.clone().add(20,'days')],['christKing','Хрыстус Кароль',moment(options.firstAdventSunday).subtract(7,'days')],['christTheHighPriest','Хрыстус Вялікі Святар',pentecost.clone().add(4,'days')],['holyFamily','Святая Сям’я',calendar.calculateHolyFamilyDate(2026)],['baptismOfLord','Хрышчэнне Пана',calendar.calculateBaptismOfLordDate(2026)]].map(([id,title,date])=>({id,title,date:date.format('YYYY-MM-DD'),source:'dynamic'}));
const exact={advent:Array.from({length:8},(_,i)=>`2026-12-${17+i}`),lent:Array.from({length:4},(_,i)=>moment(options.ashWednesday).add(i,'days').format('YYYY-MM-DD')),christmas:[]};
for(let d=moment('2026-12-25');d.isSameOrBefore(calendar.calculateBaptismOfLordDate(2027));d.add(1,'day'))exact.christmas.push(d.format('YYYY-MM-DD'));
fs.writeFileSync(path.join(here,'calendar-fixtures.js'),'globalThis.UX_CALENDAR = '+JSON.stringify({year:2026,options,maxWeeks,coordinates,contexts,fixed,dynamic,exact,provenance:'Original MyBrev pure liturgicalCalendar.js; year options from Flutter calendar tests; fixed metadata from public db-feasts patches. Dynamic configured-date fallback follows stores/calendar.js; no live yearOptions.'})+';\n');
console.log(`Exported ${fixed.length} fixed celebrations, ${dynamic.length} dynamic celebrations and ${Object.keys(coordinates).length} period coordinates.`);
