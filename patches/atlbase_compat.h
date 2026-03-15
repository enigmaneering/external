// Minimal ATL CComPtr compatibility for MinGW builds
// This provides just enough ATL functionality to compile DXC's MSFileSystemBasic.cpp

#ifndef _ATLBASE_COMPAT_H_
#define _ATLBASE_COMPAT_H_

#include <unknwn.h>
#include <cstdio>
#include <cstdarg>

// ATL macros that DXC expects
#ifndef ATL_NO_VTABLE
#define ATL_NO_VTABLE
#endif

#ifndef _ATL_DECLSPEC_ALLOCATOR
#define _ATL_DECLSPEC_ALLOCATOR
#endif

// MinGW doesn't have OutputDebugFormatA - provide a simple implementation
inline void OutputDebugFormatA(const char* format, ...) {
    char buffer[1024];
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);
    // In MinGW, we can use OutputDebugStringA or just write to stderr
    #ifdef OutputDebugStringA
    OutputDebugStringA(buffer);
    #else
    fprintf(stderr, "%s", buffer);
    #endif
}

// Minimal CComPtr implementation compatible with ATL usage in DXC
template <class T>
class CComPtr {
public:
    T* p;

    CComPtr() : p(nullptr) {}

    CComPtr(T* lp) : p(lp) {
        if (p) p->AddRef();
    }

    CComPtr(const CComPtr& lp) : p(lp.p) {
        if (p) p->AddRef();
    }

    ~CComPtr() {
        if (p) p->Release();
    }

    T* operator->() const {
        return p;
    }

    operator T*() const {
        return p;
    }

    T** operator&() {
        return &p;
    }

    CComPtr& operator=(T* lp) {
        if (p) p->Release();
        p = lp;
        if (p) p->AddRef();
        return *this;
    }

    CComPtr& operator=(const CComPtr& lp) {
        if (p) p->Release();
        p = lp.p;
        if (p) p->AddRef();
        return *this;
    }

    void Release() {
        if (p) {
            p->Release();
            p = nullptr;
        }
    }

    T* Detach() {
        T* pt = p;
        p = nullptr;
        return pt;
    }

    void Attach(T* p2) {
        if (p) p->Release();
        p = p2;
    }

    // ATL-style QueryInterface that takes a pointer to a CComPtr
    // Usage: storage.QueryInterface(&stream) where stream is CComPtr<IStream>
    template <class Q>
    HRESULT QueryInterface(Q** pp) {
        return p ? p->QueryInterface(__uuidof(Q), (void**)pp) : E_POINTER;
    }
};

