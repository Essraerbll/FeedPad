document.addEventListener('DOMContentLoaded', async () => {
  const msg = document.getElementById('msg');
  const csrfInput = document.getElementById('csrfToken');

  // Language translations
  const translations = {
    tr: {
      nav_about: 'Hakkında',
      nav_features: 'Özellikler',
      nav_how: 'Nasıl Çalışır',
      nav_team: 'Ekip',
      nav_security: 'Güvenlik',
      nav_download: 'İndir',
      nav_contact: 'İletişim',
      nav_demo: 'Demo / Teklif',
      hero_title: 'Sokaktaki Dostlarımızı Birlikte Besleyelim',
      hero_subtitle: 'FeedPad ile çevrendeki besleme noktalarını gör, dostlarımızın karnını doyur ve toplulukla paylaş.',
      about_title: 'Hakkında',
      about_text: 'Sevginin dijital izini sürün. 🐾 Sokaktaki dostlarımızın beslenme duraklarını keşfetmeniz ve her iyilik anını toplulukla paylaşmanız için tasarlanmış, teknolojiyle şefkati buluşturan modern bir ekosistem. Hayvanseverleri ve gönüllü petshop\'ları şeffaf bir iyilik ağında bir araya getirirken; uçtan uca şifreli altyapımızla hem bağışlarınızı hem de verilerinizi en yüksek güvenlik standartlarında koruyoruz. Her öğünü bir mutluluk hikayesine dönüştüren bu yolculukta, dostça olduğu kadar siber dünyada da güvenli ve tamamen şeffaf bir besleme deneyimine davetlisiniz.',
      features_title: 'Neden FeedPad?',
      feature1_title: 'Besleme Haritası',
      feature1_desc: 'Yakınındaki mama noktalarını harita üzerinden anlık takip et.',
      feature2_title: 'Anı Paylaş',
      feature2_desc: 'Besleme yaptığın anları Feed üzerinden toplulukla paylaş.',
      feature3_title: 'Büyük Bir Topluluk',
      feature3_desc: 'Hayvanseverlerle iletişim kur ve ortak etkinlikler düzenle.',
      feature4_title: 'Mama Paylaş',
      feature4_desc: 'Bağışlanan mamaları şeffafça görüntüle, pay et ve ihtiyacı olan noktalara yönlendir.',
      how_title: 'Nasıl Çalışır',
      step1_title: 'Keşfet',
      step1_desc: 'Akışta yeni içerikleri keşfet; sana uygun besleme noktalarını bul.',
      step2_title: 'Konumlan',
      step2_desc: 'Harita üzerinden en yakın besleme noktasını seç ve yol tarifi al.',
      step3_title: 'Paylaş & Etkileş',
      step3_desc: 'Yorumlar, mesajlar ve bildirimlerle toplulukla etkileşimde kal.',
      step4_title: 'Bağışla & Paylaştır',
      step4_desc: 'Mama bağışlarını ekle, şeffafça izle; ihtiyaç noktasına yönlendir.',
      team_title: 'Ekip',
      team_role: 'Yazılım Mühendisi',
      security_title: 'Güvenlik & Gizlilik',
      security1_title: 'Uçtan Uca Güvenlik',
      security1_desc: 'Verileriniz şifreli sunucularda saklanır.',
      security2_title: 'KVKK Uyumlu',
      security2_desc: 'Gizliliğiniz bizim önceliğimizdir.',
      security3_title: 'Doğrulanmış Noktalar',
      security3_desc: 'Güvenli ve temiz besleme alanları.',
      download_title: 'Hemen İndir',
      download_subtitle: 'Uygulamamızı mobil cihazlarınıza indirin ve sokak dostlarımıza yardım etmeye başlayın.',
      demo_title: 'Demo / Teklif İste',
      demo_label: 'E-posta Adresiniz',
      demo_placeholder: 'ornek@domain.com',
      demo_submit: 'Gönder',
      contact_title: 'İletişim',
      contact_email: 'E-posta',
      contact_phone: 'Telefon',
      contact_address: 'Adres',
      contact_address_text: 'Muğla Menteşe, Türkiye',
      footer_tagline: 'Her pati izi bir sevgi hikayesidir. 🐾',
      footer_copyright: '© 2025 FeedPad Projesi. Tüm Hakları Saklıdır.',
      form_sending: 'Gönderiliyor…',
      form_invalid_email: 'Lütfen geçerli bir e-posta giriniz.',
      form_success: '✅ Kaydınız başarıyla alındı! Teşekkürler.',
      form_error: '❌ Bir hata oluştu'
    },
    en: {
      nav_about: 'About',
      nav_features: 'Features',
      nav_how: 'How It Works',
      nav_team: 'Team',
      nav_security: 'Security',
      nav_download: 'Download',
      nav_contact: 'Contact',
      nav_demo: 'Demo / Quote',
      hero_title: 'Let\'s Feed Our Street Friends Together',
      hero_subtitle: 'With FeedPad, discover feeding points around you, feed our friends, and share with the community.',
      about_title: 'About',
      about_text: 'Follow the digital traces of love. 🐾 A modern ecosystem that combines technology with compassion, designed for you to discover feeding stations for our street friends and share every moment of kindness with the community. While bringing together animal lovers and volunteer pet shops in a transparent network of goodness, we protect both your donations and data with end-to-end encrypted infrastructure at the highest security standards. On this journey that turns every meal into a happiness story, you are invited to a feeding experience that is both friendly and secure in the cyber world and completely transparent.',
      features_title: 'Why FeedPad?',
      feature1_title: 'Feeding Map',
      feature1_desc: 'Track nearby food points instantly on the map.',
      feature2_title: 'Share Moments',
      feature2_desc: 'Share your feeding moments with the community through Feed.',
      feature3_title: 'Large Community',
      feature3_desc: 'Connect with animal lovers and organize joint events.',
      feature4_title: 'Share Food',
      feature4_desc: 'Transparently view donated food, share, and direct to points in need.',
      how_title: 'How It Works',
      step1_title: 'Discover',
      step1_desc: 'Discover new content in the feed; find suitable feeding points.',
      step2_title: 'Locate',
      step2_desc: 'Select the nearest feeding point on the map and get directions.',
      step3_title: 'Share & Interact',
      step3_desc: 'Stay engaged with the community through comments, messages, and notifications.',
      step4_title: 'Donate & Share',
      step4_desc: 'Add food donations, track transparently; direct to points of need.',
      team_title: 'Team',
      team_role: 'Software Engineer',
      security_title: 'Security & Privacy',
      security1_title: 'End-to-End Security',
      security1_desc: 'Your data is stored on encrypted servers.',
      security2_title: 'GDPR Compliant',
      security2_desc: 'Your privacy is our priority.',
      security3_title: 'Verified Points',
      security3_desc: 'Safe and clean feeding areas.',
      download_title: 'Download Now',
      download_subtitle: 'Download our app to your mobile devices and start helping our street friends.',
      demo_title: 'Request Demo / Quote',
      demo_label: 'Your Email Address',
      demo_placeholder: 'example@domain.com',
      demo_submit: 'Submit',
      contact_title: 'Contact',
      contact_email: 'Email',
      contact_phone: 'Phone',
      contact_address: 'Address',
      contact_address_text: 'Muğla Menteşe, Turkey',
      footer_tagline: 'Every paw print is a love story. 🐾',
      footer_copyright: '© 2025 FeedPad Project. All Rights Reserved.',
      form_sending: 'Sending…',
      form_invalid_email: 'Please enter a valid email.',
      form_success: '✅ Your registration was successful! Thank you.',
      form_error: '❌ An error occurred'
    }
  };

  // Get current language from localStorage or default to Turkish
  let currentLang = localStorage.getItem('feedpad_lang') || 'tr';

  // Function to update all text content
  function updateLanguage(lang) {
    currentLang = lang;
    localStorage.setItem('feedpad_lang', lang);
    
    const t = translations[lang];
    
    // Update all elements with data-i18n attribute
    document.querySelectorAll('[data-i18n]').forEach(el => {
      const key = el.getAttribute('data-i18n');
      if (t[key]) {
        el.textContent = t[key];
      }
    });
    
    // Update placeholders
    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
      const key = el.getAttribute('data-i18n-placeholder');
      if (t[key]) {
        el.placeholder = t[key];
      }
    });
    
    // Update language toggle button text
    const langToggle = document.getElementById('langToggle');
    if (langToggle) {
      langToggle.textContent = lang === 'tr' ? 'EN' : 'TR';
    }
    
    // Update HTML lang attribute
    document.documentElement.lang = lang;
  }

  // Language toggle button handler
  const langToggle = document.getElementById('langToggle');
  if (langToggle) {
    langToggle.addEventListener('click', () => {
      const newLang = currentLang === 'tr' ? 'en' : 'tr';
      updateLanguage(newLang);
    });
  }

  // Initialize language on page load
  updateLanguage(currentLang);

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
      msg.textContent = translations[currentLang].form_invalid_email;
      return;
    }

    msg.textContent = translations[currentLang].form_sending;

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
        msg.textContent = translations[currentLang].form_success;
        form.reset();
        document.getElementById('email').blur();
        setTimeout(() => { msg.textContent = ''; }, 5000);
      } else {
        msg.textContent = translations[currentLang].form_error + ': ' + (data.message || '');
      }
    } catch (err) {
      msg.textContent = translations[currentLang].form_error + ': ' + err.message;
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
