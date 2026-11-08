import { mkdir, writeFile } from 'node:fs/promises';
import { configuration, fixtures, cleanup, uploadResume } from './support/local-services.mjs';

let config;
try { config=configuration(); } catch(error) { console.error(error.message); process.exit(2); }
const context=await fixtures(config);
let completed=false;
try {
  const resume=await uploadResume(context,context.users[0]);
  const finalized=await context.request('/functions/v1/resume-finalize',{method:'POST',token:context.users[0].token,body:{resume_id:resume.id}});
  if(!finalized.ok) throw new Error('Local file finalization failed; seed is incomplete.');
  const directory=new URL('../../config/local/',import.meta.url);
  await mkdir(directory,{recursive:true});
  await writeFile(new URL('dummy-users.json',directory),JSON.stringify({
    warning:'LOCAL DUMMY ACCOUNTS ONLY. Do not commit or share this file.',
    users:context.users.map(({label,email,password})=>({label,email,password})),
    company_ids:context.companies.map(x=>x.id), job_ids:context.jobs.map(x=>x.id),
  },null,2));
  completed=true;
  console.log('Local dummy fixtures created. Login details are in ignored config/local/dummy-users.json; do not paste them into chat.');
} finally { if (completed) await context.database.end(); else await cleanup(config,context); }
