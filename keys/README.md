# 🔐 Release Verification

## Public key
  [/keys/release-signing.pub](https://github.com/uharries/PSASM/blob/main/keys/release-signing.pub)

## Fingerprint (SHA-256)
  `a59acc70f7cdd88cdd7887903e4abc9ca7b4e482ba3da9427407b4c34a830580`

## Verification
Before verifying a release, ensure you are using a trusted copy of the public key file and have validated its fingerprint.

Verification consists of two independent checks:

1. **Public key fingerprint verification** — ensures the public key itself is authentic and has not been replaced.
2. **Signature verification** — ensures the release artifact was produced by the holder of the corresponding private key and has not been modified.

Both steps are required. Verifying a signature with an untrusted key provides no security.

The public key file can be obtained from this repository:
  [/keys/release-signing.pub](https://github.com/uharries/PSASM/blob/main/keys/release-signing.pub)

The expected fingerprint is published here and in release notes.
For stronger assurance, compare it across multiple sources (e.g. repository, documentation, or other trusted channels).

### Public Key Fingerprint Verification

Before trusting the public key, verify the public key fingerprint.

**In PowerShell, using OpenSSL:**
```powershell
$pub = ".\keys\release-signing.pub"
$fp = "a59acc70f7cdd88cdd7887903e4abc9ca7b4e482ba3da9427407b4c34a830580"
$pubHash = (openssl pkey -pubin -in .\keys\release-signing.pub -outform DER | openssl dgst -sha256) -replace '.*?=\s+',''
$pubHash -eq $fp
```
Expected output:
```powershell
True
```

### Release Artifact Signature Verification

**In PowerShell, using OpenSSL:**
```powershell
$pub = ".\keys\release-signing.pub"
$zip = "psasm-v0.1.0.zip"
openssl pkeyutl -verify -pubin -inkey $pub -sigfile "$zip.sig" -in $zip -rawin
```
Expected output:
```powershell
Signature Verified Successfully
```
---

⚠️ **Do not trust the release if any verification step fails.**

If the fingerprint does not match, the public key may be compromised.
If the signature verification fails, the release artifact may have been tampered with.

In either case, discard the files and obtain them again from a trusted source.