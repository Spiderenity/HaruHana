#include "mouse_passthrough.h"

#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#ifdef _WIN32
#include <shellapi.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <propkey.h>
#include <propvarutil.h>
#endif

using namespace godot;

MousePassthrough *MousePassthrough::singleton = nullptr;

MousePassthrough *MousePassthrough::get_singleton() {
    return singleton;
}

MousePassthrough::MousePassthrough() {
    ERR_FAIL_COND(singleton != nullptr);
    singleton = this;
#ifdef _WIN32
    SetCurrentProcessExplicitAppUserModelID(L"HaruHana.Desktop");
#endif
}

MousePassthrough::~MousePassthrough() {
#ifdef _WIN32
    std::vector<HWND> windows;
    windows.reserve(drop_targets.size());
    for (const auto &entry : drop_targets) {
        windows.push_back(entry.first);
    }
    for (HWND hwnd : windows) {
        unregister_target(hwnd, true);
    }
#endif
    ERR_FAIL_COND(singleton != this);
    singleton = nullptr;
}

void MousePassthrough::_bind_methods() {
    ClassDB::bind_method(
        D_METHOD("set_passthrough", "window_id", "enabled"),
        &MousePassthrough::set_passthrough
    );
	ClassDB::bind_method(
		D_METHOD("raise_window_topmost", "window_id"),
		&MousePassthrough::raise_window_topmost
	);
	ClassDB::bind_method(
		D_METHOD("is_alt_pressed"),
		&MousePassthrough::is_alt_pressed
	);
    ClassDB::bind_method(
        D_METHOD("set_window_visible", "window_id", "visible"),
        &MousePassthrough::set_window_visible
    );
    ClassDB::bind_method(
        D_METHOD("set_taskbar_tasks", "window_id", "executable_path", "tasks"),
        &MousePassthrough::set_taskbar_tasks
    );
    ClassDB::bind_method(
        D_METHOD("set_file_drop_target", "window_id", "enabled"),
        &MousePassthrough::set_file_drop_target
    );
    ClassDB::bind_method(
        D_METHOD("poll_dropped_files"),
        &MousePassthrough::poll_dropped_files
    );
}

#ifdef _WIN32
HWND MousePassthrough::get_window_handle(int64_t window_id) const {
    int64_t hwnd_int = DisplayServer::get_singleton()->window_get_native_handle(
        DisplayServer::WINDOW_HANDLE,
        static_cast<int>(window_id)
    );
    return reinterpret_cast<HWND>(static_cast<intptr_t>(hwnd_int));
}

void MousePassthrough::apply_passthrough(
    DropTarget &target,
    bool enabled
) {
    if (!target.hwnd || !IsWindow(target.hwnd)) {
        return;
    }

    LONG_PTR extended_style = GetWindowLongPtr(target.hwnd, GWL_EXSTYLE);
    if (enabled) {
        extended_style |= WS_EX_LAYERED | WS_EX_TRANSPARENT;
    } else {
        extended_style &= ~WS_EX_TRANSPARENT;
    }

    SetWindowLongPtr(target.hwnd, GWL_EXSTYLE, extended_style);
}

void MousePassthrough::unregister_target(
    HWND hwnd,
    bool restore_window_proc
) {
    auto found = drop_targets.find(hwnd);
    if (found == drop_targets.end()) {
        return;
    }

    DropTarget target = found->second;
    drop_targets.erase(found);

    if (!hwnd || !IsWindow(hwnd)) {
        return;
    }

    DragAcceptFiles(hwnd, FALSE);
    if (target.temporarily_interactive && target.passthrough_enabled) {
        apply_passthrough(target, true);
    }
    if (restore_window_proc && target.original_proc) {
        SetWindowLongPtr(
            hwnd,
            GWLP_WNDPROC,
            reinterpret_cast<LONG_PTR>(target.original_proc)
        );
    }
}

