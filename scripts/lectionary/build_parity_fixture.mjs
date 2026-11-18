#!/usr/bin/env node
/**
 * Web ↔ Flutter Lectionary parity fixture (read-only on the web checkout).
 *
 * For every date 2025–2035 × four dioceses and every legal Mass option of the
 * generative Ordo engine, this runs the web's OWN Readings pipeline
 * (`planReadings → readingQueriesOfPlan → orderReadingsByPlan →
 * resolveReadingsScreen`, the pure modules the web view binds) on the
 * production snapshot and records what the screen shows: reading groups, the
 * active group, the canonical document, ALL set ids / contexts / defaults, the
 * selected set, the available and the active cycle and — for the view that
 * is rendered — the ordered structured sections with a hash of their full
 * semantic content (citation, text, refrain, verses, sequence, acclamation,
 * Passion roles, rubrics, alternatives, …).
 *
 *   node scripts/lectionary/build_parity_fixture.mjs \
 *     --web ../mybrev --snapshot ../mybrev-lectionary/.cache/prod-snapshot-20261012 \
 *     --out test/fixtures/lectionary_parity.json.gz [--from 2025 --to 2035]
 *
 * Nothing is written inside the web checkout or to Firestore. The fixture is
 * a test artefact, not app content.
 */
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';
import zlib from 'node:zlib';
import { resolveWeb } from '../lib/web_source.mjs';

function parseArgs(argv) {
  const options = { web: null, snapshot: null, out: null, from: 2025, to: 2035 };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--web') options.web = argv[++index];
    else if (arg === '--snapshot') options.snapshot = argv[++index];
    else if (arg === '--out') options.out = argv[++index];
    else if (arg === '--from') options.from = Number(argv[++index]);
    else if (arg === '--to') options.to = Number(argv[++index]);
  }
  if (!options.web || !options.snapshot || !options.out) {
    throw new Error('Usage: build_parity_fixture.mjs --web <mybrev> --snapshot <dir> --out <file.json.gz> [--from Y --to Y]');
  }
  return options;
}

const options = parseArgs(process.argv.slice(2));
const source = resolveWeb(process.argv.slice(2));
const WEB = source.web;
const web = (rel) => import(pathToFileURL(path.join(WEB, rel)).href);

const { openFirestoreSnapshot } = await web('scripts/lib/firestore-snapshot.mjs');
const appContent = await web('scripts/content/lib/app-content.mjs');
const { generateLiturgicalYear } = await web('src/utils/ordo/index.js');
const { setCalendarDefinitions } = await web('src/utils/ordo/definitions.js');
const { planReadings } = await web('src/utils/ordo/runtime.js');
const { orderReadingsByPlan, readingQueriesOfPlan, readingsNotice } = await web('src/utils/ordo/readingsPlan.js');
const identity = await web('src/utils/parsedReadingsIdentity.js');
const { resolveReadingsScreen } = await web('src/utils/readingsScreen.js');
const { queryReadings } = await web('scripts/lectionary/lib/runtime-sim.mjs');
const { contentFor, openLiturgySource } = await web('scripts/liturgy/lib/snapshot-content.mjs');
const { massReadingSetsOf, setCycles } = await web('src/utils/massReadingSets.js');

const { canonicalJson } = appContent;
export const DIOCESES = ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk'];
const hash16 = (value) => createHash('sha256').update(value, 'utf8').digest('hex').slice(0, 16);

// ── Normalised semantic representation of a section ──────────────────────────
// The SAME function exists in Dart (`MassReadingSection.canonical`). A hash
// equality proves that the app's model kept every field the web renders.

const text = (value) => (typeof value === 'string' ? value.trim() : value === null || value === undefined ? '' : String(value).trim());

export function normalizeSection(data, { kind, role, cycle } = {}) {
  const out = {};
  if (kind) out.kind = kind;
  if (role) out.role = role;
  const sectionCycle = text(cycle ?? data?.cycle).toUpperCase();
  if (sectionCycle) out.cycle = sectionCycle;
  for (const key of ['year', 'form', 'label', 'bible', 'comment', 'title', 'text', 'chorus', 'altChorus', 'altChorusRef', 'acclamation', 'verse']) {
    const value = text(data?.[key]);
    if (value) out[key] = value;
  }
  if (typeof data?.conclusion === 'string') out.conclusion = data.conclusion.trim();
  const rubrics = (Array.isArray(data?.rubrics) ? data.rubrics : []).map(text).filter(Boolean);
  if (rubrics.length) out.rubrics = rubrics;
  const verses = (Array.isArray(data?.verses) ? data.verses : [])
    .map((verse) => (typeof verse === 'string' ? verse : text(verse?.text)))
    .map(text).filter(Boolean);
  if (verses.length) out.verses = verses;
  if (data?.legend === true) out.legend = true;
  const blocks = data?.passion?.blocks;
  if (Array.isArray(blocks) && blocks.length) {
    const legend = (Array.isArray(data.passion.legend) ? data.passion.legend : []).map(text);
    out.passion = {
      ...(legend.length ? { legend } : {}),
      blocks: blocks.map((block) => (block.type === 'paragraph'
        ? { type: 'paragraph', runs: (block.runs || []).map((run) => ({ role: text(run.role), text: text(run.text) })) }
        : { type: text(block.type), text: text(block.text) })),
    };
  }
  const alternatives = (Array.isArray(data?.alternatives) ? data.alternatives : [])
    .map((alternative) => normalizeSection(alternative));
  if (alternatives.length) out.alternatives = alternatives;
  return out;
}

