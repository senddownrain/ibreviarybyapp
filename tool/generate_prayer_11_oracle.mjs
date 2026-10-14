// Local read-only oracle. No Firebase, credentials, snapshots or network.
// node tool/generate_prayer_11_oracle.mjs <MyBrev checkout at pinned commit>
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';

const web = resolve(process.argv[2]);
const commit = '0fcce378d6dd4b6f3d67a35fb45e44f49c5da4af';
if (execFileSync('git', ['rev-parse', 'HEAD'], { cwd: web, encoding: 'utf8' }).trim() !== commit) throw Error('Wrong web ref');
execFileSync('git', ['diff', '--exit-code', commit, '--', 'src/utils/prayerMarkdown.js', 'src/utils/prayerLegacyFormatting.js'], { cwd: web });
const { renderPrayerMarkdown } = await import(pathToFileURL(resolve(web, 'src/utils/prayerMarkdown.js')));
const cases = [];
function add(name, source, format = 'mybrev-markdown') {
  cases.push({ name, source, format, expectedHtml: renderPrayerMarkdown(source, format) });
}
for (const label of ['К.', 'С.', 'Н.', 'Д.', 'Л.', 'Ц.', 'V.', 'R.', 'Усе:', 'Цэлебрант:']) {
  for (const wrapper of ['', '**', '__', '*', '_', '**_', '_**']) {
    const close = wrapper.split('').reverse().join('');
    add(`${label} label ${wrapper}`, `${wrapper}${label}${close} Пан з вамі.\n${wrapper}${label}${close} _Амэн._`);
  }
  for (const wrapper of ['**', '__', '*', '_']) {
    add(`${label} utterance ${wrapper}`, `${wrapper}${label} Пан з вамі.${wrapper}`);
    add(`${label} multiline ${wrapper}`, `${wrapper}${label} Першы радок,\nдругі радок.${wrapper}`);
  }
  add(`${label} quote`, `> ${label} Пан з вамі.\n> > ${label} _Амэн._`);
  add(`${label} quote wrapper`, `> **${label}** Пан з вамі.`);
  add(`${label} standalone`, `${label}\nПане, пачуй нас.\n${label === 'Н.' ? 'К.' : 'Н.'}\nАмэн.`);
  add(`${label} isolated`, `**${label}**\nПане, пачуй нас.`);
}
for (const label of ['К.', 'С.', 'Н.', 'Д.', 'Л.', 'Ц.', 'V.', 'R.']) {
  for (const wrapper of ['**', '_', '**_']) {
    const close = wrapper.split('').reverse().join('');
    add(`${label} inside colon ${wrapper}`, `${wrapper}${label}:${close} Пан з вамі.`);
    add(`${label} outside colon ${wrapper}`, `${wrapper}${label}${close}: Пан з вамі.`);
  }
}
const directions = ['Усе ўстаюць.', 'Усе кленчаць.', 'Усе садзяцца.', 'Усе моляцца ў цішыні.', 'Святар кажа:', 'Святар гаворыць:', 'Цэлебрант кажа:', 'Цэлебрант гаворыць:', 'Народ адказвае:', 'Усе адказваюць:', 'Кантар спявае:', 'Дыякан кажа:', 'Лектар чытае:'];
for (const direction of directions) {
  add(direction, direction);
  add(`em ${direction}`, `_${direction}_`);
  add(`quote ${direction}`, `> ${direction}`);
  add(`continuation ${direction}`, `${direction}\nСловы.`);
}
const negatives = ['С. Я. Купала', 'К. Купала', 'С. Купала Янка', '**С. Імя:** _Словы апавядання._', 'С. Імя: _Словы апавядання._', '**V. Заканчэнне**', '**I. Пачатак**\n\n**V. Заканчэнне**', 'C. Пан з вамі.', 'K. Пан з вамі.', 'N. Name', 'H. І з духам тваім.', 'P. Dominus vobiscum.', 'с. пан з вамі.', '[С. Пан з вамі.](/prayer/id)', '`Н. І з духам тваім.`', '# С. Пан з вамі.', '- **С.** Пан з вамі.', '    Н. І з духам тваім.', '```\n**Н.** І з духам тваім.\n```', ':::rubric\n**Н.** І з духам тваім.\n:::', '**С.**', '_Молімся:_', '_Вітай, Марыя…_', 'Народ моліцца.', 'Усемагутны Божа, народ спявае хвалу Табе.', 'Цэлебрант можа акрапіць дзяцей асвячанай вадой.', '*С.: Словы малітвы,**Усе: Словы адказу!*', '> Н.\n> Амэн.\n> К.\n> Пане, пачуй нас.', '**С.**\n[Словы](/prayer/id)\nН. Амэн.', '**С.**\nПане, пачуй нас.\n\nН. Амэн.', 'К.\nН. Амэн.', '**Тэкст\nН. І з духам тваім.**', '**С.: Пан з вамі.**\n**Н.: І з духам тваім.**', '  **С.:**\tПан з вамі.'];
for (const [i, source] of negatives.entries()) add(`protected/context ${i}`, source);
const shapes = JSON.parse(readFileSync(resolve(web, 'tests/fixtures/prayer-legacy-shapes.json'), 'utf8'));
for (const shape of shapes.examples) add(`web corpus shape ${shape.kind}`, shape.before);
const html = [
  '<p><strong>С.:</strong> Пане, пачуй нас.</p><p><em>Молімся.</em> <a href="/prayer/target" title="Іншая">Малітва</a></p>',
  '<p><b>Н.: Амэн.</b></p><p><i>К.</i> Пане, пачуй нас.</p>',
  '<p class="rubric"><em>Усе ўстаюць.</em> <a href="/prayer/target">Малітва</a></p>',
  '<p class="mass-rubric-line">Лектар чытае:</p><p><em>Молімся.</em></p>',
  '<blockquote><p>Н. І з духам тваім.</p><p><b>С.</b> Пан з вамі.</p></blockquote>',
  '<h2>Літанія</h2><p><b>С.</b> Пан з вамі.<br><i>Н.</i> І з духам тваім.</p>',
  '<ul><li><p class="rubric"><em>Усе ўстаюць.</em></p></li><li><b>Н.</b> Амэн.</li></ul>',
  '<pre><code>Н. Амэн.\nsome_identifier</code></pre><p><code>К. Пан з вамі.</code></p>',
  '<p style="color:red"><span>С. Пан з вамі.</span></p><p><font color="red">Молімся.</font></p>',
  '<p>Н. <strong>Амэн.</strong> <a href="https://example.org/a_(b)" title="External">Іншая</a></p>',
];
for (const [i, source] of html.entries()) add(`legacy HTML ${i}`, source, 'html');
writeFileSync('test/support/prayer_11_web_oracle.json', JSON.stringify({ webCommit: commit, provenance: 'Synthetic and anonymized web structural cases; expected HTML generated by the pinned web renderer, not by Flutter.', cases }, null, 2) + '\n');
console.log(`Generated ${cases.length} cases from ${commit}`);
