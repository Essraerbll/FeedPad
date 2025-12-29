# FeedPad - Provider Kullanım Raporu

## 📋 İçindekiler
1. [Provider Genel Bakış](#provider-genel-bakış)
2. [Kullanılan Provider'lar](#kullanılan-providerlar)
3. [Provider Kayıt Yapısı](#provider-kayıt-yapısı)
4. [Provider Kullanım Detayları](#provider-kullanım-detayları)
5. [Ekran Bazında Kullanım](#ekran-bazında-kullanım)
6. [Provider Pattern Örnekleri](#provider-pattern-örnekleri)

---

## 🔄 Provider Genel Bakış

FeedPad projesinde **Provider** paketi state management için kullanılmaktadır. Provider, Flutter'da ChangeNotifier pattern'ini kullanarak reactive state management sağlar.

### Kullanılan Paket
```yaml
provider: ^6.1.2
```

### Provider Pattern
- **ChangeNotifier**: State değişikliklerini dinleyen widget'ları bilgilendirir
- **notifyListeners()**: State değiştiğinde tüm dinleyicilere bildirim gönderir
- **Provider.of**: Provider'a erişim için kullanılır
- **Consumer**: Sadece belirli widget'ları rebuild etmek için kullanılır

---

## 📦 Kullanılan Provider'lar

### 1. AuthService (ChangeNotifier)

**Dosya:** `lib/services/auth_service.dart`

**Açıklama:** Authentication state yönetimi için kullanılan tek provider.

**Sınıf Yapısı:**
```dart
class AuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  User? _currentUser;
  bool _isLoading = false;

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  // Methods
  Future<String?> signUp({...});
  Future<String?> signIn({...});
  Future<void> signOut();
  Future<void> getCurrentUser();
}
```

**State Değişkenleri:**
- `_currentUser`: Mevcut kullanıcı bilgisi (User? tipinde)
- `_isLoading`: Loading durumu (bool)

**Public Getters:**
- `currentUser`: Mevcut kullanıcı bilgisini döndürür
- `isLoading`: Loading durumunu döndürür
- `isAuthenticated`: Kullanıcının giriş yapıp yapmadığını kontrol eder

**State Değiştiren Metodlar:**
- `signUp()`: Kayıt işlemi, `_isLoading` ve `_currentUser` değiştirir
- `signIn()`: Giriş işlemi, `_isLoading` ve `_currentUser` değiştirir
- `signOut()`: Çıkış işlemi, `_currentUser`'ı null yapar
- `getCurrentUser()`: Mevcut kullanıcı bilgisini getirir, `_currentUser` değiştirir

**notifyListeners() Kullanımı:**
- Her state değişikliğinden sonra `notifyListeners()` çağrılır
- Bu sayede provider'ı dinleyen tüm widget'lar otomatik olarak rebuild edilir

---

## 🔧 Provider Kayıt Yapısı

### Ana Provider Kaydı

**Dosya:** `lib/main.dart`

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService()..getCurrentUser(),
      child: MaterialApp(
        title: 'FeedPad',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}
```

**Özellikler:**
- `ChangeNotifierProvider`: AuthService'i uygulama seviyesinde sağlar
- `create: (_) => AuthService()..getCurrentUser()`: Provider oluşturulurken mevcut kullanıcı bilgisi kontrol edilir
- Tüm uygulama boyunca AuthService'e erişilebilir

**Provider Scope:**
- Uygulama seviyesinde (MyApp widget'ı)
- Tüm alt widget'lar AuthService'e erişebilir

---

## 📱 Provider Kullanım Detayları

### Provider.of Pattern

**Kullanım Şekilleri:**

#### 1. **listen: true (Varsayılan)**
```dart
final authService = Provider.of<AuthService>(context);
```
- State değiştiğinde widget rebuild edilir
- Reactive UI için kullanılır

#### 2. **listen: false**
```dart
final authService = Provider.of<AuthService>(context, listen: false);
```
- State değiştiğinde widget rebuild edilmez
- Sadece metod çağrıları için kullanılır
- Performans optimizasyonu için

### Consumer Pattern

**Kullanım:**
```dart
Consumer<AuthService>(
  builder: (context, authService, child) {
    if (authService.isAuthenticated) {
      return MainScreen();
    }
    return LoginScreen();
  }
)
```

**Not:** FeedPad projesinde Consumer pattern kullanılmamış, sadece Provider.of kullanılmıştır.

---

## 🖥️ Ekran Bazında Kullanım

### 1. AuthWrapper

**Dosya:** `lib/screens/auth_wrapper.dart`

**Kullanım:**
```dart
final authService = Provider.of<AuthService>(context);
```

**Kullanım Amacı:**
- `isLoading`: Loading durumunu kontrol eder
- `isAuthenticated`: Kullanıcının giriş yapıp yapmadığını kontrol eder
- Welcome, Login veya MainScreen arasında yönlendirme yapar

**Kod:**
```dart
@override
Widget build(BuildContext context) {
  final authService = Provider.of<AuthService>(context);

  // Loading durumu
  if (authService.isLoading) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  // İlk kez açılışta welcome ekranını göster
  if (_showWelcome && !authService.isAuthenticated) {
    return WelcomeScreen(...);
  }

  // Kullanıcı giriş yapmışsa ana ekrana yönlendir
  if (authService.isAuthenticated) {
    return const MainScreen();
  }

  // Kullanıcı giriş yapmamışsa login ekranına yönlendir
  return const LoginScreen();
}
```

---

### 2. LoginScreen

**Dosya:** `lib/screens/login_screen.dart`

**Kullanım:**
```dart
final authService = Provider.of<AuthService>(context, listen: false);
```

**Kullanım Amacı:**
- `signIn()`: Giriş işlemi yapar
- `isAuthenticated`: Giriş başarılı olup olmadığını kontrol eder

**Kod:**
```dart
Future<void> _signIn() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  final authService = Provider.of<AuthService>(context, listen: false);
  final error = await authService.signIn(
    email: _emailController.text.trim(),
    password: _passwordController.text,
  );

  setState(() => _isLoading = false);

  if (error != null && mounted) {
    // Hata göster
  } else if (mounted && authService.isAuthenticated) {
    // Başarılı giriş - ana ekrana yönlendir
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }
}
```

**Not:** `listen: false` kullanılmasının nedeni, sadece metod çağrısı yapılması ve widget'ın rebuild edilmesine gerek olmamasıdır.

---

### 3. RegisterScreen

**Dosya:** `lib/screens/register_screen.dart`

**Kullanım:**
```dart
final authService = Provider.of<AuthService>(context, listen: false);
```

**Kullanım Amacı:**
- `signUp()`: Kayıt işlemi yapar

**Kod:**
```dart
Future<void> _signUp() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  final authService = Provider.of<AuthService>(context, listen: false);
  final error = await authService.signUp(
    email: _emailController.text.trim(),
    password: _passwordController.text,
    name: _nameController.text.trim(),
    username: _usernameController.text.trim().isEmpty
        ? null
        : _usernameController.text.trim(),
    userType: _userType ?? '',
  );

  setState(() => _isLoading = false);
  // ...
}
```

---

### 4. MainScreen

**Dosya:** `lib/screens/main_screen.dart`

**Kullanım:**
```dart
final authService = Provider.of<AuthService>(context, listen: false);
```

**Kullanım Amacı:**
- `signOut()`: Çıkış işlemi yapar

**Kod:**
```dart
Future<void> _signOut() async {
  final authService = Provider.of<AuthService>(context, listen: false);
  await authService.signOut();

  if (mounted) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
}
```

---

### 5. ProfileScreen

**Dosya:** `lib/screens/profile_screen.dart`

**Kullanım:**
```dart
// listen: false ile metod çağrıları
final auth = Provider.of<AuthService>(context, listen: false);

// listen: true ile reactive UI
final authService = Provider.of<AuthService>(context);
```

**Kullanım Amacı:**
- `currentUser`: Kullanıcı bilgilerini görüntülemek için
- `currentUser?.email`: User ID olarak email kullanımı
- Post beğenme, silme, güncelleme işlemleri

**Kod Örnekleri:**

**1. Reactive UI (listen: true):**
```dart
@override
Widget build(BuildContext context) {
  final authService = Provider.of<AuthService>(context);
  final currentUser = authService.currentUser;

  return Scaffold(
    // ...
    Text(currentUser?.name ?? 'Pet Owner'),
    Text('@${currentUser?.username ?? 'username'}'),
  );
}
```

**2. Metod Çağrıları (listen: false):**
```dart
Future<void> _toggleLike(Map<String, dynamic> post) async {
  final auth = Provider.of<AuthService>(context, listen: false);
  final userId = auth.currentUser?.email;
  if (userId == null) return;
  // ...
}

Future<void> _loadUserData() async {
  final authService = Provider.of<AuthService>(context, listen: false);
  final userId = authService.currentUser?.email;
  // ...
}
```

**3. Dialog İçinde Kullanım:**
```dart
void _showEditPostDialog(Map<String, dynamic> post) {
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        // ...
        actions: [
          ElevatedButton(
            onPressed: () async {
              final auth = Provider.of<AuthService>(context, listen: false);
              final userId = auth.currentUser?.email;
              // ...
            },
          ),
        ],
      ),
    ),
  );
}
```

---

### 6. FeedMapScreen

**Dosya:** `lib/screens/feed_map_screen.dart`

**Kullanım:**
```dart
final authService = Provider.of<AuthService>(context, listen: false);
```

**Kullanım Amacı:**
- `currentUser?.userType`: Pet shop owner kontrolü için
- Marker ekleme işlemlerinde kullanıcı tipi kontrolü

**Kod:**
```dart
void _onMapLongPress(TapPosition tapPosition, LatLng latlng) async {
  // Pet shop owner kontrolü
  final authService = Provider.of<AuthService>(context, listen: false);
  final currentUser = authService.currentUser;
  final isPetShopOwner = currentUser?.userType == 'pet_shop_owner';

  // Marker ekleme formunu popup olarak aç
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => AddMarkerScreen(position: latlng),
  );
  // ...
}
```

---

## 💡 Provider Pattern Örnekleri

### Örnek 1: Reactive UI (State Değişikliğinde Otomatik Güncelleme)

```dart
// AuthWrapper'da
final authService = Provider.of<AuthService>(context);

