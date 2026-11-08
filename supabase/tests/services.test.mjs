import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { configuration, fixtures, cleanup, uploadResume } from './support/local-services.mjs';

let config;
try { config=configuration(); } catch(error) { console.error(`BLOCKED: ${error.message}`); process.exit(2); }
const context=await fixtures(config);
let passed=0;
const test=async(name,fn)=>{await fn(); passed++; console.log(`PASS ${name}`);};
const request=context.request;
const [a,b,admin]=context.users;
try {
  await test('real Auth sign-in rejects incorrect password',async()=>{
    const result=await request('/auth/v1/token?grant_type=password',{method:'POST',body:{email:a.email,password:'Incorrect-Dummy-Password-99'}});
    assert.equal(result.ok,false);
  });
  await test('public registration cannot choose administrator and requires confirmation',async()=>{
    const email=`dummy-public-${randomBytes(6).toString('hex')}@example.test`;
    const password=`Dummy-${randomBytes(24).toString('base64url')}-aA9`;
    const result=await request('/auth/v1/signup',{method:'POST',body:{email,password,data:{role:'system_administrator'}}});
    assert.equal(result.ok,true);
    const registeredUser=result.data?.user ?? result.data;
    assert.ok(registeredUser?.id);
    context.users.push({id:registeredUser.id});
    assert.equal(result.data.access_token,undefined);
    const row=await context.database.query('select role from public.profiles where id=$1',[registeredUser.id]);
    assert.equal(row.rows[0].role,'job_seeker');
    assert.equal((await request('/auth/v1/token?grant_type=password',{method:'POST',body:{email,password}})).ok,false);
  });
  await test('REST profile isolation enforced using user JWTs',async()=>{
    const result=await request(`/rest/v1/profiles?id=eq.${b.id}`,{token:a.token});
    assert.equal(result.ok,true); assert.deepEqual(result.data,[]);
  });
  await test('Phase 2 joined profile read and transactional save use only the caller',async()=>{
    const before=await request('/rest/v1/rpc/my_job_seeker_profile',{method:'POST',token:a.token,body:{}});
    assert.equal(before.ok,true);assert.equal(before.data.profile.id,a.id);
    const saved=await request('/rest/v1/rpc/save_my_job_seeker_profile',{method:'POST',token:a.token,
      body:{p_profile:{full_name:'Dummy Phase Two',phone:null},p_details:{headline:'Dummy testing',skills:['Testing']},p_expected_updated_at:before.data.profile.updated_at}});
    assert.equal(saved.ok,true);
    const stale=await request('/rest/v1/rpc/save_my_job_seeker_profile',{method:'POST',token:a.token,
      body:{p_profile:{full_name:'Stale dummy'},p_details:{},p_expected_updated_at:before.data.profile.updated_at}});
    assert.equal(stale.ok,false);
  });
  await test('Phase 2 preference updates cannot modify another seeker',async()=>{
    const forbidden=await request(`/rest/v1/accessibility_preferences?user_id=eq.${b.id}`,{method:'PATCH',token:a.token,
      headers:{Prefer:'return=representation'},body:{high_contrast:true}});
    assert.equal(forbidden.ok,true);assert.deepEqual(forbidden.data,[]);
    const own=await request(`/rest/v1/accessibility_preferences?user_id=eq.${a.id}`,{method:'PATCH',token:a.token,
      headers:{Prefer:'return=representation'},body:{high_contrast:true,text_scale:1.5,reduce_motion:true}});
    assert.equal(own.ok,true);assert.equal(own.data[0].high_contrast,true);
  });
  await test('REST role escalation denied',async()=>{
    assert.equal((await request(`/rest/v1/profiles?id=eq.${a.id}`,{method:'PATCH',token:a.token,body:{role:'system_administrator'}})).ok,false);
  });
  const resume=await uploadResume(context,a);
  const path=resume.storage_path.split('/').map(encodeURIComponent).join('/');
  await test('Storage denies cross-user download',async()=>{
    assert.equal((await request(`/storage/v1/object/authenticated/resumes/${path}`,{token:b.token})).ok,false);
  });
  await test('server-only finalization RPC inaccessible to user',async()=>{
    assert.equal((await request('/rest/v1/rpc/finalize_resume_upload',{method:'POST',token:a.token,body:{p_resume_id:resume.id}})).ok,false);
  });
  await test('resume validation Edge Function accepts dummy PDF',async()=>{
    assert.equal((await request('/functions/v1/resume-finalize',{method:'POST',token:a.token,body:{resume_id:resume.id}})).ok,true);
  });
  const invalid=await uploadResume(context,a,{valid:false});
  await test('resume validation rejects a fake PDF signature',async()=>{
    assert.equal((await request('/functions/v1/resume-finalize',{method:'POST',token:a.token,body:{resume_id:invalid.id}})).ok,false);
  });
  await test('Storage upsert overwrite denied',async()=>{
    assert.equal((await request(`/storage/v1/object/resumes/${path}`,{method:'POST',token:a.token,
      headers:{'x-upsert':'true'},contentType:'application/pdf',bytes:Buffer.from('%PDF-overwrite')})).ok,false);
  });
  await test('simultaneous duplicate submissions yield one success',async()=>{
    const responses=await Promise.all([1,2].map(()=>request('/rest/v1/rpc/submit_application',{method:'POST',token:a.token,
      body:{p_job_id:context.jobs[0].id,p_resume_id:resume.id}})));
    assert.equal(responses.filter(x=>x.ok).length,1);
  });
  await test('Phase 2 dashboard aggregates are scoped to the signed-in seeker',async()=>{
    const mine=await request('/rest/v1/rpc/my_application_counts',{method:'POST',token:a.token,body:{}});
    const theirs=await request('/rest/v1/rpc/my_application_counts',{method:'POST',token:b.token,body:{}});
    assert.equal(mine.ok,true);assert.equal(Number(mine.data[0].total),1);assert.deepEqual(theirs.data,[]);
  });
  await test('administrator can read application-attached resume',async()=>{
    assert.equal((await request(`/storage/v1/object/authenticated/resumes/${path}`,{token:admin.token})).ok,true);
  });
  await test('suspension denies access with an already issued JWT',async()=>{
    assert.equal((await request('/rest/v1/rpc/set_job_seeker_status',{method:'POST',token:admin.token,body:{p_user_id:a.id,p_status:'suspended'}})).ok,true);
    const result=await request('/rest/v1/applications',{token:a.token});
    assert.equal(result.ok,true); assert.deepEqual(result.data,[]);
    assert.equal((await request(`/storage/v1/object/authenticated/resumes/${path}`,{token:a.token})).ok,false);
  });
  await test('real Auth refresh and logout',async()=>{
    const refreshed=await request('/auth/v1/token?grant_type=refresh_token',{method:'POST',body:{refresh_token:b.refreshToken}});
    assert.equal(refreshed.ok,true);
    assert.equal((await request('/auth/v1/logout?scope=local',{method:'POST',token:refreshed.data.access_token})).ok,true);
    assert.equal((await request('/auth/v1/token?grant_type=refresh_token',{method:'POST',body:{refresh_token:refreshed.data.refresh_token}})).ok,false);
  });
  console.log(`RESULT: ${passed} live local service checks passed. No hosted services contacted.`);
} finally { await cleanup(config,context); }
