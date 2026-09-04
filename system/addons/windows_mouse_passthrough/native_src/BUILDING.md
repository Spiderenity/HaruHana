# Building the Windows extension

This source preserves the original `MousePassthrough.set_passthrough()` API and
adds native character-window file-drop and non-activating topmost recovery.

Clone the Godot 4.6 `godot-cpp` source into a `godot-cpp` folder beside this
file, then configure with CMake and build either `template_debug` or
`template_release`. The resulting DLL is written to the addon's `bin` folder.

The checked-in DLLs were built from the Godot 4.6-stable binding revision used
by the upstream `hubacekjakub/Godot-WinMousePassthrough` project.