// authService.isAuthenticated değiştiğinde widget otomatik rebuild edilir
if (authService.isAuthenticated) {
  return const MainScreen();
}
```

**Nasıl Çalışır:**
1. `signIn()` çağrılır
2. `_currentUser` set edilir
3. `notifyListeners()` çağrılır
4. `Provider.of<AuthService>(context)` kullanan widget'lar rebuild edilir
5. `isAuthenticated` true olduğu için MainScreen gösterilir

---

### Örnek 2: Metod Çağrısı (Rebuild Gerektirmeyen)

```dart
// LoginScreen'de
final authService = Provider.of<AuthService>(context, listen: false);
final error = await authService.signIn(
  email: _emailController.text.trim(),
  password: _passwordController.text,
);
```

**Nasıl Çalışır:**
1. `listen: false` ile provider'a erişilir
2. `signIn()` metod çağrısı yapılır
3. Widget rebuild edilmez (performans optimizasyonu)
4. Manuel olarak `setState()` veya navigation ile UI güncellenir

---

### Örnek 3: User ID Erişimi

```dart
// ProfileScreen'de
final authService = Provider.of<AuthService>(context, listen: false);
final userId = authService.currentUser?.email;

// API çağrısında kullanım
final response = await _apiService.get('/posts/user/$userId');
```

**Kullanım Senaryosu:**
- Kullanıcı bilgilerine erişim
- API çağrılarında user ID kullanımı
- Post, marker gibi işlemlerde kullanıcı doğrulama

---

### Örnek 4: Conditional Rendering

```dart
// AuthWrapper'da
final authService = Provider.of<AuthService>(context);

