/**
 * 2–3 YEARS DAGESTAN — UNOFFICIAL FAN MEME ARCHIVE ENGINE
 * Implements 24 CSV Video Entries with Exact Start Timestamps & Formats
 */

document.addEventListener('DOMContentLoaded', () => {
  console.log('2-3 Years Dagestan Fan Archive Engine Initialized');

  let memeData = window.MEME_DATA;
  initApp();

  function initApp() {
    if (!memeData) return;

    renderPlaylistGrid(memeData.timestampedMemes);
    renderShortsRow(memeData.shortsMemes);
    initModalEvents();
  }

  /* ==========================================================================
     1. PLAYLIST GRID RENDERER (16:9 LANDSCAPE VIDEOS & INTERVIEWS)
     ========================================================================== */
  function renderPlaylistGrid(memes) {
    const grid = document.getElementById('playlistGrid');
    const badge = document.getElementById('playlistCountBadge');
    if (badge) badge.textContent = `${memes.length} Videos`;
    if (!grid) return;

    grid.innerHTML = memes.map(m => {
      const cleanTitle = m.title.replace(/'/g, "\\'");
      return `
        <div class="meme-card" id="${m.id}">
          <div class="card-video-frame" onclick="playInPlace(this, '${m.videoId}', '${cleanTitle}', ${m.startSeconds || 0})">
            <img class="video-thumb-img" src="https://i.ytimg.com/vi/${m.videoId}/hqdefault.jpg" alt="${m.title}" loading="lazy">
            <div class="play-btn-overlay">
              <div class="play-icon-circle">
                <svg viewBox="0 0 24 24" width="24" height="24" fill="white"><path d="M8 5v14l11-7z"/></svg>
              </div>
            </div>
            <div class="duration-chip">${m.duration}</div>
          </div>
          <div class="card-info" onclick="openMemeModal('${m.id}')">
            <div class="card-date-badge">${m.timestamp} · Starts @ ${m.startAt}</div>
            <div class="card-title">${m.title}</div>
            <div class="card-quote-preview">"${m.quote}"</div>
            <div class="card-meta">${m.views} · ${m.channel}</div>
          </div>
        </div>
      `;
    }).join('');
  }

  /* ==========================================================================
     2. SHORTS ROW RENDERER (STRICTLY 9:16 VERTICAL SHORT FORMAT)
     ========================================================================== */
  function renderShortsRow(shorts) {
    const row = document.getElementById('shortsRow');
    if (!row) return;

    row.innerHTML = shorts.map(s => `
      <div class="short-card" id="${s.id}" onclick="openMemeModal('${s.id}', true)">
        <div class="short-video-frame">
          <div class="short-vertical-poster" style="background: ${s.gradient || 'linear-gradient(180deg, #1C1917 0%, #292524 100%)'}">
            <div class="shorts-badge">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="#FF0000"><path d="M17.77 10.32l-1.2-.5a3.8 3.8 0 00-4.9-2.3 3.8 3.8 0 00-2.3 4.9l.5 1.2-1.8.8A3.8 3.8 0 005.77 19.3a3.8 3.8 0 004.9 2.3l6.5-2.7a3.8 3.8 0 002.3-4.9l-.5-1.2 1.8-.8a3.8 3.8 0 002.3-4.9 3.8 3.8 0 00-4.9-2.3z"/></svg>
              SHORTS
            </div>
            
            <div class="short-quote-overlay">
              "${s.quote}"
            </div>

            <div class="play-btn-overlay">
              <div class="play-icon-circle">
                <svg viewBox="0 0 24 24" width="22" height="22" fill="white"><path d="M8 5v14l11-7z"/></svg>
              </div>
            </div>

            <div class="duration-chip">${s.duration}</div>
          </div>
        </div>
        <div class="short-info">
          <div class="short-name">${s.title}</div>
          <div class="short-views">${s.views}</div>
        </div>
      </div>
    `).join('');
  }

  /* ==========================================================================
     3. PLAY IN PLACE HANDLER FOR PLAYLIST WITH START TIMESTAMPS
     ========================================================================== */
  window.playInPlace = function(frameEl, videoId, title, startSeconds = 0) {
    const startParam = startSeconds ? `&start=${startSeconds}` : '';
    frameEl.innerHTML = `
      <iframe 
        src="https://www.youtube-nocookie.com/embed/${videoId}?autoplay=1&rel=0${startParam}" 
        title="${title}"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
        allowfullscreen>
      </iframe>
    `;
  };

  window.scrollToMeme = function(memeId) {
    const el = document.getElementById(memeId);
    if (el) {
      const yOffset = -110;
      const y = el.getBoundingClientRect().top + window.pageYOffset + yOffset;
      window.scrollTo({ top: y, behavior: 'smooth' });
    }
  };

  /* ==========================================================================
     4. MODAL LIGHTBOX WITH LIVE YOUTUBE IFRAME & EXACT START TIMESTAMPS
     ========================================================================== */
  window.openMemeModal = function(id, isShort = false) {
    const modal = document.getElementById('memeModal');
    const slot = document.getElementById('modalEmbedSlot');
    const titleEl = document.getElementById('modalTitle');
    const metaEl = document.getElementById('modalMeta');
    const quoteEl = document.getElementById('modalQuote');
    const contextEl = document.getElementById('modalContext');

    if (!modal || !memeData) return;

    let item = isShort 
      ? memeData.shortsMemes.find(s => s.id === id)
      : memeData.timestampedMemes.find(m => m.id === id);

    if (!item) return;

    titleEl.textContent = item.title;
    metaEl.textContent = `${item.timestamp || 'YouTube Shorts'} · Starts @ ${item.startAt || '00:00'} · ${item.views || ''} · ${item.channel || 'Fan Vault'}`;
    quoteEl.textContent = `"${item.quote}"`;
    contextEl.textContent = item.context || 'Classic Islam Makhachev internet meme moment.';

    const startParam = item.startSeconds ? `&start=${item.startSeconds}` : '';

    // Inject Live YouTube Iframe into Modal with Exact Start Timestamp
    slot.innerHTML = `
      <iframe 
        src="https://www.youtube-nocookie.com/embed/${item.videoId}?autoplay=1&rel=0${startParam}" 
        title="${item.title}"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
        allowfullscreen>
      </iframe>
    `;

    modal.classList.add('active');
  };

  function initModalEvents() {
    const modal = document.getElementById('memeModal');
    const closeBtn = document.getElementById('modalCloseBtn');
    const slot = document.getElementById('modalEmbedSlot');

    function closeModal() {
      if (modal) {
        modal.classList.remove('active');
        if (slot) slot.innerHTML = ''; // Stop video playback
      }
    }

    if (closeBtn) {
      closeBtn.addEventListener('click', closeModal);
    }

    if (modal) {
      modal.addEventListener('click', (e) => {
        if (e.target === modal) {
          closeModal();
        }
      });
    }

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && modal && modal.classList.contains('active')) {
        closeModal();
      }
    });
  }
});
