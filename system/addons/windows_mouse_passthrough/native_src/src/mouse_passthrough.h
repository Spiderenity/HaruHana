#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <unordered_map>
#include <vector>
#endif

using namespace godot;

class MousePassthrough : public Object {
    GDCLASS(MousePassthrough, Object)

    static MousePassthrough *singleton;

#ifdef _WIN32
    struct DropTarget {
        int64_t window_id = -1;
        HWND hwnd = nullptr;
        WNDPROC original_proc = nullptr;
        bool passthrough_enabled = true;
        bool temporarily_interactive = false;
    };

    struct DropEvent {
        int64_t window_id = -1;
        PackedStringArray files;
    };

    std::unordered_map<HWND, DropTarget> drop_targets;
    std::unordered_map<int64_t, HWND> hidden_windows;
    std::vector<DropEvent> pending_drop_events;

    static LRESULT CALLBACK drop_window_proc(
        HWND hwnd,
        UINT message,
        WPARAM wparam,
        LPARAM lparam
    );
    HWND get_window_handle(int64_t window_id) const;
    void apply_passthrough(DropTarget &target, bool enabled);
    void update_drop_hover();
    void unregister_target(HWND hwnd, bool restore_window_proc);
#endif

public:
    static MousePassthrough *get_singleton();

    MousePassthrough();
    ~MousePassthrough();

    void set_passthrough(int64_t window_id, bool enabled);
	bool raise_window_topmost(int64_t window_id);
	bool is_alt_pressed() const;
	bool set_window_visible(int64_t window_id, bool visible);
    bool set_taskbar_tasks(
        int64_t window_id,
        const String &executable_path,
        const Array &tasks
    );
    void set_file_drop_target(int64_t window_id, bool enabled);
    Array poll_dropped_files();

protected:
    static void _bind_methods();
};
