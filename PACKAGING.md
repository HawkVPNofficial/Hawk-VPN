# 打包说明

本文档整理 Hawk VPN 当前仓库的常用打包命令。所有命令默认在项目根目录执行：

```bash
cd /Users/huxiao/Documents/github/FlClash
```

## 前置要求

首次或子模块变更后先执行：

```bash
git submodule update --init --recursive
```

Android 构建需要本机已配置 Flutter、Android SDK、NDK。当前 16KB page size 构建使用 NDK `28.2.13676358`。

## 环境参数

`setup.dart` 支持两个环境：

```bash
--env pre
--env stable
```

- `pre`：预发环境，默认值。
- `stable`：正式环境，写入 `BACKEND_BASE_URL=https://api.tooran.link/`。

正式包建议始终显式传：

```bash
--env stable
```

## Android 渠道

当前支持渠道：

```text
official,cashcat,oppo,xiaomi,googleplay,vivo,apkpure
```

指定单渠道：

```bash
--channels=official
```

指定多个渠道：

```bash
--channels=official,googleplay
```

不传 `--channels` 时，Android 会构建全部渠道。

默认构建会按渠道选择产物：`googleplay` 生成包含全部 ABI 的通用 AAB；其余渠道生成仅包含 `arm64-v8a` 的 APK。

## APK 打包

非 Google Play 渠道默认目标是仅包含 `arm64-v8a` 的 APK。

打 official 正式 APK：

```bash
dart setup.dart android --env stable --channels=official
```

打所有渠道正式包（Google Play 为 AAB，其余为 APK）：

```bash
dart setup.dart android --env stable
```

常见输出示例：

```text
dist/HawkVPN-0.0.7-android-official-release-arm64-v8a.apk
```

## Play AAB 打包

Google Play 专用 AAB 使用 `googleplay` 渠道，默认生成包含全部 ABI 的通用 AAB：

```bash
dart setup.dart android --env stable --channels=googleplay
```

输出文件：

```text
dist/HawkVPN-<version>-android-googleplay-release.aab
```

例如：

```text
dist/HawkVPN-0.0.7-android-googleplay-release.aab
```

说明：

- Google Play 渠道会忽略 `--arch`，确保 AAB 包含全部 ABI。
- 指定 `googleplay` 渠道时，`--targets` 只能为 `aab`。
- Go core 会使用 `-Wl,-z,max-page-size=16384` 重新链接。
- QuickJS Android 依赖会解析到 `fastdev-jsruntimes-quickjs:0.3.6`，避免旧版 native so 不满足 16KB page size。

## 普通 AAB 打包

如需非 Play 的普通 AAB，可显式指定目标和渠道：

```bash
dart setup.dart android --env stable --targets=aab --channels=official
```

如需构建单 ABI 的非 Play AAB，可额外传入 `--arch=arm64`。默认的渠道 APK 已固定为 `arm64-v8a`。

## 产物命名

Android 产物命名规范：

```text
HawkVPN-<version>-android-<channel>-release.<ext>
```

APK 拆分 ABI 时会追加 ABI：

```text
HawkVPN-<version>-android-<channel>-release-arm64-v8a.apk
```

## 验证 16KB page size

构建 Play AAB 后，可用以下脚本检查 AAB 内所有 `.so` 的 `LOAD p_align`：

```bash
python3 - <<'PY'
import struct, zipfile
from pathlib import Path

path = Path('dist/HawkVPN-0.0.6-android-googleplay-release.aab')

def load_aligns(data):
    if data[:4] != b'\x7fELF':
        return []
    cls = data[4]
    endian = '<' if data[5] == 1 else '>'
    aligns = []
    if cls == 2:
        e_phoff, = struct.unpack_from(endian + 'Q', data, 32)
        e_phentsize, e_phnum = struct.unpack_from(endian + 'HH', data, 54)
        for i in range(e_phnum):
            off = e_phoff + i * e_phentsize
            p_type, = struct.unpack_from(endian + 'I', data, off)
            if p_type == 1:
                p_align, = struct.unpack_from(endian + 'Q', data, off + 48)
                aligns.append(p_align)
    else:
        e_phoff, = struct.unpack_from(endian + 'I', data, 28)
        e_phentsize, e_phnum = struct.unpack_from(endian + 'HH', data, 42)
        for i in range(e_phnum):
            off = e_phoff + i * e_phentsize
            p_type, = struct.unpack_from(endian + 'I', data, off)
            if p_type == 1:
                p_align, = struct.unpack_from(endian + 'I', data, off + 28)
                aligns.append(p_align)
    return aligns

failed = []
with zipfile.ZipFile(path) as zf:
    libs = sorted(
        name for name in zf.namelist()
        if name.startswith('base/lib/') and name.endswith('.so')
    )
    print('abis=', sorted({name.split('/')[2] for name in libs}))
    for name in libs:
        aligns = load_aligns(zf.read(name))
        ok = bool(aligns) and all(align >= 0x4000 for align in aligns)
        print(f'{name}: min={hex(min(aligns) if aligns else 0)} ok={ok}')
        if not ok:
            failed.append(name)

if failed:
    raise SystemExit('not 16KB aligned: ' + ', '.join(failed))
PY
```

通过时应看到所有 `.so` 都是 `ok=True`。
