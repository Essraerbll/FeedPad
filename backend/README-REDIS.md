# Redis Kurulumu ve Kullanımı (Windows)

## Redis Konumu

Redis şu konumda kurulu: `C:\Program Files\Redis\redis-server.exe`

## Redis'i Başlatma

### Yöntem 1: Batch Script ile (Önerilen)

```bash
.\start-redis.bat
```

### Yöntem 2: PowerShell ile

```powershell
Start-Process -FilePath "C:\Program Files\Redis\redis-server.exe"
```

### Yöntem 3: Manuel olarak

Windows Explorer'da `C:\Program Files\Redis\` klasörüne gidin ve `redis-server.exe` dosyasını çift tıklayın.

## Redis'i PATH'e Ekleme (İsteğe Bağlı)

Redis'i PATH'e eklemek için:

1. **Sistem Değişkenlerini Düzenle:**

   - Windows tuşu + R → `sysdm.cpl` yazın
   - "Gelişmiş" sekmesi → "Ortam Değişkenleri"
   - "Sistem değişkenleri" altında "Path" seçin → "Düzenle"
   - "Yeni" → `C:\Program Files\Redis` ekleyin
   - Tüm pencereleri "Tamam" ile kapatın

2. **PowerShell'i yeniden başlatın**

3. **Test edin:**
   ```bash
   redis-server --version
   ```

## Redis Durumunu Kontrol Etme

```powershell
Test-NetConnection -ComputerName localhost -Port 6379
```

Port 6379 açıksa Redis çalışıyordur.

## Notlar

- Redis'i her seferinde manuel başlatmanız gerekebilir
- Redis'i Windows başlangıcında otomatik başlatmak için Windows Görev Zamanlayıcısı kullanabilirsiniz
- Redis çalışmazsa sunucu başlatılamaz ve hata verecektir
