/*
 * Chrome-session Instagram publisher.
 * Login, password, and 2FA are always completed manually in the opened Chrome profile.
 * Actual external posting requires both an approved job and the explicit --confirm flag.
 */
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');
const { chooseMusic, recordMusic } = require('./music_selector');
const { createCaption } = require('./caption_generator');
const { inspectQueue, recordShared } = require('./db_upload_queue');

const ROOT = path.resolve(__dirname, '..');
const PROFILE = path.join(__dirname, 'chrome-instagram-profile');
const CHROME = process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const INSTAGRAM = 'https://www.instagram.com/';

function readJson(file) { return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')); }
function writeJson(file, data) { fs.writeFileSync(file, JSON.stringify(data, null, 2), 'utf8'); }
function option(name) { const index = process.argv.indexOf(name); return index >= 0 ? process.argv[index + 1] : ''; }
function has(name) { return process.argv.includes(name); }
function waitForEnter(message) {
  return new Promise(resolve => {
    const prompt = readline.createInterface({ input: process.stdin, output: process.stdout });
    prompt.question(message, () => { prompt.close(); resolve(); });
  });
}
function escapeRegex(text) { return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
function validateFourByFive(files) {
  execFileSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(__dirname, 'validate_instagram_assets.ps1'), '-Paths', files.join('|')], { stdio: 'inherit' });
}

