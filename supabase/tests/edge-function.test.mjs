import assert from 'node:assert/strict';

// Execute the actual TypeScript handler with mocked network/runtime boundaries.
// No Supabase service or external network request is made by this suite.
let handler;
const variables={SUPABASE_URL:'http://127.0.0.1:54321',SUPABASE_ANON_KEY:'dummy-public',SUPABASE_SERVICE_ROLE_KEY:'dummy-server-only'};
globalThis.Deno={serve(fn){handler=fn;},env:{get(name){return variables[name];}}};
await import('../functions/resume-finalize/index.ts');
const originalFetch=globalThis.fetch;
const id='40000000-0000-4000-8000-000000000001';
let passed=0;
const json=(value,status=200)=>new Response(JSON.stringify(value),{status,headers:{'Content-Type':'application/json'}});
async function run({method='POST',authorization='Bearer dummy-user-session',body={resume_id:id},owner='dummy-user',status='pending',
  authStatus=200,pdf='%PDF-1.4\nTEST DATA ONLY',rpcStatus=204,missing=false,oversized=false}={}) {
  let finalized=false;
  globalThis.fetch=async(url,options={})=>{
    const parsed=new URL(url);
    assert.equal(parsed.origin,'http://127.0.0.1:54321');
    if(parsed.pathname==='/auth/v1/user') {
      assert.equal(options.headers.apikey,'dummy-public');
      return json({id:'dummy-user'},authStatus);
    }
    if(parsed.pathname==='/rest/v1/resumes') {
      assert.equal(options.headers.Authorization,authorization);
      return json(missing?[]:[{id,job_seeker_id:owner,upload_status:status,storage_path:`dummy-user/${id}/resume.pdf`}]);
    }
    if(parsed.pathname.startsWith('/storage/v1/object/authenticated/resumes/')) {
      assert.equal(options.headers.Authorization,authorization);
      return new Response(oversized?new Uint8Array(5242881):pdf);
    }
    if(parsed.pathname==='/rest/v1/rpc/finalize_resume_upload') {
      assert.equal(options.headers.apikey,'dummy-server-only');
      assert.equal(options.headers.Authorization,'Bearer dummy-server-only');
      assert.deepEqual(JSON.parse(options.body),{p_resume_id:id});
      finalized=true;
      return new Response(null,{status:rpcStatus});
    }
    throw new Error('Unexpected network boundary');
  };
  const request=new Request('http://localhost/resume-finalize',{method,headers:{Authorization:authorization},
    ...(method==='POST'?{body:JSON.stringify(body)}:{})});
  const result=await handler(request);
  return {status:result.status,finalized};
}
async function test(name,fn){await fn();passed++;console.log(`PASS ${name}`);}
try {
  await test('POST required',async()=>assert.equal((await run({method:'GET'})).status,405));
  await test('bearer authentication required',async()=>assert.equal((await run({authorization:''})).status,401));
  await test('invalid Auth token rejected',async()=>assert.equal((await run({authStatus:401})).status,401));
  await test('malformed resume ID rejected',async()=>assert.equal((await run({body:{resume_id:'invalid'}})).status,400));
  await test('missing RLS-visible metadata rejected',async()=>assert.equal((await run({missing:true})).status,403));
  await test('foreign owner rejected',async()=>assert.equal((await run({owner:'another-user'})).status,403));
  await test('already finalized file rejected',async()=>assert.equal((await run({status:'ready'})).status,403));
  await test('fake PDF never reaches privileged RPC',async()=>assert.deepEqual(await run({pdf:'fake file'}),{status:422,finalized:false}));
  await test('empty file rejected',async()=>assert.equal((await run({pdf:''})).status,422));
  await test('oversized stream bounded before finalization',async()=>assert.deepEqual(await run({oversized:true}),{status:422,finalized:false}));
  await test('owned PDF finalizes through server-only RPC',async()=>assert.deepEqual(await run(),{status:200,finalized:true}));
  await test('finalization race/failure returns conflict',async()=>assert.equal((await run({rpcStatus:409})).status,409));
  await test('missing runtime credentials fail closed',async()=>{
    const saved=variables.SUPABASE_SERVICE_ROLE_KEY; delete variables.SUPABASE_SERVICE_ROLE_KEY;
    try { assert.equal((await run()).status,503); } finally {variables.SUPABASE_SERVICE_ROLE_KEY=saved;}
  });
  console.log(`RESULT: ${passed} isolated Edge Function checks passed. Auth/Storage HTTP services are mocked.`);
} finally {globalThis.fetch=originalFetch;delete globalThis.Deno;}
