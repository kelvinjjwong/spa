# spa
swift pod automation

## install

1. XCode -> File -> New -> Package... -> Multiplatform -> Library

2. install script

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/kelvinjjwong/spa/main/install)"
```

3. ./build_pod.sh init

4. ./build_pod.sh test

5. ./build_pod.sh release

## build myself

```bash
./build test
./build release
```

## dependency

- /build
  - GitHub CLI
- /build_pod.sh
  - GitHub CLI
  - Cocoapods
  - Xcode