async function openChrome() {
  if (!fs.existsSync(CHROME)) throw new Error(`Chrome을 찾지 못했습니다: ${CHROME}`);
  return chromium.launchPersistentContext(PROFILE, {
    executablePath: CHROME,
    headless: has('--background'),
    viewport: { width: 1440, height: 980 },
    args: ['--disable-notifications']
  });
}
async function requireLoggedIn(page) {
  await page.goto(INSTAGRAM, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(2000);
  const loginVisible = await page.getByText(/log in|로그인/i).first().isVisible().catch(() => false);
  if (loginVisible) throw new Error('저장된 Instagram 로그인 세션이 없습니다. 먼저 setup 모드를 실행하세요.');
}
async function clickAny(page, names) {
  for (const name of names) {
    const locator = page.getByRole('button', { name: new RegExp(escapeRegex(name), 'i') }).first();
    if (await locator.isVisible().catch(() => false)) { await locator.click({ force: true }); return; }
    const aria = page.locator(`[aria-label="${name}"]`).first();
    if (await aria.isVisible().catch(() => false)) { await aria.click({ force: true }); return; }
    const icon = page.locator(`svg[aria-label="${name}"]`).first();
    if (await icon.isVisible().catch(() => false)) { await icon.click({ force: true }); return; }
  }
  throw new Error(`화면에서 버튼을 찾지 못했습니다: ${names.join(', ')}`);
}
async function clickNext(page) {
  for (const name of ['다음', 'Next']) {
    const buttons = page.locator(`button[aria-label="${name}"]:visible`);
    const count = await buttons.count();
    for (let index = 0; index < count; index += 1) {
      const box = await buttons.nth(index).boundingBox();
      if (box && box.y < 220) {
        await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
        return;
      }
    }
  }
  await clickAny(page, ['Next', '다음']);
}
async function ensureFourByFive(page) {
  const crop = page.locator('[aria-label="자르기 선택"]:visible').first();
  await crop.waitFor({ state: 'visible', timeout: 45000 }).catch(() => { throw new Error('4:5 crop selector is not available. Publishing stopped.'); });
  await crop.click({ force: true });
  const ratio = page.getByText('4:5', { exact: true }).last();
  await ratio.waitFor({ state: 'visible', timeout: 10000 });
  await ratio.click({ force: true });
}
function buildCaption(job) {
  // Prefer the algorithm-optimized AI caption (06) + 5 hashtags; fall back to the rule-based generator.
  if (job.instagram_caption) {
    const tags = Array.isArray(job.hashtags) && job.hashtags.length ? '\n\n' + job.hashtags.join(' ') : '';
    return job.instagram_caption + tags;
  }
  return createCaption(job).caption;
}
function assetsFromDirectory(directory) {
  if (!directory || !fs.existsSync(directory)) throw new Error(`업로드 폴더를 찾지 못했습니다: ${directory}`);
  const supported = new Set(['.png', '.jpg', '.jpeg', '.webp', '.mp4', '.mov']);
  const files = fs.readdirSync(directory, { withFileTypes: true })
    .filter(entry => entry.isFile() && supported.has(path.extname(entry.name).toLowerCase()))
    .map(entry => path.join(directory, entry.name))
    .sort((a, b) => path.basename(a).localeCompare(path.basename(b), 'en', { numeric: true }));
  if (files.length < 2 || files.length > 10) throw new Error(`Instagram 캐러셀은 지원 파일 2~10개가 필요합니다. 현재: ${files.length}`);
  return files;
}
function makePlan(jobPath, assetsDir = '') {
  const job = readJson(jobPath);
  const dir = path.dirname(path.resolve(jobPath));
  const images = assetsDir ? assetsFromDirectory(path.resolve(assetsDir)) : ['page-01.png', 'page-02.png', 'page-03.png', 'page-04.png'].map(file => path.join(dir, file));
  for (const image of images) if (!fs.existsSync(image)) throw new Error(`게시 이미지가 없습니다: ${image}`);
  validateFourByFive(images);
  // Freeze one article-matched selection so preview and publish use the same song.
  if (!job.music?.selection?.id) {
    job.music = { ...(job.music || {}), selection: chooseMusic(job), status: 'planned' };
    writeJson(jobPath, job);
  }
  const captionSeo = createCaption(job);
  const plan = {
    article_id: job.article.article_id,
    account: job.instagram_tracking?.handle || '@onedaytrading.io',
    job_path: path.resolve(jobPath),
    status_required: 'approved',
    image_paths: images,
    source_folder: assetsDir ? path.resolve(assetsDir) : dir,
    caption: buildCaption(job),
    caption_seo: captionSeo,
    music: job.music.selection,
    created_at: new Date().toISOString()
  };
  const planPath = path.join(dir, 'chrome-publish-plan.json');
  writeJson(planPath, plan);
  console.log(`게시 계획 생성: ${planPath}`);
  return plan;
}
async function setup() {
  const context = await openChrome();
  const page = context.pages()[0] || await context.newPage();
  await page.goto(INSTAGRAM, { waitUntil: 'domcontentloaded' });
  console.log('열린 Chrome 창에서 @onedaytrading.io 계정으로 직접 로그인하세요. 비밀번호·2단계 인증은 이 스크립트가 처리하지 않습니다.');
  await waitForEnter('로그인 완료 후 Enter를 누르세요: ');
  await requireLoggedIn(page);
  console.log('로그인 세션 저장 완료. 이후 publish 모드에서 같은 전용 Chrome 프로필을 사용합니다.');
  await context.close();
}
async function check() {
  const context = await openChrome();
  const page = context.pages()[0] || await context.newPage();
  try {
    await requireLoggedIn(page);
    console.log('로그인 세션 확인 완료: Instagram 게시 자동화 준비됨');
  } finally { await context.close(); }
}
async function activeSurface(page) {
  const dialog = page.locator('[role="dialog"]:visible').last();
  return (await dialog.count()) ? dialog : page.locator('body');
}
async function applyMusicIfAvailable(page, music) {
  if (!music?.track || !music?.artist) return { applied: false, reason: 'no_selection' };
  const surface = await activeSurface(page);
  const triggers = [
    surface.getByText(/^(Add music|음악 추가)$/i).last(),
    surface.getByRole('button', { name: /add music|음악/i }).last(),
    surface.locator('[aria-label*="music" i], [aria-label*="음악"]').last()
  ];
  let opened = false;
  for (const trigger of triggers) {
    if (await trigger.isVisible().catch(() => false)) {
      await trigger.click({ force: true });
      opened = true;
      break;
    }
  }
  if (!opened) return { applied: false, reason: 'music_ui_unavailable' };
  const search = page.locator('input[placeholder*="Search" i]:visible, input[placeholder*="검색"]:visible').last();
  if (!await search.isVisible({ timeout: 10000 }).catch(() => false)) return { applied: false, reason: 'music_search_unavailable' };
  await search.fill(`${music.track} ${music.artist}`);
  await page.waitForTimeout(1200);
  const exactTrack = page.getByText(new RegExp(`^${escapeRegex(music.track)}$`, 'i')).last();
  const looseTrack = page.getByText(new RegExp(escapeRegex(music.track), 'i')).last();
  const result = await exactTrack.isVisible().catch(() => false) ? exactTrack : looseTrack;
  if (!await result.isVisible().catch(() => false)) return { applied: false, reason: 'track_not_in_library' };
  await result.click({ force: true });
  await page.waitForTimeout(800);
  return { applied: true, track_id: music.id };
}
async function verify(jobPath) {
  const job = readJson(jobPath);
  const context = await openChrome();
  const page = context.pages()[0] || await context.newPage();
  try {
    await requireLoggedIn(page);
    const handle = (job.instagram_tracking?.handle || '@onedaytrading.io').replace('@', '');
    await page.goto(`https://www.instagram.com/${handle}/`, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(4000);
    const headline = job.pages.page1.headline.replace(/\n/g, ' ').trim();
    const bodyText = await page.locator('body').innerText();
    const imageAlts = await page.locator('img[alt]').evaluateAll(nodes => nodes.map(node => node.getAttribute('alt') || ''));
    const found = bodyText.includes(headline) || imageAlts.some(alt => alt.includes(headline));
    await page.screenshot({ path: path.join(path.dirname(path.resolve(jobPath)), 'chrome-profile-verification.png'), fullPage: false });
    const result = { checked_at: new Date().toISOString(), account: `@${handle}`, headline, found };
    writeJson(path.join(path.dirname(path.resolve(jobPath)), 'chrome-publish-verification.json'), result);
    console.log(JSON.stringify(result));
    return found;
  } finally { await context.close(); }
}
async function publish(jobPath, assetsDir = '', preview = false, dbCandidate = null) {
  const job = readJson(jobPath);
  if (job.status !== 'approved' || !job.qa?.approved) throw new Error('사람이 승인한 작업만 게시할 수 있습니다. approve_carousel.ps1을 먼저 실행하세요.');
  if (!has('--confirm')) throw new Error('실제 게시 전송은 --confirm 옵션이 필요합니다. 먼저 plan 모드로 내용을 확인하세요.');
  const plan = makePlan(jobPath, assetsDir);
  const context = await openChrome();
  const page = context.pages()[0] || await context.newPage();
  try {
    await requireLoggedIn(page);
    await clickAny(page, ['Create', '만들기', 'New post', '새 게시물', '새로운 게시물']);
    const fileInput = page.locator('input[type="file"]').first();
    await fileInput.waitFor({ state: 'attached', timeout: 15000 });
    await fileInput.setInputFiles(plan.image_paths);
    await page.waitForTimeout(3000);
    await ensureFourByFive(page);
    await clickNext(page);
    await page.waitForTimeout(1800);
    await clickNext(page);
    const surface = await activeSurface(page);
    const musicResult = await applyMusicIfAvailable(page, plan.music);
    job.music = { ...(job.music || {}), selection: plan.music, status: musicResult.applied ? 'applied' : musicResult.reason, applied: musicResult.applied };
    writeJson(jobPath, job);
    const captionBox = surface.locator('textarea:visible, div[contenteditable="true"]:visible').last();
    await captionBox.waitFor({ state: 'visible', timeout: 60000 });
    await captionBox.fill(plan.caption);
    if (preview) {
      await page.screenshot({ path: path.join(path.dirname(path.resolve(jobPath)), 'chrome-publish-preview.png'), fullPage: false });
      console.log('게시 직전 미리보기 저장. 공유하지 않았습니다.');
      return;
    }
    let shareButton = surface.getByRole('button', { name: /^(Share|공유|공유하기)$/i }).last();
    if (!(await shareButton.count())) shareButton = surface.getByText('공유하기', { exact: true }).last();
    if (!(await shareButton.count())) throw new Error('게시 모달 내부의 최종 공유 버튼을 찾지 못했습니다. 게시를 중단합니다.');
    await shareButton.click({ force: true });
    await page.waitForFunction(() => {
      const dialogs = Array.from(document.querySelectorAll('[role="dialog"]'));
      return dialogs.some(dialog => dialog.getAttribute('aria-label') === '게시물 공유됨') || dialogs.length === 0;
    }, { timeout: 120000 });
    const result = { posted_at: new Date().toISOString(), mode: 'chrome_session', plan };
    if (musicResult.applied) recordMusic(job, true);
    if (dbCandidate) recordShared(dbCandidate, plan);
    writeJson(path.join(path.dirname(path.resolve(jobPath)), 'chrome-publish-result.json'), result);
    console.log('게시 요청을 전송했습니다. Instagram 앱에서 실제 게시 여부를 확인하세요.');
  } catch (error) {
    const diagnosticDir = path.dirname(path.resolve(jobPath));
    const screenshot = path.join(diagnosticDir, 'chrome-publish-diagnostic.png');
    await page.screenshot({ path: screenshot, fullPage: true }).catch(() => {});
    const labels = await page.locator('svg[aria-label]').evaluateAll(nodes => nodes.map(node => node.getAttribute('aria-label')).filter(Boolean)).catch(() => []);
    if (labels.length) console.error(`화면 아이콘 라벨: ${labels.join(' | ')}`);
    console.error(`진단 화면: ${screenshot}`);
    throw error;
  } finally { await context.close(); }
}

function nextDbCandidate() {
  const queue = inspectQueue();
  if (!queue.next) throw new Error(`No publishable DB item: ${queue.reason}`);
  return queue.next;
}
async function planNext() {
  const candidate = nextDbCandidate();
  console.log(JSON.stringify({ status: candidate.status, folder: candidate.folder, job_path: candidate.job_path, asset_count: candidate.asset_count }, null, 2));
  return makePlan(candidate.job_path, candidate.folder);
}
async function publishNext() {
  const candidate = nextDbCandidate();
  return publish(candidate.job_path, candidate.folder, false, candidate);
}

(async () => {
  const command = process.argv[2];
  const jobPath = option('--job');
  const assetsDir = option('--assets-dir');
  if (command === 'db-status') { console.log(JSON.stringify(inspectQueue(), null, 2)); return; }
  if (command === 'plan-next') return planNext();
  if (command === 'publish-next') { if (!has('--confirm')) throw new Error('publish-next requires --confirm'); return publishNext(); }
  if (command === 'setup') return setup();
  if (command === 'check') return check();
  if (command === 'verify') { if (!jobPath) throw new Error('--job 작업 JSON 경로가 필요합니다.'); return verify(jobPath); }
  if (command === 'preview') { if (!jobPath) throw new Error('--job 작업 JSON 경로가 필요합니다.'); return publish(jobPath, assetsDir, true); }
  if (command === 'plan') { if (!jobPath) throw new Error('--job 작업 JSON 경로가 필요합니다.'); return makePlan(jobPath, assetsDir); }
  if (command === 'publish') { if (!jobPath) throw new Error('--job 작업 JSON 경로가 필요합니다.'); return publish(jobPath, assetsDir); }
  throw new Error('사용법: setup | check | verify --job <job.json> | plan --job <job.json> [--assets-dir <folder>] | publish --job <job.json> [--assets-dir <folder>] --confirm');
})().catch(error => { console.error(`오류: ${error.message}`); process.exit(1); });
