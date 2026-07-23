/*
 * OneDayTrading generative background.
 * Turns the article's hero image prompt into a text-free, vertical 4:5 editorial
 * background and wires it into the job. Text removal + recompose is achieved by
 * generating a fresh, text-free scene from the article subject (never baking the
 * source card's letters into the render).
 *
 * Engines (image generation needs a provider with quota/credit):
 *   IMAGE_ENGINE=openai (default) -> gpt-image-2   (env OPENAI_API_KEY, requires billing headroom)
 *   IMAGE_ENGINE=gemini           -> imagen        (env GEMINI_API_KEY)
 *
 * Usage:  node automation/generate_background.js <jobPath> [--engine openai]
 */
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
function readJson(f) { return JSON.parse(fs.readFileSync(f, 'utf8').replace(/^﻿/, '')); }
function writeJson(f, d) { fs.writeFileSync(f, JSON.stringify(d, null, 2), 'utf8'); }
function option(name, fallback) { const i = process.argv.indexOf(name); return i >= 0 ? process.argv[i + 1] : fallback; }

const CONFIG = readJson(path.join(ROOT, 'automation', 'config.json'));

function buildPrompt(job) {
  const base = job.visual && job.visual.image_prompt
    ? job.visual.image_prompt
    : `Editorial photograph representing: ${(job.visual && job.visual.subject) || job.article.title}.`;
  // Enforce the brand's text-free vertical composition rules regardless of model.
  return `${base}\n\nVertical 4:5 composition, cinematic editorial photography, realistic textures and natural light. ` +
    `Keep the upper-left area dark and simple as negative space for a headline. ` +
    `No text, no letters, no numbers, no logo, no watermark. ` +
    `Avoid generic stock finance imagery (globes, cash stacks, handshakes, trader screens, charts).`;
}

async function generateOpenAI(prompt, outPath) {
  const key = process.env.OPENAI_API_KEY;
  if (!key) throw new Error('OPENAI_API_KEY 없음');
  const model = process.env.OPENAI_IMAGE_MODEL || 'gpt-image-2';
  const res = await fetch('https://api.openai.com/v1/images/generations', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({ model, prompt, size: '1024x1536', n: 1 })
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`OpenAI 이미지 오류 ${res.status}: ${JSON.stringify(data.error || data)}`);
  const b64 = data.data[0].b64_json;
  fs.writeFileSync(outPath, Buffer.from(b64, 'base64'));
}

