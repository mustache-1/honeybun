// Honeybun layout adapter v2: reshapes the existing wired DOM to match the approved v3 preview.
(function(){
  function q(s,r){return (r||document).querySelector(s)}
  function byId(id){return document.getElementById(id)}

  function adaptHome(){
    var home=byId('scr-home');
    if(!home || home.dataset.hbLayoutV2==='1') return;
    var hero=q('.hero',home), note=byId('bunNote'), verify=byId('verifyBanner'), tiles=q('.tiles2',home), due=byId('dueCard');
    if(!hero || !note || !tiles || !due) return;

    var grid=document.createElement('div'); grid.className='hb-home-grid';
    var primary=document.createElement('div'); primary.className='hb-home-primary';
    home.insertBefore(grid, home.firstChild);
    grid.appendChild(primary);
    primary.appendChild(hero);
    primary.appendChild(note);
    if(verify) primary.appendChild(verify);
    primary.appendChild(tiles);
    grid.appendChild(due);

    var couple=byId('couple'), filter=byId('filterNote'), bud=byId('homeBud');
    if(couple) couple.classList.add('hb-home-extra');
    if(filter) filter.classList.add('hb-home-extra');
    if(bud) bud.classList.add('hb-home-extra');

    home.dataset.hbLayoutV2='1';
  }

  function adaptHeader(){
    var top=byId('topBar');
    if(!top || top.dataset.hbLayoutV2==='1') return;
    var inbox=byId('inboxBtn'), hi=byId('hiBtn'), month=byId('monthNav');
    if(month) month.classList.add('hb-month-hidden');
    if(!q('.hb-top-actions',top)){
      var actions=document.createElement('div'); actions.className='hb-top-actions';
      var help=document.createElement('button'); help.className='hb-iconbtn'; help.type='button'; help.setAttribute('aria-label','Help'); help.textContent='?';
      help.onclick=function(){
        var existing=byId('hbHelpDialog');
        if(!existing){
          var d=document.createElement('dialog'); d.id='hbHelpDialog'; d.className='hb-help-dialog';
          d.innerHTML='<div class="hb-help-head"><strong>Honeybun help</strong><button type="button" aria-label="Close">×</button></div><p>Need help with budgets, bills, Together, exports, or your account?</p><div class="hb-help-links"><button type="button" data-help="bun">Ask Bun</button><button type="button" data-help="settings">Settings</button><button type="button" data-help="close">Close</button></div>';
          document.body.appendChild(d);
          q('.hb-help-head button',d).onclick=function(){d.close()};
          q('[data-help="close"]',d).onclick=function(){d.close()};
          q('[data-help="settings"]',d).onclick=function(){d.close(); if(hi) hi.click()};
          q('[data-help="bun"]',d).onclick=function(){d.close(); if(inbox) inbox.click()};
          existing=d;
        }
        if(existing.showModal) existing.showModal();
      };
      var settings=document.createElement('button'); settings.className='hb-iconbtn'; settings.type='button'; settings.setAttribute('aria-label','Settings'); settings.textContent='⚙'; settings.onclick=function(){if(hi) hi.click()};
      actions.appendChild(help); actions.appendChild(settings); if(inbox) actions.appendChild(inbox);
      top.appendChild(actions);
    }
    top.dataset.hbLayoutV2='1';
  }

  function init(){adaptHeader(); adaptHome();}
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',init); else init();
  new MutationObserver(init).observe(document.documentElement,{childList:true,subtree:true});
})();
