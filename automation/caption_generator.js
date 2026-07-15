/* Natural-language Instagram caption and hashtag planner.
 * Uses five relevant tags only, avoiding keyword stuffing.
 */
const STOP_WORDS = new Set(['news', 'stock', 'market', 'global', 'update', 'breaking', 'today', 'the', 'and', 'with', 'from', 'into', 'after', 'over']);
function clean(value = '') { return String(value).replace(/\s+/g, ' ').trim(); }
function articleText(job) { return clean([job.article?.title, job.article?.description, job.pages?.page1?.headline, job.pages?.page1?.subtitle].join(' ')).toLowerCase(); }
function topicFor(job) {
  const text = articleText(job);
  if (/nvidia|h100|h200|blackwell|gpu|semiconductor|chip|ai\b/.test(text)) return 'semiconductor';
  if (/fed|fomc|inflation|cpi|ppi|interest rate|bond|yield|dollar/.test(text)) return 'macro';
  if (/bitcoin|ethereum|crypto|virtual asset/.test(text)) return 'crypto';
  if (/earnings|revenue|guidance|quarter|profit|sales/.test(text)) return 'earnings';
  return 'markets';
}
function topicTags(job) {
  const text = articleText(job);
  const tagMap = {
    semiconductor: ['#AI\ubc18\ub3c4\uccb4', '#\ubc18\ub3c4\uccb4\uc8fc', '#\ubbf8\uad6d\uc99d\uc2dc', '#\uae00\ub85c\ubc8c\uc99d\uc2dc'],
    macro: ['#\ubbf8\uad6d\uc99d\uc2dc', '#\uae08\ub9ac\uc804\ub9dd', '#\uae00\ub85c\ubc8c\uacbd\uc81c', '#\uc2dc\uc7a5\ubd84\uc11d'],
    crypto: ['#\ube44\ud2b8\ucf54\uc778', '#\uac00\uc0c1\uc790\uc0b0', '#\uae00\ub85c\ubc8c\uc99d\uc2dc', '#\uc2dc\uc7a5\ubd84\uc11d'],
    earnings: ['#\ubbf8\uad6d\uc8fc\uc2dd', '#\uc2e4\uc801\ubc1c\ud45c', '#\uae00\ub85c\ubc8c\uc99d\uc2dc', '#\ud22c\uc790\uc804\ub7b5'],
    markets: ['#\ud574\uc678\uc8fc\uc2dd', '#\ubbf8\uad6d\uc99d\uc2dc', '#\uae00\ub85c\ubc8c\uc99d\uc2dc', '#\uc2dc\uc7a5\ubd84\uc11d']
  };
  const tags = [...tagMap[topicFor(job)]];
  return tags;
}
function keyPhrase(job) {
  const title = clean(job.article?.title || job.pages?.page1?.headline || '');
  const words = title.split(/[\s,·|:/()[\]{}]+/).filter(word => word.length >= 2 && !STOP_WORDS.has(word.toLowerCase()));
  return clean(words.slice(0, 4).join(' ')) || '\uc2dc\uc7a5 \ud575\uc2ec \uc7ac\ub8cc';
}
function createCaption(job) {
  return createDetailedCaption(job);
  const headline = clean(job.pages?.page1?.headline || job.article?.title);
  const subtitle = clean(job.pages?.page1?.subtitle || job.article?.description);
  const breaking = clean(job.pages?.page1?.breaking_label || '\uae34\uae09\uc18d\ubcf4');
  const tracking = job.instagram_tracking?.code || `ODT-${job.article?.article_id || 'BRIEF'}`;
  const focus = keyPhrase(job);
  const hashtags = topicTags(job);
  const caption = [
    breaking, headline, subtitle,
    `\uc774\ubc88 \uc774\uc288\uc758 \ud575\uc2ec\uc740 ${focus}\uc785\ub2c8\ub2e4. \ub2e8\uae30 \ud5e4\ub4dc\ub77c\uc778\ubcf4\ub2e4 \uc2e4\uc801\u00b7\uc218\uae09\u00b7\uc815\ucc45\uc5d0 \ubc18\uc601\ub418\ub294 \uc21c\uc11c\ub97c \ud568\uaed8 \ubcf4\uc544\uc57c \ud569\ub2c8\ub2e4.`,
    '\uce74\ub4dc\uc5d0\uc11c \uc0ac\uc2e4, \ubc30\uacbd, \ub2e4\uc74c \ud655\uc778 \ud3ec\uc778\ud2b8\ub97c \ucc28\ub840\ub85c \uc815\ub9ac\ud588\uc2b5\ub2c8\ub2e4. \uc800\uc7a5\ud574 \ub450\uace0 \ud6c4\uc18d \ub274\uc2a4\uc640 \uc2dc\uc7a5 \ubc18\uc751\uc744 \ud568\uaed8 \ud655\uc778\ud558\uc138\uc694.',
    `ODT INSIGHT | ${tracking}`, hashtags.join(' ')
  ].filter(Boolean).join('\n\n');
  return { caption, topic: topicFor(job), focus, hashtags, tracking };
}
function unique(items) { return [...new Set(items.filter(Boolean))]; }
function buildHashtags(job) {
  const text = articleText(job);
  const entities = [];
  if (/nvidia|\uc5d4\ube44\ub514\uc544/.test(text)) entities.push('#\uc5d4\ube44\ub514\uc544');
  if (/\bh200\b/.test(text)) entities.push('#H200');
  if (/\bh100\b/.test(text)) entities.push('#H100');
  if (/tesla|\ud14c\uc2ac\ub77c/.test(text)) entities.push('#\ud14c\uc2ac\ub77c');
  if (/apple|\uc560\ud50c/.test(text)) entities.push('#\uc560\ud50c');
  if (/\uc911\uad6d|china/.test(text)) entities.push('#\uc911\uad6d\uc2dc\uc7a5');
  const topicTagsForArticle = topicTags(job);
  const orderedTopics = [topicTagsForArticle[0], ...topicTagsForArticle.slice(2), topicTagsForArticle[1]];
  const fallback = job.article?.market_label === '\ud574\uc678\uc8fc\uc2dd' ? '#\ud574\uc678\uc8fc\uc2dd' : '#\ud22c\uc790\ubd84\uc11d';
  return unique([...entities, ...orderedTopics, fallback]).slice(0, 5);
}
function bullet(items) { return items.filter(Boolean).map(item => `• ${clean(item)}`).join('\n'); }
function createDetailedCaption(job) {
  const page2 = job.pages?.page2 || {};
  const page3 = job.pages?.page3 || {};
  const headline = clean(job.pages?.page1?.headline || job.article?.title);
  const subtitle = clean(job.pages?.page1?.subtitle || job.article?.description);
  const breaking = clean(job.pages?.page1?.breaking_label || '\uae34\uae09\uc18d\ubcf4');
  const tracking = job.instagram_tracking?.code || `ODT-${job.article?.article_id || 'BRIEF'}`;
  const facts = (job.evidence || []).map(item => item.statement).slice(0, 3);
  const analysis = (page2.paragraphs || []).slice(0, 2);
  const tags = buildHashtags(job);
  const source = clean(job.article?.source_name);
  const caption = [
    `${breaking}\n${headline}`,
    subtitle,
    `[ODT \ud310\ub2e8] ${clean(page3.evaluation_summary || page2.quick_answer)}`,
    facts.length ? `\ubb34\uc2a8 \uc77c\uc774 \uc788\uc5c8\ub098\n${bullet(facts)}` : '',
    analysis.length ? `\uc65c \uc2dc\uc7a5\uc774 \uc8fc\ubaa9\ud558\ub098\n${analysis.join('\n')}` : '',
    `\ub2e4\uc74c \ud655\uc778 \ud3ec\uc778\ud2b8\n• \uae30\ub300: ${clean(page3.expect)}\n• \ud655\uc778: ${clean(page3.verify)}\n• \ud310\ub2e8: ${clean(page3.judge)}`,
    '\uce74\ub4dc\uc5d0\uc11c \uc0ac\uc2e4\u2192\ubc30\uacbd\u2192\ud310\ub2e8 \uae30\uc900\uc744 \uc21c\uc11c\ub300\ub85c \ud655\uc778\ud558\uc138\uc694. \uc800\uc7a5\ud574 \ub450\uba74 \ud6c4\uc18d \uc2e4\uc801\u00b7\uc815\ucc45 \ub274\uc2a4\ub97c \ube44\uad50\ud558\uae30 \uc88b\uc2b5\ub2c8\ub2e4.',
    source ? `\ucd9c\ucc98: ${source}` : '',
    `ODT INSIGHT | ${tracking}`,
    tags.join(' ')
  ].filter(Boolean).join('\n\n');
  return { caption, topic: topicFor(job), focus: keyPhrase(job), hashtags: tags, tracking, facts_included: facts.length, source };
}
module.exports = { createCaption };
