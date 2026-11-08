import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import pg from 'pg';

export function configuration() {
  const api = new URL(process.env.SUPABASE_LOCAL_API_URL ?? 'http://127.0.0.1:54321');
  if (api.protocol !== 'http:' || !['127.0.0.1','localhost'].includes(api.hostname) || api.port !== '54321' ||
      api.username || api.password || api.pathname !== '/' || api.search || api.hash) {
    throw new Error('Refusing non-local API. Only localhost:54321 is authorized.');
  }
  const publicKey = process.env.SUPABASE_LOCAL_PUBLIC_KEY;
  const secretKey = process.env.SUPABASE_LOCAL_SECRET_KEY;
  const databaseUrl = process.env.SUPABASE_LOCAL_DB_URL;
  if (!publicKey || !secretKey || !databaseUrl) {
    throw new Error('Local runtime settings missing. Use tools/run-local-services.ps1 after starting local Supabase.');
  }
  const database = new URL(databaseUrl);
  if (!['postgres:','postgresql:'].includes(database.protocol) ||
      !['127.0.0.1','localhost'].includes(database.hostname) || database.port !== '54322' ||
      database.pathname !== '/postgres' || database.search || database.hash) throw new Error('Refusing non-local database.');
  return { api:api.origin, publicKey, secretKey, databaseUrl };
}

export function apiClient(config) {
  return async (path, {method='GET', token, privileged=false, body, bytes, contentType, headers={}} = {}) => {
    const key = privileged ? config.secretKey : config.publicKey;
    const response = await fetch(`${config.api}${path}`, { method, redirect:'error',
      headers:{apikey:key, Authorization:`Bearer ${token ?? key}`,
        ...(body !== undefined ? {'Content-Type':'application/json'} : {}),
        ...(contentType ? {'Content-Type':contentType} : {}), ...headers},
      body:bytes ?? (body !== undefined ? JSON.stringify(body) : undefined), signal:AbortSignal.timeout(15000),
    });
    const text = await response.text();
    let data;
    try { data = text ? JSON.parse(text) : null; } catch { data = null; }
    return {ok:response.ok, status:response.status, data}; // Never log response tokens or credentials.
  };
}

export function dummyPdf() {
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  const stream='BT /F1 12 Tf 40 740 Td (TEST DATA - NOT A REAL PERSON) Tj ET\n';
  objects.push(`<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}endstream`);
  let pdf='%PDF-1.4\n'; const offsets=[0];
  objects.forEach((object,index)=>{offsets.push(Buffer.byteLength(pdf)); pdf+=`${index+1} 0 obj\n${object}\nendobj\n`;});
  const xref=Buffer.byteLength(pdf);
  pdf+=`xref\n0 6\n0000000000 65535 f \n${offsets.slice(1).map(x=>`${String(x).padStart(10,'0')} 00000 n \n`).join('')}trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(pdf);
}

export async function fixtures(config) {
  const request=apiClient(config);
  const database=new pg.Client({connectionString:config.databaseUrl});
  await database.connect();
  const context={request,database,users:[],companies:[],jobs:[],uploads:[]};
  try {
    const tag=randomBytes(6).toString('hex');
    for (const label of ['seeker-a','seeker-b','administrator']) {
      const email=`enablework-${tag}-${label}@example.test`;
      const password=`Local-${randomBytes(24).toString('base64url')}-9aA`;
      const created=await request('/auth/v1/admin/users',{method:'POST',privileged:true,
        body:{email,password,email_confirm:true,user_metadata:{full_name:`Dummy ${label}`,role:'system_administrator'}}});
      assert.equal(created.ok,true,'Local dummy Auth user creation');
      const identity=created.data?.user ?? created.data;
      assert.ok(identity?.id,'Dummy Auth identity returned');
      const user={id:identity.id,email,password,label};
      context.users.push(user);
      if(label==='administrator') await database.query('select private.bootstrap_administrator($1)',[user.id]);
      const signed=await request('/auth/v1/token?grant_type=password',{method:'POST',body:{email,password}});
      assert.equal(signed.ok,true,'Dummy login');
      user.token=signed.data.access_token; user.refreshToken=signed.data.refresh_token;
    }
    const admin=context.users[2];
    const company=await request('/rest/v1/employers',{method:'POST',token:admin.token,
      headers:{Prefer:'return=representation'},body:{company_name:`Dummy Company ${tag}`,description:'TEST DATA ONLY'}});
    assert.equal(company.ok,true,'Create dummy company record');
    context.companies.push(company.data[0]);
    for (const status of ['published','draft']) {
      const created=await request('/rest/v1/jobs',{method:'POST',token:admin.token,headers:{Prefer:'return=representation'},
        body:{employer_id:company.data[0].id,title:`Dummy ${status} job`,description:'TEST DATA ONLY',
          qualifications:'Dummy skills',employment_type:'full_time',work_arrangement:'remote'}});
      assert.equal(created.ok,true,'Create dummy job');
      const job=created.data[0]; context.jobs.push(job);
      if(status==='published') {
        assert.equal((await request('/rest/v1/rpc/set_job_status',{method:'POST',token:admin.token,
          body:{p_job_id:job.id,p_status:'published'}})).ok,true);
      }
    }
    return context;
  } catch (error) { await cleanup(config,context); throw error; }
}

export async function uploadResume(context,user,{valid=true}={}) {
  const record=await context.request('/rest/v1/rpc/begin_resume_upload',{method:'POST',token:user.token,body:{p_title:'Dummy test resume'}});
  assert.equal(record.ok,true,'Begin resume upload');
  const row=Array.isArray(record.data)?record.data[0]:record.data;
  const path=row.storage_path.split('/').map(encodeURIComponent).join('/');
  context.uploads.push(row);
  const uploaded=await context.request(`/storage/v1/object/resumes/${path}`,{method:'POST',token:user.token,
    contentType:'application/pdf',bytes:valid?dummyPdf():Buffer.from('not a PDF')});
  assert.equal(uploaded.ok,true,'Upload dummy object');
  return row;
}

export async function cleanup(config,context) {
  try {
    if(context.uploads.length) await context.request('/storage/v1/object/resumes',{method:'DELETE',privileged:true,
      body:{prefixes:context.uploads.map(x=>x.storage_path)}});
    const users=context.users.map(x=>x.id);
    const jobs=context.jobs.map(x=>x.id);
    await context.database.query('begin');
    await context.database.query('delete from public.applications where job_id=any($1::uuid[]) or job_seeker_id=any($2::uuid[])',[jobs,users]);
    await context.database.query('delete from public.resumes where job_seeker_id=any($1::uuid[])',[users]);
    await context.database.query('delete from public.jobs where id=any($1::uuid[])',[jobs]);
    await context.database.query('delete from public.employers where id=any($1::uuid[])',[context.companies.map(x=>x.id)]);
    await context.database.query('commit');
    for(const user of context.users) {
      const deleted=await context.request(`/auth/v1/admin/users/${user.id}`,{method:'DELETE',privileged:true});
      assert.equal(deleted.ok,true,'Remove local dummy Auth identity');
    }
  } finally { await context.database.end(); }
}
