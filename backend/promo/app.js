document.addEventListener('DOMContentLoaded', async () => {
  const msg = document.getElementById('msg');
  const csrfInput = document.getElementById('csrfToken');

  // CSRF token fetch
  try {
    const res = await fetch('/csrf-token', { credentials: 'include' });
    if (res.ok) {
      const data = await res.json();
      csrfInput.value = data.token;
    } else {
      console.warn('CSRF token alınamadı');
    }
  } catch (e) {
    console.warn('CSRF isteğinde hata:', e);
  }

  // CTA measurement
  document.querySelectorAll('.cta-btn').forEach(btn => {
    btn.addEventListener('click', () => console.log('CTA clicked'));
  });

  // Form validation (client-side aid; server validates)
  const form = document.getElementById('lead-form');
  form?.addEventListener('submit', (e) => {
    const email = document.getElementById('email').value.trim();
    if (!email || !email.includes('@')) {
      e.preventDefault();
      msg.textContent = 'Lütfen geçerli bir e-posta giriniz.';
    } else {
      msg.textContent = 'Gönderiliyor…';
    }
  });

  // Active nav link highlighting
  const sections = document.querySelectorAll('section[id]');
  const links = document.querySelectorAll('.nav-link');
  const linkById = {};
  links.forEach(l => {
    const id = l.getAttribute('href').replace('#','');
    linkById[id] = l;
  });
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      const id = entry.target.id;
      const link = linkById[id];
      if (!link) return;
      if (entry.isIntersecting) {
        links.forEach(l => l.classList.remove('active'));
        link.classList.add('active');
      }
    });
  }, { rootMargin: '-40% 0px -50% 0px', threshold: 0.2 });
  sections.forEach(sec => observer.observe(sec));
});

// Modal functions
function openModal(img) {
  const modal = document.getElementById('imageModal');
  const modalImg = document.getElementById('modalImage');
  modalImg.src = img.src;
  modal.classList.add('active');
}

function closeModal() {
  const modal = document.getElementById('imageModal');
  modal.classList.remove('active');
}
