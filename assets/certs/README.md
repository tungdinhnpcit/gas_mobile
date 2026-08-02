# assets/certs/

Trước khi build release, copy 2 file sau vào đây (sinh bởi `certs/generate-ca.sh` ở root repo):

- `client-mobile.p12` — client certificate mTLS của app (KHÔNG commit, đã có trong `.gitignore`)
- `ca.crt` — CA nội bộ, dùng để tin cậy server cert của nginx (an toàn để commit, chỉ là public cert)

Build với password đã dùng khi sinh `.p12`:

```
flutter build apk --release --dart-define=MTLS_P12_PASSWORD=xxx --obfuscate --split-debug-info=build/debug-info
```

Xem `certs/README.md` (root repo) và `lib/core/network/mtls_client.dart` để biết chi tiết.
