# FEEDPAD: Sokak Hayvanları İçin Gerçek Zamanlı Besleme ve Koordinasyon Platformu

Takım: Gamze Karasu, Esra Erbil  
Danışman: Öğr. Gör. Cihat Çetinkaya  
Kurum: [Üniversite Adı] - Yazılım Mühendisliği Bölümü

---

## 1) Özet (Abstract)
- Kentte sokak hayvanlarının beslenmesini gerçek zamanlı koordine eder
- Etkileşimli harita ile besleme/nokta durumları anlık görünür
- Şeffaf bağış akışı; gönüllü topluluk etkileşimi ve koordinasyonu
- Performans odaklı altyapı: hızlı, güvenli, ölçeklenebilir
- Mobil/web/masaüstü erişim ile yaygın kullanım (görsel: harita + pinler)

## 2) Problem (Pain Points)
- Besleme noktaları dağınık; güncel durum bilgisi yok
- Gönüllülerin koordinasyonu zayıf; kaynak israfı/tekrarı yaşanıyor
- Bağış süreçlerinde şeffaflık/güven sorunları
- Konum doğrulaması olmadan bilgi güvenilirliği düşük
- Medya paylaşımı dağınık; topluluk motivasyonu azalıyor

## 3) Hedef Kitle / Segmentler
- Gönüllüler, hayvansever bireyler ve yerel topluluklar
- Petshop sahipleri (işbirliği ve bağış kanalında paydaş)
- Belediye/dernek ekipleri (koordinasyon ve raporlama)
- Muhabir/saha ekipleri (kanıtlayıcı geotag’li içerik)
- Sponsorlar/bağışçılar (şeffaf etki ölçümü)

## 4) Değer Önermesi
- Harita merkezli, konum doğrulamalı güvenilir bilgi akışı
- Gerçek zamanlı besleme/stock seviyeleri ile doğru yere hızlı yönlendirme
- Şeffaf bağış ve işbirliği modeli; güven tesis eder
- Hızlı medya yükleme; topluluk etkileşimini artırır
- Basit, güvenli, ölçeklenebilir teknik mimari

## 5) Çözüm Genel Bakış
- FeedMap: besleme ve su noktalarını canlı olarak gösterir
- Share Food: petshop–gönüllü bağış köprüsü
- Feed Blog: sosyal paylaşım ve geri bildirim akışı
- Rol tabanlı erişim: Kullanıcı / Petshop sahibi akışları
- Mobil (Flutter), Backend (Node.js), Cache (Redis) entegrasyonu

## 6) Ürün Demo Akışı
- Kayıt/Giriş → konum izni → onboarding
- Ana harita: pin/cluster; stok/son besleme bilgisi
- Gönderi oluştur: medya seç, konum ekle, açıklama
- Profil görüntüle: güvenilir yazar, geçmiş faaliyetler
- Paylaş/çağrı: destek talebi, bağış yönlendirme

## 7) Teknik Mimari (High-Level)
- İstemci: Flutter/Dart → HTTPS → Node.js/Express API
- Kimlik: JWT (jsonwebtoken) + bcryptjs; cookie-parser, csurf
- Güvenlik: helmet, cors, compression, morgan, express-validator
- Veri: MongoDB (Mongoose) [kalıcı], Redis [oturum/cache/throttle]
- Dosya: multer ile medya yükleme; statik promo site (HTML/CSS/JS)

## 8) Teknoloji Yığını (Stack)
- Flutter/Dart: provider (state), flutter_map + latlong2 (harita)
- Geolocator + permission_handler: konum/izin yönetimi
- file_picker + image: medya seçimi ve görüntü işleme
- Material/Cupertino bileşenleri; http istemcisi
- Node.js + Express; dotenv, nodemon; express-rate-limit (root)

## 9) Veri Yönetimi ve Cache
- Redis: oturum, cache, hız sınırlama (throttling)
- MongoDB (Mongoose): kullanıcı, gönderi, besleme noktası, log
- Şema tasarımı: Index’ler (konum, kullanıcı), TTL logları
- Stok/Seviye güncellemeleri için hafifletilmiş yazma modeli
- Okuma-yazma ayrımı ve cached read path (plan)

## 10) API Tasarımı ve Rotalar
- Auth: POST /api/auth/register, /login, /logout, GET /me
- Feed: GET/POST /api/posts (medya, açıklama, konum)
- Lead/Marker: /api/lead, /api/marker (nokta yönetimi)
- Messaging: /api/messaging (yol haritasında)
- Validasyon: express-validator; CSRF koruma: csurf

