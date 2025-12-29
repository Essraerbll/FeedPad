# FeedPad API Endpoints Dokümantasyonu

Bu doküman FeedPad backend sunucusundaki tüm API endpoint'lerini içermektedir.

**Base URL:** `http://localhost:3000/api` (veya sunucu adresiniz)

---

## 📋 İçindekiler

1. [Health Check](#health-check)
2. [Authentication Endpoints](#authentication-endpoints)
3. [Marker Endpoints](#marker-endpoints)
4. [Post Endpoints](#post-endpoints)
5. [Messaging Endpoints](#messaging-endpoints)

---

## Health Check

### GET `/api/health`

Sunucunun durumunu kontrol eder.

**cURL:**

```bash
curl -X GET http://localhost:3000/api/health
```

**Response:**

```json
{
  "status": "OK",
  "message": "FeedPad API is running",
  "timestamp": "2025-01-01T00:00:00.000Z"
}
```

---

## Authentication Endpoints

Base Path: `/api/auth`

### POST `/api/auth/register`

Yeni kullanıcı kaydı oluşturur.

**Request Body:**

```json
{
  "email": "user@example.com",
  "password": "password123",
  "name": "Kullanıcı Adı",
  "username": "kullaniciadi", // Opsiyonel
  "userType": "user" // "user" veya "pet_shop_owner"
}
```

**Validation:**

- `email`: Geçerli e-posta adresi
- `password`: En az 6 karakter
- `name`: Zorunlu
- `username`: En az 3 karakter (opsiyonel)
- `userType`: "user" veya "pet_shop_owner"

**Response (201):**

```json
{
  "success": true,
  "message": "Kayıt başarılı",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "Kullanıcı Adı",
    "username": "kullaniciadi",
    "userType": "user"
  }
}
```

**Hata Response (400):**

```json
{
  "success": false,
  "message": "Validation hatası",
  "errors": [...]
}
```

**cURL:**

```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123",
    "name": "Kullanıcı Adı",
    "username": "kullaniciadi",
    "userType": "user"
  }'
```

---

### POST `/api/auth/login`

Kullanıcı girişi yapar ve session oluşturur.

**Request Body:**

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response (200):**

```json
{
  "success": true,
  "message": "Giriş başarılı",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "Kullanıcı Adı",
    "username": "kullaniciadi",
    "userType": "user"
  },
  "sessionId": "session-uuid"
}
```

**Cookie:** `sessionId` cookie olarak set edilir (24 saat geçerli)

**Hata Response (401):**

```json
{
  "success": false,
  "message": "Kullanıcı bulunamadı." veya "Hatalı şifre."
}
```

**cURL:**

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }' \
  -c cookies.txt
```

**Not:** `-c cookies.txt` cookie'leri kaydetmek için kullanılır. Sonraki isteklerde `-b cookies.txt` ile kullanılabilir.

---

### POST `/api/auth/logout`

Kullanıcı çıkışı yapar.

**Cookie:** `sessionId` cookie gereklidir

**Response (200):**

```json
{
  "success": true,
  "message": "Çıkış başarılı"
}
```

**cURL:**

```bash
curl -X POST http://localhost:3000/api/auth/logout \
  -H "Content-Type: application/json" \
  -b cookies.txt
```

---

### GET `/api/auth/me`

Mevcut oturumdaki kullanıcı bilgilerini getirir.

**Cookie:** `sessionId` cookie gereklidir

**Response (200):**

```json
{
  "success": true,
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "Kullanıcı Adı",
    "username": "kullaniciadi",
    "userType": "user"
  }
}
```

**Hata Response (401):**

```json
{
  "success": false,
  "message": "Oturum bulunamadı" veya "Geçersiz oturum"
}
```

**cURL (Cookie ile):**

```bash
curl -X GET http://localhost:3000/api/auth/me \
  -b cookies.txt
```

**cURL (Header ile):**

```bash
curl -X GET http://localhost:3000/api/auth/me \
  -H "x-session-id: YOUR_SESSION_ID"
```

---

### GET `/api/auth/user/:userId`

Belirli bir kullanıcının bilgilerini getirir.

**URL Parameters:**

- `userId`: Kullanıcı ID'si (UUID veya email)

**Response (200):**

```json
{
  "success": true,
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "Kullanıcı Adı",
    "username": "kullaniciadi",
    "userType": "user"
  }
}
```

**Hata Response (404):**

```json
{
  "success": false,
  "message": "Kullanıcı bulunamadı"
}
```

**cURL:**

```bash
curl -X GET http://localhost:3000/api/auth/user/USER_ID_OR_EMAIL
```

---

## Marker Endpoints

Base Path: `/api/markers`

**Not:** Tüm marker endpoint'leri (GET hariç) için authentication gereklidir. Cookie'de `sessionId` olmalı veya header'da `x-session-id` gönderilmeli.

### POST `/api/markers`

Yeni marker oluşturur.

**Authentication:** Gerekli

**Request Body:**

```json
{
  "type": "food", // "food" veya "water"
  "latitude": 41.0082,
  "longitude": 28.9784,
  "petType": "cat", // Opsiyonel: "cat" veya "dog"
  "waterLiters": 2.5, // Opsiyonel: Su miktarı (litre)
  "isWaterEnough": "yes" // Opsiyonel: "yes" veya "maybe"
}
```

**Validation:**

- `type`: "food" veya "water"
- `latitude`: -90 ile 90 arası
- `longitude`: -180 ile 180 arası
- `petType`: "cat" veya "dog" (opsiyonel)
- `waterLiters`: 0 veya pozitif sayı (opsiyonel)
- `isWaterEnough`: "yes" veya "maybe" (opsiyonel)

**Response (201):**

```json
{
  "success": true,
  "message": "Marker başarıyla oluşturuldu",
  "marker": {
    "id": "uuid",
    "userId": "uuid",
    "type": "food",
    "latitude": 41.0082,
    "longitude": 28.9784,
    "petType": "cat",
    "waterLiters": null,
    "catFoodAmount": null,
    "dogFoodAmount": null,
    "isWaterEnough": null,
    "createdAt": "2025-01-01T00:00:00.000Z"
  }
}
```

**cURL:**

```bash
curl -X POST http://localhost:3000/api/markers \
  -H "Content-Type: application/json" \
  -H "x-session-id: YOUR_SESSION_ID" \
  -d '{
    "type": "food",
    "latitude": 41.0082,
    "longitude": 28.9784,
    "petType": "cat",
    "waterLiters": 2.5,
    "isWaterEnough": "yes"
  }'
```

**Cookie ile:**

```bash
curl -X POST http://localhost:3000/api/markers \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{
    "type": "food",
    "latitude": 41.0082,
    "longitude": 28.9784
  }'
