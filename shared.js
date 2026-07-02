/* ═══════════════════════════════════════════════════════
   His Creation iDefend Mission — SHARED SCRIPT
   ═══════════════════════════════════════════════════════ */

/* Language toggle */
function sl(l){
  document.body.className = (document.body.className || '').replace(/\s*(ko|en)\s*/g, ' ').trim();
  document.body.classList.add(l);
  var ko = document.getElementById('lko');
  var en = document.getElementById('len');
  if (ko) ko.classList.toggle('on', l === 'ko');
  if (en) en.classList.toggle('on', l === 'en');
  document.documentElement.lang = l;
  localStorage.setItem('jdl', l);
}
(function(){
  var s = localStorage.getItem('jdl');
  if (s) sl(s);
})();

/* Topbar scroll state (only relevant on pages that scroll) */
window.addEventListener('scroll', function(){
  var nav = document.getElementById('topbar');
  if (nav) nav.classList.toggle('sc', window.scrollY > 50);
}, { passive: true });

/* Fullscreen menu toggle */
function toggleMenu(){
  var m = document.getElementById('menu');
  var b = document.getElementById('burger');
  if (m) m.classList.toggle('open');
  if (b) b.classList.toggle('open');
}

/* Close menu on link click (mobile convenience) */
document.addEventListener('DOMContentLoaded', function(){
  var menu = document.getElementById('menu');
  if (menu) {
    menu.querySelectorAll('a').forEach(function(a){
      a.addEventListener('click', function(){
        // allow navigation; no need to prevent
      });
    });
  }
});

/* Scroll reveal */
var io = new IntersectionObserver(function(entries){
  entries.forEach(function(e){ if (e.isIntersecting) e.target.classList.add('in'); });
}, { threshold: 0.1 });
document.addEventListener('DOMContentLoaded', function(){
  document.querySelectorAll('.rv').forEach(function(el){ io.observe(el); });
});

/* Generic tab switcher: usage <button class="tab" onclick="switchTab(this,'panelId','.tabGroupSelector')"> */
function switchTab(btn, id, groupSel){
  var scope = groupSel ? document.querySelector(groupSel) : document;
  scope.querySelectorAll('.tab').forEach(function(b){ b.classList.remove('on'); });
  scope.querySelectorAll('.tpanel').forEach(function(p){ p.classList.remove('on'); });
  btn.classList.add('on');
  document.getElementById(id).classList.add('on');
}
