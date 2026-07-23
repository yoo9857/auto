/*
 * OneDayTrading copy generator.
 * Reads a job.json (with article snapshot) and produces the 4-page carousel copy
 * contract, then writes it back into the job.
 *
 * Engine: a subscription-based CLI (no API quota needed).
 *   COPY_ENGINE=claude (default)  -> claude -p   (fast, Opus)
 *   COPY_ENGINE=codex             -> codex exec --output-schema  (slower)
 *
 * Usage:  node automation/generate_copy.js <jobPath>
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');

function readJson(file) { return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, '')); }
function writeJson(file, data) { fs.writeFileSync(file, JSON.stringify(data, null, 2), 'utf8'); }

const CONFIG = readJson(path.join(ROOT, 'automation', 'config.json'));
const LIMITS = CONFIG.limits;

const SHAPE = `{
  "market_label": "국내주식|해외주식|글로벌증시|증시·경제|크립토 중 하나",
  "source_name": "원 출처 매체명 또는 빈 문자열",
  "hero": { "subject": "핵심 시각 대상(한국어)", "image_prompt": "영문 프롬프트" },
  "video_search_profile": {
    "search_kind": "person | official_event | product_reveal | none",
    "topic": "영상 검색용 영문 핵심어(브랜드/제품/사건). 예: 'Nvidia B300', 'OpenAI'",
    "aliases": ["영문 별칭들"],
    "event_terms": ["영문 사건 키워드들"],
    "person_name": "영상으로 넣기 가장 적합한 실존 공개 인물의 영문 정식명(예: 'Jensen Huang'). 없으면 빈 문자열",
    "person_format_terms": ["interview","keynote","talk","fireside","conference"],
    "official_channel_hints": ["기사 주제에 맞는 공식/기관/뉴스 채널 영문명"],
    "rights_risk": "low | high"
  },
  "evidence": [ { "statement": "기사에서 확인되는 사실", "source": "근거 위치", "confidence": 0.0 } ],
  "instagram_caption": "인스타 피드용 캡션 전체(여러 줄, 줄바꿈은 \\n). 해시태그는 넣지 말 것",
  "hashtags": ["#태그1","#태그2","#태그3","#태그4","#태그5"],
  "pages": {
    "page1": { "breaking_label": "", "headline": "1줄\\n2줄", "subtitle": "1줄\\n2줄", "cta": "" },
    "page2": { "analysis_headline": "", "quick_answer": "", "paragraphs": ["", "", ""], "memory_line": "" },
    "page3": { "evaluation": "", "evaluation_headline": "지금 평가는\\n'라벨'", "evaluation_summary": "", "expect": "", "verify": "", "judge": "", "paragraphs": ["", "", ""], "memory_line": "" }
  }
}`;

function buildPrompt(article) {
  const body = (article.body || '').slice(0, 6000);
  return `당신은 OneDayTrading(@onedaytrading.io)의 인스타그램 경제뉴스 카드 수석 에디터다.
아래 기사 원문만 근거로 4페이지 캐러셀 카피를 한국어로 작성한다.

[절대 원칙]
- 원문에 없는 사실·수치·인과관계를 만들지 않는다. 본문에서 확인되는 내용만 쓴다.
- 매수·매도 권유, 단정적 예측, 선정적 표현 금지. 불확실한 것은 "확인이 필요하다"로 남긴다.

[문체] 독자의 핵심 질문 → 기사 근거 → 기대와 위험 → 조건부 결론. 짧고 단정한 경제지 분석 문장.

[길이 규칙 — 렌더 영역에 맞추려면 반드시 지킬 것]
- page1.headline: 반드시 2줄(\\n). 각 줄은 공백 포함 9자 이내(예: "엔비디아 H200" 8자, "중국 출하 시작" 7자). 짧고 강하게. 원문 제목 복붙 금지.
- page1.subtitle: 2줄(\\n), 각 줄 20자 이내.
- page2.quick_answer: 1~2문장, 70자 이내.
- page2.paragraphs: 각 문단 2문장 이내, 각 90자 이내.
- page3.paragraphs: 각 문단 2문장 이내, 각 68자 이내(짧게 — 판단 3줄과 함께 한 화면에 들어가야 함).
- 모든 문장은 짧고 밀도 높게. 길게 늘어지면 잘린다.

[스타일 예시 — 이 정도 간결함/톤을 목표로]
headline: "엔비디아 H200\\n중국 출하 시작"
subtitle: "최상위 AI칩까지 넘어선\\n미국의 수출 규제선"
page2.paragraph 예: "출하 재개는 상위 AI칩 판매가 다시 열렸다는 신호다. 중국향 데이터센터 매출 회복의 첫 단추로 읽힌다."

[페이지 규칙]
page1(훅):
- breaking_label: 긴급속보/속보/호재/악재/중립/분석 중 기사 성격에 맞게.
- headline: 핵심 인물·기업·사건을 담아 압축(위 길이 규칙 필수).
- subtitle: "왜 중요한가"를 위 길이 규칙대로. headline과 중복 금지.
- cta: 분석·전망→"핵심 분석 보기 →", 단순 속보→"기사 자세히 보기 →", 데이터·공시→"투자 포인트 보기 →".
page2(핵심 분석):
- analysis_headline: 질문형/요지 헤드라인. 2줄(\\n), 각 줄 12자 이내.
- quick_answer: 30초 브리핑(위 길이 규칙).
- paragraphs: 정확히 3개 — [1]기대 효과/의미 [2]확인할 변수 [3]확장/실패 가능성. 기사 속 종목·수치를 구체 인용하되 위 길이 규칙 준수.
- memory_line: 핵심 한 줄 ${LIMITS.memory_line_chars}자 이내.
page3(평가):
- evaluation: 반드시 다음 5개 중 정확히 하나 — "명확한 호재", "제한적 호재", "중립", "제한적 악재", "명확한 악재". (다른 표현 금지)
- evaluation_headline: "지금 평가는\\n'{evaluation}'" 형태 2줄(\\n). {evaluation}은 위에서 고른 값 그대로.
- evaluation_summary: 평가 근거 1~2문장.
- expect/verify/judge: 각각 14자 이내의 짧고 구체적인 명사구(문장 아님). expect=기대 포인트, verify=확인할 데이터, judge=평가를 가를 기준. 조사·서술어 없이 핵심만.
- paragraphs: 정확히 3개(기대→위험→평가 상향 기준). 각 2~3문장.
- memory_line: 핵심 한 줄 ${LIMITS.memory_line_chars}자 이내.

[중복 회피] page2와 page3는 역할이 다르다. page2는 "시장 의미와 확인할 변수", page3는 "투자 판단(기대/확인/판단 기준)과 평가"에 집중한다. 같은 문장·표현을 재사용하지 말고 서로 다른 단어로 쓴다.

[추가 산출]
- hero.subject: 1페이지 배경으로 쓸 핵심 시각 대상.
- hero.image_prompt: 텍스트 없는 세로 4:5 에디토리얼 실사 사진용 영문 프롬프트. 기사 핵심 대상을 앞부분에 명시, 왼쪽 상단은 어둡고 단순한 여백(제목 자리), 자연스러운 실사 질감. 끝에 반드시 "no text, no letters, no numbers, no logo, no watermark". 범용 차트/지구본/돈다발/악수/트레이더 화면 금지.
- video_search_profile: 2페이지 영상용 검색 프로파일. 카테고리 성격에 맞게 search_kind를 고른다:
  · person — 인물 중심(빅테크·CEO·기관장). person_name에 대표 인물 영문명, 그의 인터뷰/키노트를 맥락으로. (예: IT, 증시·금리[파월], 모빌리티[머스크])
  · official_event — 인물이 약한 정책·데이터·거시 기사(부동산 정책, 임상, 거시경제). person_name은 비우고, topic + 기관/뉴스 공식 채널(official_channel_hints)로 브리핑·발표·컨퍼런스 영상을 찾는다.
  · product_reveal — 제품/게임 공개(게임 신작, 하드웨어 런칭). 공식 트레일러/쇼케이스. official_channel_hints에 공식 채널.
  · none — 관련 영상이 원래 없을 기사. 모든 필드 최소화(영상 생략이 정상).
  topic은 항상 영문 핵심 검색어. official_channel_hints는 기사 주제의 공식/기관/신뢰 뉴스 채널 영문명.
  rights_risk: 엔터(K팝·뮤직비디오·공연)·게임 트레일러 등 저작권이 강한 콘텐츠면 "high", 그 외 뉴스/발언/기관 영상은 "low". 정치적으로 민감하거나 부적절한 인물(자극적 논란 채널 등)은 피한다.
- evidence: 기사에서 확인되는 핵심 사실 3~4개.
- instagram_caption: 인스타그램 피드 알고리즘 최적화 캡션. 규칙:
  · 첫 줄은 스크롤을 멈추게 하는 훅(독자 질문 또는 긴장). 이모지 최대 1개.
  · 이어서 핵심 사실 1개 + 아직 확인 안 된 변수 1개를 3~5줄로 간결히.
  · "카드를 넘겨 사실→분석→판단을 확인하세요" 같은 캐러셀 유도 1줄.
  · 참여 유도 1줄: 저장·팔로우 권유 + 독자 의견 질문(예: "여러분 판단은? 댓글로").
  · 마지막 줄: "투자 참고용 · 매매 권유 아님".
  · 낚시·공포 조장·매수/매도 권유 금지. 원문에 없는 수치 금지. 해시태그는 캡션 본문에 넣지 말 것.
- hashtags: 정확히 5개. 한국어 위주. 기사 핵심 종목·엔티티 1~2개 + 주제 태그 + 시장/브랜드 태그를 관련성 높은 것만(키워드 스터핑 금지). 각 항목은 '#'로 시작하고 공백 없음.

[출력] 아래 정확한 형태의 JSON "하나만" 출력한다. 코드펜스·주석·설명 없이 JSON만. 모든 줄바꿈은 문자열 안에서 \\n 로 표기.
${SHAPE}

=== 기사 원문 ===
제목: ${article.title}
분류: ${article.category}
발행: ${article.published_at}
요약: ${article.description}

본문:
${body}`;
}

function extractJson(text) {
  let t = String(text).trim();
  t = t.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '');
  const start = t.indexOf('{');
  const end = t.lastIndexOf('}');
  if (start < 0 || end < 0) throw new Error('응답에서 JSON을 찾지 못했습니다.');
  return JSON.parse(t.slice(start, end + 1));
}

function runClaude(prompt) {
  const res = spawnSync('claude', ['-p', '--output-format', 'json'], {
    input: prompt, encoding: 'utf8', shell: true, maxBuffer: 32 * 1024 * 1024
  });
  if (res.status !== 0) throw new Error(`claude CLI 실패 (${res.status}): ${res.stderr || res.stdout}`);
  const outer = JSON.parse(res.stdout);
  if (outer.is_error) throw new Error(`claude 오류: ${outer.result}`);
  return extractJson(outer.result);
}

function runCodex(prompt) {
  const schemaFile = path.join(os.tmpdir(), `odt-copy-schema-${process.pid}.json`);
  const outFile = path.join(os.tmpdir(), `odt-copy-out-${process.pid}.json`);
  fs.writeFileSync(schemaFile, fs.readFileSync(path.join(__dirname, 'copy.schema.json'), 'utf8'));
  const res = spawnSync('codex', ['exec', '--output-schema', schemaFile, '--output-last-message', outFile,
    '-s', 'read-only', '--skip-git-repo-check', '--ephemeral', '--color', 'never', prompt],
    { encoding: 'utf8', shell: true, maxBuffer: 32 * 1024 * 1024, timeout: 300000 });
  if (!fs.existsSync(outFile)) throw new Error(`codex 출력 없음: ${res.stderr || res.stdout}`);
  return extractJson(fs.readFileSync(outFile, 'utf8'));
}

function validate(out) {
  if (!out.pages) throw new Error('pages 누락');
  if (!Array.isArray(out.pages.page2.paragraphs) || out.pages.page2.paragraphs.length !== 3) throw new Error('page2 문단 3개 아님');
  if (!Array.isArray(out.pages.page3.paragraphs) || out.pages.page3.paragraphs.length !== 3) throw new Error('page3 문단 3개 아님');
  for (const f of ['breaking_label', 'headline', 'subtitle', 'cta']) if (!out.pages.page1[f]) throw new Error(`page1.${f} 누락`);
}

function main() {
  const jobPath = process.argv[2];
  if (!jobPath || jobPath.startsWith('--')) throw new Error('사용법: node automation/generate_copy.js <jobPath>');
  const engine = process.env.COPY_ENGINE || 'claude';
  const job = readJson(jobPath);
  const prompt = buildPrompt(job.article);

  console.log(`카피 생성 중 (engine=${engine})...`);
  const run = engine === 'codex' ? runCodex : runClaude;
  let out;
  try { out = run(prompt); validate(out); }
  catch (e) {
    console.log(`재시도 (사유: ${e.message})`);
    out = run(prompt + '\n\n반드시 위 형태의 유효한 JSON "하나만", 코드펜스 없이 출력하라. page2/page3 문단은 정확히 3개.');
    validate(out);
  }

  out.pages.page4 = { instagram_handle: CONFIG.brand.instagram_handle, website: 'onedaytrading.net' };
  job.pages = out.pages;
  if (out.market_label) job.article.market_label = out.market_label;
  if (out.source_name) job.article.source_name = out.source_name;
  if (!job.visual) job.visual = {};
  job.visual.subject = out.hero ? out.hero.subject : '';
  job.visual.image_prompt = out.hero ? out.hero.image_prompt : '';
  // AI-derived video search profile so any article can auto-find a page-2 clip.
  if (out.video_search_profile && out.video_search_profile.topic) {
    const vp = out.video_search_profile;
    job.video_search_profile = {
      search_kind: vp.search_kind || (vp.person_name ? 'person' : 'official_event'),
      topic: vp.topic, aliases: vp.aliases || [], event_terms: vp.event_terms || [],
      person_name: vp.person_name || '', person_format_terms: (vp.person_format_terms && vp.person_format_terms.length ? vp.person_format_terms : ['interview', 'keynote', 'talk', 'fireside', 'conference']),
      official_channel_hints: vp.official_channel_hints || [],
      rights_risk: (vp.rights_risk === 'high' ? 'high' : 'low'),
      minimum_grade: 'A', context_minimum_grade: 'S', confidence: 'medium', matched_rule: 'ai_derived',
      generated_at: new Date().toISOString()
    };
  }
  job.analysis_evidence = out.evidence || [];
  // Instagram caption + exactly 5 hashtags (algorithm-optimized) for the 06 deliverable.
  if (out.instagram_caption) job.instagram_caption = out.instagram_caption;
  if (Array.isArray(out.hashtags)) {
    let tags = out.hashtags.filter(Boolean).map(t => (String(t).startsWith('#') ? String(t) : '#' + String(t)).replace(/\s+/g, ''));
    job.hashtags = tags.slice(0, 5);
  }
  job.copy_provider = { engine, generated_at: new Date().toISOString() };

  writeJson(jobPath, job);
  console.log(`카피 생성 완료: ${jobPath}`);
  console.log(`  headline : ${out.pages.page1.headline.replace(/\n/g, ' / ')}`);
  console.log(`  subtitle : ${out.pages.page1.subtitle.replace(/\n/g, ' / ')}`);
  console.log(`  eval     : ${out.pages.page3.evaluation}`);
  console.log(`  hero     : ${job.visual.subject}`);
}

try { main(); } catch (err) { console.error(err.message || err); process.exit(1); }
