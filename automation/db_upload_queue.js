/* Finds the earliest DB carousel with an approved job that has not been shared. */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const ROOT = path.resolve(__dirname, '..');
const DB_ROOT = path.join(ROOT, 'DB');
const JOB_ROOT = path.join(ROOT, 'output', 'jobs');
const LEDGER = path.join(__dirname, 'instagram-upload-ledger.jsonl');
const EXTENSIONS = new Set(['.png', '.jpg', '.jpeg', '.webp', '.mp4', '.mov']);
function readJson(file) { return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')); }
function mediaFiles(folder) { return fs.readdirSync(folder, { withFileTypes: true }).filter(x => x.isFile() && EXTENSIONS.has(path.extname(x.name).toLowerCase())).map(x => path.join(folder, x.name)).sort((a,b) => path.basename(a).localeCompare(path.basename(b), 'en', {numeric:true})); }
function signature(files) { const h = crypto.createHash('sha256'); for (const f of files) { h.update(path.extname(f).toLowerCase()); h.update(fs.readFileSync(f)); } return h.digest('hex'); }
function readLedger() { return fs.existsSync(LEDGER) ? fs.readFileSync(LEDGER, 'utf8').split(/\r?\n/).filter(Boolean).map(JSON.parse) : []; }
function jobIndex() {
  const index = new Map(); if (!fs.existsSync(JOB_ROOT)) return index;
  for (const d of fs.readdirSync(JOB_ROOT, {withFileTypes:true}).filter(x => x.isDirectory())) for (const n of ['job.final.json','job.json']) {
    const file=path.join(JOB_ROOT,d.name,n); if (!fs.existsSync(file)) continue;
    try { const job=readJson(file), id=job.article?.article_id || job.article_id; if (id && (!index.has(id) || n==='job.final.json')) index.set(id,{path:file,job}); } catch (_) {}
  } return index;
}
function articleId(folder) {
  const id=path.basename(folder).match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i); if (id) return id[0];
  for (const f of fs.readdirSync(folder).filter(x => x.endsWith('.json'))) try { const x=readJson(path.join(folder,f)); if (x.article_id || x.article?.article_id) return x.article_id || x.article.article_id; } catch (_) {}
  return '';
}
function alreadyShared() {
  const ids=new Set(), hashes=new Set(); for (const x of readLedger()) { ids.add(x.article_id); hashes.add(x.asset_signature); }
  if (!fs.existsSync(JOB_ROOT)) return {ids,hashes};
  for (const d of fs.readdirSync(JOB_ROOT,{withFileTypes:true}).filter(x=>x.isDirectory())) {
    const folder=path.join(JOB_ROOT,d.name), verify=path.join(folder,'chrome-publish-verification.json'), jobFile=path.join(folder,'job.final.json');
    if (!fs.existsSync(verify) || !fs.existsSync(jobFile)) continue;
    try { if (!readJson(verify).found) continue; ids.add(readJson(jobFile).article.article_id); const f=fs.readdirSync(folder).filter(n=>/^page-0[1-9]-(hook|evidence|analysis|judgment|cta)\.(png|jpe?g|webp|mp4|mov)$/i.test(n)).map(n=>path.join(folder,n)).sort(); if(f.length>=2) hashes.add(signature(f)); } catch (_) {}
  } return {ids,hashes};
}
function inspectQueue() {
  const index=jobIndex(), shared=alreadyShared(), items=[]; if(!fs.existsSync(DB_ROOT)) return {next:null,items,reason:'db_not_found'};
  const dirs=fs.readdirSync(DB_ROOT,{withFileTypes:true}).filter(x=>x.isDirectory()&&x.name.toLowerCase()!=='step1').map(x=>path.join(DB_ROOT,x.name)).sort((a,b)=>path.basename(a).localeCompare(path.basename(b),'en',{numeric:true}));
  for(const folder of dirs) { const assets=mediaFiles(folder), id=articleId(folder), item={folder,article_id:id,asset_count:assets.length};
    if(assets.length<2||assets.length>10) { item.status='needs_2_to_10_carousel_assets'; items.push(item); continue; }
    item.asset_signature=signature(assets);
    if(shared.ids.has(id)||shared.hashes.has(item.asset_signature)) { item.status='already_posted'; items.push(item); continue; }
    const linked=index.get(id); if(!linked) { item.status='needs_generated_job'; items.push(item); continue; }
    if(linked.job.status!=='approved'||!linked.job.qa?.approved) { item.status='waiting_for_approval'; item.job_path=linked.path; items.push(item); continue; }
    item.status='ready'; item.job_path=linked.path; item.assets=assets; items.push(item); return {next:item,items,reason:'ready'};
  } return {next:null,items,reason:'no_ready_item'};
}
function recordShared(candidate,plan) { if(readLedger().some(x=>x.asset_signature===candidate.asset_signature||x.article_id===candidate.article_id)) return; fs.appendFileSync(LEDGER,`${JSON.stringify({shared_at:new Date().toISOString(),article_id:candidate.article_id,folder:candidate.folder,asset_signature:candidate.asset_signature,plan_path:plan.job_path,status:'shared_pending_verify'})}\n`,'utf8'); }
module.exports={inspectQueue,recordShared};
