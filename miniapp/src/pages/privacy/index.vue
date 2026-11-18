<script setup lang="ts">
const updatedAt = '2026-11-18'
</script>

<template>
  <view class="privacy-page">
    <text class="privacy-page__title">用户协议与隐私政策</text>
    <text class="privacy-page__date">更新日期：{{ updatedAt }}</text>

    <view class="section">
      <text class="section__title">一、我们收集的信息</text>
      <text class="section__text">
        为提供记账服务，我们会收集你的微信 openid（用于登录识别）、你主动录入的账单与物品信息、以及你主动上传的导入文件。
      </text>
    </view>

    <view class="section">
      <text class="section__title">二、信息的使用</text>
      <text class="section__text">
        上述信息仅用于账号登录、账本展示、统计报表与数据导入导出，不会用于广告推送或向无关第三方出售。
      </text>
    </view>

    <view class="section">
      <text class="section__title">三、信息的存储</text>
      <text class="section__text">
        数据存储在中华人民共和国境内的服务器。我们采取 HTTPS 传输和访问控制等措施保护数据安全。
      </text>
    </view>

    <view class="section">
      <text class="section__title">四、账号注销</text>
      <text class="section__text">
        你可以在「我的」页面注销账号。注销后，账号下的账单、物品、分类、标签等数据将被删除且无法恢复。
      </text>
    </view>

    <view class="section">
      <text class="section__title">五、你的权利</text>
      <text class="section__text">
        你可以随时查看、修改、导出或删除自己的数据。如需协助，可通过小程序内的反馈渠道联系我们。
      </text>
    </view>

    <text class="privacy-page__footer">
      继续使用本小程序即表示你已阅读并同意本协议。
    </text>
  </view>
</template>

<style lang="scss" scoped>
.privacy-page {
  padding: 40rpx 36rpx 80rpx;

  &__title {
    display: block;
    font-size: 40rpx;
    font-weight: 700;
    color: var(--color-text);
  }

  &__date {
    display: block;
    margin-top: 12rpx;
    font-size: 24rpx;
    color: var(--color-text-tertiary);
  }

  &__footer {
    display: block;
    margin-top: 48rpx;
    font-size: 24rpx;
    color: var(--color-text-tertiary);
  }
}

.section {
  padding: 32rpx;
  margin-top: 28rpx;
  background-color: var(--color-surface);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);

  &__title {
    display: block;
    font-size: 30rpx;
    font-weight: 600;
    color: var(--color-text);
  }

  &__text {
    display: block;
    margin-top: 16rpx;
    font-size: 26rpx;
    line-height: 1.7;
    color: var(--color-text-secondary);
  }
}
</style>
