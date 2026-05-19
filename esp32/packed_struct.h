/* Portable packed-struct support for the esp-serial-flasher sources.
 *
 * GCC/Clang use __attribute__((packed)); MSVC has no such attribute and
 * instead uses #pragma pack. To keep the wire-protocol struct layouts
 * byte-identical across all three compilers without touching every
 * struct definition, this header provides:
 *
 *   PACKED                  - put after `struct`/`enum`; expands to the
 *                             GCC/Clang attribute, empty on MSVC.
 *   PACKED_STRUCT_BEGIN/END  - wrap a region of packed struct definitions;
 *                             expands to #pragma pack(push,1)/pop on MSVC,
 *                             empty on GCC/Clang.
 *
 * Note: the packed enums in these headers are never embedded as enum-typed
 * members of a packed struct (members always use fixed-width uintN_t), so
 * the enum's own storage size does not affect wire layout.
 */

#pragma once

#if defined(_MSC_VER)
  #define PACKED
  #define PACKED_STRUCT_BEGIN __pragma(pack(push, 1))
  #define PACKED_STRUCT_END   __pragma(pack(pop))
#else
  #define PACKED __attribute__((packed))
  #define PACKED_STRUCT_BEGIN
  #define PACKED_STRUCT_END
#endif
