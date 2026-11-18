export function showConfirm(
  title: string,
  content: string,
  confirmText = '确定',
): Promise<boolean> {
  return new Promise((resolve) => {
    uni.showModal({
      title,
      content,
      confirmText,
      cancelText: '取消',
      confirmColor: '#DC2626',
      success: (result) => resolve(result.confirm),
      fail: () => resolve(false),
    })
  })
}
