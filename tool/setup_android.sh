#!/usr/bin/env bash
#
# Materializa o projeto Android nativo e aplica as configurações canônicas
# do DirectTube por cima do template gerado pelo Flutter.
#
# Por que este script existe: o ambiente de desenvolvimento não consegue baixar
# os artefatos do Flutter (storage.googleapis.com bloqueado), e o gradle wrapper
# é um binário que não vive neste repositório. `flutter create` regenera tudo
# isso de forma idempotente; este script garante que applicationId, namespace,
# permissões e MainActivity sejam SEMPRE os nossos, independente da versão do
# template (Groovy ou Kotlin DSL).
#
# Uso local:  bash tool/setup_android.sh
# Uso na CI:  idem (ver .github/workflows/ci.yml)
set -euo pipefail

cd "$(dirname "$0")/.."

APP_ID="com.directtube.app"
ORG="com.directtube"
PROJECT="directtube"
GENERATED_ID="${ORG}.${PROJECT}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERRO: 'flutter' não está no PATH." >&2
  exit 1
fi

echo "==> flutter create (android)"
flutter create --platforms=android --org "$ORG" --project-name "$PROJECT" . >/dev/null

echo "==> aplicando AndroidManifest.xml canônico"
cp tool/android/AndroidManifest.xml android/app/src/main/AndroidManifest.xml

echo "==> aplicando MainActivity ($APP_ID)"
# Remove o pacote gerado pelo template (…/com/directtube/directtube) e instala o nosso.
find android/app/src/main/kotlin -type d -name "${PROJECT}" -prune -exec rm -rf {} + 2>/dev/null || true
MAIN_DIR="android/app/src/main/kotlin/$(echo "$APP_ID" | tr '.' '/')"
mkdir -p "$MAIN_DIR"
cp tool/android/MainActivity.kt "$MAIN_DIR/MainActivity.kt"

echo "==> ajustando applicationId/namespace para $APP_ID"
for f in android/app/build.gradle android/app/build.gradle.kts; do
  if [ -f "$f" ]; then
    sed -i "s/${GENERATED_ID}/${APP_ID}/g" "$f"
    # file_picker (via flutter_plugin_android_lifecycle) exige compileSdk >= 36.
    sed -i -E "s/compileSdk = .*/compileSdk = 36/" "$f"
    sed -i -E "s/compileSdkVersion .*/compileSdkVersion 36/" "$f"
    echo "    patch: $f"
  fi
done

echo "==> garantindo propriedades de build"
touch android/gradle.properties
for line in \
  "org.gradle.jvmargs=-Xmx2048M -Dfile.encoding=UTF-8" \
  "android.useAndroidX=true" \
  "android.enableJetifier=true"; do
  key="${line%%=*}"
  if ! grep -q "^${key}=" android/gradle.properties; then
    echo "$line" >> android/gradle.properties
  fi
done

echo "==> OK. applicationId=$(grep -rho "applicationId[ =\"']*[a-zA-Z0-9._]*" android/app/build.gradle* 2>/dev/null | head -1)"