// Undefine Windows macros that conflict with DXC's COFF.h enum definitions
// winnt.h defines these as macros, but DXC's COFF.h needs them as enum values
#ifdef IMAGE_FILE_MACHINE_UNKNOWN
// Machine types
#undef IMAGE_FILE_MACHINE_UNKNOWN
#undef IMAGE_FILE_MACHINE_AM33
#undef IMAGE_FILE_MACHINE_AMD64
#undef IMAGE_FILE_MACHINE_ARM
#undef IMAGE_FILE_MACHINE_ARMNT
#undef IMAGE_FILE_MACHINE_ARM64
#undef IMAGE_FILE_MACHINE_EBC
#undef IMAGE_FILE_MACHINE_I386
#undef IMAGE_FILE_MACHINE_IA64
#undef IMAGE_FILE_MACHINE_M32R
#undef IMAGE_FILE_MACHINE_MIPS16
#undef IMAGE_FILE_MACHINE_MIPSFPU
#undef IMAGE_FILE_MACHINE_MIPSFPU16
#undef IMAGE_FILE_MACHINE_POWERPC
#undef IMAGE_FILE_MACHINE_POWERPCFP
#undef IMAGE_FILE_MACHINE_R4000
#undef IMAGE_FILE_MACHINE_SH3
#undef IMAGE_FILE_MACHINE_SH3DSP
#undef IMAGE_FILE_MACHINE_SH4
#undef IMAGE_FILE_MACHINE_SH5
#undef IMAGE_FILE_MACHINE_THUMB
#undef IMAGE_FILE_MACHINE_WCEMIPSV2
// File characteristics
#undef IMAGE_FILE_RELOCS_STRIPPED
#undef IMAGE_FILE_EXECUTABLE_IMAGE
#undef IMAGE_FILE_LINE_NUMS_STRIPPED
#undef IMAGE_FILE_LOCAL_SYMS_STRIPPED
#undef IMAGE_FILE_LARGE_ADDRESS_AWARE
#undef IMAGE_FILE_BYTES_REVERSED_LO
#undef IMAGE_FILE_32BIT_MACHINE
#undef IMAGE_FILE_DEBUG_STRIPPED
#undef IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP
#undef IMAGE_FILE_NET_RUN_FROM_SWAP
#undef IMAGE_FILE_SYSTEM
#undef IMAGE_FILE_DLL
#undef IMAGE_FILE_UP_SYSTEM_ONLY
#undef IMAGE_FILE_BYTES_REVERSED_HI
// Symbol values
#undef IMAGE_SYM_DEBUG
#undef IMAGE_SYM_ABSOLUTE
#undef IMAGE_SYM_UNDEFINED
// Symbol types - all IMAGE_SYM_TYPE_* macros
#undef IMAGE_SYM_TYPE_NULL
#undef IMAGE_SYM_TYPE_VOID
#undef IMAGE_SYM_TYPE_CHAR
#undef IMAGE_SYM_TYPE_SHORT
#undef IMAGE_SYM_TYPE_INT
#undef IMAGE_SYM_TYPE_LONG
#undef IMAGE_SYM_TYPE_FLOAT
#undef IMAGE_SYM_TYPE_DOUBLE
#undef IMAGE_SYM_TYPE_STRUCT
#undef IMAGE_SYM_TYPE_UNION
#undef IMAGE_SYM_TYPE_ENUM
#undef IMAGE_SYM_TYPE_MOE
#undef IMAGE_SYM_TYPE_BYTE
#undef IMAGE_SYM_TYPE_WORD
#undef IMAGE_SYM_TYPE_UINT
#undef IMAGE_SYM_TYPE_DWORD
// Symbol derived types - all IMAGE_SYM_DTYPE_* macros
#undef IMAGE_SYM_DTYPE_NULL
#undef IMAGE_SYM_DTYPE_POINTER
#undef IMAGE_SYM_DTYPE_FUNCTION
#undef IMAGE_SYM_DTYPE_ARRAY
// Section characteristics - all IMAGE_SCN_* macros
#undef IMAGE_SCN_TYPE_NO_PAD
#undef IMAGE_SCN_CNT_CODE
#undef IMAGE_SCN_CNT_INITIALIZED_DATA
#undef IMAGE_SCN_CNT_UNINITIALIZED_DATA
#undef IMAGE_SCN_LNK_OTHER
#undef IMAGE_SCN_LNK_INFO
#undef IMAGE_SCN_LNK_REMOVE
#undef IMAGE_SCN_LNK_COMDAT
#undef IMAGE_SCN_GPREL
#undef IMAGE_SCN_MEM_PURGEABLE
#undef IMAGE_SCN_MEM_16BIT
#undef IMAGE_SCN_MEM_LOCKED
#undef IMAGE_SCN_MEM_PRELOAD
#undef IMAGE_SCN_ALIGN_1BYTES
#undef IMAGE_SCN_ALIGN_2BYTES
#undef IMAGE_SCN_ALIGN_4BYTES
#undef IMAGE_SCN_ALIGN_8BYTES
#undef IMAGE_SCN_ALIGN_16BYTES
#undef IMAGE_SCN_ALIGN_32BYTES
#undef IMAGE_SCN_ALIGN_64BYTES
#undef IMAGE_SCN_ALIGN_128BYTES
#undef IMAGE_SCN_ALIGN_256BYTES
#undef IMAGE_SCN_ALIGN_512BYTES
#undef IMAGE_SCN_ALIGN_1024BYTES
#undef IMAGE_SCN_ALIGN_2048BYTES
#undef IMAGE_SCN_ALIGN_4096BYTES
#undef IMAGE_SCN_ALIGN_8192BYTES
#undef IMAGE_SCN_LNK_NRELOC_OVFL
#undef IMAGE_SCN_MEM_DISCARDABLE
#undef IMAGE_SCN_MEM_NOT_CACHED
#undef IMAGE_SCN_MEM_NOT_PAGED
#undef IMAGE_SCN_MEM_SHARED
#undef IMAGE_SCN_MEM_EXECUTE
#undef IMAGE_SCN_MEM_READ
#undef IMAGE_SCN_MEM_WRITE
// Relocation types - IMAGE_REL_I386_* macros
#undef IMAGE_REL_I386_ABSOLUTE
#undef IMAGE_REL_I386_DIR16
#undef IMAGE_REL_I386_REL16
#undef IMAGE_REL_I386_DIR32
#undef IMAGE_REL_I386_DIR32NB
#undef IMAGE_REL_I386_SEG12
#undef IMAGE_REL_I386_SECTION
#undef IMAGE_REL_I386_SECREL
#undef IMAGE_REL_I386_TOKEN
#undef IMAGE_REL_I386_SECREL7
#undef IMAGE_REL_I386_REL32
// Relocation types - IMAGE_REL_AMD64_* macros
#undef IMAGE_REL_AMD64_ABSOLUTE
#undef IMAGE_REL_AMD64_ADDR64
#undef IMAGE_REL_AMD64_ADDR32
#undef IMAGE_REL_AMD64_ADDR32NB
#undef IMAGE_REL_AMD64_REL32
#undef IMAGE_REL_AMD64_REL32_1
#undef IMAGE_REL_AMD64_REL32_2
#undef IMAGE_REL_AMD64_REL32_3
#undef IMAGE_REL_AMD64_REL32_4
#undef IMAGE_REL_AMD64_REL32_5
#undef IMAGE_REL_AMD64_SECTION
#undef IMAGE_REL_AMD64_SECREL
#undef IMAGE_REL_AMD64_SECREL7
#undef IMAGE_REL_AMD64_TOKEN
#undef IMAGE_REL_AMD64_SREL32
#undef IMAGE_REL_AMD64_PAIR
#undef IMAGE_REL_AMD64_SSPAN32
// Relocation types - IMAGE_REL_ARM_* macros (for completeness)
#undef IMAGE_REL_ARM_ABSOLUTE
#undef IMAGE_REL_ARM_ADDR32
#undef IMAGE_REL_ARM_ADDR32NB
#undef IMAGE_REL_ARM_BRANCH24
#undef IMAGE_REL_ARM_BRANCH11
#undef IMAGE_REL_ARM_TOKEN
#undef IMAGE_REL_ARM_BLX24
#undef IMAGE_REL_ARM_BLX11
#undef IMAGE_REL_ARM_SECTION
#undef IMAGE_REL_ARM_SECREL
#undef IMAGE_REL_ARM_MOV32A
#undef IMAGE_REL_ARM_MOV32T
#undef IMAGE_REL_ARM_BRANCH20T
#undef IMAGE_REL_ARM_BRANCH24T
#undef IMAGE_REL_ARM_BLX23T
// Relocation types - IMAGE_REL_ARM64_* macros
#undef IMAGE_REL_ARM64_ABSOLUTE
#undef IMAGE_REL_ARM64_ADDR32
#undef IMAGE_REL_ARM64_ADDR32NB
#undef IMAGE_REL_ARM64_BRANCH26
#undef IMAGE_REL_ARM64_PAGEBASE_REL21
#undef IMAGE_REL_ARM64_REL21
#undef IMAGE_REL_ARM64_PAGEOFFSET_12A
#undef IMAGE_REL_ARM64_PAGEOFFSET_12L
#undef IMAGE_REL_ARM64_SECREL
#undef IMAGE_REL_ARM64_SECREL_LOW12A
#undef IMAGE_REL_ARM64_SECREL_HIGH12A
#undef IMAGE_REL_ARM64_SECREL_LOW12L
#undef IMAGE_REL_ARM64_TOKEN
#undef IMAGE_REL_ARM64_SECTION
#undef IMAGE_REL_ARM64_ADDR64
#undef IMAGE_REL_ARM64_BRANCH19
// COMDAT selection types
#undef IMAGE_COMDAT_SELECT_NODUPLICATES
#undef IMAGE_COMDAT_SELECT_ANY
#undef IMAGE_COMDAT_SELECT_SAME_SIZE
#undef IMAGE_COMDAT_SELECT_EXACT_MATCH
#undef IMAGE_COMDAT_SELECT_ASSOCIATIVE
#undef IMAGE_COMDAT_SELECT_LARGEST
#undef IMAGE_COMDAT_SELECT_NEWEST
// Weak external characteristics
#undef IMAGE_WEAK_EXTERN_SEARCH_NOLIBRARY
#undef IMAGE_WEAK_EXTERN_SEARCH_LIBRARY
#undef IMAGE_WEAK_EXTERN_SEARCH_ALIAS
// Subsystem types
#undef IMAGE_SUBSYSTEM_UNKNOWN
#undef IMAGE_SUBSYSTEM_NATIVE
#undef IMAGE_SUBSYSTEM_WINDOWS_GUI
#undef IMAGE_SUBSYSTEM_WINDOWS_CUI
#undef IMAGE_SUBSYSTEM_OS2_CUI
#undef IMAGE_SUBSYSTEM_POSIX_CUI
#undef IMAGE_SUBSYSTEM_NATIVE_WINDOWS
#undef IMAGE_SUBSYSTEM_WINDOWS_CE_GUI
#undef IMAGE_SUBSYSTEM_EFI_APPLICATION
#undef IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER
#undef IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER
#undef IMAGE_SUBSYSTEM_EFI_ROM
#undef IMAGE_SUBSYSTEM_XBOX
#undef IMAGE_SUBSYSTEM_WINDOWS_BOOT_APPLICATION
// Debug types
#undef IMAGE_DEBUG_TYPE_UNKNOWN
#undef IMAGE_DEBUG_TYPE_COFF
#undef IMAGE_DEBUG_TYPE_CODEVIEW
#undef IMAGE_DEBUG_TYPE_FPO
#undef IMAGE_DEBUG_TYPE_MISC
#undef IMAGE_DEBUG_TYPE_EXCEPTION
#undef IMAGE_DEBUG_TYPE_FIXUP
#undef IMAGE_DEBUG_TYPE_OMAP_TO_SRC
#undef IMAGE_DEBUG_TYPE_OMAP_FROM_SRC
#undef IMAGE_DEBUG_TYPE_BORLAND
#undef IMAGE_DEBUG_TYPE_RESERVED10
#undef IMAGE_DEBUG_TYPE_CLSID
// Base relocation types
#undef IMAGE_REL_BASED_ABSOLUTE
#undef IMAGE_REL_BASED_HIGH
#undef IMAGE_REL_BASED_LOW
#undef IMAGE_REL_BASED_HIGHLOW
#undef IMAGE_REL_BASED_HIGHADJ
#undef IMAGE_REL_BASED_MIPS_JMPADDR
#undef IMAGE_REL_BASED_ARM_MOV32
#undef IMAGE_REL_BASED_THUMB_MOV32
#undef IMAGE_REL_BASED_MIPS_JMPADDR16
#undef IMAGE_REL_BASED_DIR64
// Symbol storage class - all IMAGE_SYM_CLASS_* macros
#undef IMAGE_SYM_CLASS_END_OF_FUNCTION
#undef IMAGE_SYM_CLASS_NULL
#undef IMAGE_SYM_CLASS_AUTOMATIC
#undef IMAGE_SYM_CLASS_EXTERNAL
#undef IMAGE_SYM_CLASS_STATIC
#undef IMAGE_SYM_CLASS_REGISTER
#undef IMAGE_SYM_CLASS_EXTERNAL_DEF
#undef IMAGE_SYM_CLASS_LABEL
#undef IMAGE_SYM_CLASS_UNDEFINED_LABEL
#undef IMAGE_SYM_CLASS_MEMBER_OF_STRUCT
#undef IMAGE_SYM_CLASS_ARGUMENT
#undef IMAGE_SYM_CLASS_STRUCT_TAG
#undef IMAGE_SYM_CLASS_MEMBER_OF_UNION
#undef IMAGE_SYM_CLASS_UNION_TAG
#undef IMAGE_SYM_CLASS_TYPE_DEFINITION
#undef IMAGE_SYM_CLASS_UNDEFINED_STATIC
#undef IMAGE_SYM_CLASS_ENUM_TAG
#undef IMAGE_SYM_CLASS_MEMBER_OF_ENUM
#undef IMAGE_SYM_CLASS_REGISTER_PARAM
#undef IMAGE_SYM_CLASS_BIT_FIELD
#undef IMAGE_SYM_CLASS_BLOCK
#undef IMAGE_SYM_CLASS_FUNCTION
#undef IMAGE_SYM_CLASS_END_OF_STRUCT
#undef IMAGE_SYM_CLASS_FILE
#undef IMAGE_SYM_CLASS_SECTION
#undef IMAGE_SYM_CLASS_WEAK_EXTERNAL
#undef IMAGE_SYM_CLASS_CLR_TOKEN
#endif

#endif // _ATLBASE_COMPAT_H_
