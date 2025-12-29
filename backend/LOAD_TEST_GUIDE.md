# FeedPad API - Load Test Kılavuzu

Bu kılavuz, Postman Collection'ını load test için nasıl kullanacağınızı açıklar.

## 📁 Dosyalar

- **FeedPad_API_LoadTest.postman_collection.json**: Load test için optimize edilmiş collection (önerilen)
- **FeedPad_API.postman_collection.json**: Standart collection

## 🚀 Load Test Collection Özellikleri

### ✅ Otomatik Veri Yönetimi

Collection'da bulunan özellikler:

1. **Unique Email Oluşturma**: Her Register işleminde otomatik unique email oluşturur

   - Format: `test_{timestamp}_{random}@loadtest.com`
   - Duplicate email hatası almazsınız

2. **Session Yönetimi**: Login sonrası otomatik session_id kaydeder

   - Tüm authenticated endpoint'lerde otomatik kullanılır
   - Geçersiz session hatası almazsınız

3. **ID Yönetimi**:

   - `user_id`: Register/Login sonrası otomatik kaydedilir
   - `marker_id`: Marker oluşturulduktan sonra kaydedilir
   - `post_id`: Post oluşturulduktan sonra kaydedilir
   - Bu ID'ler ilgili endpoint'lerde otomatik kullanılır

4. **Pre-request Script'leri**: Her request'ten önce:

   - Gerekli veriler kontrol edilir
   - Varsa uyarılar gösterilir
   - Request body'ler dinamik olarak oluşturulur

5. **Test Script'leri**: Response'dan veriler çıkarılıp variable'lara kaydedilir

## 📥 Collection'ı Import Etme

1. Postman'i açın
2. Sol üstten **Import** butonuna tıklayın
3. `FeedPad_API_LoadTest.postman_collection.json` dosyasını seçin
4. Import edin

## 🎯 Load Test Senaryosu

### Senaryo 1: Tam Akış Testi (ÖNERİLEN - EN KOLAY YOL)

**🚀 Load Test Flow Folder'ını Kullanın:**

Collection'da **"🚀 Load Test Flow (Önerilen)"** adında özel bir folder var. Bu folder içinde endpoint'ler doğru sırayla hazırlanmış:

1. ✅ `1. Register` - Yeni kullanıcı oluştur
2. ✅ `2. Login` - Giriş yap (session al)
3. ✅ `3. Create Marker` - Marker oluştur
4. ✅ `4. Get My Markers` - Marker'ları görüntüle
5. ✅ `5. Create Post` - Post oluştur
6. ✅ `6. Like Post` - Post'u beğen

**Postman Runner'da Kullanımı:**

