#ifndef RUNNER_NVME_HEALTH_H_
#define RUNNER_NVME_HEALTH_H_

#include <flutter/encodable_value.h>

// 通过 Windows Storage Protocol API 读取指定物理磁盘的 NVMe SMART/Health
// Information Log。不支持 NVMe 或驱动拒绝查询时返回空 Map。
flutter::EncodableMap QueryNvmeHealth(int device_id);

#endif  // RUNNER_NVME_HEALTH_H_