## 11) Güvenlik ve Uyumluluk
- Şifre hash: bcryptjs; token: JWT (süreli, yenileme politikası)
- HTTP başlık sertleştirme: helmet; CORS kontrollü
- CSRF koruması (web) ve input sanitizasyonu
- Rate limit: express-rate-limit; kötüye kullanım önleme
- Loglama: morgan; denetim izi ve anomali takibi

## 12) Mobil İstemci Detayları
- Harita: cluster, ısı haritası (gelecek), pin türleri
- Konum doğrulama: izin akışları, hassasiyet/accuracy
- Medya: sıkıştırma, EXIF/konum temizleme seçenekleri
- Erişilebilirlik: büyük fontlar, kontrast; offline uyarılar
- Performans: lazy list, cache, ağ zamanlayıcıları

## 13) Operasyon ve DevOps
- Ortam değişkenleri: dotenv; gizli yönetimi (plan: Vault)
- Dağıtım: Node servisleri; CDN ile statikler/medya
- İzleme: log/metric/alert; hata izleme (plan: Sentry)
- Yedekleme: Mongo snapshot; Redis kalıcılık opsiyonları
- CI/CD: test, lint, güvenlik kontrol adımları (plan)

## 14) Performans ve Ölçeklenebilirlik
- Redis cache ile millisecond seviyesinde okuma
- Sık erişimli rotalar için cache policy ve invalidation
- Konum sorguları için geospatial index (Mongo 2dsphere)
- Yatay ölçek: stateless API, oturum Redis’te
- Medya için asenkron işleme ve kuyruk (plan)

## 15) Kullanım Senaryoları
- “Su seviyesi 2.5 L” güncellemesi; anlık harita yansıması
- Besleme etkinliği paylaşımı; topluluk etkileşimi
- Petshop stok/bagış eşleşmesi; şeffaf geçmiş
- Belediye/dernek raporları için veri çıktıları
- Kriz anlarında yoğunluk haritası ile kaynak yönlendirme

## 16) Başarı Metrikleri (KPI)
- DAU/MAU, 7-gün tutulma
- Geotag’li gönderi oranı; medya tamamlama
- Ortalama yükleme gecikmesi; API hata/başarı oranı
- Aktif besleme noktası sayısı; bağış hacmi
- Spam/istismar olayları ve engelleme başarısı

## 17) Yol Haritası (3–4 Çeyrek)
- Q1: Bildirimler, zengin medya önizleme, temel moderasyon
- Q2: Mesajlaşma, kayıtlı konumlar, gelişmiş harita görselleştirme
- Q3: Kurumsal çalışma alanları; rol/izin detayları
- Q4: Analitik pano; bağış/sponsor entegrasyonları

## 18) Riskler ve Tedbirler
- Konum gizliliği: açık rıza, opt-in/iptal, veri minimizasyonu
- Yükleme güvenilirliği: yeniden deneme, parça/parça (resumable) planı
- İstismar/spam: rate limit, doğrulama, raporlama/moderasyon
- Altyapı kesintileri: çoklu bölge ve yedekleme stratejisi
- Hukuki uyum: KVKK/GDPR yönergeleri ve saklama politikaları

## 19) İş Modeli ve Sürdürülebilirlik
- Freemium; kurumsal workspace paketleri
- Sponsorlu/verified pin’ler ve ortak kampanyalar
- API/entegrasyon gelirleri; bağış yönetimi hizmet bedeli
- Belediyeler/derneklerle projeler; sosyal etki fonları
- Şeffaflık ve ölçülebilir etkiyle sürdürülebilir büyüme

## 20) Çağrı ve Kapanış
- Pilot destek ve kullanıcı kohortları ile sahada test
- Altyapı/özellik yatırımı; veri ve harita ortaklıkları
- Demo/POC planlayalım: iletişim [e-posta/telefon]
- FeedPad: güvenilir, harita-odaklı, topluluk güdümlü çözüm
- Teşekkürler (görsel: basit, temiz kapanış slide)

---

## Ek: Dosya ve Teknolojiler Referansı
- Backend bağımlılıkları: `backend/package.json` (Express, helmet, cors, compression, cookie-parser, csurf, morgan, express-validator, jsonwebtoken, bcryptjs, uuid, multer, dotenv, mongoose, redis, nodemon)
- Root bağımlılık: `package.json` (express-rate-limit)
- Flutter bağımlılıkları: `feedpad/pubspec.yaml` (provider, flutter_map, latlong2, geolocator, permission_handler, file_picker, image, cupertino_icons, http)
- Promo site: `backend/promo/` (HTML/CSS/JS)
- Örnek API: `backend/routes/` (auth.routes.js, posts.routes.js, marker.routes.js, lead.routes.js, messaging.routes.js)
