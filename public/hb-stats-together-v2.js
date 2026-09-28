(function(){
  function makeTabs(screen, labels, onPick){
    if(!screen || screen.querySelector('.hb-mini-tabs')) return;
    var tabs=document.createElement('div');
    tabs.className='hb-mini-tabs '+(labels.length===3?'three':'two');
    labels.forEach(function(label,i){
      var b=document.createElement('button');
      b.type='button'; b.textContent=label; b.setAttribute('aria-selected',i===0?'true':'false');
      b.addEventListener('click',function(){
        tabs.querySelectorAll('button').forEach(function(x){x.setAttribute('aria-selected','false')});
        b.setAttribute('aria-selected','true'); onPick(i);
      });
      tabs.appendChild(b);
    });
    var title=screen.querySelector('.page-title');
    if(title && title.nextSibling) screen.insertBefore(tabs,title.nextSibling); else screen.insertBefore(tabs,screen.firstChild);
  }
  function hide(el,yes){ if(el) el.classList.toggle('hb-sub-hidden',!!yes); }

  function initStats(){
    var s=document.getElementById('scr-stats'); if(!s) return;
    var kids=Array.from(s.children).filter(function(x){return !x.classList.contains('hb-mini-tabs') && !x.classList.contains('page-title')});
    var badgeGroup=new Set();
    var badgeHeader=null;
    kids.forEach(function(el){
      var t=(el.textContent||'').trim().toLowerCase();
      if(el.classList.contains('section-h') && t.indexOf('badge')>-1) badgeHeader=el;
      if(el.classList.contains('badges') || el.classList.contains('badge-grid')) badgeGroup.add(el);
    });
    if(badgeHeader) badgeGroup.add(badgeHeader);
    makeTabs(s,['Overview','Badges'],function(i){
      kids.forEach(function(el){ hide(el,i===1 ? !badgeGroup.has(el) : badgeGroup.has(el)); });
      window.scrollTo({top:0,behavior:'smooth'});
    });
    kids.forEach(function(el){ hide(el,badgeGroup.has(el)); });
  }

  function initTogether(){
    var s=document.getElementById('scr-us'); if(!s) return;
    var kids=Array.from(s.children).filter(function(x){return !x.classList.contains('hb-mini-tabs') && !x.classList.contains('page-title')});
    var invite=new Set(), settings=new Set(), overview=new Set();
    var mode='overview';
    kids.forEach(function(el){
      var id=(el.id||'').toLowerCase(), t=(el.textContent||'').trim().toLowerCase();
      if(id==='inviteh' || (el.classList.contains('section-h') && t.indexOf('invite')>-1)) mode='invite';
      if(id==='seth' || (el.classList.contains('section-h') && (t.indexOf('setting')>-1 || t.indexOf('preference')>-1))) mode='settings';
      if(id==='settlewrap') mode='overview';
      (mode==='invite'?invite:mode==='settings'?settings:overview).add(el);
    });
    kids.forEach(function(el){
      if(el.classList.contains('install')||el.classList.contains('legal')||el.classList.contains('center')) settings.add(el);
    });
    function show(which){
      kids.forEach(function(el){
        var keep=which===0?overview.has(el):which===1?invite.has(el):settings.has(el);
        hide(el,!keep);
      });
      window.scrollTo({top:0,behavior:'smooth'});
    }
    makeTabs(s,['Us','Invite','Settings'],show); show(0);
  }

  function init(){ if(window.innerWidth<=620){initStats();initTogether();} }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',init); else init();
})();