void MousePassthrough::update_drop_hover() {
    const bool drag_button_down =
        (GetAsyncKeyState(VK_LBUTTON) & 0x8000) != 0 ||
        (GetAsyncKeyState(VK_RBUTTON) & 0x8000) != 0;

    POINT cursor{};
    const bool has_cursor = GetCursorPos(&cursor) != FALSE;

    for (auto &entry : drop_targets) {
        DropTarget &target = entry.second;
        bool cursor_inside = false;

        if (has_cursor && target.hwnd && IsWindowVisible(target.hwnd)) {
            RECT rect{};
            if (GetWindowRect(target.hwnd, &rect)) {
                cursor_inside = PtInRect(&rect, cursor) != FALSE;
            }
        }

        const bool should_accept_drag = drag_button_down && cursor_inside;
        if (
            should_accept_drag &&
            target.passthrough_enabled &&
            !target.temporarily_interactive
        ) {
            apply_passthrough(target, false);
            target.temporarily_interactive = true;
        } else if (
            !should_accept_drag &&
            target.temporarily_interactive
        ) {
            if (target.passthrough_enabled) {
                apply_passthrough(target, true);
            }
            target.temporarily_interactive = false;
        }
    }
}

LRESULT CALLBACK MousePassthrough::drop_window_proc(
    HWND hwnd,
    UINT message,
    WPARAM wparam,
    LPARAM lparam
) {
    MousePassthrough *instance = MousePassthrough::get_singleton();
    if (!instance) {
        return DefWindowProc(hwnd, message, wparam, lparam);
    }

    auto found = instance->drop_targets.find(hwnd);
    if (found == instance->drop_targets.end()) {
        return DefWindowProc(hwnd, message, wparam, lparam);
    }

    WNDPROC original_proc = found->second.original_proc;

    if (message == WM_DROPFILES) {
        HDROP drop = reinterpret_cast<HDROP>(wparam);
        UINT file_count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
        DropEvent event;
        event.window_id = found->second.window_id;

        for (UINT index = 0; index < file_count; ++index) {
            UINT length = DragQueryFileW(drop, index, nullptr, 0);
            std::vector<wchar_t> buffer(length + 1, L'\0');
            if (DragQueryFileW(drop, index, buffer.data(), length + 1) > 0) {
                event.files.append(String::utf16(
                    reinterpret_cast<const char16_t *>(buffer.data())
                ));
            }
        }

        DragFinish(drop);
        if (!event.files.is_empty()) {
            instance->pending_drop_events.push_back(event);
        }

        DropTarget &target = found->second;
        if (target.passthrough_enabled) {
            instance->apply_passthrough(target, true);
        }
        target.temporarily_interactive = false;
        return 0;
    }

    if (message == WM_NCDESTROY) {
        instance->unregister_target(hwnd, false);
        return original_proc
            ? CallWindowProc(original_proc, hwnd, message, wparam, lparam)
            : DefWindowProc(hwnd, message, wparam, lparam);
    }

    return original_proc
        ? CallWindowProc(original_proc, hwnd, message, wparam, lparam)
        : DefWindowProc(hwnd, message, wparam, lparam);
}
#endif

void MousePassthrough::set_passthrough(
    int64_t window_id,
    bool enabled
) {
#ifdef _WIN32
    HWND hwnd = get_window_handle(window_id);
    if (!hwnd) {
        return;
    }

    auto found = drop_targets.find(hwnd);
    if (found != drop_targets.end()) {
        found->second.passthrough_enabled = enabled;
        if (!found->second.temporarily_interactive) {
            apply_passthrough(found->second, enabled);
        }
        return;
    }

    DropTarget temporary;
    temporary.hwnd = hwnd;
    apply_passthrough(temporary, enabled);
#endif
}

bool MousePassthrough::raise_window_topmost(int64_t window_id) {
#ifdef _WIN32
    HWND hwnd = nullptr;
    auto hidden = hidden_windows.find(window_id);
    if (hidden != hidden_windows.end() && IsWindow(hidden->second)) {
        hwnd = hidden->second;
    } else {
        hidden_windows.erase(window_id);
        hwnd = get_window_handle(window_id);
    }
    if (!hwnd || !IsWindow(hwnd)) {
        return false;
    }

    return SetWindowPos(
        hwnd,
        HWND_TOPMOST,
        0,
        0,
        0,
        0,
        SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW
    ) != FALSE;
#else
    return false;
#endif
}

