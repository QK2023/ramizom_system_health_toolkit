#include "nvme_health.h"

#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <limits>
#include <string>
#include <vector>

#include <ntddstor.h>
#include <nvme.h>

namespace {

uint64_t ReadUint64LittleEndian(const UCHAR value[16]) {
  uint64_t result = 0;
  for (int i = 7; i >= 0; --i) {
    result = (result << 8) | value[i];
  }
  return result;
}

int64_t NvmeDataUnitsToBytes(const UCHAR value[16]) {
  // NVMe SMART 的一个 Data Unit 表示 1000 * 512 字节。
  constexpr uint64_t kBytesPerDataUnit = 512000;
  const uint64_t units = ReadUint64LittleEndian(value);
  if (units >
      static_cast<uint64_t>(std::numeric_limits<int64_t>::max()) /
          kBytesPerDataUnit) {
    return std::numeric_limits<int64_t>::max();
  }
  return static_cast<int64_t>(units * kBytesPerDataUnit);
}

int64_t NvmeCounter(const UCHAR value[16]) {
  return static_cast<int64_t>(std::min<uint64_t>(
      ReadUint64LittleEndian(value),
      static_cast<uint64_t>(std::numeric_limits<int64_t>::max())));
}

}  // namespace

flutter::EncodableMap QueryNvmeHealth(int device_id) {
  const std::wstring path =
      L"\\\\.\\PhysicalDrive" + std::to_wstring(device_id);
  HANDLE drive = CreateFileW(path.c_str(), 0,
                             FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                             OPEN_EXISTING, 0, nullptr);
  if (drive == INVALID_HANDLE_VALUE) {
    return {};
  }

  const size_t query_size =
      FIELD_OFFSET(STORAGE_PROPERTY_QUERY, AdditionalParameters) +
      sizeof(STORAGE_PROTOCOL_SPECIFIC_DATA) + sizeof(NVME_HEALTH_INFO_LOG);
  std::vector<uint8_t> buffer(query_size, 0);

  auto* query = reinterpret_cast<PSTORAGE_PROPERTY_QUERY>(buffer.data());
  query->PropertyId = StorageDeviceProtocolSpecificProperty;
  query->QueryType = PropertyStandardQuery;

  auto* protocol = reinterpret_cast<PSTORAGE_PROTOCOL_SPECIFIC_DATA>(
      query->AdditionalParameters);
  protocol->ProtocolType = ProtocolTypeNvme;
  protocol->DataType = NVMeDataTypeLogPage;
  protocol->ProtocolDataRequestValue = NVME_LOG_PAGE_HEALTH_INFO;
  protocol->ProtocolDataRequestSubValue = 0;
  protocol->ProtocolDataOffset = sizeof(STORAGE_PROTOCOL_SPECIFIC_DATA);
  protocol->ProtocolDataLength = sizeof(NVME_HEALTH_INFO_LOG);

  DWORD returned = 0;
  const BOOL succeeded =
      DeviceIoControl(drive, IOCTL_STORAGE_QUERY_PROPERTY, buffer.data(),
                      static_cast<DWORD>(buffer.size()), buffer.data(),
                      static_cast<DWORD>(buffer.size()), &returned, nullptr);
  CloseHandle(drive);

  if (!succeeded ||
      returned < sizeof(STORAGE_PROTOCOL_DATA_DESCRIPTOR)) {
    return {};
  }

  auto* descriptor =
      reinterpret_cast<PSTORAGE_PROTOCOL_DATA_DESCRIPTOR>(buffer.data());
  auto* result_protocol = &descriptor->ProtocolSpecificData;
  if (result_protocol->ProtocolDataLength < sizeof(NVME_HEALTH_INFO_LOG) ||
      result_protocol->ProtocolDataOffset +
              sizeof(NVME_HEALTH_INFO_LOG) >
          buffer.size()) {
    return {};
  }

  auto* health = reinterpret_cast<PNVME_HEALTH_INFO_LOG>(
      reinterpret_cast<uint8_t*>(result_protocol) +
      result_protocol->ProtocolDataOffset);

  const int used = std::min<int>(health->PercentageUsed, 100);
  return {
      {flutter::EncodableValue("healthPercent"),
       flutter::EncodableValue(100 - used)},
      {flutter::EncodableValue("lifetimeBytesRead"),
       flutter::EncodableValue(NvmeDataUnitsToBytes(health->DataUnitRead))},
      {flutter::EncodableValue("lifetimeBytesWritten"),
       flutter::EncodableValue(NvmeDataUnitsToBytes(health->DataUnitWritten))},
      {flutter::EncodableValue("powerCycles"),
       flutter::EncodableValue(NvmeCounter(health->PowerCycle))},
      {flutter::EncodableValue("unsafeShutdowns"),
       flutter::EncodableValue(NvmeCounter(health->UnsafeShutdowns))},
      {flutter::EncodableValue("mediaErrors"),
       flutter::EncodableValue(NvmeCounter(health->MediaErrors))},
  };
}