```

---

### GET `/api/markers`

Tüm marker'ları getirir. Yakınlık bazlı filtreleme opsiyoneldir.

**Query Parameters:**

- `latitude`: Enlem (opsiyonel)
- `longitude`: Boylam (opsiyonel)
- `radius`: Yarıçap (km) - latitude ve longitude ile birlikte kullanılmalı

**Response (200):**

```json
{
  "success": true,
  "markers": [
    {
      "id": "uuid",
      "userId": "uuid",
      "type": "food",
      "latitude": 41.0082,
      "longitude": 28.9784,
      "petType": "cat",
      "waterLiters": null,
      "catFoodAmount": null,
      "dogFoodAmount": null,
      "isWaterEnough": null,
      "addedAmount": null,
      "addedByUserId": null,
      "isEnoughNow": null,
      "createdAt": "2025-01-01T00:00:00.000Z"
    }
  ]
}
```

**cURL (Tüm marker'lar):**

```bash
curl -X GET http://localhost:3000/api/markers
```

**cURL (Yakınlık filtresi ile):**

```bash
curl -X GET "http://localhost:3000/api/markers?latitude=41.0082&longitude=28.9784&radius=10"
```

---

### GET `/api/markers/my-markers`

Kullanıcının kendi marker'larını getirir.

**Authentication:** Gerekli

**Response (200):**

```json
{
  "success": true,
  "markers": [...]
}
```

**cURL:**

```bash
curl -X GET http://localhost:3000/api/markers/my-markers \
  -H "x-session-id: YOUR_SESSION_ID"
