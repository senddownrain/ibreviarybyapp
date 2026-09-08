import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const tokens = JSON.parse(readFileSync(new URL('./mobile-design-tokens.json', import.meta.url), 'utf8'));
const rgb = hex => {
  assert.match(hex, /^#[0-9a-f]{6}$/i);
  return hex.slice(1).match(/../g).map(value => parseInt(value, 16));
};
const luminance = hex => {
  const [r, g, b] = rgb(hex).map(value => value / 255)
    .map(value => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
const contrast = (foreground, background) => {
  const [a, b] = [luminance(foreground), luminance(background)];
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
};
const blend = (foreground, background, opacity) => {
  const back = rgb(background);
  return '#' + rgb(foreground).map((value, index) =>
    Math.round(value * opacity + back[index] * (1 - opacity)).toString(16).padStart(2, '0')).join('');
};
const checks = [];
const check = (name, fg, bg, minimum) => {
  const ratio = contrast(fg, bg);
  checks.push({name, ratio: Number(ratio.toFixed(2)), minimum});
  assert.ok(ratio >= minimum, `${name}: ${ratio.toFixed(2)} < ${minimum}`);
};

for (const mode of ['light', 'dark']) {
  const p = tokens.colors[mode];
  Object.values(p).forEach(rgb);
  const ambient = tokens.ambient[mode];
  const ambientPage = blend(ambient.color, p.page, ambient.peakOpacity);
  for (const fg of ['ink', 'muted']) check(`${mode}.${fg}/ambientPeak`, p[fg], ambientPage, 4.5);
  for (const fg of ['ink', 'muted']) {
    for (const bg of ['page', 'reader', 'standard', 'elevated', 'floating']) {
      check(`${mode}.${fg}/${bg}`, p[fg], p[bg], 4.5);
    }
    for (const bg of ['standard', 'elevated', 'floating']) {
      check(`${mode}.${fg}/${bg}.pressed`, p[fg], blend(p.primary, p[bg], tokens.opacity.androidPressed), 4.5);
    }
  }
  for (const [fg, bg, minimum] of [
    ['onPrimary', 'primary', 4.5], ['rubric', 'reader', 4.5],
    ['rubric', 'rubricTint', 4.5], ['error', 'errorTint', 4.5],
    ['outline', 'standard', 3], ['ink', 'reader', 7],
  ]) check(`${mode}.${fg}/${bg}`, p[fg], p[bg], minimum);
  for (const [family, variants] of Object.entries(tokens.liturgical)) {
    const l = variants[mode];
    Object.values(l).forEach(rgb);
    for (const bg of ['reader', 'standard']) check(`${mode}.${family}.ink/${bg}`, l.ink, p[bg], 4.5);
    check(`${mode}.${family}.ink/tint`, l.ink, l.tint, 4.5);
    check(`${mode}.${family}.marker/reader`, l.marker, p.reader, 3);
  }
  const opacity = mode === 'light' ? tokens.surfaces.glass.fallbackLightOpacity : tokens.surfaces.glass.fallbackDarkOpacity;
  for (const backdrop of ['#000000', '#FFFFFF']) {
    const composed = blend(p.standard, backdrop, opacity);
    check(`${mode}.ink/glassFallback(${backdrop})`, p.ink, composed, 4.5);
  }
}

assert.equal(tokens.surfaces.reader.opacity, 1);
assert.equal(tokens.surfaces.reader.blurSigma, 0);
assert.equal(tokens.surfaces.glass.platform, 'ios only');
assert.equal(tokens.policies.liturgicalColorsAffectPrimary, false);
assert.equal(tokens.policies.runtimeFontDownload, false);
assert.equal(tokens.ambient.requiredDefault, true);
assert.equal(tokens.ambient.underReaderBody, false);
assert.equal(tokens.policies.floatingDockBothPlatforms, true);
assert.ok(tokens.layout.customTouchTargetMin >= 48);
assert.ok(tokens.typography.scaling.min < 1 && tokens.typography.scaling.max > 1);
assert.equal(tokens.motion.fontResize, 0);

console.log(JSON.stringify({
  status: 'passed',
  contrastChecks: checks.length,
  lowestTextContrast: Math.min(...checks.filter(c => c.minimum === 4.5).map(c => c.ratio)),
  readerBodyContrast: checks.filter(c => c.minimum === 7),
  limits: 'Token and numeric composition checks only. Native glass, rendered layouts, fonts and device accessibility require separate QA.'
}, null, 2));
