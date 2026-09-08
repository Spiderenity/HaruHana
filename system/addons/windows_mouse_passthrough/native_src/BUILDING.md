# Building the Windows extension

This source preserves the original `MousePassthrough.set_passthrough()` API and
adds native character-window file-drop and non-activating topmost recovery.

Clone `https://github.com/godotengine/godot-cpp` at revision
`58d1de720b8ffe9f8ffcdfe3a85148582cfd2e74` into a `godot-cpp` folder beside this
file, then configure with CMake and build either `template_debug` or
`template_release`. The resulting DLL is written to the addon's `bin` folder.

The checked-in DLLs were built from the Godot 4.6-stable binding revision used
by the upstream `hubacekjakub/Godot-WinMousePassthrough` project.

The workspace `scripts/native-lock.json` records the dependency revision and
the native source/binary hashes. A release verifies these hashes; after native
changes rebuild both DLLs and update the lock. The updater is built separately
from `system/services/update/native/HaruHanaUpdater.cs` by `scripts/release.ps1`
using the Windows .NET Framework C# compiler.