if (authService.isLoading) {
  return const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

if (authService.isAuthenticated) {
  return const MainScreen();
}

return const LoginScreen();
```

**Kullanım Senaryosu:**
- Loading durumunda spinner gösterimi
- Authentication durumuna göre ekran yönlendirmesi
- Reactive UI güncellemeleri

---

## 📊 Provider Kullanım İstatistikleri

### Toplam Provider Sayısı
- **1 Provider**: AuthService

### Provider Kullanılan Ekranlar
1. ✅ AuthWrapper
2. ✅ LoginScreen
3. ✅ RegisterScreen
4. ✅ MainScreen
5. ✅ ProfileScreen
6. ✅ FeedMapScreen

### Provider Kullanım Şekilleri
- **listen: true**: 2 ekran (AuthWrapper, ProfileScreen - build method'unda)
- **listen: false**: 6 ekran (Tüm ekranlarda metod çağrıları için)

### Provider Metodları Kullanımı
- `signIn()`: LoginScreen
- `signUp()`: RegisterScreen
- `signOut()`: MainScreen
- `getCurrentUser()`: main.dart (uygulama başlangıcında)
- `currentUser`: ProfileScreen, FeedMapScreen
- `isAuthenticated`: AuthWrapper
- `isLoading`: AuthWrapper

---

## 🔍 Provider Pattern Avantajları

### ✅ Avantajlar

1. **Basit ve Anlaşılır**
   - ChangeNotifier pattern'i kolay anlaşılır
   - Minimal boilerplate code

2. **Reactive UI**
   - `notifyListeners()` ile otomatik UI güncellemeleri
   - State değişikliklerinde widget'lar otomatik rebuild edilir

3. **Performans Optimizasyonu**
   - `listen: false` ile gereksiz rebuild'ler önlenir
   - Sadece gerekli widget'lar güncellenir

4. **Separation of Concerns**
   - Business logic service layer'da
   - UI logic widget'larda
   - Temiz kod yapısı

5. **Test Edilebilirlik**
   - Mock provider'lar ile test yazılabilir
   - Unit test'ler kolay yazılır

### ⚠️ Dezavantajlar

1. **Manuel State Management**
   - Her state için ChangeNotifier gerekli
   - Redux gibi otomatik state management yok

2. **Boilerplate Code**
   - Her service için ChangeNotifier extend etmek gerekir
   - `notifyListeners()` her yerde çağrılmalı

3. **No Time Travel**
   - Redux DevTools gibi debugging tool'ları yok
   - State history takibi yok

4. **Limited Scalability**
   - Çok fazla provider olduğunda yönetim zorlaşır
   - Complex state için yetersiz kalabilir

---

## 🎯 Öneriler ve İyileştirmeler

### 1. Consumer Pattern Kullanımı
```dart
// Mevcut
final authService = Provider.of<AuthService>(context);

// Önerilen (daha performanslı)
Consumer<AuthService>(
  builder: (context, authService, child) {
    return Text(authService.currentUser?.name ?? 'User');
  },
  child: ExpensiveWidget(), // child rebuild edilmez
)
```

### 2. MultiProvider Kullanımı
```dart
// Gelecekte birden fazla provider eklenebilir
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthService()),
    ChangeNotifierProvider(create: (_) => MarkerService()),
    ChangeNotifierProvider(create: (_) => PostService()),
  ],
  child: MaterialApp(...),
)
```

### 3. Selector Pattern
```dart
// Sadece belirli bir property değiştiğinde rebuild
Selector<AuthService, User?>(
  selector: (_, authService) => authService.currentUser,
  builder: (context, user, child) {
    return Text(user?.name ?? 'User');
  },
)
```

### 4. Provider Scope Optimizasyonu
```dart
// Sadece belirli bir widget tree'de provider sağlama
Provider<AuthService>(
  create: (_) => AuthService(),
  child: ProfileScreen(),
)
```

---

## 📝 Özet

### Kullanılan Provider
- **1 Provider**: AuthService (ChangeNotifier)

### Provider Kullanımı
- **6 Ekran**: Provider kullanıyor
- **2 Kullanım Şekli**: listen: true/false
- **7 Metod/Property**: Kullanılıyor

### Provider Pattern
- **ChangeNotifier**: State management için
- **Provider.of**: Provider'a erişim için
- **notifyListeners()**: State değişikliklerini bildirmek için

### Sonuç
FeedPad projesinde Provider pattern başarıyla kullanılmıştır. Authentication state yönetimi için yeterli ve etkili bir çözümdür. Gelecekte daha fazla state management gerektiğinde (MarkerService, PostService gibi) aynı pattern kullanılabilir.

---

**Rapor Tarihi:** 25 Aralık 2025  
**Proje Versiyonu:** 1.0.0  
**Provider Versiyonu:** ^6.1.2

