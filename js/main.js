/**
 * 2–3 YEARS DAGESTAN — UNOFFICIAL FAN MEME ARCHIVE ENGINE
 * Rounded Light Theme, Scrubber Progress Bar & Live Video Modal Handler
 */

document.addEventListener('DOMContentLoaded', () => {
  console.log('2-3 Years Dagestan Fan Archive Engine Initialized');

  let memeData = null;

  // Load data from global variable (avoids CORS issues on local file://)
  memeData = window.MEME_DATA;
  initApp();

  function initApp() {
    if (!memeData) return;

    renderPlaylistGrid(memeData.timestampedMemes);
    renderShortsRow(memeData.shortsMemes);
    initModalEvents();
  }

  /* ==========================================================================
     1. PLAYLIST GRID RENDERER
     ========================================================================== */
  function renderPlaylistGrid(memes) {
    const grid = document.getElementById('playlistGrid');
    if (!grid) return;

    grid.innerHTML = memes.map(m => `
      <div class="meme-card" id="${m.id}" onclick="openMemeModal('${m.id}')">
        <div class="card-thumbnail-box">
          <div class="thumbnail-caption">${m.title}</div>
          <div class="duration-chip">${m.duration}</div>
        </div>
        <div class="card-info">
          <div class="card-date-badge">${m.timestamp}</div>
          <div class="card-title">${m.title}</div>
          <div class="card-meta">${m.views} · ${m.channel}</div>
        </div>
      </div>
    `).join('');
  }

  /* ==========================================================================
     2. SHORTS ROW RENDERER
     ========================================================================== */
  function renderShortsRow(shorts) {
    const row = document.getElementById('shortsRow');
    if (!row) return;

    row.innerHTML = shorts.map(s => `
      <div class="short-card" onclick="openMemeModal('${s.id}', true)">
        <div class="short-thumbnail-box">
          <div class="short-title">"${s.quote}"</div>
          <div class="duration-chip">${s.duration}</div>
        </div>
        <div class="short-info">
          <div class="short-name">${s.title}</div>
          <div class="short-views">${s.views}</div>
        </div>
      </div>
    `).join('');
  }

  window.scrollToMeme = function(memeId) {
    const el = document.getElementById(memeId);
    if (el) {
      const yOffset = -110;
      const y = el.getBoundingClientRect().top + window.pageYOffset + yOffset;
      window.scrollTo({ top: y, behavior: 'smooth' });
    }
  };

  /* ==========================================================================
     4. MODAL LIGHTBOX WITH LIVE YOUTUBE IFRAME
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
    metaEl.textContent = `${item.timestamp || 'Shorts'} · ${item.views || ''} · ${item.channel || 'Fan Vault'}`;
    quoteEl.textContent = `"${item.quote}"`;
    contextEl.textContent = item.context || 'Classic Islam Makhachev internet meme moment.';

    // Inject Live YouTube Iframe
    const embedUrl = "https://www.youtube.com/embed/NaF0TUvWEk0?start=54";
    slot.innerHTML = `
      <iframe 
        src="${embedUrl}" 
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
