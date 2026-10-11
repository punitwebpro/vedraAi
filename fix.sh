set -e
cd /workspaces/vedraAi

# 1. Keystore: Codespace ki key copy karo (na ho to nayi banao)
if [ ! -f ~/.android/debug.keystore ]; then
  mkdir -p ~/.android
  keytool -genkey -v -keystore ~/.android/debug.keystore -storepass android \
    -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 \
    -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
fi
cp ~/.android/debug.keystore android/app/vedra-debug.keystore

# 2. Gradle me signing block jodo, chat screen me asli error dikhao, version badhao
python3 - <<'PY'
import re
# Gradle
p = 'android/app/build.gradle.kts'
s = open(p).read()
if 'vedra-debug.keystore' not in s:
    block = '''    signingConfigs {
        getByName("debug") {
            storeFile = file("vedra-debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

'''
    assert '    buildTypes {' in s, 'buildTypes nahi mila'
    s = s.replace('    buildTypes {', block + '    buildTypes {', 1)
    open(p, 'w').write(s)
    print('Gradle: signing block joda')

# Chat screen
p = 'lib/features/chat/vedra_chat_screen.dart'
s = open(p).read()
old = "    } catch (_) {\n      reply = 'Jawab nahi mil paaya. Internet check karke dobara try karein.';\n    }"
new = "    } catch (e) {\n      reply = 'Jawab nahi mil paaya.\\n($e)';\n    }"
if old in s:
    open(p, 'w').write(s.replace(old, new, 1))
    print('Chat screen: asli error dikhega')
else:
    print('Chat screen: purana catch nahi mila (shayad pehle hi badla hai)')

# Version
p = 'pubspec.yaml'
s = open(p).read()
m = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)', s, re.M)
n = int(m.group(2)) + 1
s = s.replace(m.group(0), f'version: {m.group(1)}+{n}', 1)
open(p, 'w').write(s)
open('/tmp/vbuild', 'w').write(str(n))
print('Version:', m.group(1) + '+' + str(n))
PY

N=$(cat /tmp/vbuild)

# 3. Git push
git add -f android/app/vedra-debug.keystore
git add -A
git commit -m "Fix signing key, show real chat error, version $N"
git push

# 4. Build aur release
flutter build apk --debug
gh release create "v$N" build/app/outputs/flutter-apk/app-debug.apk \
  --title "Vedra v$N" --notes "Fixed signing, real error shown"

echo ""
echo "HO GAYA. Ye link phone me kholo:"
echo "https://github.com/punitwebpro/vedraAi/releases/latest"
