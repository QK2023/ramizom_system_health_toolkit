const securityEnglish = <String, String>{
  'toolRestartRequired':
      'Completed. Restart Windows to finish applying changes.',
  'toolFailedCode':
      'The tool did not complete successfully (exit code {code}). Administrator approval may have been cancelled. Review the Windows tool logs for details.',
  'privacyFailed': 'Some settings could not be changed. Try again or choose Restore.',
  'privacyReadFailed': 'We could not check the setting. Refresh and try again.',
  'privacyCaptureFailed': 'Windows capture is limited, but not every app could be checked.',
  'microphoneProtectionDesc':
      'When on, apps cannot use the microphone.',
  'cameraProtectionDesc':
      'When on, apps cannot use the camera.',
  'screenProtectionDesc':
      'Limits Windows screenshots and screen recording.',
  'privacyConfirm':
      'This turns off related devices. Calls, recordings, or face sign-in may stop working for a while. Administrator approval is needed. Continue?',
  'privacyRefresh': 'Refresh',
  'privacyRestore': 'Restore',
  'runTool': 'Run',
  'repairSystemFiles': 'Repair system files (SFC)',
  'repairSystemFilesDesc':
      'Check and fix Windows files. This can take a few minutes.',
  'repairWindowsImage': 'Repair Windows image (DISM)',
  'repairWindowsImageDesc':
      'Fix Windows repair files. This can take a while and may use Windows Update.',
  'scanSystemDisk': 'Scan system disk online',
  'scanSystemDiskDesc':
      'Check the Windows drive for errors. Your PC will not restart.',
  'flushDns': 'Flush DNS cache',
  'flushDnsDesc':
      'Clear saved website addresses. It can help when a site will not open.',
  'cleanComponentStore': 'Clean Windows component store',
  'cleanComponentStoreDesc':
      'Remove old Windows update files. Your personal files stay safe.',
};

const securityChinese = <String, String>{
  'toolRestartRequired': '已完成，请重启 Windows 使更改完全生效。',
  'toolFailedCode': '工具未成功完成（退出码 {code}），也可能是取消了管理员授权。请查看 Windows 工具日志了解详情。',
  'privacyFailed': '有些设置没有完成。请重试，或点“恢复”。',
  'privacyReadFailed': '暂时看不出设置是否成功。请刷新后再试。',
  'privacyCaptureFailed': '已限制截图和录屏，但无法确认每个软件是否都有效。',
  'microphoneProtectionDesc': '打开后，软件不能使用麦克风。',
  'cameraProtectionDesc': '打开后，软件不能使用摄像头。',
  'screenProtectionDesc': '限制 Windows 截图和录屏。',
  'privacyConfirm':
      '这会关闭相关设备，通话、录音或人脸登录可能暂时不能用。需要管理员同意。要继续吗？',
  'privacyRefresh': '刷新',
  'privacyRestore': '恢复',
  'runTool': '运行',
  'repairSystemFiles': '修复系统文件（SFC）',
  'repairSystemFilesDesc':
      '检查并修复 Windows 文件，可能要等几分钟。',
  'repairWindowsImage': '修复 Windows 映像（DISM）',
  'repairWindowsImageDesc':
      '修复 Windows 修复文件，可能要等一会儿，也可能使用 Windows 更新。',
  'scanSystemDisk': '在线扫描系统盘',
  'scanSystemDiskDesc':
      '检查系统盘有没有错误，不会让电脑重启。',
  'flushDns': '刷新 DNS 缓存',
  'flushDnsDesc': '清除保存过的网址信息，网站打不开时可以试试。',
  'cleanComponentStore': '清理 Windows 组件存储',
  'cleanComponentStoreDesc':
      '清理旧的 Windows 更新文件，不会删除你的个人文件。',
};
