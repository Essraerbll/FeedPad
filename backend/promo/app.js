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

  // Form submission with fetch
  const form = document.getElementById('lead-form');
  form?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('email').value.trim();
    const csrfToken = document.getElementById('csrfToken').value;

    if (!email || !email.includes('@')) {
      msg.textContent = 'Lütfen geçerli bir e-posta giriniz.';
      return;
    }

    msg.textContent = 'Gönderiliyor…';

    try {
      const params = new URLSearchParams();
      params.append('email', email);
      params.append('_csrf', csrfToken);

      const res = await fetch('/lead', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: params.toString(),
        credentials: 'include'
      });

      const text = await res.text();
      console.log('Response:', text);
      let data;
      try {
        data = JSON.parse(text);
      } catch (e) {
        console.error('JSON parse error:', text);
        msg.textContent = '❌ Server hatası: ' + text;
        return;
      }

      if (res.ok && data.success) {
        msg.textContent = '✅ Kaydınız başarıyla alındı! Teşekkürler.';
        form.reset();
        document.getElementById('email').blur();
        setTimeout(() => { msg.textContent = ''; }, 5000);
      } else {
        msg.textContent = '❌ ' + (data.message || 'Bir hata oluştu');
      }
    } catch (err) {
      msg.textContent = '❌ Hata: ' + err.message;
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
      if (entry.isIntersecting) {
        const id = entry.target.id;
        const link = linkById[id];
        if (!link) return;
        links.forEach(l => l.classList.remove('active'));
        link.classList.add('active');
      }
    });
  }, { rootMargin: '0px 0px -80% 0px', threshold: 0 });
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
