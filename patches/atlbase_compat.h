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

#endif // _ATLBASE_COMPAT_H_
