#!/usr/bin/env python3

from PIL import Image
import os

LOGO_PATH = "assets/images/logo.jpeg"

ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

IOS_SIZES = {
    "Icon-App-20x20@1x.png": 20,      # iPad
    "Icon-App-20x20@2x.png": 40,      # iPhone/iPad
    "Icon-App-20x20@3x.png": 60,      # iPhone
    "Icon-App-29x29@1x.png": 29,      # iPhone/iPad
    "Icon-App-29x29@2x.png": 58,      # iPhone/iPad
    "Icon-App-29x29@3x.png": 87,      # iPhone
    "Icon-App-40x40@1x.png": 40,      # iPad
    "Icon-App-40x40@2x.png": 80,      # iPhone/iPad
    "Icon-App-40x40@3x.png": 120,     # iPhone
    "Icon-App-60x60@2x.png": 120,     # iPhone
    "Icon-App-60x60@3x.png": 180,     # iPhone
    "Icon-App-76x76@1x.png": 76,      # iPad
    "Icon-App-76x76@2x.png": 152,     # iPad
    "Icon-App-83.5x83.5@2x.png": 167, # iPad Pro
    "Icon-App-1024x1024@1x.png": 1024,
}

MACOS_SIZES = {
    "app_icon_16.png": 16,
    "app_icon_32.png": 32,
    "app_icon_64.png": 64,
    "app_icon_128.png": 128,
    "app_icon_256.png": 256,
    "app_icon_512.png": 512,
    "app_icon_1024.png": 1024,
}

WEB_SIZES = {
    "favicon.png": 48,
    "Icon-192.png": 192,
    "Icon-512.png": 512,
    "Icon-maskable-192.png": 192,
    "Icon-maskable-512.png": 512,
}

def create_icon(input_path, output_path, size):
    try:
        img = Image.open(input_path)
        
        if img.mode != 'RGB':
            if img.mode in ('RGBA', 'LA'):
                background = Image.new('RGB', img.size, (255, 255, 255))
                if img.mode == 'RGBA':
                    background.paste(img, mask=img.split()[3])
                else:
                    background.paste(img)
                img = background
            else:
                img = img.convert('RGB')
        
        img_resized = img.resize((size, size), Image.Resampling.LANCZOS)
        
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        img_resized.save(output_path, "PNG", optimize=True)
        print(f"[OK] Olusturuldu: {output_path} ({size}x{size})")
        return True
    except Exception as e:
        print(f"[HATA] ({output_path}): {e}")
        return False

def main():
    if not os.path.exists(LOGO_PATH):
        print(f"HATA: Logo dosyasi bulunamadi: {LOGO_PATH}")
        return
    
    print(f"Logo yukleniyor: {LOGO_PATH}\n")
    
    success_count = 0
    total_count = 0
    
    print("Android ikonlari olusturuluyor...")
    for folder, size in ANDROID_SIZES.items():
        output_path = f"android/app/src/main/res/{folder}/ic_launcher.png"
        total_count += 1
        if create_icon(LOGO_PATH, output_path, size):
            success_count += 1
    
    print("\niOS ikonlari olusturuluyor...")
    ios_base = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for filename, size in IOS_SIZES.items():
        output_path = f"{ios_base}/{filename}"
        total_count += 1
        if create_icon(LOGO_PATH, output_path, size):
            success_count += 1
    
    print("\nmacOS ikonlari olusturuluyor...")
    macos_base = "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for filename, size in MACOS_SIZES.items():
        output_path = f"{macos_base}/{filename}"
        total_count += 1
        if create_icon(LOGO_PATH, output_path, size):
            success_count += 1
    
    print("\nWeb ikonlari olusturuluyor...")
    for filename, size in WEB_SIZES.items():
        output_path = f"web/{filename}" if filename == "favicon.png" else f"web/icons/{filename}"
        total_count += 1
        if create_icon(LOGO_PATH, output_path, size):
            success_count += 1
    
    print(f"\nTAMAMLANDI: {success_count}/{total_count} ikon basariyla olusturuldu!")
    if success_count < total_count:
        print("UYARI: Bazi ikonlar olusturulamadi. Lutfen hatalari kontrol edin.")

if __name__ == "__main__":
    main()