export const sectionHash = (data, meta) => hash16(canonicalJson(normalizeSection(data, meta)));

// ── What the web card renders for a legacy (flat) document ───────────────────

const LEGACY_KIND = { psalm: 'psalm', alleluia: 'acclamation', gospel: 'gospel', sequence: 'sequence' };

export function legacySections(reading) {
  const readingKeys = Object.keys(reading)
    .filter((key) => /^reading\d+$/.test(key) && reading[key])
    .sort((left, right) => Number(left.replace('reading', '')) - Number(right.replace('reading', '')));
  const firstReading = readingKeys.filter((key) => key === 'reading1');
  const laterReadings = readingKeys.filter((key) => key !== 'reading1');
  const ordered = [
    ...firstReading,
    ...(reading.psalm ? ['psalm'] : []),
    ...laterReadings,
    ...(reading.sequence?.text ? ['sequence'] : []),
    ...(reading.alleluia ? ['alleluia'] : []),
    ...(reading.gospel ? ['gospel'] : []),
  ];
  return ordered.map((key) => ({
    kind: key.startsWith('reading') ? 'reading' : LEGACY_KIND[key],
    role: key,
    data: reading[key],
  }));
}

// ── Data ─────────────────────────────────────────────────────────────────────

const snapshot = await openFirestoreSnapshot(path.resolve(options.snapshot));
const entries = async (name) => ((await snapshot.collectionEntries(name)) || [])
  .map(({ id, data }) => appContent.storedDocument(id, data));
const [celebrations, dioceseOverrides, yearOverrides, readingsAll] = await Promise.all([
  entries('liturgicalCelebrations'), entries('liturgicalDioceseOverrides'), entries('liturgicalYearOverrides'), entries('readings'),
]);
// The engine runs on the published (snapshot) definitions, as the Ordo fixture.
setCalendarDefinitions({ celebrations, dioceseOverrides, yearOverrides });
// Firestore answers an equality query ordered by document id.
const docs = [...readingsAll]
  .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))
  .filter((doc) => doc._obsolete !== true)
  .map((doc) => ({ ...doc }))
  .filter(identity.hasReadingDocumentContent);

const hashesById = Object.fromEntries(readingsAll.map((doc) => [doc.id, appContent.documentHash(doc)]));
const digest = appContent.collectionDigest(hashesById);

// The Hours pipeline of the same snapshot: the day id of an option is what the
// Hours put in the Readings route (`?dayId=`), the Flutter app's only link.
const liturgy = await openLiturgySource({ snapshotDir: path.resolve(options.snapshot), propers: 'snapshot', templates: 'snapshot' });

// ── Tables (deduplicated) ────────────────────────────────────────────────────

const views = new Map(); // key → view
const screens = []; // distinct screen records
const screenIndex = new Map();
const lookups = []; // distinct plan lookups per option
const lookupIndex = new Map();
const intern = (list, index, value) => {
  const key = JSON.stringify(value);
  if (!index.has(key)) { index.set(key, list.length); list.push(value); }
  return index.get(key);
};

function viewOf(screen) {
  const reading = screen.activeReading;
  if (!reading) return null;
  const structured = Array.isArray(reading._sections);
  const key = structured
    ? `${reading.id}|${reading._setId}|${screen.activeCycle || ''}`
    : `${reading.id}|-|${normalizeCycle(reading.year)}`;
  if (!views.has(key)) {
    const sections = structured
      ? reading._sections.map((section, index) => [
        index, section.kind, section.role || '', section.cycle || '', sectionHash(section, { kind: section.kind, role: section.role, cycle: section.cycle }),
      ])
      : legacySections(reading).map((section, index) => [
        index, section.kind, section.role, '', sectionHash(section.data, { kind: section.kind, role: section.role }),
      ]);
    views.set(key, {
      doc: reading.id,
      set: structured ? reading._setId : null,
      label: structured ? reading._setLabel || '' : '',
      cycle: structured ? reading.year || '' : normalizeCycle(reading.year),
      referenceOnly: Boolean(reading._referenceOnly),
      sections,
    });
  }
  return key;
}

const normalizeCycle = (value) => identity.normalizeReadingCycle(value);

