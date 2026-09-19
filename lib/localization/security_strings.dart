const securityEnglish = <String, String>{
  'toolRestartRequired':
      'Completed. Restart Windows to finish applying changes.',
  'toolFailedCode':
      'The tool did not complete successfully (exit code {code}). Administrator approval may have been cancelled. Review the Windows tool logs for details.',
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
  'runTool': '运行',
  'repairSystemFiles': '修复系统文件（SFC）',
  'repairSystemFilesDesc': '检查并修复 Windows 文件，可能要等几分钟。',
  'repairWindowsImage': '修复 Windows 映像（DISM）',
  'repairWindowsImageDesc': '修复 Windows 修复文件，可能要等一会儿，也可能使用 Windows 更新。',
  'scanSystemDisk': '在线扫描系统盘',
  'scanSystemDiskDesc': '检查系统盘有没有错误，不会让电脑重启。',
  'flushDns': '刷新 DNS 缓存',
  'flushDnsDesc': '清除保存过的网址信息，网站打不开时可以试试。',
  'cleanComponentStore': '清理 Windows 组件存储',
  'cleanComponentStoreDesc': '清理旧的 Windows 更新文件，不会删除你的个人文件。',
};