```

---

### GET `/api/markers/:id`

Belirli bir marker'ı getirir.

**URL Parameters:**

- `id`: Marker ID'si

**Response (200):**

```json
{
  "success": true,
  "marker": {
    "id": "uuid",
    "userId": "uuid",
    "type": "food",
    "latitude": 41.0082,
    "longitude": 28.9784,
    "petType": "cat",
    "waterLiters": null,
    "catFoodAmount": null,
    "dogFoodAmount": null,
    "isWaterEnough": null,
    "addedAmount": null,
    "addedByUserId": null,
    "isEnoughNow": null,
    "createdAt": "2025-01-01T00:00:00.000Z"
  }
}
```

**cURL:**

```bash
curl -X GET http://localhost:3000/api/markers/MARKER_ID
```

---

### PUT `/api/markers/:id`

Marker'ı günceller.

**Authentication:** Gerekli

**Not:** Sadece marker sahibi temel bilgileri (type, latitude, longitude, petType, waterLiters, catFoodAmount, dogFoodAmount) güncelleyebilir. Opinion ve ekleme işlemleri (isWaterEnough, addedAmount, addedByUserId, isEnoughNow) herkes tarafından yapılabilir.

**Request Body:** (Tüm alanlar opsiyonel)

```json
{
  "type": "water",
  "latitude": 41.0082,
  "longitude": 28.9784,
  "petType": "dog",
  "waterLiters": 5.0,
  "catFoodAmount": 2.5,
  "dogFoodAmount": 3.0,
  "isWaterEnough": "no",
  "addedAmount": 2.0,
  "addedByUserId": "uuid",
  "isEnoughNow": "yes"
}
```

**Response (200):**

```json
{
  "success": true,
  "message": "Marker başarıyla güncellendi",
  "marker": {
    "id": "uuid",
    "userId": "uuid",
    "type": "water",
    "latitude": 41.0082,
    "longitude": 28.9784,
    "petType": "dog",
    "waterLiters": 5.0,
    "catFoodAmount": 2.5,
    "dogFoodAmount": 3.0,
    "isWaterEnough": "no",
    "addedAmount": 2.0,
    "addedByUserId": "uuid",
    "isEnoughNow": "yes",
    "createdAt": "2025-01-01T00:00:00.000Z",
    "updatedAt": "2025-01-01T00:00:00.000Z"
  }
}
```

**cURL:**

```bash
curl -X PUT http://localhost:3000/api/markers/MARKER_ID \
  -H "Content-Type: application/json" \
  -H "x-session-id: YOUR_SESSION_ID" \
  -d '{
    "type": "water",
    "waterLiters": 5.0,
    "isWaterEnough": "no"
  }'
```

---

### DELETE `/api/markers/:id`

Marker'ı siler.

**Authentication:** Gerekli

**Not:** Sadece marker sahibi silebilir.

**Response (200):**

```json
{
  "success": true,
  "message": "Marker başarıyla silindi"
}
```

**Hata Response (403):**

```json
{
  "success": false,
  "message": "Bu marker'ı silme yetkiniz yok"
}
```

**cURL:**

```bash
curl -X DELETE http://localhost:3000/api/markers/MARKER_ID \
  -H "x-session-id: YOUR_SESSION_ID"
