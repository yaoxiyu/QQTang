#include "register_types.h"

#include <gdextension_interface.h>
#include <godot_cpp/godot.hpp>

#include "checksum/native_checksum_builder.h"
#include "codec/native_packed_state_codec.h"
#include "explosion/native_explosion_kernel.h"
#include "movement/native_movement_kernel.h"
#include "snapshot/native_snapshot_ring.h"

using namespace godot;

void initialize_qqt_native_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    ClassDB::register_class<QQTNativePackedStateCodec>();
    ClassDB::register_class<QQTNativeChecksumBuilder>();
    ClassDB::register_class<QQTNativeSnapshotRing>();
    ClassDB::register_class<QQTNativeMovementKernel>();
    ClassDB::register_class<QQTNativeExplosionKernel>();
}

void uninitialize_qqt_native_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {
GDExtensionBool GDE_EXPORT qqt_native_library_init(
    GDExtensionInterfaceGetProcAddress p_get_proc_address,
    const GDExtensionClassLibraryPtr p_library,
    GDExtensionInitialization *r_initialization
) {
    GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

    init_obj.register_initializer(initialize_qqt_native_module);
    init_obj.register_terminator(uninitialize_qqt_native_module);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
}
}
