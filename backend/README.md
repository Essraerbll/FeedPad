# FeedPad Backend - Redis Authentication

Bu proje, Redis kullanarak authentication sistemi içeren bir Node.js backend uygulamasıdır.

## Özellikler

- ✅ Redis ile session yönetimi
- ✅ Email/Password ile kayıt ve giriş
- ✅ Cookie tabanlı authentication
- ✅ Web arayüzü (HTML/CSS/JS)
- ✅ FeedPad Flutter uygulamasıyla uyumlu yapı

## Kurulum

### 1. Bağımlılıkları Yükle

```bash
npm install
```

### 2. Redis Kurulumu

Redis'in sisteminizde kurulu ve çalışıyor olması gerekiyor:

**Windows:**
- Redis'i [buradan](https://github.com/microsoftarchive/redis/releases) indirip kurun
- Veya WSL kullanarak Linux Redis'i kullanabilirsiniz

**Linux/Mac:**
```bash
# Ubuntu/Debian
sudo apt-get install redis-server

# Mac
brew install redis
```

Redis'i başlatın:
```bash
redis-server
```

### 3. Environment Variables

`.env` dosyası oluşturun (`.env.example` dosyasını referans alabilirsiniz):

```env
PORT=3000
NODE_ENV=development
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
```

### 4. Sunucuyu Başlat

```bash
# Development mode (nodemon ile)
npm run dev

# Production mode
npm start
```

Sunucu `http://localhost:3000` adresinde çalışacaktır.

## Kullanım

### Web Arayüzü

Tarayıcınızda `http://localhost:3000` adresine gidin. Aşağıdaki özellikler mevcuttur:

- **Login**: Email ve şifre ile giriş yapın
- **Register**: Yeni kullanıcı kaydı oluşturun
- **Dashboard**: Giriş yaptıktan sonra kullanıcı bilgilerinizi görüntüleyin

### API Endpoints

#### POST `/api/auth/register`
Kullanıcı kaydı oluşturur.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "name": "John Doe",
  "username": "johndoe",
  "location": "Istanbul",
  "userType": "user"
}
```

#### POST `/api/auth/login`
Kullanıcı girişi yapar.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

#### POST `/api/auth/logout`
Kullanıcı çıkışı yapar.

#### GET `/api/auth/me`
Mevcut kullanıcı bilgilerini getirir (cookie ile authentication gerekli).

## Teknolojiler

- **Express.js**: Web framework
- **Redis**: Session ve veri saklama
- **bcryptjs**: Şifre hashleme
- **express-validator**: Request validation
- **cookie-parser**: Cookie yönetimi
- **uuid**: Unique ID oluşturma

## Notlar

- Redis verileri geçici olarak saklanır. Sunucu yeniden başlatıldığında veriler kaybolabilir.
- Production ortamında Redis persistence ayarlarını yapılandırın.
- Gerçek bir uygulamada kullanıcı verilerini kalıcı bir veritabanında saklamanız önerilir.