1. Collection'a sağ tıklayın → **Run collection**
2. Sol panelden **sadece "🚀 Load Test Flow (Önerilen)"** folder'ını seçin
3. Tüm endpoint'lerin seçili olduğundan emin olun
4. **Iterations**: 100 (veya istediğiniz sayı)
5. **Delay**: 100-500ms (opsiyonel)
6. ✅ **"Keep variable values" seçeneğini KAPALI tutun** (her iteration'da yeni session için)
7. **Start Run**

**Avantajları:**

- ✅ Endpoint'ler doğru sırada
- ✅ Her iteration'da otomatik unique email oluşturulur
- ✅ Session yönetimi otomatik
- ✅ Marker/Post ID'leri otomatik kaydedilir
- ✅ Console'da her adım log'lanır ([1/6], [2/6] gibi)

### ⚠️ ÖNEMLİ: Endpoint Sıralaması

**Collection Genel Sırası:**

1. ✅ `Health Check` - Sunucu durumunu kontrol et
2. ✅ `Logout (Session Temizleme)` - Eski session'ı temizle (session yoksa hata vermez)
3. ✅ `Load Test Flow` veya diğer klasörler - Yeni test döngüsü

- Logout YOK (zaten collection'ın başında temizleniyor)
- Sıra: `Register` → `Login` → `Create Marker` → `Get My Markers` → `Create Post` → `Like Post`
- Tüm işlemler aynı session ile çalışır

**Authentication klasöründe:**

- ✅ `Register` → `Login` → `Get Me` → `Get User by ID`
- Logout yok (collection seviyesinde Health Check'ten sonra)

### Senaryo 2: Manuel Sıralama

Eğer farklı bir kombinasyon test etmek istiyorsanız:

**Sıralama:**

1. `Register` - Yeni kullanıcı oluştur
2. `Login` - Giriş yap (session al)
3. `Create Marker` - Marker oluştur
4. `Get My Markers` - Marker'ları görüntüle
5. `Create Post` - Post oluştur
6. `Like Post` - Post'u beğen
7. `Add Comment` - Yorum ekle

**Postman Runner'da:**

- Collection'ı seçin
- İstediğiniz endpoint'leri sırayla seçin
- Iteration sayısını ayarlayın (örn: 100)
- Delay ekleyin (opsiyonel)

### Senaryo 2: Sadece Read İşlemleri

Eğer sadece read endpoint'lerini test etmek istiyorsanız:

1. Önce manuel olarak bir kez `Register` ve `Login` yapın
2. Sonra `Get All Markers`, `Get Feed`, `Get User Posts` gibi endpoint'leri test edin

## 🔧 Postman Collection Runner Kullanımı

### Adım 1: Collection Runner'ı Açın

1. Collection'a sağ tıklayın
2. **Run collection** seçeneğini seçin

### Adım 2: Ayarları Yapın

- **Iterations**: Kaç kez çalıştırılacağı (örn: 100)
- **Delay**: Her iteration arası bekleme süresi (ms)
- **Data File**: CSV veya JSON data file kullanabilirsiniz (opsiyonel)

### Adım 3: Endpoint'leri Seçin

**EN KOLAY YOL: "🚀 Load Test Flow" Folder'ını Kullanın**

1. Sol panelden sadece **"🚀 Load Test Flow (Önerilen)"** folder'ını açın
2. İçindeki tüm endpoint'lerin (1-6) seçili olduğundan emin olun
3. ✅ **"Keep variable values" seçeneğini KAPALI tutun** (önemli!)

**Alternatif: Manuel Seçim**

Eğer farklı bir kombinasyon test etmek istiyorsanız:

- Test etmek istediğiniz endpoint'leri seçin/kaldırın
- **Önemli:**
  - `Register` ve `Login` her iteration'da çalışmalı (unique email için)
  - Create işlemleri (Marker, Post) ilgili Get işlemlerinden önce olmalı

### Adım 4: Çalıştırın

**Start Run** butonuna tıklayın.

## 📊 Variables (Değişkenler)

Collection'da kullanılan variable'lar:

| Variable         | Açıklama          | Nasıl Set Edilir                            |
| ---------------- | ----------------- | ------------------------------------------- |
| `base_url`       | API base URL      | Manuel (default: http://localhost:3000/api) |
| `session_id`     | Oturum ID'si      | Login endpoint'i otomatik set eder          |
| `user_id`        | Kullanıcı ID'si   | Register/Login otomatik set eder            |
| `user_email`     | Kullanıcı email   | Register otomatik oluşturur                 |
| `user_name`      | Kullanıcı adı     | Register otomatik set eder                  |
| `user_password`  | Kullanıcı şifresi | Manuel (default: TestPassword123!)          |
| `marker_id`      | Marker ID'si      | Create Marker otomatik set eder             |
| `post_id`        | Post ID'si        | Create Post otomatik set eder               |
| `test_timestamp` | Test timestamp    | Her request'te otomatik güncellenir         |

## ⚠️ Önemli Notlar

### 1. Load Test Öncesi

**ÖNEMLİ: "Keep variable values" Seçeneği**

- Collection Runner'da **"Keep variable values" seçeneğini MUTLAKA KAPALI tutun**
- Bu seçenek kapalı olursa, her iteration'da:
  - Yeni unique email oluşturulur
  - Yeni session alınır
  - Yeni marker/post oluşturulur
  - Hata almazsınız!

**Eğer açık olursa:**

- Aynı email kullanılır → "email zaten kullanımda" hatası
- Aynı session kullanılır → timeout olabilir
- Hatalar alırsınız

**Kontrol:**

- Collection'a sağ tıklayın → **Edit**
- Variables sekmesinde `session_id`, `user_id` gibi değerleri temizleyin (opsiyonel, Keep variable values kapalıysa gerekmez)

### 2. Unique Email Sorunu

Eğer hala "email zaten kullanımda" hatası alıyorsanız:

- Register endpoint'inde `test_timestamp` kullanılıyor
- Her iteration'da yeni timestamp oluşturulur
- Eğer problem devam ederse, pre-request script'te `Math.random()` değerini artırın

### 3. Session Timeout

- Session'lar 24 saat geçerlidir
- Eğer session timeout hatası alıyorsanız:
  - Her iteration'da `Login` endpoint'ini çalıştırın
  - Veya `Register` → `Login` akışını her iteration'da yapın

### 4. Marker/Post ID Sorunu

Eğer "marker not found" veya "post not found" hatası alıyorsanız:

- Collection Runner'da endpoint sıralamasını kontrol edin
- `Create Marker` veya `Create Post` endpoint'lerinin önce çalıştığından emin olun
- Veya her iteration'da create işlemlerini de dahil edin

## 🎯 Load Test Best Practices

### 1. Basit Başlayın

İlk olarak 5-10 iteration ile test edin:

- Hataları görün
- Log'ları kontrol edin
- Sorunları düzeltin

### 2. Yavaşça Artırın

- 10 → 50 → 100 → 500 → 1000 şeklinde artırın
- Her seviyede sonuçları analiz edin

### 3. Delay Kullanın

- Çok hızlı request'ler sunucuyu aşırı yükleyebilir
- 100-500ms delay ekleyin (sunucu kapasitesine göre)

### 4. Monitoring

- Sunucu CPU, Memory, Redis bağlantı sayısını izleyin
- Response time'ları takip edin
- Error rate'i ölçün

### 5. Data File Kullanımı (Gelişmiş)

Birden fazla farklı kullanıcı ile test etmek için:

**CSV dosyası oluşturun (users.csv):**

```csv
email,password,name
test1@example.com,Pass123,User 1
test2@example.com,Pass123,User 2
test3@example.com,Pass123,User 3
```

Collection Runner'da:

1. **Select File** → CSV dosyanızı seçin
2. Request'lerde `{{email}}`, `{{password}}` gibi değerler kullanın

## 🔍 Debugging

### Console Log'ları İzleme

Postman Console'u açın (View → Show Postman Console):

- Pre-request script'lerdeki `console.log()` çıktılarını görebilirsinz
- Test script'lerdeki log'ları görebilirsiniz

### Variable'ları Kontrol Etme

1. Collection'a sağ tıklayın → **Edit**
2. **Variables** sekmesine gidin
3. Variable değerlerini kontrol edin

### Request/Response İnceleme

Collection Runner sonuçlarında:

- Her request için detaylı bilgi görebilirsiniz
- Response body'leri inceleyebilirsiniz
- Error mesajlarını görebilirsiniz

## 📈 Örnek Load Test Sonuçları

Başarılı bir load test:

- ✅ %0-1 error rate
- ✅ Ortalama response time < 500ms
- ✅ 95th percentile < 1s
- ✅ Sunucu kaynakları normal seviyede

## 🆘 Sorun Giderme

### Problem: "Geçersiz session"

**Çözüm:**

- Her iteration'da `Login` endpoint'ini çalıştırın
- Veya `Register` → `Login` akışını dahil edin

### Problem: "Email zaten kullanımda"

**Çözüm:**

- Register endpoint'inin pre-request script'ini kontrol edin
- `test_timestamp` ve `Math.random()` kombinasyonunun çalıştığından emin olun
- Collection variable'larını temizleyin

### Problem: "Marker/Post not found"

**Çözüm:**

- Endpoint sıralamasını kontrol edin
- Create işlemlerinin önce çalıştığından emin olun
- Her iteration'da create işlemlerini dahil edin

### Problem: "User ID not found"

**Çözüm:**

- Register veya Login endpoint'inin çalıştığından emin olun
- Collection variable'larında `user_id` değerini kontrol edin

## 💡 İpuçları

1. **Collection'ı Clone'layın**: Farklı test senaryoları için farklı collection'lar oluşturun

2. **Environment Kullanın**: Farklı environment'lar için (dev, staging, prod) environment variable'ları kullanın

3. **Monitor İyi**: Load test sırasında sunucuyu izleyin

4. **Kademeli Artırın**: Bir anda 1000 iteration yapmayın, yavaşça artırın

5. **Cleanup**: Test sonrası test verilerini temizleyin (gerekirse)

---

**Son Güncelleme:** 25 Aralık 2025