function screenRecord(screen) {
  const record = {
    g: screen.groups.map((group) => [group.key, group.documents.map((doc) => doc.id)]),
    a: screen.groups.indexOf(screen.activeGroup),
    sd: screen.setDocument?.id || null,
    st: (screen.sets || []).map((set) => [set.id, set.label || '', set.context || '', set.default === true ? 1 : 0, set.referenceOnly ? 1 : 0, setCycles(set).join('')]),
    as: screen.activeSet?.id || null,
    ac: screen.availableCycles.join(''),
    cy: screen.activeCycle || '',
    v: viewOf(screen),
  };
  return intern(screens, screenIndex, record);
}

// ── Main loop ────────────────────────────────────────────────────────────────

const started = Date.now();
const days = {};
const counters = { days: 0, options: 0, screens: 0 };
for (const diocese of DIOCESES) {
  days[diocese] = [];
  for (let year = options.from; year <= options.to; year += 1) {
    for (const day of generateLiturgicalYear(year, { country: 'BY', diocese })) {
      const hours = contentFor(liturgy, day.date, { diocese });
      const dayIdOf = (optionId) => hours.dayOptions.find((item) => item.ordo?.optionId === optionId)?.dayId || '';
      const planFor = (dayId, dayIdToOption) => planReadings(day, { dayId, ...(dayIdToOption ? { dayIdToOption } : {}) });
      const loadFor = (dayId) => {
        const plan = planFor(dayId);
        const pool = [...new Map(readingQueriesOfPlan(plan, { dayId })
          .flatMap((spec) => queryReadings(docs, spec)).map((doc) => [doc.id, doc])).values()];
        const context = { cycle: plan.cycle, sundayCycle: plan.sundayCycle, dayOfWeek: plan.dayOfWeek };
        const items = orderReadingsByPlan(plan, pool, {
          dayId,
          includeAlternatives: true,
          selectCalendarDayVariants: identity.selectCalendarDayVariants,
          selectVariants: (list) => identity.selectReadingLectionaryVariants(list, context),
        });
        return { plan, pool, context, items };
      };
      const loaded = new Map();
      const loadedFor = (dayId) => {
        if (!loaded.has(dayId)) loaded.set(dayId, loadFor(dayId));
        return loaded.get(dayId);
      };
      const base = loadedFor('');
      const all = [day.primary, ...day.alternatives];
      const optionRecords = all.map((option, index) => {
        const planOption = base.plan.options[index];
        const noticePlan = planFor('', option.id);
        const notice = readingsNotice(noticePlan, base.pool);
        const dayId = dayIdOf(option.id);
        const viaDay = dayId ? loadedFor(dayId) : null;
        counters.options += 1;
        return {
          id: option.id,
          kind: option.kind,
          ok: option.officeKind,
          st: planOption.readingsStatus || '',
          lk: intern(lookups, lookupIndex, planOption.lookup.map((entry) => ({ p: entry.purpose, w: entry.where }))),
          nt: notice ? `${notice.status}${notice.reference ? ':ref' : ''}` : '',
          // by the ordo option id (the date picker route) …
          so: screenRecord(resolveReadingsScreen({ items: base.items, context: base.context, query: { option: option.id } })),
          // … and by the Hours day id (the route of the Hours → Readings link).
          ...(dayId ? {
            di: dayId,
            sd: screenRecord(resolveReadingsScreen({ items: viaDay.items, context: viaDay.context, query: { dayId } })),
          } : {}),
        };
      });
      counters.screens += all.length;
      days[diocese].push({
        date: day.date,
        cy: [day.readingCycle.sunday, day.readingCycle.weekday],
        dow: day.dayOfWeek,
        items: base.items.map((item) => item.id),
        pool: base.pool.length,
        d: screenRecord(resolveReadingsScreen({ items: base.items, context: base.context, query: {} })),
        o: optionRecords,
      });
      counters.days += 1;
    }
  }
}

const identityOfDoc = (doc) => ({
  id: doc.id,
  hash: hashesById[doc.id],
  sets: massReadingSetsOf(doc).map((set) => set.id),
});

const fixture = {
  schema: 1,
  generatedAt: new Date().toISOString(),
  web: {
    head: source.head,
    dataset: `readings@${digest}`,
    documents: readingsAll.length,
    snapshot: snapshot.manifest.snapshotVersion ?? String(Date.parse(snapshot.manifest.exportedAt)),
    exportedAt: snapshot.manifest.exportedAt,
  },
  years: [options.from, options.to],
  dioceses: DIOCESES,
  documents: docs.map(identityOfDoc),
  tables: { lookups, views: Object.fromEntries(views), screens },
  days,
  counters,
};
const gz = zlib.gzipSync(Buffer.from(JSON.stringify(fixture)), { level: 9 });
gz.writeUInt32LE(0, 4);
fs.mkdirSync(path.dirname(path.resolve(options.out)), { recursive: true });
fs.writeFileSync(options.out, gz);
console.log(JSON.stringify({
  out: options.out,
  ...counters,
  distinctScreens: screens.length,
  distinctViews: views.size,
  distinctLookups: lookups.length,
  bytes: gz.length,
  seconds: Math.round((Date.now() - started) / 1000),
}, null, 2));
