# TopOn Android 配置

Android 广告已使用 TopOn SDK。`TOPON_APP_ID`、`TOPON_APP_KEY` 与已启用的横幅、激励视频广告位均有项目默认值，并会由 `setup.dart` 写入 `env.json`；同名环境变量可覆盖默认值。

发布前可在 `env.json` 中覆盖以下广告位 ID：

```json
{
  "SHOW_TOPON_ADS": true,
  "TOPON_BANNER_PLACEMENT_ID": "TopOn 横幅 placementId",
  "TOPON_REWARDED_PLACEMENT_ID": "TopOn 激励视频 placementId"
}
```

`TOPON_SDK_DEBUG_KEY` 会在调试构建传给 TopOn `setDebuggerConfig`；应用调试构建同时会开启 SDK 网络日志。

激励广告在请求前创建后端会话，将后端用户 ID 作为 TopOn `USER_ID`、会话 ID 作为 `USER_CUSTOM_DATA` 上传。后端的服务端奖励回调必须在 TopOn 控制台配置完成后再启用，且需按控制台显示的签名字段与密钥验证，不能沿用 Google SSV 公钥验签。

## 激励回调配置

在 TopOn 创建激励规则时，将后端奖励回调 URL 配置为：

```text
https://<backend-host>/api/traffic/ad-reward/ssv?user_id={user_id}&trans_id={trans_id}&reward_amount={reward_amount}&reward_name={reward_name}&placement_id={placement_id}&extra_data={extra_data}&network_firm_id={network_firm_id}&adsource_id={adsource_id}&scenario_id={scenario_id}&sign={sign}&ilrd={ilrd}
```

TopOn 会先增加 `is_test=1` 请求该地址验证连通性。将广告位关联到已启用的激励规则后，再把对应的激励视频 placementId 写入 `TOPON_REWARDED_PLACEMENT_ID`。

部署后端时，需要启用奖励广告并配置与控制台规则一致的值：`REWARDED_AD_ENABLED=true`、`TOPON_REWARDED_PLACEMENT_ID`、`TOPON_REWARD_NAME`、`REWARDED_AD_REWARD_AMOUNT` 和 `TOPON_REWARD_SEC_KEY`。其中回调密钥仅应存放在部署环境变量中，不能提交到仓库。后端按 TopOn 的 MD5 规则验签，使用 `trans_id` 与既有奖励会话保证幂等，并在签名失败时返回 601、其他处理失败时返回 602。

`setup.dart` 会将已有的 `SHOW_GOOGLE_ADS=true` 迁移为 `SHOW_TOPON_ADS=true`，也可以在 `env.json` 中显式控制。