```

---

## Post Endpoints

Base Path: `/api/posts`

### GET `/api/posts/user/:userId`

Belirli bir kullanıcının postlarını getirir.

**URL Parameters:**

- `userId`: Kullanıcı ID'si (UUID veya email)

**Query Parameters:**

- `requesterId`: İstekte bulunan kullanıcı ID'si (opsiyonel) - beğeni durumunu kontrol etmek için

**Response (200):**

```json
{
  "success": true,
  "posts": [
    {
      "id": "post_id",
      "userId": "uuid",
      "userName": "Kullanıcı Adı",
      "caption": "Post açıklaması",
      "imageUrl": "http://...",
      "location": "İstanbul",
      "likes": 10,
      "liked": true,
      "comments": [
        {
          "id": "comment_id",
          "userId": "uuid",
          "userName": "Yorumcu Adı",
          "username": "username",
          "userProfileImage": "http://...",
          "text": "Yorum metni",
          "timestamp": 1704067200000
        }
      ],
      "timestamp": 1704067200000,
      "user": {
        "name": "Kullanıcı Adı",
        "username": "username",
        "profileImage": "http://..."
      }
    }
  ],
  "user": {
    "bio": "Kullanıcı biyografisi",
    "profileImage": "http://..."
  }
}
```

**cURL:**

```bash
curl -X GET "http://localhost:3000/api/posts/user/USER_ID?requesterId=REQUESTER_ID"
```

---

### POST `/api/posts/create`

Yeni post oluşturur.

**Request Body (JSON):**

```json
{
  "userId": "uuid veya email",
  "userName": "Kullanıcı Adı",
  "caption": "Post açıklaması",
  "imageUrl": "http://...", // Opsiyonel: multipart/form-data ile dosya yüklenirse gerekmez
  "location": "İstanbul" // Opsiyonel
}
```

**Request Body (multipart/form-data):**

- `userId`: string
- `userName`: string
- `caption`: string
- `image`: file (opsiyonel)
- `location`: string (opsiyonel)

**Response (200):**

```json
{
  "success": true,
  "postId": "post_id",
  "post": {
    "id": "post_id",
    "userId": "uuid",
    "userName": "Kullanıcı Adı",
    "caption": "Post açıklaması",
    "imageUrl": "http://...",
    "location": "İstanbul",
    "likes": 0,
    "comments": 0,
    "timestamp": 1704067200000,
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "name": "Kullanıcı Adı",
      "username": "username",
      "profileImage": null,
      "bio": null
    }
  }
}
```

**cURL (JSON ile):**

```bash
curl -X POST http://localhost:3000/api/posts/create \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user@example.com",
    "userName": "Kullanıcı Adı",
    "caption": "Post açıklaması",
    "imageUrl": "http://example.com/image.jpg",
    "location": "İstanbul"
  }'
```

**cURL (Multipart/form-data ile dosya yükleme):**

```bash
curl -X POST http://localhost:3000/api/posts/create \
  -F "userId=user@example.com" \
  -F "userName=Kullanıcı Adı" \
  -F "caption=Post açıklaması" \
  -F "image=@/path/to/image.jpg" \
  -F "location=İstanbul"
```

---

### GET `/api/posts/feed`

Global feed'i getirir.

**Query Parameters:**

- `limit`: Sayfa başına post sayısı (varsayılan: 20)
- `offset`: Başlangıç index'i (varsayılan: 0)
- `requesterId`: İstekte bulunan kullanıcı ID'si (opsiyonel) - beğeni durumunu kontrol etmek için

**Response (200):**

```json
{
  "success": true,
  "posts": [...]
}
```

**cURL:**

```bash
curl -X GET "http://localhost:3000/api/posts/feed?limit=20&offset=0&requesterId=USER_ID"
```

---

### POST `/api/posts/like`

Post'u beğenir/beğenmeyi kaldırır.

**Request Body:**

```json
{
  "postId": "post_id",
  "userId": "uuid"
}
```

**Response (200):**

```json
{
  "success": true,
  "liked": true // veya false
}
```

**cURL:**

```bash
curl -X POST http://localhost:3000/api/posts/like \
  -H "Content-Type: application/json" \
  -d '{
    "postId": "post_id",
    "userId": "user_id"
  }'
