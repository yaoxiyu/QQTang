#ifndef QQT_NATIVE_ASSERT_H
#define QQT_NATIVE_ASSERT_H

#include <godot_cpp/variant/utility_functions.hpp>

namespace qqt_native {

inline void warn_contract_violation(const char *message) {
    godot::UtilityFunctions::push_warning(message);
}

} // namespace qqt_native

#endif
