#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "nvme_health.h"

namespace {

std::wstring Utf16FromUtf8(const std::string& value) {
  if (value.empty()) return {};
  const int length = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                         static_cast<int>(value.size()),
                                         nullptr, 0);
  if (length <= 0) return {};
  std::wstring result(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), result.data(), length);
  return result;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  storage_health_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "system_health_toolkit/storage_health",
          &flutter::StandardMethodCodec::GetInstance());
  storage_health_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != "queryNvmeHealth" || !call.arguments()) {
          result->NotImplemented();
          return;
        }
        int device_id = -1;
        if (const auto* int32_value =
                std::get_if<int32_t>(call.arguments())) {
          device_id = *int32_value;
        } else if (const auto* int64_value =
                       std::get_if<int64_t>(call.arguments())) {
          device_id = static_cast<int>(*int64_value);
        }
        if (device_id < 0 || device_id > 255) {
          result->Error("invalid_device", "Invalid physical drive index");
          return;
        }
        result->Success(
            flutter::EncodableValue(QueryNvmeHealth(device_id)));
      });
  app_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "system_health_toolkit/app",
          &flutter::StandardMethodCodec::GetInstance());
  app_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "setWindowTitle" || !call.arguments()) {
          result->NotImplemented();
          return;
        }
        const auto* title = std::get_if<std::string>(call.arguments());
        if (!title) {
          result->Error("invalid_title", "Window title must be a string");
          return;
        }
        const std::wstring wide_title = Utf16FromUtf8(*title);
        SetWindowTextW(GetHandle(), wide_title.c_str());
        result->Success();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    app_channel_.reset();
    storage_health_channel_.reset();
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
