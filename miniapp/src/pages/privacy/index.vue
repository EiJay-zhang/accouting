<script setup lang="ts">
const updatedAt = '2026-11-18'
</script>

<template>
  <view class="privacy-page">
    <text class="privacy-page__title">用户协议与隐私政策</text>
    <text class="privacy-page__date">更新日期：{{ updatedAt }}</text>

    <text class="privacy-page__part">用户协议</text>

    <view class="section">
      <text class="section__title">一、服务说明</text>
      <text class="section__text">
        本小程序为你提供个人记账、账单统计、物品管理和数据导入导出服务。你可以免费使用基础功能，服务内容可能随版本更新调整。
      </text>
    </view>

    <view class="section">
      <text class="section__title">二、账号与使用规范</text>
      <text class="section__text">
        请妥善保管账号和密码，因个人保管不当造成的损失由你自行承担。你应保证录入和导入的数据来源合法，不得利用本服务从事违法违规活动。
      </text>
    </view>

    <view class="section">
      <text class="section__title">三、数据与免责</text>
      <text class="section__text">
        账本数据由你自行录入，统计结果仅作个人参考，不构成任何财务或投资建议。因不可抗力、网络故障或第三方服务异常导致的服务中断，我们会尽力恢复但无法承担由此产生的间接损失。
      </text>
    </view>

    <text class="privacy-page__part">隐私政策</text>

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

  &__part {
    display: block;
    margin-top: 40rpx;
    font-size: 32rpx;
    font-weight: 700;
    color: var(--color-text);
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
