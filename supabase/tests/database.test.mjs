import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { configuration } from './support/local-services.mjs';

const db = new PGlite(); // In-memory only: no host, URL, credential or remote connection.
let passed = 0;
const seeker = '10000000-0000-4000-8000-000000000001';
const other = '10000000-0000-4000-8000-000000000002';
const admin = '10000000-0000-4000-8000-000000000003';
const company = '20000000-0000-4000-8000-000000000001';
const job = '30000000-0000-4000-8000-000000000001';
const draft = '30000000-0000-4000-8000-000000000002';
const expired = '30000000-0000-4000-8000-000000000003';
const one = async (sql, args = []) => (await db.query(sql, args)).rows[0];
async function test(name, fn) { await fn(); passed++; console.log(`PASS ${name}`); }
async function asUser(id, fn, role = 'authenticated') {
  await db.exec('begin');
  try {
    await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id ?? '']);
    await db.exec(`set local role ${role}`);
    const value = await fn();
    await db.exec('commit');
    return value;
  } catch (error) { await db.exec('rollback'); throw error; }
}
const denied = async (id, sql, args = [], code = '42501', role) =>
  assert.rejects(asUser(id, () => db.query(sql, args), role), error => error.code === code);

try {
  await db.exec(await readFile(new URL('./support/managed-schemas.sql', import.meta.url), 'utf8'));
  const directory = new URL('../migrations/', import.meta.url);
  const migrations = (await readdir(directory)).filter(x => x.endsWith('.sql')).sort();
  for (const name of migrations) {
    await db.exec(await readFile(new URL(name, directory), 'utf8'));
    console.log(`APPLIED ${name}`);
  }
  console.log(`PostgreSQL: ${(await one('select version() as version')).version}`);
  await test('all seven application tables enable RLS', async () => {
    const row = await one("select count(*)::int n, bool_and(relrowsecurity) secure from pg_class where relnamespace='public'::regnamespace and relkind='r'");
    assert.equal(row.n, 7); assert.equal(row.secure, true);
  });
  await db.query('insert into auth.users(id,raw_user_meta_data) values ($1,$2),($3,$4),($5,$6)', [
    seeker, {full_name:'Dummy Seeker A', role:'system_administrator'},
    other, {full_name:'Dummy Seeker B'}, admin, {full_name:'Dummy Administrator'}]);
  await test('forged signup metadata cannot create an administrator', async () => {
    assert.equal((await one('select role from public.profiles where id=$1',[seeker])).role,'job_seeker');
  });
  await test('signup creates seeker and preference rows', async () => {
    assert.equal((await one('select count(*)::int n from public.accessibility_preferences')).n,3);
  });
  await db.query('select private.bootstrap_administrator($1)',[admin]);
  await test('trusted bootstrap removes seeker-only rows', async () => {
    assert.equal((await one('select role from public.profiles where id=$1',[admin])).role,'system_administrator');
    assert.equal((await one('select count(*)::int n from public.job_seeker_profiles where user_id=$1',[admin])).n,0);
  });
  await test('public bootstrap execute revoked', () => denied(seeker,'select private.bootstrap_administrator($1)',[seeker]));
  await test('service role cannot bootstrap administrator', () => denied(null,'select private.bootstrap_administrator($1)',[seeker],'42501','service_role'));
  await test('role column not client writable', () => denied(seeker,"update public.profiles set role='system_administrator' where id=$1",[seeker]));
  await test('account status not client writable', () => denied(seeker,"update public.profiles set account_status='suspended' where id=$1",[other]));
  await test('profile insertion forbidden', () => denied(seeker,'insert into public.profiles(id) values($1)',[seeker]));
  await test('own profile readable; another profile hidden', async () => {
    assert.equal((await asUser(seeker,()=>one('select count(*)::int n from public.profiles'))).n,1);
  });
  await test('cross-user profile update changes no rows', async () => {
    assert.equal((await asUser(seeker,()=>db.query("update public.profiles set full_name='Forged' where id=$1 returning id",[other]))).rows.length,0);
  });
  await test('owner profile edit succeeds', async () => {
    await asUser(seeker,()=>db.query("update public.profiles set full_name='Dummy Seeker A updated' where id=$1",[seeker]));
  });
  await test('administrator reads seekers but not their preferences', async () => {
    assert.equal((await asUser(admin,()=>one('select count(*)::int n from public.job_seeker_profiles'))).n,2);
    assert.equal((await asUser(admin,()=>one('select count(*)::int n from public.accessibility_preferences'))).n,0);
  });
  await test('cross-user preferences hidden', async () => {
    assert.equal((await asUser(seeker,()=>one('select count(*)::int n from public.accessibility_preferences'))).n,1);
  });
  await test('accessibility text scale bounded', () => denied(seeker,'update public.accessibility_preferences set text_scale=3 where user_id=$1',[seeker],'23514'));
  await test('anonymous profile access denied', () => denied(null,'select * from public.profiles',[],'42501','anon'));

  await db.query('insert into public.employers(id,company_name,created_by,updated_by) values($1,$2,$3,$3)',[company,'Dummy Company Only',admin]);
  await db.query(`insert into public.jobs(id,employer_id,title,description,qualifications,employment_type,work_arrangement,created_by,updated_by)
    values ($1,$4,'Dummy Open Job','Dummy description','Dummy skills','full_time','remote',$5,$5),
    ($2,$4,'Dummy Draft','Dummy description','Dummy skills','part_time','onsite',$5,$5),
    ($3,$4,'Dummy Expired','Dummy description','Dummy skills','contract','hybrid',$5,$5)`,[job,draft,expired,company,admin]);
  await asUser(admin,()=>db.query('select public.set_job_status($1,$2)',[job,'published']));
  await db.query("update public.jobs set status='published',published_at=now()-interval '2 days',application_deadline=now()-interval '1 day' where id=$1",[expired]);
  await test('seekers see open jobs, not drafts or expired jobs', async () => {
    assert.equal((await asUser(seeker,()=>one('select count(*)::int n from public.jobs'))).n,1);
  });
  await test('employers never become auth users', async () => {
    assert.equal((await one('select count(*)::int n from auth.users')).n,3);
    assert.equal((await asUser(seeker,()=>one('select count(*)::int n from public.employers'))).n,1);
  });
  await test('seeker employer creation denied', () => denied(seeker,"insert into public.employers(company_name) values('Forbidden')"));
  await test('seeker job creation denied', () => denied(seeker,"insert into public.jobs(employer_id,title,description,qualifications,employment_type,work_arrangement) values($1,'Bad','Bad','Bad','full_time','remote')",[company]));
  await test('direct publication denied even to frontend admin', () => denied(admin,"update public.jobs set status='published' where id=$1",[draft]));
  await test('seeker status RPC denied', () => denied(seeker,'select public.set_job_status($1,$2)',[draft,'published']));
  await test('job salary constraint enforced', () => denied(admin,'update public.jobs set salary_min=10,salary_max=1 where id=$1',[job],'23514'));
  await test('administrator content update allowed', () => asUser(admin,()=>db.query("update public.jobs set title='Updated Dummy Job' where id=$1",[job])));

  const begin = async id => (await asUser(id,()=>one("select * from public.begin_resume_upload('Dummy test PDF')")));
  const resume = await begin(seeker);
  const foreignResume = await begin(other);
  const unused = await begin(seeker);
  const objectInsert = 'insert into storage.objects(bucket_id,name,owner_id,metadata) values($1,$2,$3,$4)';
  await test('private resume bucket and PDF limit configured', async () => {
    const bucket = await one("select * from storage.buckets where id='resumes'");
    assert.equal(bucket.public,false); assert.equal(Number(bucket.file_size_limit),5242880);
    assert.deepEqual(bucket.allowed_mime_types,['application/pdf']);
  });
  await test('own predetermined upload allowed', () => asUser(seeker,()=>db.query(objectInsert,['resumes',resume.storage_path,seeker,{size:100,mimetype:'application/pdf'}])));
  await test('cross-user storage upload denied', () => denied(other,objectInsert,['resumes',unused.storage_path,other,{size:100,mimetype:'application/pdf'}]));
  await test('owner_id spoof denied', () => denied(other,objectInsert,['resumes',foreignResume.storage_path,seeker,{size:100,mimetype:'application/pdf'}]));
  await test('unregistered object path denied', () => denied(seeker,objectInsert,['resumes',`${seeker}/unregistered.pdf`,seeker,{size:100}]));
  await test('anonymous storage read returns no rows', async () => {
    assert.equal((await asUser(null,()=>one('select count(*)::int n from storage.objects'),'anon')).n,0);
  });
  await test('another seeker cannot read object', async () => {
    assert.equal((await asUser(other,()=>one('select count(*)::int n from storage.objects'))).n,0);
  });
  await test('admin cannot read unsubmitted resume', async () => {
    assert.equal((await asUser(admin,()=>one('select count(*)::int n from public.resumes'))).n,0);
    assert.equal((await asUser(admin,()=>one('select count(*)::int n from storage.objects'))).n,0);
  });
  await test('seeker cannot mark file ready directly', () => denied(seeker,"update public.resumes set upload_status='ready',size_bytes=100 where id=$1",[resume.id]));
  await test('seeker cannot call server finalizer', () => denied(seeker,'select public.finalize_resume_upload($1)',[resume.id]));
  await test('pending resume cannot be submitted', () => denied(seeker,'select public.submit_application($1,$2)',[job,resume.id]));
  await test('missing storage object cannot finalize', () => assert.rejects(db.query('select public.finalize_resume_upload($1)',[unused.id]),e=>e.code==='23514'));
  await asUser(null,()=>db.query('select public.finalize_resume_upload($1)',[resume.id]),'service_role');
  await test('server finalizer records ready size', async () => {
    const row=await one('select upload_status,size_bytes from public.resumes where id=$1',[resume.id]);
    assert.equal(row.upload_status,'ready'); assert.equal(Number(row.size_bytes),100);
  });
  await test('storage update/overwrite forbidden', async () => {
    assert.equal((await asUser(seeker,()=>db.query("update storage.objects set metadata='{}' where name=$1 returning id",[resume.storage_path]))).rows.length,0);
  });
  await test('foreign resume cannot be submitted', () => denied(other,'select public.submit_application($1,$2)',[job,resume.id]));
  await test('draft job submission rejected', () => denied(seeker,'select public.submit_application($1,$2)',[draft,resume.id],'23514'));
  await test('expired job submission rejected', () => denied(seeker,'select public.submit_application($1,$2)',[expired,resume.id],'23514'));
  const application = (await asUser(seeker,()=>one('select public.submit_application($1,$2) id',[job,resume.id]))).id;
  await test('duplicate application rejected', () => denied(seeker,'select public.submit_application($1,$2)',[job,resume.id],'23505'));
  await test('application owner reads own, other seeker sees none', async () => {
    assert.equal((await asUser(seeker,()=>one('select count(*)::int n from public.applications'))).n,1);
    assert.equal((await asUser(other,()=>one('select count(*)::int n from public.applications'))).n,0);
  });
  await test('application direct writes forbidden', () => denied(seeker,"update public.applications set status='hired' where id=$1",[application]));
  await test('application direct insert forbidden', () => denied(seeker,'insert into public.applications(job_id,job_seeker_id,resume_id) values($1,$2,$3)',[draft,seeker,resume.id]));
  await test('cross-owner composite FK enforced even for trusted SQL', () => assert.rejects(db.query('insert into public.applications(job_id,job_seeker_id,resume_id) values($1,$2,$3)',[draft,other,resume.id]),e=>e.code==='23503'));
  await test('admin reads submitted resume only', async () => {
    assert.equal((await asUser(admin,()=>one('select count(*)::int n from public.resumes'))).n,1);
    assert.equal((await asUser(admin,()=>one('select count(*)::int n from storage.objects'))).n,1);
  });
  await test('submitted resume cannot enter deletion', () => denied(seeker,'select public.begin_resume_deletion($1)',[resume.id],'23503'));
  await test('submitted storage object cannot be deleted', async () => {
    assert.equal((await asUser(seeker,()=>db.query('delete from storage.objects where name=$1 returning id',[resume.storage_path]))).rows.length,0);
  });
  await test('invalid application transition rejected', () => denied(admin,'select public.set_application_status($1,$2)',[application,'hired'],'23514'));
  await test('valid application transitions accepted', async () => {
    for (const status of ['under_review','shortlisted','hired']) await asUser(admin,()=>db.query('select public.set_application_status($1,$2)',[application,status]));
  });
  await test('terminal status cannot reopen', () => denied(admin,'select public.set_application_status($1,$2)',[application,'submitted'],'23514'));
  await asUser(admin,()=>db.query('select public.set_job_status($1,$2)',[job,'inactive']));
  await test('historical jobs visible only to their applicants', async () => {
    assert.equal((await asUser(seeker,()=>one('select count(*)::int n from public.jobs where id=$1',[job]))).n,1);
    assert.equal((await asUser(other,()=>one('select count(*)::int n from public.jobs where id=$1',[job]))).n,0);
  });
  await test('job with application cannot return to draft', () => denied(admin,'select public.set_job_status($1,$2)',[job,'draft'],'23514'));
  await test('inactive employer blocks publishing', async () => {
    await asUser(admin,()=>db.query('update public.employers set is_active=false where id=$1',[company]));
    await denied(admin,'select public.set_job_status($1,$2)',[draft,'published'],'23514');
  });
  await test('owner can set current ready resume', () => asUser(seeker,()=>db.query('select public.set_current_resume($1)',[resume.id])));
  await test('other user cannot set current resume', () => denied(other,'select public.set_current_resume($1)',[resume.id]));
  await test('current flag cannot be changed directly', () => denied(seeker,'update public.resumes set is_current=true where id=$1',[unused.id]));
  await test('cross-user metadata hidden', async () => {
    assert.equal((await asUser(other,()=>one('select count(*)::int n from public.resumes where id=$1',[resume.id]))).n,0);
  });
  await test('unused resume deletion workflow succeeds', async () => {
    await asUser(seeker,()=>db.query('select public.begin_resume_deletion($1)',[unused.id]));
    await asUser(seeker,()=>db.query('select public.complete_resume_deletion($1)',[unused.id]));
    assert.equal((await one('select count(*)::int n from public.resumes where id=$1',[unused.id])).n,0);
  });
  await test('admin cannot change own account through seeker status RPC', () => denied(admin,'select public.set_job_seeker_status($1,$2)',[admin,'suspended'],'P0002'));
  await asUser(admin,()=>db.query('select public.set_job_seeker_status($1,$2)',[seeker,'suspended']));
  await test('suspension immediately denies profile/application/storage access', async () => {
    for (const table of ['profiles','job_seeker_profiles','accessibility_preferences','applications','resumes'])
      assert.equal((await asUser(seeker,()=>one(`select count(*)::int n from public.${table}`))).n,0);
    assert.equal((await asUser(seeker,()=>one('select count(*)::int n from storage.objects'))).n,0);
  });
  await test('suspended user cannot invoke seeker operations', () => denied(seeker,"select public.begin_resume_upload('Blocked')"));
  await test('seeker cannot restore self', () => denied(seeker,'select public.set_job_seeker_status($1,$2)',[seeker,'active']));
  await asUser(admin,()=>db.query('select public.set_job_seeker_status($1,$2)',[seeker,'active']));
  await test('trusted bootstrap refuses seeker with submissions', () => assert.rejects(db.query('select private.bootstrap_administrator($1)',[seeker]),e=>e.code==='23514'));
  await test('all application security-definer functions pin search_path', async () => {
    const result=await db.query("select proname,proconfig from pg_proc where prosecdef and pronamespace in ('public'::regnamespace,'private'::regnamespace)");
    assert.ok(result.rows.length>10);
    for (const row of result.rows) assert.ok(row.proconfig?.some(x=>x.startsWith('search_path=')),row.proname);
  });
  await test('default PUBLIC cannot execute privileged public functions', async () => {
    const result=await db.query("select proname,has_function_privilege('anon',oid,'EXECUTE') allowed from pg_proc where prosecdef and pronamespace='public'::regnamespace");
    for(const row of result.rows) assert.equal(row.allowed,false,row.proname);
  });
  await test('administrator cannot acquire a seeker child row', () => assert.rejects(
    db.query('insert into public.job_seeker_profiles(user_id) values($1)',[admin]), e=>e.code==='23514'));
  await test('local service guard rejects hosted API before credentials or connections', async () => {
    const old=process.env.SUPABASE_LOCAL_API_URL;
    process.env.SUPABASE_LOCAL_API_URL='https://example.supabase.co';
    try { assert.throws(()=>configuration(),/Refusing non-local API/); }
    finally { if(old===undefined) delete process.env.SUPABASE_LOCAL_API_URL; else process.env.SUPABASE_LOCAL_API_URL=old; }
  });
  await test('local service guard rejects hosted SQL destination', async () => {
    const names=['SUPABASE_LOCAL_API_URL','SUPABASE_LOCAL_PUBLIC_KEY','SUPABASE_LOCAL_SECRET_KEY','SUPABASE_LOCAL_DB_URL'];
    const old=Object.fromEntries(names.map(n=>[n,process.env[n]]));
    Object.assign(process.env,{SUPABASE_LOCAL_API_URL:'http://127.0.0.1:54321',SUPABASE_LOCAL_PUBLIC_KEY:'dummy',
      SUPABASE_LOCAL_SECRET_KEY:'dummy',SUPABASE_LOCAL_DB_URL:'postgresql://dummy:dummy@example.test:54322/postgres'});
    try { assert.throws(()=>configuration(),/Refusing non-local database/); }
    finally { for(const n of names) { if(old[n]===undefined) delete process.env[n]; else process.env[n]=old[n]; } }
  });
  await test('local SQL guard rejects query-based connection overrides', async () => {
    const names=['SUPABASE_LOCAL_API_URL','SUPABASE_LOCAL_PUBLIC_KEY','SUPABASE_LOCAL_SECRET_KEY','SUPABASE_LOCAL_DB_URL'];
    const old=Object.fromEntries(names.map(n=>[n,process.env[n]]));
    Object.assign(process.env,{SUPABASE_LOCAL_API_URL:'http://127.0.0.1:54321',SUPABASE_LOCAL_PUBLIC_KEY:'dummy',
      SUPABASE_LOCAL_SECRET_KEY:'dummy',SUPABASE_LOCAL_DB_URL:'postgresql://127.0.0.1:54322/postgres?host=example.test'});
    try { assert.throws(()=>configuration(),/Refusing non-local database/); }
    finally { for(const n of names) { if(old[n]===undefined) delete process.env[n]; else process.env[n]=old[n]; } }
  });
  const badMime=await begin(seeker);
  await asUser(seeker,()=>db.query(objectInsert,['resumes',badMime.storage_path,seeker,{size:100}]));
  await test('server finalization rejects missing MIME metadata',()=>assert.rejects(
    db.query('select public.finalize_resume_upload($1)',[badMime.id]),e=>e.code==='23514'));
  const badSize=await begin(seeker);
  await asUser(seeker,()=>db.query(objectInsert,['resumes',badSize.storage_path,seeker,{size:5242881,mimetype:'application/pdf'}]));
  await test('server finalization rejects oversized object metadata',()=>assert.rejects(
    db.query('select public.finalize_resume_upload($1)',[badSize.id]),e=>e.code==='23514'));
  const disposable=await begin(seeker);
  await asUser(seeker,()=>db.query(objectInsert,['resumes',disposable.storage_path,seeker,{size:100,mimetype:'application/pdf'}]));
  await db.query('select public.finalize_resume_upload($1)',[disposable.id]);
  await test('partial unique index rejects multiple current resumes',()=>assert.rejects(
    db.query('update public.resumes set is_current=true where id=$1',[disposable.id]),e=>e.code==='23505'));
  await test('selecting a new current resume clears the previous one',async()=>{
    await asUser(seeker,()=>db.query('select public.set_current_resume($1)',[disposable.id]));
    assert.equal((await one('select count(*)::int n from public.resumes where job_seeker_id=$1 and is_current',[seeker])).n,1);
    assert.equal((await one('select is_current from public.resumes where id=$1',[resume.id])).is_current,false);
  });
  await asUser(seeker,()=>db.query('select public.begin_resume_deletion($1)',[disposable.id]));
  await test('metadata cannot disappear before the Storage object',()=>denied(seeker,
    'select public.complete_resume_deletion($1)',[disposable.id],'23514'));
  await test('deletion permits removing only a marked unattached object',async()=>{
    assert.equal((await asUser(seeker,()=>db.query('delete from storage.objects where name=$1 returning id',[disposable.storage_path]))).rows.length,1);
    await asUser(seeker,()=>db.query('select public.complete_resume_deletion($1)',[disposable.id]));
  });
  await test('frontend roles cannot create schema objects', async () => {
    for (const role of ['anon','authenticated']) {
      for (const schema of ['public','private']) {
        assert.equal((await one('select has_schema_privilege($1,$2,$3) allowed',[role,schema,'CREATE'])).allowed,false);
      }
    }
  });
  console.log(`RESULT: ${passed} database/security checks passed. Managed Auth/Storage are test doubles; no HTTP service or concurrency validation claimed.`);
} finally { await db.close(); }
