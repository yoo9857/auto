/*
 * Meta (Instagram Graph API) carousel publisher.
 * Publishes the 5-page carousel (01 hook, 02 video, 03 analysis, 04 judgment,
 * 05 cta) with the 06 caption to @onedaytrading.io via the Instagram Content
 * Publishing API.
 *
 * Meta fetches media from PUBLIC URLs — local files cannot be uploaded directly.
 * So the DB assets must first be reachable at public https URLs.
 *
 * Env:
 *   ODT_IG_USER_ID              Instagram Business/Creator account id (numeric)
 *   ODT_INSTAGRAM_ACCESS_TOKEN  long-lived token w/ instagram_content_publish
 *   ODT_META_API_VERSION        optional, default from config (v24.0)
 *
 * Usage:
 *   node automation/meta_instagram_publisher.js <dbDir> --base-url https://onedaytrading.net/i/ig/<id>
 *   node automation/meta_instagram_publisher.js <dbDir> --manifest urls.json
 *   add --publish to actually post (otherwise dry-run prints the plan)
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const CONFIG = JSON.parse(fs.readFileSync(path.join(ROOT, 'automation', 'config.json'), 'utf8').replace(/^﻿/, ''));

function opt(name, fb) { const i = process.argv.indexOf(name); return i >= 0 ? process.argv[i + 1] : fb; }
const HAS = n => process.argv.includes(n);
const sleep = ms => new Promise(r => setTimeout(r, ms));

// Ordered carousel items: page 2 is the video, the rest are images.
const ORDER = [
  { file: '01-훅.png', type: 'image' },
  { file: '02-영상.mp4', type: 'video' },
  { file: '03-분석.png', type: 'image' },
  { file: '04-판단.png', type: 'image' },
  { file: '05-마무리.png', type: 'image' }
];

function readCaption(dir) {
  const p = path.join(dir, '06-캡션.md');
  if (!fs.existsSync(p)) return '';
  const lines = fs.readFileSync(p, 'utf8').replace(/^﻿/, '').split(/\r?\n/);
  // Drop the markdown title line; keep caption body + hashtags as the IG caption.
  return lines.filter(l => !/^#\s/.test(l)).join('\n').replace(/\n{3,}/g, '\n\n').trim();
}

function resolveUrls(dir) {
  const manifest = opt('--manifest', '');
  if (manifest) {
    const m = JSON.parse(fs.readFileSync(manifest, 'utf8').replace(/^﻿/, ''));
    return ORDER.map(o => ({ ...o, url: m[o.file] })).filter(o => o.url);
  }
  const base = opt('--base-url', '');
  if (!base) throw new Error('공개 URL이 필요합니다: --base-url <https://.../> 또는 --manifest <urls.json>');
  const b = base.replace(/\/$/, '');
  return ORDER.filter(o => fs.existsSync(path.join(dir, o.file)))
    .map(o => ({ ...o, url: `${b}/${encodeURIComponent(o.file)}` }));
}

async function graph(pathname, params, token, method = 'POST') {
  const version = process.env.ODT_META_API_VERSION || CONFIG.instagram.api_version || 'v24.0';
  const url = `https://graph.facebook.com/${version}/${pathname}`;
  const body = new URLSearchParams({ ...params, access_token: token });
  const res = await fetch(url, method === 'GET' ? undefined : { method, body });
  const data = await res.json();
  if (!res.ok || data.error) throw new Error(`Graph ${pathname} 오류: ${JSON.stringify(data.error || data)}`);
  return data;
}

async function createItemContainer(igId, token, item) {
  const params = item.type === 'video'
    ? { media_type: 'VIDEO', video_url: item.url, is_carousel_item: 'true' }
    : { image_url: item.url, is_carousel_item: 'true' };
  const { id } = await graph(`${igId}/media`, params, token);
  return id;
}

async function waitReady(containerId, token, label) {
  const version = process.env.ODT_META_API_VERSION || CONFIG.instagram.api_version || 'v24.0';
  for (let i = 0; i < 30; i++) {
    const res = await fetch(`https://graph.facebook.com/${version}/${containerId}?fields=status_code&access_token=${encodeURIComponent(token)}`);
    const data = await res.json();
    if (data.status_code === 'FINISHED') return;
    if (data.status_code === 'ERROR') throw new Error(`${label} 처리 실패`);
    console.log(`  ...${label} 처리 중 (${data.status_code || '?'})`);
    await sleep(5000);
  }
  throw new Error(`${label} 처리 대기 시간 초과`);
}

async function main() {
  const dir = process.argv[2];
  if (!dir || dir.startsWith('--')) throw new Error('사용법: node automation/meta_instagram_publisher.js <dbDir> --base-url <https://.../> [--publish]');
  const items = resolveUrls(dir);
  if (items.length < 2) throw new Error(`캐러셀은 항목 2개 이상 필요 (현재 ${items.length}).`);
  const caption = readCaption(dir);

  console.log(`대상 계정: ${CONFIG.instagram.handle}`);
  console.log(`캐러셀 ${items.length}장:`);
  items.forEach((it, i) => console.log(`  ${i + 1}. [${it.type}] ${it.file} -> ${it.url}`));
  console.log(`\n캡션(${caption.length}자):\n${caption}\n`);

  if (!HAS('--publish')) {
    console.log('[DRY-RUN] --publish 를 붙이면 실제 발행합니다. (토큰·IG 계정 ID·공개 URL 필요)');
    return;
  }

  const igId = process.env.ODT_IG_USER_ID;
  const token = process.env[CONFIG.instagram.access_token_env] || process.env.ODT_INSTAGRAM_ACCESS_TOKEN;
  if (!igId) throw new Error('ODT_IG_USER_ID 환경변수가 없습니다.');
  if (!token) throw new Error(`${CONFIG.instagram.access_token_env} 환경변수가 없습니다.`);

  console.log('1) 항목 컨테이너 생성...');
  const childIds = [];
  for (const it of items) {
    const id = await createItemContainer(igId, token, it);
    if (it.type === 'video') await waitReady(id, token, it.file);
    childIds.push(id);
    console.log(`  ${it.file} -> ${id}`);
  }

  console.log('2) 캐러셀 컨테이너 생성...');
  const { id: carouselId } = await graph(`${igId}/media`, { media_type: 'CAROUSEL', children: childIds.join(','), caption }, token);
  await waitReady(carouselId, token, 'carousel');

  console.log('3) 발행...');
  const published = await graph(`${igId}/media_publish`, { creation_id: carouselId }, token);
  console.log(`발행 완료. media_id=${published.id}`);
  process.stdout.write(JSON.stringify({ media_id: published.id, tracking: `${CONFIG.instagram.tracking_prefix}-${path.basename(dir)}` }) + '\n');
}

main().catch(err => { console.error(err.message || err); process.exit(1); });
