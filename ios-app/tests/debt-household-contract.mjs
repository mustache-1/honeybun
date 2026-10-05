// Debt Center+ household privacy, against a running worker (default: `npx wrangler dev --local --port 8788`; `npm run db:init:local` first):
//   node ios-app/tests/debt-household-contract.mjs
// Two people share one budget: both see the debts and each other's debt payments (that is what a shared debt is), but neither sees the other's
// PRIVATE entries, and a different household sees nothing. Exits 1 on any FAIL.
const BASE=process.env.HB_BASE||"http://localhost:8788", ORIGIN=new URL(BASE).origin;
function client(){ let cookie=""; return async (path,method="GET",body)=>{ const h={accept:"application/json",origin:ORIGIN}; if(cookie)h.cookie=cookie; let payload; if(body!==undefined||method!=="GET"){h["content-type"]="application/json";payload=JSON.stringify(body??{});} const r=await fetch(BASE+path,{method,headers:h,body:payload}); const sc=r.headers.get("set-cookie"); if(sc){const c=sc.split(",").map(x=>x.split(";")[0].trim()).filter(x=>x.startsWith("__Host-hb=")).join("; "); if(c)cookie=c;} let j=null;try{j=await r.json()}catch{} return {status:r.status,json:j}; }; }
const A=client(),B=client(); const t=Date.now()%1e7; const out=[]; let bad=0; const ok=(n,v)=>{out.push((v?"PASS ":"FAIL ")+n); if(!v)bad++;};
await A("/api/signup","POST",{name:"Ann",username:"pa"+t,password:"Passw0rd!xyzzy"});
let r=await A("/api/nests","POST",{name:"Us",kind:"couple"}); await A("/api/setup/done","POST",{});
const meA=(await A("/api/me")).json.user.id;
const nest=(await A("/api/nest?month="+new Date().toISOString().slice(0,7))).json; const code=nest.nest.invite_code;
await B("/api/signup","POST",{name:"Ben",username:"pb"+t,password:"Passw0rd!xyzzy"});
r=await B("/api/nests/join","POST",{code}); ok("Ben joins Ann's household",r.status===200);
const meB=(await B("/api/me")).json.user.id;
const month=new Date().toISOString().slice(0,7), today=new Date().toISOString().slice(0,10);
r=await A("/api/debts","POST",{name:"Shared Visa",balance:2000,apr:20,min:60}); const id=r.json.id;
await A(`/api/debts/${id}/pay`,"POST",{amount:150,member_id:meA,date:today});
await B(`/api/debts/${id}/pay`,"POST",{amount:50,member_id:meB,date:today});
// Ann's PRIVATE expense: Ben must never see it, and it must not leak into the debt totals
await A("/api/entries","POST",{type:"expense",amount:777.77,label:"Ann secret gift",date:today,member_id:meA,shared:false,private:true,category:"fun"});
const seenByB=(await B("/api/nest?month="+month)).json, seenByA=(await A("/api/nest?month="+month)).json;
const tot=(j,m)=>(j.debt_paid_by||[]).filter(c=>c.debt_id===id&&c.member_id===m).reduce((a,c)=>a+c.paid_cents,0);
ok("Ben sees the shared debt and both members' totals (Ann 15000, Ben 5000)",(seenByB.debts||[]).some(d=>d.id===id&&d.paid_cents===20000)&&tot(seenByB,meA)===15000&&tot(seenByB,meB)===5000);
ok("Ann sees the same totals",tot(seenByA,meA)===15000&&tot(seenByA,meB)===5000);
ok("Ann's private expense is visible to Ann but NOT to Ben",seenByA.entries.some(e=>e.label==="Ann secret gift")&&!seenByB.entries.some(e=>e.label==="Ann secret gift"));
ok("nothing about the private entry appears anywhere in Ben's response",!JSON.stringify(seenByB).includes("secret")&&!JSON.stringify(seenByB).includes("77777"));
ok("debt_paid_by contains only {debt_id, member_id, paid_cents}",(seenByB.debt_paid_by||[]).every(c=>Object.keys(c).sort().join()==="debt_id,member_id,paid_cents"));
// a stranger in another household sees none of it
const C=client(); await C("/api/signup","POST",{name:"Cy",username:"pc"+t,password:"Passw0rd!xyzzy"}); await C("/api/nests","POST",{name:"Other",kind:"solo"}); await C("/api/setup/done","POST",{});
const seenByC=(await C("/api/nest?month="+month)).json;
ok("a different household sees no debts and no totals",(seenByC.debts||[]).length===0&&(seenByC.debt_paid_by||[]).length===0);
r=await C(`/api/debts/${id}/pay`,"POST",{amount:5,member_id:meA,date:today}); ok("a stranger cannot pay someone else's debt (404)",r.status===404);
console.log(out.join("\n")); process.exit(bad?1:0);
