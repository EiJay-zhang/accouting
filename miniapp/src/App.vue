<script setup lang="ts">
import { onLaunch } from '@dcloudio/uni-app'

import { restoreSession } from '@/stores/session'

onLaunch(() => {
  restoreSession()
})
</script>

<style lang="scss">
@import './styles/theme.scss';

page {
  background-color: var(--color-bg);
  color: var(--color-text);
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Helvetica Neue',
    sans-serif;
  font-size: 28rpx;
}

view,
text,
button,
input,
textarea {
  box-sizing: border-box;
}
</style>