```

---

### POST `/api/posts/follow`

Kullanıcıyı takip eder/takibi bırakır.

**Request Body:**

```json
{
  "followerId": "uuid",
  "followingId": "uuid"
}
```

**Response (200):**

```json
{
  "success": true,
  "following": true // veya false
}
```

**cURL:**

```bash
curl -X POST http://localhost:3000/api/posts/follow \
  -H "Content-Type: application/json" \
  -d '{
    "followerId": "follower_id",
    "followingId": "following_id"
  }'
```

---

### GET `/api/posts/stats/:userId`

Kullanıcı istatistiklerini getirir.

**URL Parameters:**

- `userId`: Kullanıcı ID'si (UUID veya email)

**Response (200):**

```json
{
  "success": true,
  "stats": {
    "posts": 10,
    "followers": 50,
    "following": 30
  }
}
```

**cURL:**

```bash
curl -X GET http://localhost:3000/api/posts/stats/USER_ID
```

---

### GET `/api/posts/follow/status`

Kullanıcının başka bir kullanıcıyı takip edip etmediğini kontrol eder.

**Query Parameters:**

- `followerId`: Takip eden kullanıcı ID'si
- `followingId`: Takip edilen kullanıcı ID'si

**Response (200):**

```json
{
  "success": true,
  "isFollowing": true
}
```

**cURL:**

```bash
curl -X GET "http://localhost:3000/api/posts/follow/status?followerId=FOLLOWER_ID&followingId=FOLLOWING_ID"
```

---

### PUT `/api/posts/profile`

Kullanıcı profilini günceller.

**Request Body:**

```json
{
  "userId": "uuid",
  "name": "Yeni İsim",  // Opsiyonel
  "bio": "Yeni biyografi",  // Opsiyonel
  "profileImage": "http://..." veya "data:image/..."  // Opsiyonel
}
```

**Response (200):**

```json
{
  "success": true,
  "message": "Profile updated",
  "user": {
    // Güncellenmiş kullanıcı verileri
  }
}
```

**cURL:**

```bash
curl -X PUT http://localhost:3000/api/posts/profile \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user_id",
    "name": "Yeni İsim",
    "bio": "Yeni biyografi",
    "profileImage": "data:image/jpeg;base64,/9j/4AAQSkZJRg..."
  }'
```

---

### POST `/api/posts/comment`

Post'a yorum ekler.

**Request Body:**

```json
{
  "postId": "post_id",
  "userId": "uuid",
  "userName": "Kullanıcı Adı",
  "text": "Yorum metni"
}
```

**Response (200):**

```json
{
  "success": true,
  "commentId": "comment_id",
  "comment": {
    "id": "comment_id",
    "userId": "uuid",
    "userName": "Kullanıcı Adı",
    "userProfileImage": "http://...",
    "text": "Yorum metni",
    "timestamp": 1704067200000
  }
}
```

**cURL:**

```bash
curl -X POST http://localhost:3000/api/posts/comment \
  -H "Content-Type: application/json" \
  -d '{
    "postId": "post_id",
    "userId": "user_id",
    "userName": "Kullanıcı Adı",
    "text": "Yorum metni"
  }'
```

---

### POST `/api/posts/delete`

Post'u siler.

**Request Body:**

```json
{
  "postId": "post_id",
  "userId": "uuid"
}
```

**Response (200):**

```json
{
  "success": true,
  "message": "Post deleted successfully"
}
```

**Hata Response (403):**

```json
{
  "success": false,
  "message": "Not authorized to delete this post"
}
```

**cURL:**

```bash
curl -X POST http://localhost:3000/api/posts/delete \
  -H "Content-Type: application/json" \
  -d '{
    "postId": "post_id",
    "userId": "user_id"
  }'