async function generateGemini(prompt, outPath) {
  const key = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;
  if (!key) throw new Error('GEMINI_API_KEY 없음');
  const model = process.env.GEMINI_IMAGE_MODEL || 'imagen-3.0-generate-002';
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:predict?key=${key}`;
  const res = await fetch(url, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ instances: [{ prompt }], parameters: { sampleCount: 1, aspectRatio: '3:4' } })
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`Gemini 이미지 오류 ${res.status}: ${JSON.stringify(data.error || data)}`);
  const b64 = data.predictions[0].bytesBase64Encoded;
  fs.writeFileSync(outPath, Buffer.from(b64, 'base64'));
}

async function downloadImage(url, dest) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`대표 이미지 다운로드 실패 ${res.status}: ${url}`);
  fs.writeFileSync(dest, Buffer.from(await res.arrayBuffer()));
  return dest;
}

// Codex CLI generates/edits the image via the ChatGPT subscription (no API billing).
// The prompt is fed on stdin (with '-') so long Korean/quoted text never touches the
// shell argument line; stdin is closed immediately so codex does not block.
// When a source image is given, codex RECOMPOSES it: strips baked-in text and
// outpaints to a vertical 4:5 frame while keeping the article's real subject — so
// the background stays topically relevant to the news (e.g. its OpenAI visual),
// instead of inventing an unrelated scene.
function generateCodex(prompt, outPath, jobDir, sourceImage) {
  const abs = path.resolve(outPath);
  const before = new Set(fs.readdirSync(jobDir).filter(f => f.toLowerCase().endsWith('.png')));
  const args = ['exec', '-C', jobDir, '-s', 'workspace-write', '--skip-git-repo-check', '--color', 'never'];
  let codexPrompt;
  if (sourceImage && fs.existsSync(sourceImage)) {
    args.push('-i', path.resolve(sourceImage));
    codexPrompt =
      `첨부한 이미지는 이 뉴스 기사에 이미 등록된 대표 이미지다. 핵심 피사체와 주제(인물/제품/장면)를 그대로 유지하면서 아래를 수행해라.\n` +
      `[제거] 뉴스 편집 과정에서 덧씌운 오버레이 요소만 지운다: 큰 제목/부제 문구, 좌상단 카테고리 라벨, 하단 매체 워터마크(예: "ONEDAY TRADING"), 각종 자막.\n` +
      `[보존] 사진 원본에 원래부터 있던 브랜드 로고·제품 마크(예: OpenAI 로고 심볼과 워드마크)는 반드시 그대로 유지한다. 이것이 기사 주제를 나타내므로 절대 지우지 마라.\n` +
      `[확장] 세로 4:5(1080x1350)로 만든다. 단, 원본 피사체(인물·얼굴·사물)의 비율을 절대 왜곡하거나 늘리지(stretch) 마라. 원본 부분은 가로세로 비율 그대로 두고, 부족한 위/아래(필요하면 좌우) 공간에 같은 장면의 배경을 자연스럽게 새로 그려 채운다(outpaint). 인물이 홀쭉하거나 길쭉해지면 안 된다.\n` +
      `왼쪽 상단은 제목이 올라갈 수 있게 어둡고 단순하게 정리한다.\n` +
      `결과를 배경 이미지로 정확히 이 경로에 저장해줘(다른 경로/파일명 금지): ${abs}\n` +
      `참고 주제: ${prompt}\n뉴스 오버레이 텍스트/워터마크는 없어야 하지만, 원본 사진의 브랜드 로고는 남긴다. 저장을 끝내면 '완료' 한 줄만 답해라.`;
  } else {
    codexPrompt =
      `아래 조건의 이미지를 한 장 생성해서, 정확히 이 파일 경로에 저장해줘(다른 경로/파일명 금지):\n${abs}\n\n` +
      `[조건]\n${prompt}\n\n반드시 텍스트/글자/숫자/로고/워터마크가 전혀 없어야 한다. 세로 4:5 비율. 저장을 끝내면 '완료' 한 줄만 답해라.`;
  }
  const res = spawnSync('codex', [...args, '-'],
    { input: codexPrompt, encoding: 'utf8', shell: true, timeout: 600000, maxBuffer: 64 * 1024 * 1024 });
  if (!fs.existsSync(abs)) {
    // Fallback: codex may have saved under a different name — take the newest PNG created during this run.
    const fresh = fs.readdirSync(jobDir).filter(f => f.toLowerCase().endsWith('.png') && !before.has(f))
      .map(f => ({ f, m: fs.statSync(path.join(jobDir, f)).mtimeMs })).sort((a, b) => b.m - a.m);
    if (!fresh.length) throw new Error(`codex가 이미지를 저장하지 못했습니다: ${(res.stderr || res.stdout || '').slice(-400)}`);
    fs.renameSync(path.join(jobDir, fresh[0].f), abs);
  }
}

async function main() {
  const jobPath = process.argv[2];
  if (!jobPath || jobPath.startsWith('--')) throw new Error('사용법: node automation/generate_background.js <jobPath> [--engine codex|openai|gemini]');
  const engine = option('--engine', process.env.IMAGE_ENGINE || 'codex');
  const job = readJson(jobPath);
  const jobDir = path.dirname(jobPath);
  const outPath = path.join(jobDir, 'background.png');
  const prompt = buildPrompt(job);

  // Prefer recomposing the article's already-registered image so the background
  // stays relevant to the news. Fall back to pure generation only if none exists.
  const sourceUrl = (job.article && job.article.og_image) || (job.visual && job.visual.source_url) || '';
  let sourceImage = '';
  const noSource = process.argv.includes('--no-source');
  if (sourceUrl && !noSource) {
    sourceImage = path.join(jobDir, 'source-image' + (path.extname(sourceUrl.split('?')[0]) || '.jpg'));
    try { await downloadImage(sourceUrl, sourceImage); console.log(`대표 이미지 확보: ${sourceUrl}`); }
    catch (e) { console.log(`대표 이미지 없음(생성으로 대체): ${e.message}`); sourceImage = ''; }
  }

  console.log(`배경 생성 중 (engine=${engine}${sourceImage ? ', recompose' : ', generate'})...`);
  if (engine === 'gemini') await generateGemini(prompt, outPath);
  else if (engine === 'openai') await generateOpenAI(prompt, outPath);
  else generateCodex(prompt, outPath, jobDir, sourceImage);

  if (!job.visual) job.visual = {};
  job.visual.background_path = outPath.split(path.sep).join('/');
  job.visual.strategy = sourceImage ? 'reference_recompose' : 'original_generated';
  job.visual.license = sourceImage ? 'generated_from_reference' : 'owned';
  job.visual.image_engine = engine;
  writeJson(jobPath, job);
  console.log(`배경 생성 완료: ${outPath}`);
}

main().catch(err => { console.error(err.message || err); process.exit(1); });
