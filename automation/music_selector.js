const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.resolve(__dirname, '..');
const catalog = JSON.parse(fs.readFileSync(path.join(__dirname, 'music_catalog.json'), 'utf8'));
const historyPath = path.join(__dirname, 'music-history.jsonl');
function readHistory() {
  if (!fs.existsSync(historyPath)) return [];
  return fs.readFileSync(historyPath, 'utf8').split(/\r?\n/).filter(Boolean).map(line => JSON.parse(line));
}
function inferMoods(job) {
  const text = `${job.article.title} ${job.article.description || ''} ${job.pages.page1.breaking_label}`.toLowerCase();
  const moods = new Set(['analysis', 'premium']);
  if (/ai|반도체|엔비디아|기술|tech|gpu|h200/.test(text)) moods.add('tech');
  if (/긴급|속보|급등|급락|규제|breaking/.test(text)) moods.add('urgent');
  if (/중국|수출|미국|글로벌|해외/.test(text)) moods.add('future');
  return [...moods];
}
function chooseMusic(job) {
  if (job.music?.selection?.id) return job.music.selection;
  const history = readHistory();
  const used = new Set(history.map(item => item.track_id));
  const moods = inferMoods(job);
  let candidates = catalog.tracks.filter(track => !used.has(track.id) && track.moods.some(mood => moods.includes(mood)));
  if (!candidates.length) candidates = catalog.tracks.filter(track => !used.has(track.id));
  if (!candidates.length) candidates = catalog.tracks;
  const seed = crypto.randomBytes(4).readUInt32BE(0);
  const selection = candidates[seed % candidates.length];
  return { ...selection, selected_at: new Date().toISOString(), target_moods: moods };
}
function recordMusic(job, applied) {
  if (!applied || !job.music?.selection?.id) return;
  const history = readHistory();
  if (history.some(item => item.article_id === job.article.article_id && item.track_id === job.music.selection.id)) return;
  const event = { recorded_at: new Date().toISOString(), article_id: job.article.article_id, track_id: job.music.selection.id };
  fs.appendFileSync(historyPath, `${JSON.stringify(event)}\n`, 'utf8');
}
module.exports = { chooseMusic, recordMusic };
