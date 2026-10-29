# 第三方组件声明 / Third-Party Notices

本仓库源码**不包含（vendor）任何第三方库的源代码**。Flutter 依赖由 `pubspec.yaml` / `pubspec.lock` 声明，新增安卓依赖由 `android/app/build.gradle` 声明，在构建时经 pub 或 Gradle 获取，分别适用各自的许可或使用条款，与本项目的 [LICENSE](LICENSE)（双许可）相互独立。

## 本地截图识别新增组件 / Added screenshot OCR component

- Google ML Kit Chinese Text Recognition：`com.google.mlkit:text-recognition-chinese:16.0.1`，中文模型随安卓安装包提供。适用 [ML Kit 条款及隐私说明](https://developers.google.com/ml-kit/terms)，并非将 SDK 或模型改为本项目许可。
- 图像和识别输出在设备上处理，不发送给 Google；SDK 可能联系 Google 获取兼容信息或发送性能、使用统计。截图兜底默认关闭，开启前显示用途及统计说明。
- Bundled Chinese OCR is governed by the linked ML Kit terms. Images and recognized text remain on-device; SDK performance/utilization metrics and compatibility traffic may still be transmitted. The original Flutter dependency list below is retained.

`packages/` 目录下的 `flutter_ai_kit*` 与 `flutter_cloud_sync*` 系列为本项目自研组件，属许可软件本体、受项目 LICENSE 约束，**不属于第三方组件**。

> 以下清单基于各包发布物中的 LICENSE 文本核验（2026-07 整理，共 51 个第三方直接依赖，**无 GPL / LGPL / AGPL 项**）。传递依赖可用 `flutter pub deps` 查看；如与上游申明不符，以上游为准。
>
> **English**: This repository does **not vendor** any third-party source code. All dependencies are declared in `pubspec.yaml` / `pubspec.lock` and fetched by pub at build time under their own licenses, independent of this project's dual [LICENSE](LICENSE_EN). Packages under `packages/` (`flutter_ai_kit*`, `flutter_cloud_sync*`) are first-party components covered by the project LICENSE. The list below was verified against each package's published LICENSE text (as of 2026-07, 51 direct third-party dependencies, **no GPL / LGPL / AGPL**); upstream prevails in case of discrepancy.

## 直接依赖 / Direct dependencies

**Flutter SDK / flutter_localizations** — BSD-3-Clause

**MIT（20）**
archive · country_flags · csv · dio · drift · excel · file_picker · fl_chart · flutter_image_compress · flutter_list_view · flutter_riverpod · flutter_svg · gbk_codec · in_app_review · permission_handler · reorderable_grid_view · sqlite3_flutter_libs · supabase_flutter · uuid · yaml

**BSD-3-Clause（26）**
collection · connectivity_plus · crypto · flutter_local_notifications · gal · home_widget · http · image_cropper · in_app_purchase · in_app_purchase_storekit · intl · jovial_svg · local_auth · open_filex · package_info_plus · path · path_provider · qr_flutter · quick_actions · record · share_plus · shared_preferences · url_launcher · visibility_detector · webview_flutter · webview_flutter_wkwebview

**Apache-2.0（4）**
app_links · decimal · image_picker · table_calendar

**BSD-2-Clause（1）**
timezone

---

如发现本清单与上游实际协议不符，欢迎提 Issue 指正。