bool MousePassthrough::is_alt_pressed() const {
#ifdef _WIN32
	return (GetAsyncKeyState(VK_MENU) & 0x8000) != 0;
#else
	return false;
#endif
}

bool MousePassthrough::set_window_visible(int64_t window_id, bool visible) {
#ifdef _WIN32
    HWND hwnd = nullptr;
    auto hidden = hidden_windows.find(window_id);
    if (hidden != hidden_windows.end() && IsWindow(hidden->second)) {
        hwnd = hidden->second;
    } else {
        hidden_windows.erase(window_id);
        hwnd = get_window_handle(window_id);
    }
    if (!hwnd || !IsWindow(hwnd)) {
        return false;
    }

    if (!visible) {
        hidden_windows[window_id] = hwnd;
    }
    ShowWindow(hwnd, visible ? SW_SHOWNOACTIVATE : SW_HIDE);
    if (visible) {
        SetWindowPos(
            hwnd,
            HWND_TOPMOST,
            0,
            0,
            0,
            0,
            SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE
        );
    }
    return true;
#else
    return false;
#endif
}

bool MousePassthrough::set_taskbar_tasks(
    int64_t window_id,
    const String &executable_path,
    const Array &tasks
) {
#ifdef _WIN32
    const Char16String executable_utf16 = executable_path.utf16();
    const wchar_t *executable = reinterpret_cast<const wchar_t *>(executable_utf16.get_data());
    const wchar_t *app_id = L"HaruHana.Desktop";
    SetCurrentProcessExplicitAppUserModelID(app_id);
    const HRESULT com_result = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
    const bool should_uninitialize = SUCCEEDED(com_result);
    if (FAILED(com_result) && com_result != RPC_E_CHANGED_MODE) {
        return false;
    }
    HWND taskbar_window = get_window_handle(window_id);
    if (taskbar_window != nullptr) {
        IPropertyStore *window_properties = nullptr;
        if (SUCCEEDED(SHGetPropertyStoreForWindow(taskbar_window, IID_PPV_ARGS(&window_properties))) && window_properties != nullptr) {
            PROPVARIANT app_id_value;
            PropVariantInit(&app_id_value);
            if (SUCCEEDED(InitPropVariantFromString(app_id, &app_id_value))) {
                window_properties->SetValue(PKEY_AppUserModel_ID, app_id_value);
                window_properties->Commit();
            }
            PropVariantClear(&app_id_value);
            window_properties->Release();
        }
    }
    PWSTR programs_path = nullptr;
    if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_Programs, KF_FLAG_CREATE, nullptr, &programs_path)) && programs_path != nullptr) {
        std::wstring shortcut_path(programs_path);
        shortcut_path += L"\\하루하나.lnk";
        CoTaskMemFree(programs_path);
        IShellLinkW *registration_link = nullptr;
        if (SUCCEEDED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&registration_link))) && registration_link != nullptr) {
            registration_link->SetPath(executable);
            registration_link->SetIconLocation(executable, 0);
            IPropertyStore *registration_properties = nullptr;
            if (SUCCEEDED(registration_link->QueryInterface(IID_PPV_ARGS(&registration_properties))) && registration_properties != nullptr) {
                PROPVARIANT registration_id;
                PropVariantInit(&registration_id);
                if (SUCCEEDED(InitPropVariantFromString(app_id, &registration_id))) {
                    registration_properties->SetValue(PKEY_AppUserModel_ID, registration_id);
                    registration_properties->Commit();
                }
                PropVariantClear(&registration_id);
                registration_properties->Release();
            }
            IPersistFile *persist_file = nullptr;
            if (SUCCEEDED(registration_link->QueryInterface(IID_PPV_ARGS(&persist_file))) && persist_file != nullptr) {
                persist_file->Save(shortcut_path.c_str(), TRUE);
                persist_file->Release();
            }
            registration_link->Release();
        }
    }
    ICustomDestinationList *destination = nullptr;
    HRESULT result = CoCreateInstance(CLSID_DestinationList, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&destination));
    if (FAILED(result) || destination == nullptr) {
        if (should_uninitialize) {
            CoUninitialize();
        }
        return false;
    }
    destination->SetAppID(app_id);
    UINT minimum_slots = 0;
    IObjectArray *removed_items = nullptr;
    result = destination->BeginList(&minimum_slots, IID_PPV_ARGS(&removed_items));
    if (removed_items != nullptr) {
        removed_items->Release();
    }
    IObjectCollection *collection = nullptr;
    if (SUCCEEDED(result)) {
        result = CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&collection));
    }
    if (SUCCEEDED(result) && collection != nullptr) {
        for (int index = 0; index < tasks.size(); ++index) {
            const Variant task_value = tasks[index];
            if (task_value.get_type() != Variant::DICTIONARY) {
                continue;
            }
            const Dictionary task = task_value;
            const String title = task.get("title", "");
            const String action = task.get("action", "");
            if (title.is_empty() || action.is_empty()) {
                continue;
            }
            IShellLinkW *link = nullptr;
            HRESULT task_result = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&link));
            if (FAILED(task_result) || link == nullptr) {
                continue;
            }
            const String arguments = "-- --taskbar-action=" + action;
            const Char16String arguments_utf16 = arguments.utf16();
            link->SetPath(executable);
            link->SetArguments(reinterpret_cast<const wchar_t *>(arguments_utf16.get_data()));
            IPropertyStore *properties = nullptr;
            task_result = link->QueryInterface(IID_PPV_ARGS(&properties));
            if (SUCCEEDED(task_result) && properties != nullptr) {
                const Char16String title_utf16 = title.utf16();
                PROPVARIANT title_value;
                PropVariantInit(&title_value);
                task_result = InitPropVariantFromString(reinterpret_cast<const wchar_t *>(title_utf16.get_data()), &title_value);
                if (SUCCEEDED(task_result)) {
                    task_result = properties->SetValue(PKEY_Title, title_value);
                    if (SUCCEEDED(task_result)) {
                        task_result = properties->Commit();
                    }
                }
                PropVariantClear(&title_value);
                properties->Release();
            }
            if (SUCCEEDED(task_result)) {
                collection->AddObject(link);
            }
            link->Release();
        }
        result = destination->AddUserTasks(collection);
        collection->Release();
    }
    if (SUCCEEDED(result)) {
        result = destination->CommitList();
    } else {
        destination->AbortList();
    }
    destination->Release();
    if (should_uninitialize) {
        CoUninitialize();
    }
    return SUCCEEDED(result);
