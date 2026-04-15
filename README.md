# CodeMe App - Instruções de Build

## Gerar Keystore (apenas uma vez)

```bash
mkdir -p android/keystore

keytool -genkey -v \
  -keystore android/keystore/codeme-release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias codeme \
  -storepass SUA_SENHA_DO_KEYSTORE \
  -keypass SUA_SENHA_DA_KEY \
  -dname "CN=CodeMe, OU=Dev, O=CodeMe, L=Lisboa, ST=Lisboa, C=PT"
```

## Configurar assinatura

1. Copia `android/key.properties.template` para `android/key.properties`
2. Preenche com as tuas senhas
3. Adiciona `android/key.properties` e `android/keystore/` ao `.gitignore`

## Build APK / AAB

```bash
# Instalar dependências
flutter pub get

# APK release (para instalar direto)
flutter build apk --release

# AAB (para Google Play)
flutter build appbundle --release
```

## Android suportado

- Mínimo: Android 7.0 (API 24)
- Target: Android 14 (API 34)
