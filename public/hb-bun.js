// Honeybun Bun assistant — useful, private, and powered by the user's own budget data.
// No third-party AI call: answers are calculated from the authenticated /api/nest payload.
(function(){
  "use strict";
  const $ = (id) => document.getElementById(id);
  const money = (n) => new Intl.NumberFormat(undefined,{style:"currency",currency:"USD"}).format(Number(n||0));
  const cats = {home:"Housing",groc:"Groceries",food:"Eating out",date:"Date night",bills:"Bills",subs:"Subscriptions",car:"Getting around",fun:"Gifts & fun",pets:"Kids & pets",debt:"Debt payments",other:"Other"};

  function monthKey(offset){
    const d = new Date(); d.setDate(1); d.setMonth(d.getMonth()+(offset||0));
    return d.getFullYear()+"-"+String(d.getMonth()+1).padStart(2,"0");
  }
  function monthName(key){ const [y,m]=key.split("-").map(Number); return new Date(y,m-1,1).toLocaleDateString(undefined,{month:"long",year:"numeric"}); }
  function qMonth(q){ q=q.toLowerCase(); if(q.includes("last month")||q.includes("previous month")) return monthKey(-1); return monthKey(0); }
  async function getData(month){
    const r=await fetch("/api/nest?month="+encodeURIComponent(month),{credentials:"same-origin"});
    if(!r.ok) throw new Error("I couldn't load your budget right now.");
    return r.json();
  }
  function entries(d){ return (d.entries||[]).map(e=>({...e,amount:Number(e.amount_cents||0)/100})); }
  function memberName(d,id){ const m=(d.members||[]).find(x=>x.user_id===id||x.id===id); return m?m.name:"Someone"; }
  function totals(d){
    const es=entries(d), income=es.filter(e=>e.type==="income").reduce((s,e)=>s+e.amount,0), spent=es.filter(e=>e.type==="expense").reduce((s,e)=>s+e.amount,0);
    return {es,income,spent,left:income-spent};
  }
  function byCategory(es){ const o={}; es.filter(e=>e.type==="expense").forEach(e=>{const k=e.category||"other";o[k]=(o[k]||0)+e.amount}); return o; }
  function topEntries(es,n){ return es.filter(e=>e.type==="expense").slice().sort((a,b)=>b.amount-a.amount).slice(0,n||3); }
  function topCats(es,n){ return Object.entries(byCategory(es)).sort((a,b)=>b[1]-a[1]).slice(0,n||3); }

  function summary(d,month){
    const t=totals(d), tc=topCats(t.es,1)[0], big=topEntries(t.es,1)[0];
    let s=`For ${monthName(month)}, you brought in ${money(t.income)} and spent ${money(t.spent)}, leaving ${money(t.left)}.`;
    if(tc) s+=` Your biggest category is ${cats[tc[0]]||tc[0]} at ${money(tc[1])}.`;
    if(big) s+=` Your biggest single expense was ${big.label||"an expense"} for ${money(big.amount)}.`;
    const count=t.es.filter(e=>e.type==="expense").length; s+=` You logged ${count} expense${count===1?"":"s"}.`;
    return s;
  }
  function categoryAnswer(d,q){
    const t=totals(d), map=byCategory(t.es), low=q.toLowerCase();
    const aliases={home:["housing","rent","home"],groc:["groceries","grocery"],food:["food","eating out","restaurant","restaurants"],date:["date","date night"],bills:["bill","bills","utilities"],subs:["subscription","subscriptions"],car:["car","gas","transportation","getting around"],fun:["fun","gifts"],pets:["pets","kids"],debt:["debt","credit card"],other:["other"]};
    for(const [k,words] of Object.entries(aliases)) if(words.some(w=>low.includes(w))) return `You spent ${money(map[k]||0)} on ${cats[k]} this month.`;
    return null;
  }
  function merchantAnswer(d,q){
    const low=q.toLowerCase(), es=entries(d).filter(e=>e.type==="expense");
    const common=[...new Set(es.map(e=>(e.label||"").trim()).filter(Boolean))].sort((a,b)=>b.length-a.length);
    const hit=common.find(x=>low.includes(x.toLowerCase())); if(!hit) return null;
    const arr=es.filter(e=>(e.label||"").toLowerCase()===hit.toLowerCase());
    return `You spent ${money(arr.reduce((s,e)=>s+e.amount,0))} at ${hit} across ${arr.length} transaction${arr.length===1?"":"s"}.`;
  }
  function personAnswer(d,q){
    const low=q.toLowerCase(); const m=(d.members||[]).find(x=>x.name&&low.includes(x.name.toLowerCase())); if(!m) return null;
    const es=entries(d).filter(e=>e.type==="expense"&&(e.member_id===m.user_id||e.member_id===m.id));
    return `${m.name} logged ${money(es.reduce((s,e)=>s+e.amount,0))} in spending this month across ${es.length} transaction${es.length===1?"":"s"}.`;
  }
  function budgetAnswer(d){
    const es=entries(d), spent=byCategory(es), bs=d.budgets||[]; if(!bs.length) return "You don't have category budgets set yet. Add them in Plan and I can tell you what's over or under.";
    const rows=bs.map(b=>{const lim=Number(b.limit_cents||0)/100, used=spent[b.category]||0;return {cat:b.category,lim,used,diff:lim-used}}).sort((a,b)=>a.diff-b.diff);
    const over=rows.filter(x=>x.diff<0); if(over.length) return `You're over budget in ${over.length} categor${over.length===1?"y":"ies"}. ${over.slice(0,3).map(x=>`${cats[x.cat]||x.cat} by ${money(Math.abs(x.diff))}`).join(", ")}.`;
    const tight=rows[0]; return `You're within all your category budgets. ${cats[tight.cat]||tight.cat} is the closest, with ${money(Math.max(0,tight.diff))} left.`;
  }
  function goalsAnswer(d){ const gs=d.goals||[]; if(!gs.length) return "You don't have a savings goal yet."; return gs.slice(0,3).map(g=>{const saved=Number(g.saved_cents||0)/100,target=Number(g.target_cents||0)/100,p=target?Math.round(saved/target*100):0;return `${g.emoji||"♡"} ${g.name}: ${money(saved)} of ${money(target)} (${p}%)`;}).join("\n"); }
  function debtAnswer(d){ const ds=d.debts||[]; if(!ds.length) return "You don't have any debts tracked in Honeybun."; const pays=d.debt_payments||[]; return ds.slice(0,3).map(x=>{const paid=pays.filter(p=>p.debt_id===x.id).reduce((s,p)=>s+Number(p.amount_cents||0)/100,0),start=Number(x.start_cents||0)/100;return `${x.name}: about ${money(Math.max(0,start-paid))} remaining.`;}).join("\n"); }
  function dueAnswer(d){
    const r=(d.recurring||[]).filter(x=>x.type==="expense"); if(!r.length) return "You don't have recurring bills set up yet.";
    const total=r.reduce((s,x)=>s+Number(x.amount_cents||0)/100,0); return `You have ${r.length} recurring bill${r.length===1?"":"s"} set up, totaling ${money(total)} per cycle. Biggest ones: ${r.slice().sort((a,b)=>b.amount_cents-a.amount_cents).slice(0,3).map(x=>`${x.label} ${money(Number(x.amount_cents||0)/100)}`).join(", ")}.`;
  }

  async function answer(q){
    const month=qMonth(q), d=await getData(month), low=q.toLowerCase().trim(), t=totals(d);
    if(/summari[sz]e|summary|how did (we|i) do|month overview|overview/.test(low)) return summary(d,month);
    if(/how much.*(spend|spent)|total spend|spent this month/.test(low)&&!categoryAnswer(d,q)&&!merchantAnswer(d,q)) return `You spent ${money(t.spent)} in ${monthName(month)}.`;
    if(/income|brought in|made this month|got paid/.test(low)) return `You brought in ${money(t.income)} in ${monthName(month)}.`;
    if(/left|remaining|have left|safe to spend/.test(low)) return `Income minus logged spending leaves ${money(t.left)} for ${monthName(month)}.`;
    if(/biggest|largest|most expensive|top expense/.test(low)){ const top=topEntries(t.es,3); return top.length?`Your biggest expenses were:\n${top.map((e,i)=>`${i+1}. ${e.label||"Expense"} — ${money(e.amount)}`).join("\n")}`:"No expenses are logged yet."; }
    if(/top categor|category|categories|where.*money/.test(low)){ const top=topCats(t.es,3); return top.length?`Top spending categories:\n${top.map(([k,v],i)=>`${i+1}. ${cats[k]||k} — ${money(v)}`).join("\n")}`:"No spending is logged yet."; }
    const ma=merchantAnswer(d,q); if(ma) return ma;
    const pa=personAnswer(d,q); if(pa) return pa;
    const ca=categoryAnswer(d,q); if(ca) return ca;
    if(/budget|over budget|under budget/.test(low)) return budgetAnswer(d);
    if(/goal|saving|savings/.test(low)) return goalsAnswer(d);
    if(/debt|owe|payoff/.test(low)) return debtAnswer(d);
    if(/due|bill|upcoming/.test(low)) return dueAnswer(d);
    if(/streak/.test(low)){const m=d.me||{};return `Your current hop streak is ${m.streak||0} day${m.streak===1?"":"s"}. Your best is ${m.best_streak||m.streak||0}.`;}
    return `I can answer questions about your Honeybun data. Try “summarize my month”, “what did I spend the most on?”, “how much did I spend on food?”, “am I over budget?”, “how are my goals?”, or ask about a merchant or household member.`;
  }

  function msg(text,who){
    const chat=$("chat"); if(!chat) return; const wrap=document.createElement("div"); wrap.className="hb-bun-msg "+(who==="me"?"me":"bun");
    const bubble=document.createElement("div"); bubble.className="hb-bun-bubble"; bubble.textContent=text; wrap.appendChild(bubble); chat.appendChild(wrap); chat.scrollTop=chat.scrollHeight;
  }
  async function ask(q){ q=(q||"").trim(); if(!q)return; msg(q,"me"); msg("Thinking…","bun"); const chat=$("chat"); const thinking=chat&&chat.lastElementChild;
    try{const a=await answer(q); if(thinking) thinking.remove(); msg(a,"bun");}catch(e){if(thinking)thinking.remove();msg(e.message||"I couldn't read your budget right now.","bun");}
  }
  function mount(){
    const chat=$("chat"), quick=document.querySelector("#scr-inbox .quick-replies"); if(!chat||!quick||$("hbBunForm")) return false;
    if(chat.textContent.trim()==="Not found."||!chat.children.length){chat.innerHTML="";msg("Hi ♡ Ask me anything about your Honeybun budget. I can summarize your month, find where your money went, check budgets, goals, debts, and more.","bun");}
    const form=document.createElement("form");form.id="hbBunForm";form.className="hb-bun-form";
    const input=document.createElement("input");input.id="hbBunInput";input.type="text";input.autocomplete="off";input.placeholder="Ask Bun about your money…";input.setAttribute("aria-label","Ask Bun a budget question");
    const button=document.createElement("button");button.type="submit";button.textContent="Ask";form.append(input,button);quick.parentNode.insertBefore(form,quick);
    form.addEventListener("submit",e=>{e.preventDefault();const q=input.value;input.value="";ask(q);});
    const q1=$("qrDue"),q2=$("qrStreak"),q3=$("qrAdd");
    if(q1){q1.textContent="Summarize month";q1.onclick=()=>ask("summarize my month");}
    if(q2){q2.textContent="Biggest spend";q2.onclick=()=>ask("what were my biggest expenses?");}
    if(q3){q3.textContent="Am I over budget?";q3.onclick=()=>ask("am I over budget?");}
    return true;
  }
  function boot(){let tries=0;const timer=setInterval(()=>{tries++;if(mount()||tries>40)clearInterval(timer)},250);}
  if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",()=>setTimeout(boot,400));else setTimeout(boot,400);
})();
