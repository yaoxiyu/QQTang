#ifndef QQT_NATIVE_TYPES_H
#define QQT_NATIVE_TYPES_H

#include <cstdint>

namespace qqt_native {

constexpr const char *KERNEL_VERSION = "kernel_v1";

struct IVec2 {
    int32_t x = 0;
    int32_t y = 0;
};

} // namespace qqt_native

#endif