```

---

### POST `/api/posts/update`

Post'u günceller.

**Request Body:**

```json
{
  "postId": "post_id",
  "userId": "uuid",
  "caption": "Yeni açıklama",
  "location": "Yeni konum" // Opsiyonel
}
```

**Response (200):**

```json
{
  "success": true,
  "message": "Post updated successfully",
  "post": {
    // Güncellenmiş post verileri
  }
}
```

**cURL:**

```bash
curl -X POST http://localhost:3000/api/posts/update \
  -H "Content-Type: application/json" \
  -d '{
    "postId": "post_id",
    "userId": "user_id",
    "caption": "Yeni açıklama",
    "location": "Yeni konum"
  }'
```

---

### GET `/api/posts/:postId`

Belirli bir post'un detaylarını getirir.

**URL Parameters:**

- `postId`: Post ID'si

**Query Parameters:**

- `requesterId`: İstekte bulunan kullanıcı ID'si (opsiyonel) - beğeni durumunu kontrol etmek için

**Response (200):**

```json
{
  "success": true,
  "post": {
    "id": "post_id",
    "userId": "uuid",
    "userName": "Kullanıcı Adı",
    "caption": "Post açıklaması",
    "imageUrl": "http://...",
    "location": "İstanbul",
    "likes": 10,
    "liked": true,
    "comments": [...],
    "timestamp": 1704067200000,
    "user": {
      "name": "Kullanıcı Adı",
      "username": "username",
      "profileImage": "http://..."
    }
  }
}
```

**cURL:**

```bash
curl -X GET "http://localhost:3000/api/posts/POST_ID?requesterId=USER_ID"
```

---

### POST `/api/posts/migrate/user-post-keys`

Kullanıcının post anahtarlarını email'den UUID'ye migrate eder (yardımcı endpoint).

**Request Body:**

```json
{
  "userId": "email@example.com"
}
```

**Response (200):**

```json
{
  "success": true,
  "migrated": 5,
  "canonicalUserId": "uuid",
  "postsTotal": 10
}
```

**cURL:**

```bash
curl -X POST http://localhost:3000/api/posts/migrate/user-post-keys \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "email@example.com"
  }'
```

---

## Messaging Endpoints

Base Path: `/api/messaging`

### POST `/api/messaging/send`

Mesaj gönderir.

**Request Body:**

```json
{
  "senderId": "uuid veya email",
  "senderName": "Gönderen Adı",
  "recipientId": "uuid veya email",
  "recipientName": "Alıcı Adı",
  "text": "Mesaj metni"
}
```

**Response (200):**

```json
{
  "success": true,
  "message": "Mesaj gönderildi",
  "data": {
    "id": "msg_id",
    "senderId": "uuid",
    "senderName": "Gönderen Adı",
    "recipientId": "email",
    "recipientName": "Alıcı Adı",
    "text": "Mesaj metni",
    "timestamp": "2025-01-01T00:00:00.000Z"
  }
}
```

**cURL:**

```bash
curl -X POST http://localhost:3000/api/messaging/send \
  -H "Content-Type: application/json" \
  -d '{
    "senderId": "sender@example.com",
    "senderName": "Gönderen Adı",
    "recipientId": "recipient@example.com",
    "recipientName": "Alıcı Adı",
    "text": "Mesaj metni"
  }'