#else
    return false;
#endif
}

void MousePassthrough::set_file_drop_target(
    int64_t window_id,
    bool enabled
) {
#ifdef _WIN32
    HWND hwnd = get_window_handle(window_id);
    if (!hwnd) {
        return;
    }

    if (!enabled) {
        unregister_target(hwnd, true);
        return;
    }

    if (drop_targets.find(hwnd) != drop_targets.end()) {
        return;
    }

    DropTarget target;
    target.window_id = window_id;
    target.hwnd = hwnd;
    target.passthrough_enabled =
        (GetWindowLongPtr(hwnd, GWL_EXSTYLE) & WS_EX_TRANSPARENT) != 0;
    target.original_proc = reinterpret_cast<WNDPROC>(SetWindowLongPtr(
        hwnd,
        GWLP_WNDPROC,
        reinterpret_cast<LONG_PTR>(&MousePassthrough::drop_window_proc)
    ));

    if (!target.original_proc) {
        return;
    }

    drop_targets.emplace(hwnd, target);
    DragAcceptFiles(hwnd, TRUE);
#endif
}

Array MousePassthrough::poll_dropped_files() {
    Array result;
#ifdef _WIN32
    update_drop_hover();

    for (const DropEvent &event : pending_drop_events) {
        Dictionary item;
        item["window_id"] = event.window_id;
        item["files"] = event.files;
        result.append(item);
    }
    pending_drop_events.clear();
#endif
    return result;
}
