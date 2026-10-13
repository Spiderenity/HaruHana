HaruHana 0.1.11-beta

현재 편집 프로젝트: 이 폴더의 project.godot
소스, 캐릭터/말풍선/폰트 자산, 네이티브 DLL과 소스, 테스트를 함께 보관하세요.
.git 폴더에는 기존 개발 이력이 있습니다. 소스 ZIP에는 Git 이력은 포함하지 않습니다.

개발 환경: Godot 4.6.3, 같은 버전의 Windows x86_64 export template.
업데이터 빌드에는 Windows .NET Framework C# compiler가 필요합니다.

PowerShell에서:
  ./scripts/test.ps1 -Godot 'Godot 실행 파일의 전체 경로'
  ./scripts/release.ps1 -Godot 'Godot 실행 파일의 전체 경로' -WindowsTemplate 'windows_release_x86_64.exe의 전체 경로'

test.ps1은 이 폴더 바깥 work/validation 아래에 분리된 테스트 프로필을 만듭니다.
실제 개인 설정이나 API 키를 사용하지 않습니다. 테스트 중에는 에디터를 닫으세요.
patch_reports 테스트는 characters/patch_regression_fixture를 일시적으로 만들고
test.ps1이 종료 시 제거합니다. 해당 테스트를 단독 실행했다면 생성물을 제거하세요.
release.ps1은 바깥 releases/버전 폴더에 실행 파일, 배포 ZIP, 소스 ZIP, 체크섬을 만듭니다.
같은 버전의 결과물이 있으면 덮어쓰지 않고 중단합니다.

최근 수정/검증/남은 확인: docs/PATCH-0.1.11.txt
네이티브 재빌드: system/addons/windows_mouse_passthrough/native_src/BUILDING.md
이번 패치에서는 네이티브 DLL을 변경하지 않았습니다.