```

---

### GET `/api/messaging/conversations/:userId`

Kullanıcının tüm konuşmalarını getirir.

**URL Parameters:**

- `userId`: Kullanıcı ID'si (email)

**Response (200):**

```json
{
  "success": true,
  "conversations": [
    {
      "id": "email1:email2",
      "user1": "user1@example.com",
      "user1Name": "Kullanıcı 1",
      "user1Username": "username1",
      "user1ProfileImage": "http://...",
      "user2": "user2@example.com",
      "user2Name": "Kullanıcı 2",
      "user2Username": "username2",
      "user2ProfileImage": "http://...",
      "lastMessage": "Son mesaj metni",
      "lastMessageTime": "2025-01-01T00:00:00.000Z",
      "lastMessageBy": "Gönderen Adı"
    }
  ]
}
```

**Not:** Konuşmalar son mesaj zamanına göre sıralanır. Gizlenen konuşmalar döndürülmez.

**cURL:**

```bash
curl -X GET http://localhost:3000/api/messaging/conversations/USER_EMAIL
```

---

### GET `/api/messaging/conversation/:userId/:otherUserId`

Belirli bir konuşmanın mesajlarını getirir.

**URL Parameters:**

- `userId`: Kullanıcı ID'si (UUID veya email)
- `otherUserId`: Diğer kullanıcı ID'si (UUID veya email)

**Response (200):**

```json
{
  "success": true,
  "conversationId": "email1:email2",
  "messages": [
    {
      "id": "msg_id",
      "senderId": "email1",
      "senderName": "Gönderen Adı",
      "recipientId": "email2",
      "recipientName": "Alıcı Adı",
      "text": "Mesaj metni",
      "timestamp": "2025-01-01T00:00:00.000Z"
    }
  ],
  "metadata": {
    // Konuşma metadata'sı
  }
}
```

**Not:** Mesajlar ters sıralanır (eski mesajlar altta, yeni mesajlar üstte).

**cURL:**

```bash
curl -X GET http://localhost:3000/api/messaging/conversation/USER_ID/OTHER_USER_ID
```

---

### DELETE `/api/messaging/message/:conversationId/:messageId`

Mesajı siler.

**URL Parameters:**

- `conversationId`: Konuşma ID'si
- `messageId`: Mesaj ID'si

**Query Parameters:**

- `userId`: İstekte bulunan kullanıcı ID'si

**Response (200):**

```json
{
  "success": true,
  "message": "Mesaj silindi"
}
```

**Hata Response (403):**

```json
{
  "success": false,
  "message": "Yalnızca kendi mesajınızı silebilirsiniz"
}
```

**cURL:**

```bash
curl -X DELETE "http://localhost:3000/api/messaging/message/CONVERSATION_ID/MESSAGE_ID?userId=USER_ID"
```

---

### DELETE `/api/messaging/conversation/:conversationId`

Konuşmayı tamamen siler.

**URL Parameters:**

- `conversationId`: Konuşma ID'si

**Query Parameters:**

- `userId`: İstekte bulunan kullanıcı ID'si

**Response (200):**

```json
{
  "success": true,
  "message": "Sohbet silindi"
}
```

**cURL:**

```bash
curl -X DELETE "http://localhost:3000/api/messaging/conversation/CONVERSATION_ID?userId=USER_ID"
```

---

### POST `/api/messaging/conversation/hide`

Konuşmayı sadece kendisi için gizler (soft delete).

**Request Body:**

```json
{
  "conversationId": "email1:email2",
  "userId": "email"
}
```

**Response (200):**

```json
{
  "success": true,
  "message": "Sohbet gizlendi"
}
```

**cURL:**

```bash
curl -X POST http://localhost:3000/api/messaging/conversation/hide \
  -H "Content-Type: application/json" \
  -d '{
    "conversationId": "email1@example.com:email2@example.com",
    "userId": "user@example.com"
  }'
```

---

## 🔐 Authentication Notları

- Çoğu endpoint için `sessionId` cookie veya `x-session-id` header gereklidir
- Session'lar 24 saat geçerlidir
- Login endpoint'i `sessionId` cookie'sini otomatik olarak set eder

## 📝 Genel Hata Formatı

```json
{
  "success": false,
  "message": "Hata mesajı"
}
```

**Yaygın HTTP Status Kodları:**

- `200`: Başarılı
- `201`: Oluşturuldu
- `400`: Geçersiz istek
- `401`: Yetkisiz erişim
- `403`: Yetki yok
- `404`: Bulunamadı
- `500`: Sunucu hatası
- `503`: Servis kullanılamıyor (Redis bağlantı hatası)

---

**Son Güncelleme:** 25 Aralık 2025
