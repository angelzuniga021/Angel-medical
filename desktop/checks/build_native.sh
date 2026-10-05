#!/usr/bin/env bash
set -euo pipefail
mkdir -p desktop/native
git clone --depth 1 --branch v4.6.1 https://github.com/sqlcipher/sqlcipher.git desktop/native/source
cd desktop/native/source
./configure --enable-tempstore=yes --disable-tcl CFLAGS='-DSQLITE_HAS_CODEC -I/mingw64/include' LDFLAGS='-L/mingw64/lib -lcrypto'
make sqlite3.c
gcc -shared -O2 -DSQLITE_HAS_CODEC -DSQLCIPHER_CRYPTO_OPENSSL -DSQLITE_TEMP_STORE=2 -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_COLUMN_METADATA -DSQLITE_ENABLE_FTS5 -I/mingw64/include sqlite3.c -L/mingw64/lib -lcrypto -Wl,--export-all-symbols -o ../sqlcipher.dll
cp LICENSE.md ../SQLCipher-LICENSE.txt
cp /mingw64/bin/openssl.exe /mingw64/bin/libcrypto-3-x64.dll /mingw64/bin/libssl-3-x64.dll /mingw64/lib/ossl-modules/legacy.dll ../
cp /mingw64/bin/libgcc_s_seh-1.dll /mingw64/bin/libwinpthread-1.dll ../
license_file=$(find /mingw64/share/licenses/openssl -maxdepth 1 -iname 'LICENSE*' -print -quit)
test -n "$license_file"
cp "$license_file" ../OpenSSL-LICENSE.txt
