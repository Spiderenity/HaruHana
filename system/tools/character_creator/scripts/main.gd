extends Control

const CreatorThemeScript = preload("res://system/tools/character_creator/scripts/creator_theme.gd")
const PackModelScript = preload("res://system/tools/character_creator/scripts/pack_model.gd")
const CreatorAIScript = preload("res://system/tools/character_creator/scripts/creator_ai.gd")
const CreatorCatalogScript = preload("res://system/tools/character_creator/scripts/creator_catalog.gd")
const CreatorNamingScript = preload("res://system/tools/character_creator/scripts/creator_naming.gd")
const AppearanceSettingsScript = preload("res://system/app/appearance_settings.gd")
const DistributionPathsScript = preload("res://system/app/distribution_paths.gd")
const AppLanguageScript = preload("res://system/app/app_language.gd")
const ThemedColorPickerScript = preload("res://system/tools/shared/themed_color_picker.gd")
const RuntimeInstanceCoordinatorScript = preload("res://system/services/runtime/runtime_instance_coordinator.gd")
const DesktopCharacterManagerScript = preload("res://system/services/desktop/desktop_character_manager.gd")

const LANGUAGE_REFRESH_INTERVAL_SECONDS: float = 0.5
const TAB_SCROLLBAR_WIDTH: float = 6.0
const TAB_SCROLLBAR_CONTENT_GAP: int = 12

const UI_KO: Dictionary = {
	"Character Creator": "캐릭터 크리에이터",
	"Character Settings": "캐릭터 설정",
	"Edit character packs, profiles and AI context.": "캐릭터 팩, 프로필과 AI 문맥을 편집합니다.",
	"Pack": "팩",
	"One character": "1인",
	"Two characters": "2인",
	"Reset": "리셋",
	"Open": "열기",
	"Save": "저장",
	"Review the checklist before saving to res://characters.": "res://characters에 저장하기 전에 체크리스트를 확인합니다.",
	"Start editing": "편집 시작",
	"Choose how to start this Character Creator session.": "캐릭터 크리에이터 작업을 어떻게 시작할지 선택하세요.",
	"Start from scratch": "처음부터 시작하기",
	"Start new": "새로 만들기",
	"Use preset": "프리셋 사용하기",
	"1-character preset": "1인 프리셋",
	"2-character preset": "2인 프리셋",
	"Open existing pack": "기존 팩 열기",
	"Character count": "캐릭터 인원",
	"Character": "캐릭터",
	"Pack information stored in manifest.json.": "manifest.json에 저장되는 팩 정보입니다.",
	"Pack ID": "팩 ID",
	"Lowercase letters / numbers / _": "영문 소문자 / 숫자 / _",
	"Display name": "표시 이름",
	"Name shown to users": "사용자에게 보이는 이름",
	"Description": "설명",
	"Pack description": "팩 설명",
	"Default language": "기본 언어",
	"Languages": "지원 언어",
	"Current interface language": "현재 인터페이스 언어",
	"Current language only": "현재 언어만",
	"Korean and English": "한국어와 영어",
	"The default language follows the current interface language.": "기본 언어는 현재 인터페이스 언어를 따릅니다.",
	"Profile": "프로필",
	"Character personality and AI context from profile.json.": "profile.json의 캐릭터 성격과 AI 문맥입니다.",
	"Character ID": "캐릭터 ID",
	"Character name": "캐릭터 이름",
	"Chat color": "채팅 색상",
	"Role": "역할",
	"What this character is": "이 캐릭터가 무엇인지",
	"Setting note": "설정 메모",
	"World and default situation": "세계관과 기본 상황",
	"Appearance": "외형",
	"Appearance summary": "외형 요약",
	"Personality": "성격",
	"One item per line": "한 줄에 하나",
	"Voice": "말투",
	"Speech style and sentence habits": "말투와 문장 습관",
	"Voice · avoid": "피해야 할 말투",
	"Behavior": "행동 패턴",
	"Mundane details": "일상 디테일",
	"Everyday details · one per line": "일상적 디테일 · 한 줄에 하나",
	"Private internal": "내면 설정",
	"Inner thoughts not normally spoken · one per line": "겉으로 말하지 않는 내면 · 한 줄에 하나",
	"User role": "사용자 역할",
	"How this character sees the user": "캐릭터가 사용자를 어떻게 보는지",
	"User description": "사용자 설명",
	"Relationship with the user": "사용자와의 관계",
	"AI rules": "AI 규칙",
	"Lore": "설정 / 로어",
	"Desktop": "데스크톱",
	"Default on desktop": "데스크톱에 기본 표시",
	"Use the first desktop slot.": "첫 번째 데스크톱 슬롯에 배정합니다.",
	"Relationship": "관계",
	"Relationship with the other character": "다른 캐릭터와의 관계",
	"Default Lines": "대사",
	"Edit default and fallback dialogue.": "기본 대사와 fallback 대사를 편집합니다.",
	"View": "보기",
	"Character 1": "캐릭터 1",
	"Character 2": "캐릭터 2",
	"Conversation": "대화",
	"No conversations yet. Use Generate all on the Save tab.": "아직 대화가 없습니다. 저장 탭에서 일괄 생성해 주세요.",
	"No conversations yet. Use + Line or Generate all on the Save tab.": "아직 대화가 없습니다. + 대사를 누르거나 저장 탭에서 일괄 생성해 주세요.",
	"No lines yet. Use Generate all on the Save tab.": "아직 대사가 없습니다. 저장 탭에서 일괄 생성해 주세요.",
	"No lines yet. Use + Line or Generate all on the Save tab.": "아직 대사가 없습니다. + 대사를 누르거나 저장 탭에서 일괄 생성해 주세요.",
	"Group": "그룹",
	"+ Line": "+ 대사",
	"Play": "재생",
	"Characters are still loading.": "캐릭터를 불러오는 중입니다.",
	"No desktop character is available for preview.": "시연할 데스크톱 캐릭터가 없습니다.",
	"Enter a line before playing it.": "재생할 대사를 먼저 입력해 주세요.",
	"Generate": "생성",
	"AI Settings": "AI 설정",
	"Generation uses the current Character Settings and remains editable afterward.": "현재 캐릭터 설정을 바탕으로 생성하며, 생성 후 직접 수정할 수 있습니다.",
	"Line": "대사",
	"Sprites": "스프라이트",
	"Upload 400×600 transparent PNGs and preview the composed result.": "400×600 투명 PNG를 업로드하고 실제 합성 결과를 확인합니다.",
	"Sprite mode": "스프라이트 모드",
	"Simple": "단순",
	"Default": "기본",
	"PNG only · exactly 400×600 · transparent background required": "PNG만 가능 · 정확히 400×600 · 투명 배경 필수",
	"Preview": "미리보기",
	"BODY": "BODY · 몸",
	"BLINK": "BLINK · 눈 깜빡임",
	"EMOTION": "EMOTION · 감정",
	"Uploaded": "업로드됨",
	"Fallback": "대체 사용",
	"Upload": "업로드",
	"Clear": "지우기",
	"Body": "몸",
	"Neutral": "중립",
	"Happy": "기쁨",
	"Amused": "즐거움",
	"Smug": "의기양양",
	"Curious": "호기심",
	"Surprised": "놀람",
	"Annoyed": "짜증",
	"Angry": "화남",
	"Worried": "걱정",
	"Sad": "슬픔",
	"Embarrassed": "부끄러움",
	"Tired": "피곤",
	"Flustered · Worried": "당황 · 걱정",
	"Flustered · Surprised": "당황 · 놀람",
	"Flustered · Annoyed": "당황 · 짜증",
	"Blink · Open": "눈 깜빡임 · 뜸",
	"Blink · Half": "눈 깜빡임 · 반쯤",
	"Blink · Closed": "눈 깜빡임 · 감음",
	"Default-line generator": "기본 대사 생성기",
	"Endpoint": "엔드포인트",
	"Model": "모델",
	"API Key": "API 키",
	"API Key is stored locally in this Creator's user:// settings.": "API 키는 이 Creator의 user:// 설정에 로컬 저장됩니다.",
	"Cancel": "취소",
	"Choose a character pack manifest.json from res://characters": "res://characters에서 캐릭터 팩 manifest.json 선택",
	"Choose a 400×600 transparent PNG": "400×600 투명 PNG 선택",
	"New pack": "새 팩",
	"First boot": "첫 부팅",
	"Idle": "대기",
	"Timer complete": "타이머 완료",
	"Timer pause": "타이머 일시정지",
	"Timer resume": "타이머 재개",
	"Timer stop": "타이머 중단",
	"Desktop leave": "데스크톱 떠남",
	"Desktop arrive": "데스크톱 도착",
	"Boot primary": "부팅 기본",
	"Arrival": "합류",
	"After peer arrival": "동료 합류 후",
	"Hourly · morning": "정시 · 아침",
	"Hourly · day": "정시 · 낮",
	"Hourly · evening": "정시 · 저녁",
	"Hourly · late night": "정시 · 심야",
	"Pet": "터치",
	"Poke · head": "찌르기 · head",
	"Fluster": "과부하 / 당황",
	"neutral": "중립",
	"happy": "기쁨",
	"amused": "즐거움",
	"smug": "의기양양",
	"curious": "호기심",
	"surprised": "놀람",
	"annoyed": "짜증",
	"angry": "화남",
	"worried": "걱정",
	"sad": "슬픔",
	"embarrassed": "부끄러움",
	"tired": "피곤",
	"flustered_worried": "당황 · 걱정",
	"flustered_surprised": "당황 · 놀람",
	"flustered_annoyed": "당황 · 짜증",
	"Edit pack identity and language metadata.": "팩의 이름, ID와 언어 정보를 편집합니다.",
	"Edit the selected character's public identity and runtime options.": "선택한 캐릭터의 기본 정보와 런타임 옵션을 편집합니다.",
	"Character personality and AI context stored in profile.json.": "profile.json에 저장되는 성격과 AI 문맥을 편집합니다.",
	"Edit mode": "편집 모드",
	"Advanced": "고급",
	"Simple mode uses AI": "간단 모드는 AI 사용",
	"Simple mode hides advanced profile fields. When saving, blank hidden fields are generated with the main program's AI settings. Existing text is never erased when modes change.": "간단 모드는 고급 프로필 항목을 숨깁니다. 저장할 때 비어 있는 숨김 항목은 메인 프로그램의 AI 설정으로 생성합니다. 모드를 바꿔도 기존 내용은 삭제되지 않습니다.",
	"Simple mode AI notice": "간단 모드 AI 안내",
	"In Simple mode, blank advanced profile fields are generated with the shared AI settings before saving.": "단순 모드에서는 저장 전에 비어 있는 고급 프로필 항목을 공용 AI 설정으로 생성합니다.",
	"Simple mode uses AI to fill blank advanced profile fields before saving. It uses the same AI key and model as the main program. You can switch to Advanced at any time and edit those fields yourself.": "간단 모드는 저장 전에 비어 있는 고급 프로필 항목을 AI로 채웁니다. 메인 프로그램과 같은 AI 키와 모델을 사용합니다. 언제든 고급 모드로 바꾸어 직접 편집할 수 있습니다.",
	"Required in Simple mode": "간단 모드 필수",
	"Fields marked * are required before AI can complete the hidden profile fields.": "* 표시 항목은 AI가 숨겨진 프로필 항목을 생성하기 전에 반드시 입력해야 합니다.",
	"Display name *": "표시 이름 *",
	"Birthday": "생일",
	"MM-DD · optional": "MM-DD · 선택 사항",
	"Role *": "역할 *",
	"Appearance *": "외형 *",
	"Personality *": "성격 *",
	"Voice *": "말투 *",
	"Chat color preset": "채팅 색상",
	"Blue": "블루",
	"Green": "그린",
	"Yellow": "옐로",
	"Pink": "핑크",
	"Orange": "오렌지",
	"Purple": "퍼플",
	"Custom": "사용자 지정",
	"Custom color": "사용자 지정 색상",
	"Existing": "기존 팩",
	"Save warning": "저장 전 확인",
	"Some sprites are missing or still use the Creator defaults.": "일부 스프라이트가 없거나 크리에이터 기본값을 그대로 사용 중입니다.",
	"Save with missing sprites routed to available fallbacks/neutral?": "없는 스프라이트를 사용 가능한 대체 경로 또는 중립으로 연결하여 저장할까요?",
	"Missing required fields": "필수 항목 누락",
	"Fill the following required fields first:": "다음 필수 항목을 먼저 입력하세요:",
	"Close": "닫기",
	"Generating hidden profile fields…": "숨겨진 프로필 항목 생성 중…",
	"Profile generation failed": "프로필 생성 실패",
	"AI could not generate the hidden profile fields for %s. You can leave them blank and continue saving, or cancel and edit them manually.": "%s의 숨겨진 프로필 항목을 AI로 생성하지 못했습니다. 비워 둔 채 계속 저장하거나 취소 후 직접 편집할 수 있습니다.",
	"Leave blank and continue": "비워 두고 계속",
	"AI settings are shared with the main program.": "AI 설정은 메인 프로그램과 공유됩니다.",
	"Custom OpenRouter model...": "OpenRouter 모델 직접 입력...",
	"Save AI settings": "AI 설정 저장",
	"Model provider": "AI 모델",
	"OpenRouter model ID": "OpenRouter 모델 ID",
	"Default sprite": "기본 스프라이트",
	"Missing": "없음",
	"Save readiness": "저장 준비 상태",
	"Required information": "필수 정보",
	"AI completion": "AI 자동 보완",
	"Sprite files": "스프라이트 파일",
	"Ready": "준비됨",
	"Not needed": "필요 없음",
	"AI settings are missing": "AI 설정이 필요함",
	"The following blank advanced fields will be generated when saving:": "저장할 때 다음의 비어 있는 고급 항목을 AI로 생성합니다:",
	"Generate all will fill these blank advanced fields:": "일괄 생성에서 다음의 비어 있는 고급 항목을 채웁니다:",
	"Use Generate all to complete the remaining AI content.": "일괄 생성으로 남은 AI 콘텐츠를 완성하세요.",
	"Missing required fields:": "빠진 필수 항목:",
	"Missing sprites will be saved as absent and use runtime fallbacks.": "빠진 스프라이트는 없는 파일로 저장되며 실행 시 대체 스프라이트를 사용합니다.",
	"No required sprites are missing.": "필수 스프라이트가 모두 준비되었습니다.",
	"Open AI Settings": "AI 설정 열기",
	"Generate all": "일괄 생성",
	"Stop generation": "생성 중단",
	"Generation stopped": "생성을 중단했습니다.",
	"Generation error": "생성 오류",
	"Save error": "저장 오류",
	"Generation completed": "일괄 생성을 완료했습니다.",
	"Dialogue and conversations": "대사와 대화",
	"Default dialogue will be generated for each character.": "각 캐릭터의 기본 대사를 생성합니다.",
	"Conversations will be generated for the two characters.": "두 캐릭터가 주고받는 대화를 생성합니다.",
	"All default dialogue is ready.": "모든 기본 대사가 준비되었습니다.",
	"A two-character conversation has not been generated.": "2인 대화가 생성되지 않았습니다.",
	"%d groups missing": "%d개 그룹이 비어 있음",
	"All advanced profile fields are ready.": "모든 고급 프로필 항목이 준비되었습니다.",
	"Additional locales": "추가 로캘",
	"No additional locale is selected.": "추가 로캘을 선택하지 않았습니다.",
	"Generate all will create the following locale:": "일괄 생성에서 다음 로캘을 생성합니다:",
	"Generated": "생성됨",
	"Not generated": "생성되지 않음",
	"Conversation %d": "대화 %d",
	"What this character is · e.g. wandering god, office assistant": "이 캐릭터가 무엇인지 · 예: 방랑하는 신, 사무 보조원",
	"Appearance summary · e.g. short silver hair, worn brown coat": "외형 요약 · 예: 짧은 은발, 낡은 갈색 코트",
	"One item per line · e.g. cautious but curious": "한 줄에 하나 · 예: 조심스럽지만 호기심이 많음",
	"Speech style and sentence habits · e.g. short formal sentences": "말투와 문장 습관 · 예: 짧고 격식 있는 문장",
	"How this character sees the user · e.g. roommate, captain": "캐릭터가 사용자를 어떻게 보는지 · 예: 룸메이트, 선장"
}

const MOODS: Array[String] = CreatorCatalogScript.MOODS
const SLOT_LABELS: Dictionary = CreatorCatalogScript.SLOT_LABELS
const CHAT_COLOR_PRESETS: Array[Dictionary] = CreatorCatalogScript.CHAT_COLOR_PRESETS

var model: CreatorPackModel = null
var ai: CreatorAI = null
var selected_character_index := 0
var current_line_group_id := "idle"
var pending_sprite_slot := ""

var background_rect: ColorRect = null
var project_label: Label = null
var status_label: Label = null
var character_selectors: Array[OptionButton] = []
var tabs: TabContainer = null
var content_surface_panel: PanelContainer = null
var navigation_separator: ColorRect = null
var index_tab_rail: VBoxContainer = null
var index_tab_buttons: Array[Button] = []
var last_theme_id: String = ""
var last_interface_language: String = ""
var language_refresh_accumulator: float = 0.0
var appearance_refresh_accumulator: float = 0.0
var external_scroll_bars: Array[VScrollBar] = []
var empty_theme_icon: Texture2D = null

var manifest_pack_controls: Dictionary = {}
var manifest_profile_controls: Dictionary = {}
var relationship_label: Label = null
var relationship_edit: TextEdit = null
var chat_color_selector: OptionButton = null
var chat_color_custom_edit: LineEdit = null
var simple_mode_button: Button = null
var advanced_mode_button: Button = null
var profile_mode_group: ButtonGroup = null
var advanced_profile_rows: Array[Control] = []
var character_id_row: Control = null
var add_line_button: Button = null
var character_count_one_button: Button = null
var character_count_two_button: Button = null
var save_checklist: VBoxContainer = null
var generation_error_label: Label = null
var bulk_generate_button: Button = null
var save_validation_dialog: Window = null
var save_validation_background: ColorRect = null
var save_validation_panel: PanelContainer = null
var save_validation_message: Label = null
var sprite_warning_dialog: Window = null
var sprite_warning_background: ColorRect = null
var sprite_warning_panel: PanelContainer = null
var sprite_warning_message: Label = null
var profile_generation_queue: Array[int] = []
var pending_profile_character_index: int = -1
var save_pipeline_active: bool = false

var line_group_selector: OptionButton = null
var line_rows: VBoxContainer = null
var line_status: Label = null
var line_group_row: Control = null
var line_action_row: Control = null
var dialogue_scope_buttons: Array[Button] = []
var conversation_view: bool = false
var dialogue_generation_queue: Array[int] = []
var dialogue_generation_character_index: int = -1
var dialogue_generated_group_count: int = 0
var bulk_generation_active: bool = false
var bulk_generation_total_steps: int = 0
var bulk_generation_completed_steps: int = 0
var pending_locale_languages: Array[String] = []

var sprite_mode_selector: OptionButton = null
var sprite_grid: VBoxContainer = null
var sprite_preview_body: TextureRect = null
var sprite_preview_face: TextureRect = null
var sprite_preview_caption: Label = null
var sprite_status: Label = null
var preview_slot := "neutral"

var open_manifest_dialog: FileDialog = null
var sprite_dialog: FileDialog = null
var ai_settings_window: AISettingsDialog = null
var creator_window: Window = null
var startup_window: Window = null
var startup_background: ColorRect = null
var startup_panel: PanelContainer = null
var startup_default_button: Button = null
var startup_selection_made: bool = false
var suppress_identity_tracking: bool = false
var pack_id_user_edited: bool = false
var pack_display_name_user_edited: bool = false
var character_id_user_edited: Array[bool] = [false, false]
var desktop_row_control: Control = null
var desktop_note_control: Control = null
var desktop_character_runtime: Node = null
var desktop_character_manager: DesktopCharacterManager = null
var runtime_instance_coordinator: RuntimeInstanceCoordinator = null
var desktop_characters_ready: bool = false
var preview_playback_token: int = 0
var chat_color_icon_cache: Dictionary = {}

func _ready() -> void:
	runtime_instance_coordinator = RuntimeInstanceCoordinatorScript.new()
	add_child(runtime_instance_coordinator)
	if not runtime_instance_coordinator.claim("character_creator"):
		get_tree().quit()
		return
	creator_window = get_window()
	_prepare_creator_window()
	creator_window.close_requested.connect(_on_close_requested)

	theme = CreatorThemeScript.build()
	model = PackModelScript.new()
	ai = CreatorAIScript.new()
	add_child(ai)
	ai.generation_finished.connect(_on_generation_finished)
	ai.generation_failed.connect(_on_generation_failed)
	ai.profile_generation_finished.connect(_on_profile_generation_finished)
	ai.profile_generation_failed.connect(_on_profile_generation_failed)
	ai.conversation_generation_finished.connect(_on_conversation_generation_finished)
	ai.conversation_generation_failed.connect(_on_conversation_generation_failed)
	ai.locale_generation_finished.connect(_on_locale_generation_finished)
	ai.locale_generation_failed.connect(_on_locale_generation_failed)

	_build_ui()
	_build_file_dialogs()
	model.new_pack(2)
	selected_character_index = 0
	conversation_view = false
	_refresh_all()
	_apply_board_appearance(true)
	_apply_interface_language(true)
	_build_startup_window()
	startup_window.popup_centered()
	if startup_default_button != null:
		startup_default_button.call_deferred("grab_focus")
	_start_desktop_character_preview()
	set_process(true)

func _prepare_creator_window() -> void:
	if creator_window == null:
		return
	creator_window.title = _l("Character Creator")
	creator_window.mode = Window.MODE_WINDOWED
	creator_window.borderless = false
	creator_window.transparent = false
	creator_window.transparent_bg = false
	creator_window.always_on_top = false
	creator_window.unfocusable = false
	creator_window.unresizable = false
	creator_window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	creator_window.content_scale_factor = 1.0
	creator_window.min_size = Vector2i(820, 600)
	creator_window.size = Vector2i(980, 720)

func _on_close_requested() -> void:
	preview_playback_token += 1
	if desktop_character_manager != null and is_instance_valid(desktop_character_manager):
		desktop_character_manager.clear_spawned_characters()
	get_tree().quit()

func _start_desktop_character_preview() -> void:
	desktop_character_runtime = Node.new()
	desktop_character_runtime.name = "CreatorDesktopCharacters"
	add_child(desktop_character_runtime)
	desktop_character_manager = DesktopCharacterManagerScript.new()
	desktop_character_manager.name = "DesktopCharacterManager"
	desktop_character_manager.host_window_clickthrough_on_ready = false
	desktop_character_manager.startup_boot_on_ready = false
	desktop_character_manager.manual_preview_mode = true
	desktop_character_manager.cast_changed.connect(_on_desktop_preview_cast_changed)
	desktop_character_runtime.add_child(desktop_character_manager)
	runtime_instance_coordinator.bind_character_manager(desktop_character_manager)
	var specs: Array[Dictionary] = desktop_character_manager.get_preferred_preview_specs(2)
	desktop_character_manager.spawn_preview_cast(specs)

func _on_desktop_preview_cast_changed(_character_ids: Array[String]) -> void:
	desktop_characters_ready = true
	call_deferred("_sync_desktop_character_preview")

func _l(english: String, korean: String = "") -> String:
	var resolved_korean: String = korean
	if resolved_korean.is_empty():
		resolved_korean = str(UI_KO.get(english, english))
	return AppLanguageScript.text(english, resolved_korean)

func _bind_localized_property(
	control: Object,
	property_name: String,
	english: String,
	korean: String = ""
) -> void:
	var resolved_korean: String = korean
	if resolved_korean.is_empty():
		resolved_korean = str(UI_KO.get(english, english))
	control.set_meta("_creator_en_" + property_name, english)
	control.set_meta("_creator_ko_" + property_name, resolved_korean)
	control.set(property_name, _l(english, resolved_korean))

func _apply_language_to_node(node: Node) -> void:
	for property_name: String in [
		"text",
		"placeholder_text",
		"title"
	]:
		var en_key: String = "_creator_en_" + property_name
		var ko_key: String = "_creator_ko_" + property_name
		if node.has_meta(en_key):
			node.set(
				property_name,
				_l(
					str(node.get_meta(en_key, "")),
					str(node.get_meta(ko_key, ""))
				)
			)

	for child: Node in node.get_children():
		_apply_language_to_node(child)

func _apply_interface_language(force: bool) -> void:
	var language: String = AppLanguageScript.get_language()
	if not force and language == last_interface_language:
		return

	_apply_language_to_node(self)

	if creator_window != null:
		creator_window.title = _l("Character Creator")

	_refresh_index_tab_titles()
	_refresh_sprite_mode_labels()
	_refresh_line_group_labels()
	_refresh_existing_mood_labels()
	_refresh_line_status_text()
	_refresh_sprite_cards()
	_refresh_sprite_preview()
	_refresh_project_label()
	_refresh_relationship_label_text()
	_refresh_chat_color_labels()
	_refresh_profile_mode_visibility()
	_refresh_ai_model_labels()
	_refresh_language_selectors()
	_refresh_dialogue_scope_buttons()
	_refresh_save_checklist()

	last_interface_language = language

func _refresh_index_tab_titles() -> void:
	var names: Array[String] = [
		"Character",
		"Pack",
		"Profile",
		"Default Lines",
		"Sprites",
		"Save"
	]
	for index: int in range(index_tab_buttons.size()):
		if index < names.size():
			index_tab_buttons[index].text = _l(names[index])

func _refresh_sprite_mode_labels() -> void:
	if sprite_mode_selector == null:
		return

	var labels: Array[String] = [
		"Simple",
		"Default",
		"Advanced"
	]
	for index: int in range(mini(sprite_mode_selector.item_count, labels.size())):
		sprite_mode_selector.set_item_text(index, _l(labels[index]))

func _refresh_chat_color_labels() -> void:
	if chat_color_selector == null:
		return
	for index: int in range(CHAT_COLOR_PRESETS.size()):
		if index < chat_color_selector.item_count:
			chat_color_selector.set_item_text(index, _l(str(CHAT_COLOR_PRESETS[index].get("label", ""))))
	if chat_color_selector.item_count > CHAT_COLOR_PRESETS.size():
		chat_color_selector.set_item_text(CHAT_COLOR_PRESETS.size(), _l("Custom"))
	_refresh_chat_color_icons()
	_update_chat_color_preview()

func _refresh_profile_mode_visibility() -> void:
	if model == null or model.characters.is_empty():
		return
	var mode: String = model.get_editor_mode(selected_character_index)
	if simple_mode_button != null:
		simple_mode_button.button_pressed = mode == "simple"
	if advanced_mode_button != null:
		advanced_mode_button.button_pressed = mode == "advanced"
	for row: Control in advanced_profile_rows:
		if row != null and is_instance_valid(row):
			row.visible = mode == "advanced"
	if character_id_row != null:
		character_id_row.visible = mode == "advanced"
	if add_line_button != null:
		add_line_button.visible = mode == "advanced" and not conversation_view
	if line_action_row != null:
		line_action_row.visible = mode == "advanced" and not conversation_view
	if character_count_one_button != null:
		character_count_one_button.button_pressed = model.characters.size() == 1
	if character_count_two_button != null:
		character_count_two_button.button_pressed = model.characters.size() == 2
	if index_tab_buttons.size() == 6:
		index_tab_buttons[1].visible = mode == "advanced"
		if mode != "advanced" and tabs.current_tab == 1:
			tabs.current_tab = 0

func _refresh_ai_model_labels() -> void:
	if ai_settings_window != null and is_instance_valid(ai_settings_window):
		ai_settings_window.apply_language()

func _current_language_code() -> String:
	var language: String = AppLanguageScript.get_language().strip_edges().to_lower()
	return "ko" if language.begins_with("ko") else "en"

func _language_display_name(language: String) -> String:
	return _l("Korean", "한국어") if language == "ko" else _l("English", "영어")

func _refresh_language_selectors() -> void:
	if (
		model == null
		or not manifest_pack_controls.has("default_language")
		or not manifest_pack_controls.has("supported_languages")
	):
		return
	var current: String = _current_language_code()
	if model.source_root.is_empty() or model.supported_languages.has(current):
		model.default_language = current
	var selected_default: String = model.default_language
	if selected_default.is_empty():
		selected_default = current
		model.default_language = selected_default

	var default_selector: OptionButton = manifest_pack_controls["default_language"] as OptionButton
	default_selector.clear()
	default_selector.add_item("%s (%s)" % [_language_display_name(selected_default), selected_default])
	default_selector.set_item_metadata(0, selected_default)
	default_selector.select(0)

	var supported_selector: OptionButton = manifest_pack_controls["supported_languages"] as OptionButton
	supported_selector.clear()
	supported_selector.add_item(_l("Current language only"))
	supported_selector.set_item_metadata(0, selected_default)
	supported_selector.add_item(_l("Korean and English"))
	supported_selector.set_item_metadata(1, "ko,en")
	var supports_both: bool = (
		model.supported_languages.has("ko")
		and model.supported_languages.has("en")
	)
	supported_selector.select(1 if supports_both else 0)
	if supports_both:
		model.supported_languages = ["ko", "en"]
	else:
		model.supported_languages = [selected_default]

func _on_supported_language_selected(index: int) -> void:
	if not manifest_pack_controls.has("supported_languages"):
		return
	var selector: OptionButton = manifest_pack_controls["supported_languages"] as OptionButton
	var metadata: String = str(selector.get_item_metadata(index))
	var default_selector: OptionButton = manifest_pack_controls["default_language"] as OptionButton
	model.default_language = str(default_selector.get_item_metadata(default_selector.selected))
	model.supported_languages = _comma_list(metadata)
	if not model.supported_languages.has(model.default_language):
		model.supported_languages.push_front(model.default_language)
	model.dirty = true
	_refresh_save_checklist()

func _refresh_line_group_labels() -> void:
	if line_group_selector == null:
		return

	for index: int in range(line_group_selector.item_count):
		var group_id: String = str(
			line_group_selector.get_item_metadata(index)
		)
		line_group_selector.set_item_text(
			index,
			_line_group_label(group_id)
		)

func _refresh_existing_mood_labels() -> void:
	if line_rows == null:
		return

	for child: Node in line_rows.get_children():
		if not (child is PanelContainer):
			continue

		var panel: PanelContainer = child as PanelContainer
		if panel.get_child_count() == 0:
			continue

		var margin: MarginContainer = panel.get_child(0) as MarginContainer
		if margin == null or margin.get_child_count() == 0:
			continue

		var row: HBoxContainer = margin.get_child(0) as HBoxContainer
		if row == null or row.get_child_count() == 0:
			continue

		var mood: OptionButton = row.get_child(0) as OptionButton
		if mood == null:
			continue

		for index: int in range(mood.item_count):
			var mood_id: String = str(mood.get_item_metadata(index))
			mood.set_item_text(index, _mood_label(mood_id))

func _refresh_line_status_text() -> void:
	if line_status == null or line_rows == null:
		return
	line_status.text = ""

func _line_group_label(group_id: String) -> String:
	match group_id:
		"first_boot":
			return _l("First boot")
		"idle":
			return _l("Idle")
		"timer_complete":
			return _l("Timer complete")
		"timer_pause":
			return _l("Timer pause")
		"timer_resume":
			return _l("Timer resume")
		"timer_stop":
			return _l("Timer stop")
		"desktop_leave":
			return _l("Desktop leave")
		"desktop_arrive":
			return _l("Desktop arrive")
		"boot_primary":
			return _l("Boot primary")
		"boot_arrival":
			return _l("Arrival")
		"boot_peer":
			return _l("After peer arrival")
		"hourly_morning":
			return _l("Hourly · morning")
		"hourly_day":
			return _l("Hourly · day")
		"hourly_evening":
			return _l("Hourly · evening")
		"hourly_late":
			return _l("Hourly · late night")
		"pet":
			return _l("Pet")
		"poke_head":
			return _l("Poke · head")
		"fluster":
			return _l("Fluster")
		_:
			return group_id

func _sprite_slot_label(slot: String) -> String:
	return _l(str(SLOT_LABELS.get(slot, slot)))

func _mood_label(mood: String) -> String:
	return _l(mood)

func _process(delta: float) -> void:
	language_refresh_accumulator += maxf(0.0, delta)
	appearance_refresh_accumulator += maxf(0.0, delta)

	if language_refresh_accumulator >= LANGUAGE_REFRESH_INTERVAL_SECONDS:
		language_refresh_accumulator = 0.0
		_apply_interface_language(false)

	if appearance_refresh_accumulator >= 0.25:
		appearance_refresh_accumulator = 0.0
		_apply_board_appearance(false)

func _apply_board_appearance(force: bool) -> void:
	var theme_id: String = AppearanceSettingsScript.get_theme_signature()
	if not force and theme_id == last_theme_id:
		return

	theme = CreatorThemeScript.build()

	if background_rect != null:
		background_rect.color = CreatorThemeScript.background()

	if content_surface_panel != null:
		content_surface_panel.add_theme_stylebox_override(
			"panel",
			CreatorThemeScript.board_panel()
		)

	if navigation_separator != null:
		navigation_separator.color = CreatorThemeScript.border()

	_apply_index_tab_styles()

	for bar: VScrollBar in external_scroll_bars:
		if bar != null and is_instance_valid(bar):
			_style_external_scroll_bar(bar)

	if open_manifest_dialog != null and is_instance_valid(open_manifest_dialog):
		open_manifest_dialog.theme = CreatorThemeScript.build()

	if sprite_dialog != null and is_instance_valid(sprite_dialog):
		sprite_dialog.theme = CreatorThemeScript.build()

	if ai_settings_window != null and is_instance_valid(ai_settings_window):
		ai_settings_window.theme = CreatorThemeScript.build()
	if startup_window != null and is_instance_valid(startup_window):
		startup_window.theme = CreatorThemeScript.build()
	if startup_background != null and is_instance_valid(startup_background):
		startup_background.color = CreatorThemeScript.background()
	if startup_panel != null and is_instance_valid(startup_panel):
		startup_panel.add_theme_stylebox_override("panel", CreatorThemeScript.board_panel())
	if save_validation_background != null and is_instance_valid(save_validation_background):
		save_validation_background.color = CreatorThemeScript.background()
	if save_validation_panel != null and is_instance_valid(save_validation_panel):
		save_validation_panel.add_theme_stylebox_override("panel", CreatorThemeScript.board_panel())
	if sprite_warning_background != null and is_instance_valid(sprite_warning_background):
		sprite_warning_background.color = CreatorThemeScript.background()
	if sprite_warning_panel != null and is_instance_valid(sprite_warning_panel):
		sprite_warning_panel.add_theme_stylebox_override("panel", CreatorThemeScript.board_panel())
	for dialog_value: Variant in [save_validation_dialog, sprite_warning_dialog]:
		if dialog_value is Window and is_instance_valid(dialog_value):
			(dialog_value as Window).theme = CreatorThemeScript.build()

	last_theme_id = theme_id

func _build_ui() -> void:
	background_rect = ColorRect.new()
	background_rect.color = CreatorThemeScript.background()
	background_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background_rect)

	var root_margin: MarginContainer = MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 18)
	root_margin.add_theme_constant_override("margin_top", 14)
	root_margin.add_theme_constant_override("margin_right", 18)
	root_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(root_margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root_margin.add_child(root)

	root.add_child(_build_header())

	var tab_shell: HBoxContainer = HBoxContainer.new()
	tab_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_shell.add_theme_constant_override("separation", 10)
	root.add_child(tab_shell)

	content_surface_panel = PanelContainer.new()
	content_surface_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_surface_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_surface_panel.add_theme_stylebox_override("panel", CreatorThemeScript.board_panel())
	tab_shell.add_child(content_surface_panel)

	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 14)
	content_margin.add_theme_constant_override("margin_top", 12)
	content_margin.add_theme_constant_override("margin_right", 0)
	content_margin.add_theme_constant_override("margin_bottom", 12)
	content_surface_panel.add_child(content_margin)

	tabs = TabContainer.new()
	tabs.tabs_visible = false
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tab_changed.connect(_on_tab_changed)
	content_margin.add_child(tabs)

	var character_tab: Control = _build_character_tab()
	character_tab.name = "Character"
	tabs.add_child(character_tab)
	var pack_tab: Control = _build_pack_tab()
	pack_tab.name = "Pack"
	tabs.add_child(pack_tab)
	var profile_tab: Control = _build_profile_tab()
	profile_tab.name = "Profile"
	tabs.add_child(profile_tab)
	var lines_tab: Control = _build_lines_tab()
	lines_tab.name = "Lines"
	tabs.add_child(lines_tab)
	var sprites_tab: Control = _build_sprites_tab()
	sprites_tab.name = "Sprites"
	tabs.add_child(sprites_tab)
	var save_tab: Control = _build_save_tab()
	save_tab.name = "Save"
	tabs.add_child(save_tab)

	navigation_separator = ColorRect.new()
	navigation_separator.custom_minimum_size.x = 1.0
	navigation_separator.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	navigation_separator.color = CreatorThemeScript.border()
	tab_shell.add_child(navigation_separator)

	var navigation_margin: MarginContainer = MarginContainer.new()
	navigation_margin.custom_minimum_size.x = 126.0
	navigation_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation_margin.add_theme_constant_override("margin_left", 8)
	navigation_margin.add_theme_constant_override("margin_top", 6)
	navigation_margin.add_theme_constant_override("margin_right", 0)
	navigation_margin.add_theme_constant_override("margin_bottom", 6)
	tab_shell.add_child(navigation_margin)

	index_tab_rail = VBoxContainer.new()
	index_tab_rail.custom_minimum_size.x = 118.0
	index_tab_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	index_tab_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	index_tab_rail.alignment = BoxContainer.ALIGNMENT_CENTER
	index_tab_rail.add_theme_constant_override("separation", 8)
	navigation_margin.add_child(index_tab_rail)
	_build_index_tab_buttons()

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	status_label.add_theme_color_override("font_color", CreatorThemeScript.muted())
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(status_label)

func _build_header() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)

	var title: Label = Label.new()
	_bind_localized_property(title, "text", "Character Creator")
	title.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_LARGE)
	box.add_child(title)

	project_label = Label.new()
	project_label.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	project_label.add_theme_color_override("font_color", CreatorThemeScript.muted())
	project_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(project_label)
	return box

func _make_character_selector() -> OptionButton:
	var selector: OptionButton = OptionButton.new()
	selector.custom_minimum_size = Vector2(0.0, CreatorThemeScript.CONTROL_HEIGHT)
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.item_selected.connect(_on_character_selected)
	character_selectors.append(selector)
	return selector

func _add_character_row(parent: VBoxContainer) -> void:
	var row: HBoxContainer = _make_settings_row("Character")
	parent.add_child(row)
	row.add_child(_make_character_selector())

func _build_index_tab_buttons() -> void:
	if tabs == null or index_tab_rail == null:
		return

	for child: Node in index_tab_rail.get_children():
		child.queue_free()

	index_tab_buttons.clear()

	var labels: Array[String] = [
		"Character",
		"Pack",
		"Profile",
		"Default Lines",
		"Sprites",
		"Save"
	]

	for index: int in range(tabs.get_tab_count()):
		var button: Button = Button.new()
		var label_key: String = labels[index] if index < labels.size() else str(tabs.get_child(index).name)
		button.text = _l(label_key)
		button.custom_minimum_size = Vector2(120, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_index_tab_pressed.bind(index))
		index_tab_rail.add_child(button)
		index_tab_buttons.append(button)

	_apply_index_tab_styles()
	_sync_index_tab_buttons()

func _on_index_tab_pressed(index: int) -> void:
	if tabs == null or index < 0 or index >= tabs.get_tab_count():
		return
	tabs.current_tab = index
	_sync_index_tab_buttons()

func _sync_index_tab_buttons() -> void:
	if tabs == null:
		return
	for index: int in range(index_tab_buttons.size()):
		index_tab_buttons[index].button_pressed = index == tabs.current_tab

func _apply_index_tab_styles() -> void:
	var text_color: Color = CreatorThemeScript.nav_text_color()
	for button: Button in index_tab_buttons:
		button.add_theme_stylebox_override("normal", CreatorThemeScript.nav_style("normal"))
		button.add_theme_stylebox_override("hover", CreatorThemeScript.nav_style("hover"))
		button.add_theme_stylebox_override("pressed", CreatorThemeScript.nav_style("pressed"))
		button.add_theme_stylebox_override("hover_pressed", CreatorThemeScript.nav_style("pressed"))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", text_color)
		button.add_theme_color_override("font_hover_color", text_color)
		button.add_theme_color_override("font_pressed_color", text_color)

func _make_scrollable_page(content: Control) -> Control:
	var overlay: Control = Control.new()
	overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay.mouse_filter = Control.MOUSE_FILTER_PASS

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 2.0
	scroll.offset_top = 2.0
	scroll.offset_right = -float(TAB_SCROLLBAR_CONTENT_GAP)
	scroll.offset_bottom = 0.0
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	overlay.add_child(scroll)

	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var external_bar: VScrollBar = VScrollBar.new()
	external_bar.anchor_left = 1.0
	external_bar.anchor_top = 0.0
	external_bar.anchor_right = 1.0
	external_bar.anchor_bottom = 1.0
	external_bar.offset_left = -(TAB_SCROLLBAR_WIDTH * 0.5)
	external_bar.offset_top = 0.0
	external_bar.offset_right = TAB_SCROLLBAR_WIDTH * 0.5
	external_bar.offset_bottom = 0.0
	external_bar.custom_minimum_size.x = TAB_SCROLLBAR_WIDTH
	external_bar.z_index = 20
	external_bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_external_scroll_bar(external_bar)
	overlay.add_child(external_bar)
	external_scroll_bars.append(external_bar)

	call_deferred(
		"_setup_external_scroll_bar",
		scroll,
		external_bar
	)
	return overlay

func _make_fixed_page_with_scrollbar(
	content: Control,
	inner_scroll: ScrollContainer
) -> Control:
	var overlay: Control = Control.new()
	overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay.mouse_filter = Control.MOUSE_FILTER_PASS

	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 2.0
	content.offset_top = 2.0
	content.offset_right = -float(TAB_SCROLLBAR_CONTENT_GAP)
	content.offset_bottom = 0.0
	overlay.add_child(content)

	var external_bar: VScrollBar = VScrollBar.new()
	external_bar.anchor_left = 1.0
	external_bar.anchor_top = 0.0
	external_bar.anchor_right = 1.0
	external_bar.anchor_bottom = 1.0
	external_bar.offset_left = -(TAB_SCROLLBAR_WIDTH * 0.5)
	external_bar.offset_right = TAB_SCROLLBAR_WIDTH * 0.5
	external_bar.custom_minimum_size.x = TAB_SCROLLBAR_WIDTH
	external_bar.z_index = 20
	external_bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_external_scroll_bar(external_bar)
	overlay.add_child(external_bar)
	external_scroll_bars.append(external_bar)

	call_deferred("_setup_external_scroll_bar", inner_scroll, external_bar)
	return overlay

func _setup_external_scroll_bar(
	scroll: ScrollContainer,
	external_bar: VScrollBar
) -> void:
	if scroll == null or external_bar == null:
		return

	var native_bar: VScrollBar = scroll.get_v_scroll_bar()
	if native_bar == null:
		return

	_hide_native_scroll_bar(native_bar)
	_sync_external_scroll_bar(native_bar, external_bar)

	native_bar.value_changed.connect(
		_on_native_scroll_value_changed.bind(external_bar)
	)
	external_bar.value_changed.connect(
		_on_external_scroll_value_changed.bind(native_bar)
	)
	native_bar.changed.connect(
		_sync_external_scroll_bar.bind(native_bar, external_bar)
	)
	scroll.resized.connect(
		_sync_external_scroll_bar.bind(native_bar, external_bar)
	)

func _hide_native_scroll_bar(bar: VScrollBar) -> void:
	bar.modulate.a = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size.x = 0.0

	var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
	bar.add_theme_stylebox_override("scroll", empty_style)
	bar.add_theme_stylebox_override("scroll_focus", empty_style)
	bar.add_theme_stylebox_override("grabber", empty_style)
	bar.add_theme_stylebox_override("grabber_highlight", empty_style)
	bar.add_theme_stylebox_override("grabber_pressed", empty_style)

	var empty_icon: Texture2D = _get_empty_theme_icon()
	for icon_name: String in [
		"increment",
		"increment_highlight",
		"increment_pressed",
		"decrement",
		"decrement_highlight",
		"decrement_pressed"
	]:
		bar.add_theme_icon_override(icon_name, empty_icon)

func _style_external_scroll_bar(bar: VScrollBar) -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(0.0, 0.0, 0.0, 0.0)

	var thumb: StyleBoxFlat = StyleBoxFlat.new()
	thumb.bg_color = AppearanceSettingsScript.get_ui_color("scrollbar")
	thumb.corner_radius_top_left = 3
	thumb.corner_radius_top_right = 3
	thumb.corner_radius_bottom_left = 3
	thumb.corner_radius_bottom_right = 3

	var thumb_active: StyleBoxFlat = thumb.duplicate() as StyleBoxFlat
	thumb_active.bg_color = AppearanceSettingsScript.get_ui_color("scroll_hover")

	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", thumb)
	bar.add_theme_stylebox_override("grabber_highlight", thumb_active)
	bar.add_theme_stylebox_override("grabber_pressed", thumb_active)
	bar.add_theme_constant_override("grabber_size", 44)
	bar.add_theme_constant_override("padding_left", 0)
	bar.add_theme_constant_override("padding_right", 0)
	bar.custom_minimum_size.x = TAB_SCROLLBAR_WIDTH

	var empty_icon: Texture2D = _get_empty_theme_icon()
	for icon_name: String in [
		"increment",
		"increment_highlight",
		"increment_pressed",
		"decrement",
		"decrement_highlight",
		"decrement_pressed"
	]:
		bar.add_theme_icon_override(icon_name, empty_icon)

func _sync_external_scroll_bar(
	native_bar: VScrollBar,
	external_bar: VScrollBar
) -> void:
	if (
		native_bar == null
		or external_bar == null
		or not is_instance_valid(native_bar)
		or not is_instance_valid(external_bar)
	):
		return

	external_bar.min_value = native_bar.min_value
	external_bar.max_value = native_bar.max_value
	external_bar.page = native_bar.page
	external_bar.step = native_bar.step
	external_bar.set_value_no_signal(native_bar.value)
	external_bar.visible = native_bar.max_value > native_bar.page + 0.5

func _on_native_scroll_value_changed(
	value: float,
	external_bar: VScrollBar
) -> void:
	if external_bar != null and is_instance_valid(external_bar):
		external_bar.set_value_no_signal(value)

func _on_external_scroll_value_changed(
	value: float,
	native_bar: VScrollBar
) -> void:
	if native_bar != null and is_instance_valid(native_bar):
		native_bar.value = value

func _get_empty_theme_icon() -> Texture2D:
	if empty_theme_icon != null:
		return empty_theme_icon

	var image: Image = Image.create(
		1,
		1,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	empty_theme_icon = ImageTexture.create_from_image(image)
	return empty_theme_icon

func _build_pack_tab() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", AppearanceSettingsScript.UI_STACK_GAP)

	root.add_child(_page_heading(
		"Pack",
		"Edit pack identity and language metadata."
	))
	root.add_child(HSeparator.new())

	manifest_pack_controls["id"] = _add_line_field(
		root, "Pack ID", "Lowercase letters / numbers / _"
	)
	manifest_pack_controls["id"].text_changed.connect(_on_pack_id_input_changed)
	manifest_pack_controls["display_name"] = _add_line_field(
		root, "Display name", "Name shown to users"
	)
	manifest_pack_controls["display_name"].text_changed.connect(_on_pack_display_name_input_changed)
	manifest_pack_controls["description"] = _add_text_field(
		root, "Description", "Pack description", 72
	)
	var default_language_row: HBoxContainer = _make_settings_row("Default language")
	root.add_child(default_language_row)
	var default_language_selector: OptionButton = OptionButton.new()
	default_language_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	default_language_selector.disabled = true
	default_language_row.add_child(default_language_selector)
	manifest_pack_controls["default_language"] = default_language_selector

	var language_note: Label = Label.new()
	_bind_localized_property(
		language_note,
		"text",
		"The default language follows the current interface language."
	)
	language_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	language_note.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	language_note.add_theme_color_override("font_color", CreatorThemeScript.muted())
	root.add_child(language_note)

	var supported_language_row: HBoxContainer = _make_settings_row("Languages")
	root.add_child(supported_language_row)
	var supported_language_selector: OptionButton = OptionButton.new()
	supported_language_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	supported_language_selector.item_selected.connect(_on_supported_language_selected)
	supported_language_row.add_child(supported_language_selector)
	manifest_pack_controls["supported_languages"] = supported_language_selector
	_refresh_language_selectors()

	return _make_scrollable_page(root)

func _build_character_tab() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", AppearanceSettingsScript.UI_STACK_GAP)

	root.add_child(_page_heading(
		"Character",
		"Edit the selected character's public identity and runtime options."
	))
	root.add_child(HSeparator.new())
	_add_character_row(root)

	var count_row: HBoxContainer = _make_settings_row("Character count")
	root.add_child(count_row)
	var count_buttons: HBoxContainer = HBoxContainer.new()
	count_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_buttons.add_theme_constant_override("separation", 6)
	count_row.add_child(count_buttons)
	var count_group: ButtonGroup = ButtonGroup.new()

	character_count_one_button = Button.new()
	_bind_localized_property(character_count_one_button, "text", "One character")
	character_count_one_button.toggle_mode = true
	character_count_one_button.button_group = count_group
	character_count_one_button.custom_minimum_size = Vector2(110, CreatorThemeScript.CONTROL_HEIGHT)
	character_count_one_button.pressed.connect(_on_new_one)
	count_buttons.add_child(character_count_one_button)

	character_count_two_button = Button.new()
	_bind_localized_property(character_count_two_button, "text", "Two characters")
	character_count_two_button.toggle_mode = true
	character_count_two_button.button_group = count_group
	character_count_two_button.custom_minimum_size = Vector2(110, CreatorThemeScript.CONTROL_HEIGHT)
	character_count_two_button.pressed.connect(_on_new_two)
	count_buttons.add_child(character_count_two_button)

	var mode_row: HBoxContainer = _make_settings_row("Edit mode")
	root.add_child(mode_row)
	var mode_buttons: HBoxContainer = HBoxContainer.new()
	mode_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_buttons.add_theme_constant_override("separation", 6)
	mode_row.add_child(mode_buttons)
	profile_mode_group = ButtonGroup.new()

	simple_mode_button = Button.new()
	_bind_localized_property(simple_mode_button, "text", "Simple")
	simple_mode_button.toggle_mode = true
	simple_mode_button.button_group = profile_mode_group
	simple_mode_button.custom_minimum_size = Vector2(110, CreatorThemeScript.CONTROL_HEIGHT)
	simple_mode_button.pressed.connect(_on_profile_mode_selected.bind("simple"))
	mode_buttons.add_child(simple_mode_button)

	advanced_mode_button = Button.new()
	_bind_localized_property(advanced_mode_button, "text", "Advanced")
	advanced_mode_button.toggle_mode = true
	advanced_mode_button.button_group = profile_mode_group
	advanced_mode_button.custom_minimum_size = Vector2(110, CreatorThemeScript.CONTROL_HEIGHT)
	advanced_mode_button.pressed.connect(_on_profile_mode_selected.bind("advanced"))
	mode_buttons.add_child(advanced_mode_button)

	manifest_profile_controls["id"] = _add_line_field(
		root, "Character ID", "Lowercase letters / numbers / _"
	)
	manifest_profile_controls["id"].text_changed.connect(_on_character_id_input_changed)
	character_id_row = manifest_profile_controls["id"].get_parent() as Control
	manifest_profile_controls["display_name"] = _add_line_field(
		root, "Display name *", "Character name"
	)
	manifest_profile_controls["display_name"].text_changed.connect(_on_character_display_name_changed)
	manifest_profile_controls["birthday"] = _add_line_field(
		root, "Birthday", "MM-DD · optional"
	)
	manifest_profile_controls["birthday"].text_changed.connect(_on_birthday_changed)
	_add_chat_color_row(root)

	var desktop_row: HBoxContainer = _make_settings_row("Desktop")
	desktop_row_control = desktop_row
	root.add_child(desktop_row)
	var default_desktop: CheckBox = CheckBox.new()
	_bind_localized_property(default_desktop, "text", "Default on desktop")
	default_desktop.toggled.connect(_on_default_desktop_toggled)
	manifest_profile_controls["default_on_desktop"] = default_desktop
	desktop_row.add_child(default_desktop)

	var desktop_note: Label = Label.new()
	desktop_note_control = desktop_note
	_bind_localized_property(
		desktop_note,
		"text",
		"Use the first desktop slot."
	)
	desktop_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desktop_note.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	desktop_note.add_theme_color_override("font_color", CreatorThemeScript.muted())
	root.add_child(desktop_note)

	return _make_scrollable_page(root)

func _build_profile_tab() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", AppearanceSettingsScript.UI_STACK_GAP)

	root.add_child(_page_heading(
		"Profile",
		"Character personality and AI context stored in profile.json."
	))
	root.add_child(HSeparator.new())
	_add_character_row(root)

	var required_note: Label = Label.new()
	_bind_localized_property(
		required_note,
		"text",
		"Fields marked * are required before AI can complete the hidden profile fields."
	)
	required_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	required_note.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	required_note.add_theme_color_override("font_color", CreatorThemeScript.muted())
	root.add_child(required_note)

	manifest_profile_controls["role"] = _add_line_field(
		root, "Role *", "What this character is · e.g. wandering god, office assistant"
	)
	manifest_profile_controls["appearance"] = _add_text_field(
		root, "Appearance *", "Appearance summary · e.g. short silver hair, worn brown coat", 68
	)
	manifest_profile_controls["core_personality"] = _add_text_field(
		root, "Personality *", "One item per line · e.g. cautious but curious", 96
	)
	manifest_profile_controls["voice_casual"] = _add_text_field(
		root, "Voice *", "Speech style and sentence habits · e.g. short formal sentences", 84
	)
	manifest_profile_controls["user_role"] = _add_line_field(
		root, "User role", "How this character sees the user · e.g. roommate, captain"
	)
	manifest_profile_controls["user_description"] = _add_text_field(
		root, "User description", "Relationship with the user", 72
	)

	relationship_label = Label.new()
	_bind_localized_property(relationship_label, "text", "Relationship")
	relationship_label.custom_minimum_size.x = 120.0
	relationship_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var relationship_row: HBoxContainer = HBoxContainer.new()
	relationship_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relationship_row.add_theme_constant_override("separation", 12)
	relationship_row.add_child(relationship_label)

	relationship_edit = TextEdit.new()
	relationship_edit.custom_minimum_size = Vector2(0, 90)
	relationship_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_localized_property(
		relationship_edit,
		"placeholder_text",
		"Relationship with the other character"
	)
	relationship_edit.text_changed.connect(_mark_dirty)
	relationship_row.add_child(relationship_edit)
	root.add_child(relationship_row)

	manifest_profile_controls["setting_note"] = _add_text_field(
		root, "Setting note", "World and default situation", 78
	)
	advanced_profile_rows.append(manifest_profile_controls["setting_note"].get_parent() as Control)
	manifest_profile_controls["voice_avoid"] = _add_text_field(
		root, "Voice · avoid", "One item per line", 90
	)
	advanced_profile_rows.append(manifest_profile_controls["voice_avoid"].get_parent() as Control)
	manifest_profile_controls["behavior_patterns"] = _add_text_field(
		root, "Behavior", "One item per line", 96
	)
	advanced_profile_rows.append(manifest_profile_controls["behavior_patterns"].get_parent() as Control)
	manifest_profile_controls["mundane_details"] = _add_text_field(
		root, "Mundane details", "Everyday details · one per line", 84
	)
	advanced_profile_rows.append(manifest_profile_controls["mundane_details"].get_parent() as Control)
	manifest_profile_controls["private_internal"] = _add_text_field(
		root, "Private internal", "Inner thoughts not normally spoken · one per line", 84
	)
	advanced_profile_rows.append(manifest_profile_controls["private_internal"].get_parent() as Control)
	manifest_profile_controls["ai_rules"] = _add_text_field(
		root, "AI rules", "One item per line", 100
	)
	advanced_profile_rows.append(manifest_profile_controls["ai_rules"].get_parent() as Control)
	manifest_profile_controls["lore"] = _add_text_field(
		root, "Lore", "One item per line", 100
	)
	advanced_profile_rows.append(manifest_profile_controls["lore"].get_parent() as Control)

	return _make_scrollable_page(root)

func _build_lines_tab() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)

	root.add_child(_page_heading(
		"Default Lines",
		"Edit default and fallback dialogue."
	))
	root.add_child(HSeparator.new())

	var view_row: HBoxContainer = _make_settings_row("View")
	root.add_child(view_row)
	var view_buttons: HBoxContainer = HBoxContainer.new()
	view_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_buttons.add_theme_constant_override("separation", 6)
	view_row.add_child(view_buttons)
	var view_group: ButtonGroup = ButtonGroup.new()
	for label: String in ["Character 1", "Character 2", "Conversation"]:
		var button: Button = Button.new()
		_bind_localized_property(button, "text", label)
		button.toggle_mode = true
		button.button_group = view_group
		button.custom_minimum_size = Vector2(130, CreatorThemeScript.CONTROL_HEIGHT)
		button.pressed.connect(_on_dialogue_scope_selected.bind(dialogue_scope_buttons.size()))
		view_buttons.add_child(button)
		dialogue_scope_buttons.append(button)

	var group_row: HBoxContainer = _make_settings_row("Group")
	line_group_row = group_row
	root.add_child(group_row)

	line_group_selector = OptionButton.new()
	line_group_selector.custom_minimum_size.y = CreatorThemeScript.CONTROL_HEIGHT
	line_group_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_group_selector.item_selected.connect(_on_line_group_selected)
	group_row.add_child(line_group_selector)

	var action_row: HBoxContainer = _make_settings_row("")
	line_action_row = action_row
	root.add_child(action_row)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 6)
	action_row.add_child(actions)
	add_line_button = _toolbar_button("+ Line", _on_add_line)
	actions.add_child(add_line_button)

	line_status = Label.new()
	line_status.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	line_status.add_theme_color_override("font_color", CreatorThemeScript.muted())
	root.add_child(line_status)

	line_rows = VBoxContainer.new()
	line_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_rows.add_theme_constant_override("separation", 2)
	root.add_child(line_rows)

	return _make_scrollable_page(root)

func _build_save_tab() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)

	root.add_child(_page_heading(
		"Save",
		"Review the checklist before saving to res://characters."
	))
	root.add_child(HSeparator.new())

	save_checklist = VBoxContainer.new()
	save_checklist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_checklist.add_theme_constant_override("separation", 8)
	root.add_child(save_checklist)

	generation_error_label = Label.new()
	generation_error_label.visible = false
	generation_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	generation_error_label.add_theme_color_override("font_color", CreatorThemeScript.danger())
	root.add_child(generation_error_label)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 8)
	root.add_child(action_row)

	var generation_actions: HBoxContainer = HBoxContainer.new()
	generation_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generation_actions.add_theme_constant_override("separation", 6)
	action_row.add_child(generation_actions)

	bulk_generate_button = _toolbar_button("Generate all", _on_bulk_generate)
	bulk_generate_button.custom_minimum_size.x = 180.0
	generation_actions.add_child(bulk_generate_button)

	var ai_button: Button = _toolbar_button("Open AI Settings", _open_ai_settings)
	ai_button.custom_minimum_size.x = 150.0
	generation_actions.add_child(ai_button)

	var save_button: Button = _toolbar_button("Save", _on_export)
	save_button.custom_minimum_size = Vector2(180, 40)
	save_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	save_button.add_theme_stylebox_override(
		"normal",
		CreatorThemeScript.box(
			CreatorThemeScript.soft_accent(),
			CreatorThemeScript.soft_accent(),
			9,
			0.0
		)
	)
	action_row.add_child(save_button)

	return _make_scrollable_page(root)

func _build_sprites_tab() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)

	root.add_child(_page_heading(
		"Sprites",
		"Upload 400×600 transparent PNGs and preview the composed result."
	))
	root.add_child(HSeparator.new())
	_add_character_row(root)

	var mode_row: HBoxContainer = _make_settings_row("Sprite mode")
	root.add_child(mode_row)

	sprite_mode_selector = OptionButton.new()
	sprite_mode_selector.custom_minimum_size.y = CreatorThemeScript.CONTROL_HEIGHT
	sprite_mode_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for label: String in ["Simple", "Default", "Advanced"]:
		sprite_mode_selector.add_item(_l(label))
	sprite_mode_selector.item_selected.connect(_on_sprite_mode_selected)
	mode_row.add_child(sprite_mode_selector)

	var requirement: Label = Label.new()
	_bind_localized_property(
		requirement,
		"text",
		"PNG only · exactly 400×600 · transparent background required"
	)
	requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	requirement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	requirement.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	requirement.add_theme_color_override("font_color", CreatorThemeScript.muted())
	root.add_child(requirement)

	sprite_status = Label.new()
	sprite_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sprite_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_status.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	root.add_child(sprite_status)

	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	var preview_box: VBoxContainer = VBoxContainer.new()
	preview_box.custom_minimum_size.x = 200.0
	preview_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	preview_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preview_box.add_theme_constant_override("separation", 8)
	body.add_child(preview_box)

	var preview_heading: Label = Label.new()
	_bind_localized_property(preview_heading, "text", "Preview")
	preview_heading.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_MEDIUM)
	preview_box.add_child(preview_heading)

	var preview_frame: AspectRatioContainer = AspectRatioContainer.new()
	preview_frame.ratio = 2.0 / 3.0
	preview_frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	preview_frame.custom_minimum_size = Vector2(180, 270)
	preview_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_box.add_child(preview_frame)

	var stack: Control = Control.new()
	preview_frame.add_child(stack)

	sprite_preview_body = TextureRect.new()
	sprite_preview_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite_preview_body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_preview_body.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(sprite_preview_body)

	sprite_preview_face = TextureRect.new()
	sprite_preview_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite_preview_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_preview_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(sprite_preview_face)

	sprite_preview_caption = Label.new()
	sprite_preview_caption.custom_minimum_size.x = 180.0
	sprite_preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sprite_preview_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sprite_preview_caption.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	sprite_preview_caption.add_theme_color_override("font_color", CreatorThemeScript.muted())
	preview_box.add_child(sprite_preview_caption)

	var separator: ColorRect = ColorRect.new()
	separator.custom_minimum_size.x = 1.0
	separator.size_flags_vertical = Control.SIZE_EXPAND_FILL
	separator.color = CreatorThemeScript.border()
	body.add_child(separator)

	var sprite_scroll: ScrollContainer = ScrollContainer.new()
	sprite_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sprite_scroll)

	sprite_grid = VBoxContainer.new()
	sprite_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_grid.add_theme_constant_override("separation", 10)
	sprite_scroll.add_child(sprite_grid)

	return _make_fixed_page_with_scrollbar(root, sprite_scroll)

func _build_file_dialogs() -> void:
	open_manifest_dialog = FileDialog.new()
	_bind_localized_property(
		open_manifest_dialog,
		"title",
		"Choose a character pack manifest.json from res://characters"
	)
	open_manifest_dialog.theme = CreatorThemeScript.build()
	open_manifest_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_manifest_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_manifest_dialog.use_native_dialog = true
	open_manifest_dialog.current_dir = DistributionPathsScript.get_characters_directory()
	open_manifest_dialog.filters = PackedStringArray([
		"manifest.json ; Character pack manifest"
	])
	open_manifest_dialog.file_selected.connect(_on_manifest_file_selected)
	open_manifest_dialog.canceled.connect(_on_manifest_open_canceled)
	add_child(open_manifest_dialog)

	sprite_dialog = FileDialog.new()
	_bind_localized_property(
		sprite_dialog,
		"title",
		"Choose a 400×600 transparent PNG"
	)
	sprite_dialog.theme = CreatorThemeScript.build()
	sprite_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	sprite_dialog.access = FileDialog.ACCESS_FILESYSTEM
	sprite_dialog.use_native_dialog = true
	sprite_dialog.filters = PackedStringArray(["*.png ; PNG"])
	sprite_dialog.file_selected.connect(_on_sprite_file_selected)
	add_child(sprite_dialog)

func _build_startup_window() -> void:
	startup_window = Window.new()
	_bind_localized_property(startup_window, "title", "Start editing")
	startup_window.theme = CreatorThemeScript.build()
	startup_window.size = Vector2i(540, 300)
	startup_window.min_size = Vector2i(480, 280)
	startup_window.transient = true
	startup_window.exclusive = true
	startup_window.close_requested.connect(_on_startup_window_closed)
	add_child(startup_window)

	startup_background = ColorRect.new()
	startup_background.color = CreatorThemeScript.background()
	startup_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	startup_window.add_child(startup_background)

	var outer: MarginContainer = MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 18)
	outer.add_theme_constant_override("margin_top", 18)
	outer.add_theme_constant_override("margin_right", 18)
	outer.add_theme_constant_override("margin_bottom", 18)
	startup_window.add_child(outer)

	startup_panel = PanelContainer.new()
	startup_panel.add_theme_stylebox_override("panel", CreatorThemeScript.board_panel())
	outer.add_child(startup_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	startup_panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title: Label = Label.new()
	_bind_localized_property(title, "text", "Start editing")
	title.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_LARGE)
	box.add_child(title)

	var subtitle: Label = Label.new()
	_bind_localized_property(
		subtitle,
		"text",
		"Choose how to start this Character Creator session."
	)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	subtitle.add_theme_color_override("font_color", CreatorThemeScript.muted())
	box.add_child(subtitle)

	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)

	for definition: Dictionary in [
		{"label": "Start new", "callback": _on_startup_new},
		{"label": "Use preset", "callback": _on_startup_preset.bind(2)},
		{"label": "Open", "callback": _on_startup_open}
	]:
		var callback: Callable = definition.get("callback", Callable())
		var button: Button = _toolbar_button(
			str(definition.get("label", "")),
			callback
		)
		button.custom_minimum_size = Vector2(300, 38)
		buttons.add_child(button)
		if startup_default_button == null:
			startup_default_button = button

	_apply_language_to_node(startup_window)

func _on_startup_window_closed() -> void:
	_on_startup_new()

func _on_startup_new() -> void:
	_start_new_pack(2, false)

func _on_startup_preset(character_count: int) -> void:
	_start_new_pack(character_count, true)

func _start_new_pack(character_count: int, use_preset_sprites: bool) -> void:
	startup_selection_made = true
	startup_window.hide()
	pack_id_user_edited = false
	pack_display_name_user_edited = false
	character_id_user_edited = [false, false]
	model.new_pack(character_count, use_preset_sprites)
	selected_character_index = 0
	conversation_view = false
	current_line_group_id = "idle"
	_refresh_all()
	_refresh_auto_pack_identity()
	_sync_desktop_character_preview()
	_set_status(_l(
		"New %d-character pack · saves to res://characters",
		"새 %d인 팩 · 저장 위치 res://characters"
	) % character_count)

func _on_startup_open() -> void:
	startup_window.hide()
	open_manifest_dialog.popup_centered_ratio(0.75)

func _on_manifest_open_canceled() -> void:
	if not startup_selection_made and startup_window != null:
		startup_window.popup_centered()

func _toolbar_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	_bind_localized_property(button, "text", text)
	button.custom_minimum_size.y = CreatorThemeScript.CONTROL_HEIGHT
	button.pressed.connect(callback)
	return button

func _page_heading(title_text: String, subtitle_text: String) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)

	var title: Label = Label.new()
	_bind_localized_property(title, "text", title_text)
	title.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_LARGE)
	box.add_child(title)

	var subtitle: Label = Label.new()
	_bind_localized_property(subtitle, "text", subtitle_text)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	subtitle.add_theme_color_override("font_color", CreatorThemeScript.muted())
	box.add_child(subtitle)
	return box

func _make_settings_row(label_text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size.y = float(CreatorThemeScript.CONTROL_HEIGHT)

	var label: Label = Label.new()
	_bind_localized_property(label, "text", label_text)
	label.custom_minimum_size.x = 120.0
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return row

func _add_chat_color_row(parent: VBoxContainer) -> void:
	var row: HBoxContainer = _make_settings_row("Chat color preset")
	parent.add_child(row)

	var controls: HBoxContainer = HBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 6)
	row.add_child(controls)

	chat_color_selector = OptionButton.new()
	chat_color_selector.custom_minimum_size = Vector2(190, CreatorThemeScript.CONTROL_HEIGHT)
	for preset: Dictionary in CHAT_COLOR_PRESETS:
		chat_color_selector.add_item(_l(str(preset.get("label", ""))))
		var preset_index: int = chat_color_selector.item_count - 1
		var preset_color: String = str(preset.get("color", "#3A83F7"))
		chat_color_selector.set_item_metadata(preset_index, preset_color)
	chat_color_selector.add_item(_l("Custom"))
	chat_color_selector.set_item_metadata(chat_color_selector.item_count - 1, "__custom__")
	_refresh_chat_color_icons()
	chat_color_selector.item_selected.connect(_on_chat_color_preset_selected)
	controls.add_child(chat_color_selector)

	chat_color_custom_edit = ThemedColorPickerScript.new()
	chat_color_custom_edit.custom_minimum_size.y = CreatorThemeScript.CONTROL_HEIGHT
	chat_color_custom_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_localized_property(chat_color_custom_edit, "placeholder_text", "Custom color")
	chat_color_custom_edit.text_changed.connect(_on_custom_chat_color_changed)
	controls.add_child(chat_color_custom_edit)

func _add_line_field(
	parent: VBoxContainer,
	label_text: String,
	placeholder: String
) -> LineEdit:
	var row: HBoxContainer = _make_settings_row(label_text)
	parent.add_child(row)

	var edit: LineEdit = LineEdit.new()
	_bind_localized_property(edit, "placeholder_text", placeholder)
	edit.custom_minimum_size.y = CreatorThemeScript.CONTROL_HEIGHT
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(_mark_dirty_text)
	row.add_child(edit)
	return edit

func _add_text_field(
	parent: VBoxContainer,
	label_text: String,
	placeholder: String,
	height: int
) -> TextEdit:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label: Label = Label.new()
	_bind_localized_property(label, "text", label_text)
	label.custom_minimum_size.x = 120.0
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)

	var edit: TextEdit = TextEdit.new()
	_bind_localized_property(edit, "placeholder_text", placeholder)
	edit.custom_minimum_size = Vector2(0, height)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.text_changed.connect(_mark_dirty)
	row.add_child(edit)
	return edit

func _refresh_all() -> void:
	_refresh_project_label()
	_refresh_character_selector()
	_refresh_manifest_form()
	_refresh_dialogue_scope_buttons()
	_refresh_line_groups()
	_refresh_sprite_tab()
	_refresh_profile_mode_visibility()
	_refresh_save_checklist()

func _refresh_save_checklist() -> void:
	if save_checklist == null or model == null:
		return
	_clear_children(save_checklist)

	var required: Array[String] = _collect_required_field_errors(false)
	_refresh_bulk_generate_button_state(required)
	_add_checklist_section(
		"Required information",
		"Ready" if required.is_empty() else "Missing required fields:",
		required,
		required.is_empty()
	)

	var ai_details: Array[String] = []
	for character_index: int in range(model.characters.size()):
		var fields: Array[String] = model.get_missing_advanced_profile_fields(character_index)
		if fields.is_empty():
			continue
		var character: Dictionary = model.characters[character_index]
		var profile: Dictionary = character.get("profile", {})
		var display_name: String = str(profile.get("display_name", character.get("id", "Character")))
		for field: String in fields:
			ai_details.append("%s · %s" % [display_name, _advanced_field_label(field)])

	var ai_settings: Dictionary = ai.load_settings()
	var ai_ready: bool = (
		not str(ai_settings.get("api_key", "")).strip_edges().is_empty()
		and not str(ai_settings.get("model", "")).strip_edges().is_empty()
	)
	var ai_status: String = "All advanced profile fields are ready."
	var ai_ok: bool = ai_details.is_empty()
	if not ai_details.is_empty():
		ai_status = "Generate all will fill these blank advanced fields:"
		if not ai_ready:
			ai_details.push_front(_l("AI settings are missing"))
	_add_checklist_section("AI completion", ai_status, ai_details, ai_ok)

	var dialogue_details: Array[String] = []
	for character_index: int in range(model.characters.size()):
		var missing_group_count: int = 0
		for group: Dictionary in model.get_line_groups(character_index):
			if model.get_line_group(character_index, str(group.get("id", ""))).is_empty():
				missing_group_count += 1
		if missing_group_count > 0:
			var character: Dictionary = model.characters[character_index]
			var profile: Dictionary = character.get("profile", {})
			var display_name: String = str(profile.get("display_name", character.get("id", "Character")))
			dialogue_details.append("%s · %s" % [
				display_name,
				_l("%d groups missing", "%d개 그룹이 비어 있음") % missing_group_count
			])
	if model.characters.size() == 2 and model.conversations.is_empty():
		dialogue_details.append(_l("A two-character conversation has not been generated."))
	if not dialogue_details.is_empty() and not ai_ready:
		dialogue_details.push_front(_l("AI settings are missing"))
	_add_checklist_section(
		"Dialogue and conversations",
		"All default dialogue is ready." if dialogue_details.is_empty() else "Use Generate all to complete the remaining AI content.",
		dialogue_details,
		dialogue_details.is_empty()
	)

	var locale_details: Array[String] = []
	var locale_ok: bool = true
	for language: String in model.supported_languages:
		if language == model.default_language:
			continue
		var generated: bool = model.secondary_locales.has(language)
		locale_ok = locale_ok and generated
		locale_details.append("%s · %s" % [
			_language_display_name(language),
			_l("Generated") if generated else _l("Not generated")
		])
	var locale_status: String = (
		"No additional locale is selected."
		if locale_details.is_empty()
		else "Generate all will create the following locale:"
	)
	_add_checklist_section(
		"Additional locales",
		locale_status,
		locale_details,
		locale_ok
	)

	var sprite_warnings: Array[Dictionary] = model.get_sprite_save_warnings()
	var sprite_details: Array[String] = []
	for warning: Dictionary in sprite_warnings:
		sprite_details.append("%s · %s" % [
			str(warning.get("character", "")),
			_sprite_slot_label(str(warning.get("slot", "")))
		])
	_add_checklist_section(
		"Sprite files",
		"No required sprites are missing." if sprite_warnings.is_empty() else "Missing sprites will be saved as absent and use runtime fallbacks.",
		sprite_details,
		sprite_warnings.is_empty()
	)

func _refresh_bulk_generate_button_state(required: Array[String]) -> void:
	if bulk_generate_button == null:
		return
	bulk_generate_button.add_theme_color_override(
		"font_disabled_color",
		CreatorThemeScript.muted()
	)
	if bulk_generation_active:
		bulk_generate_button.disabled = false
		bulk_generate_button.text = _l("Stop generation")
		return
	bulk_generate_button.disabled = not required.is_empty()
	bulk_generate_button.text = _l("Generate all")

func _add_checklist_section(
	title_key: String,
	status_key: String,
	details: Array[String],
	ok: bool
) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", CreatorThemeScript.row_panel())
	save_checklist.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var title: Label = Label.new()
	title.text = ("✓ " if ok else "! ") + _l(title_key)
	title.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_MEDIUM)
	title.add_theme_color_override(
		"font_color",
		CreatorThemeScript.success() if ok else CreatorThemeScript.danger()
	)
	box.add_child(title)

	var status: Label = Label.new()
	status.text = _l(status_key)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)

	for detail: String in details:
		var detail_label: Label = Label.new()
		detail_label.text = "• " + detail
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_label.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
		detail_label.add_theme_color_override("font_color", CreatorThemeScript.muted())
		box.add_child(detail_label)

func _advanced_field_label(field: String) -> String:
	match field:
		"setting_note": return _l("Setting note")
		"voice_avoid": return _l("Voice · avoid")
		"behavior_patterns": return _l("Behavior")
		"mundane_details": return _l("Mundane details")
		"private_internal": return _l("Private internal")
		"ai_behavior_rules": return _l("AI rules")
		"lore": return _l("Lore")
		_: return field

func _refresh_relationship_label_text() -> void:
	if (
		relationship_label == null
		or model == null
		or model.characters.size() != 2
	):
		return

	relationship_label.text = _l("Relationship")

func _refresh_project_label() -> void:
	if project_label == null or model == null:
		return

	var source: String = (
		_l("New pack")
		if model.source_root.is_empty()
		else model.source_root
	)
	var character_count_text: String = _l(
		"%d character",
		"%d인"
	) % model.characters.size()
	if model.characters.size() != 1:
		character_count_text = _l(
			"%d characters",
			"%d인"
		) % model.characters.size()

	project_label.text = "%s · %s · %s" % [
		source,
		character_count_text,
		DistributionPathsScript.get_characters_directory().path_join(model.pack_id),
	]

func _refresh_character_selector() -> void:
	selected_character_index = clampi(
		selected_character_index,
		0,
		maxi(0, model.characters.size() - 1)
	)
	for selector: OptionButton in character_selectors:
		selector.clear()
		for index: int in range(model.characters.size()):
			var character: Dictionary = model.characters[index]
			var profile: Dictionary = character.get("profile", {})
			var label: String = str(
				profile.get("display_name", character.get("id", "Character"))
			)
			selector.add_item("%d · %s" % [index + 1, label])
		if selector.item_count > 0:
			selector.select(selected_character_index)

func _refresh_dialogue_scope_buttons() -> void:
	if dialogue_scope_buttons.size() != 3 or model == null:
		return
	var has_conversation: bool = model.characters.size() == 2
	dialogue_scope_buttons[0].visible = model.characters.size() >= 1
	dialogue_scope_buttons[1].visible = has_conversation
	dialogue_scope_buttons[2].visible = has_conversation
	if not has_conversation:
		conversation_view = false
		selected_character_index = 0
	for index: int in range(dialogue_scope_buttons.size()):
		var selected: bool = (
			conversation_view and index == 2
			or not conversation_view and index == selected_character_index
		)
		dialogue_scope_buttons[index].set_pressed_no_signal(selected)
	if line_group_row != null:
		line_group_row.visible = not conversation_view
	_refresh_profile_mode_visibility()

func _refresh_chat_color_control(current_color: String) -> void:
	if chat_color_selector == null or chat_color_custom_edit == null:
		return
	var normalized: String = current_color.strip_edges().to_upper()
	var matched_index: int = -1
	for index: int in range(CHAT_COLOR_PRESETS.size()):
		if str(CHAT_COLOR_PRESETS[index].get("color", "")).to_upper() == normalized:
			matched_index = index
			break
	if matched_index >= 0:
		chat_color_selector.select(matched_index)
	else:
		chat_color_selector.select(CHAT_COLOR_PRESETS.size())
		model.set_custom_chat_color(selected_character_index, current_color)
	chat_color_custom_edit.text = model.get_custom_chat_color(selected_character_index)
	chat_color_custom_edit.visible = chat_color_selector.selected == CHAT_COLOR_PRESETS.size()
	_refresh_chat_color_icons()
	_update_chat_color_preview()

func _get_selected_chat_color() -> String:
	if (
		chat_color_selector == null
		or chat_color_selector.item_count == 0
		or chat_color_selector.selected < 0
	):
		return "#3A83F7"
	var metadata: String = str(chat_color_selector.get_item_metadata(chat_color_selector.selected))
	if metadata == "__custom__":
		var custom_value: String = chat_color_custom_edit.text.strip_edges()
		if custom_value.is_empty():
			custom_value = model.get_custom_chat_color(selected_character_index)
		if custom_value.is_empty():
			custom_value = "#3A83F7"
		return custom_value
	return metadata

func _on_chat_color_preset_selected(_index: int) -> void:
	if chat_color_selector == null or chat_color_custom_edit == null:
		return
	chat_color_custom_edit.visible = chat_color_selector.selected == CHAT_COLOR_PRESETS.size()
	_refresh_chat_color_icons()
	_update_chat_color_preview()
	_invalidate_secondary_locales()
	model.dirty = true

func _on_custom_chat_color_changed(value: String) -> void:
	model.set_custom_chat_color(selected_character_index, value)
	_refresh_chat_color_icons()
	_update_chat_color_preview()
	_invalidate_secondary_locales()
	model.dirty = true

func _refresh_chat_color_icons() -> void:
	if chat_color_selector == null:
		return
	var popup: PopupMenu = chat_color_selector.get_popup()
	for index: int in range(chat_color_selector.item_count):
		popup.set_item_as_radio_checkable(index, false)
		popup.set_item_as_checkable(index, false)
		var color_value: String = "#3A83F7"
		if index < CHAT_COLOR_PRESETS.size():
			color_value = str(CHAT_COLOR_PRESETS[index].get("color", color_value))
		elif model != null and not model.characters.is_empty():
			color_value = model.get_custom_chat_color(selected_character_index)
		chat_color_selector.set_item_icon(
			index,
			_chat_color_circle_icon(color_value)
		)

func _chat_color_circle_icon(color_value: String) -> Texture2D:
	var normalized: String = color_value.strip_edges().to_upper()
	var circle_color: Color = CreatorThemeScript.nav_text_color()
	if Color.html_is_valid(normalized):
		circle_color = Color.html(normalized)
	else:
		normalized = "__FALLBACK__"
	if chat_color_icon_cache.has(normalized):
		return chat_color_icon_cache[normalized] as Texture2D
	var icon_image: Image = Image.create(18, 18, false, Image.FORMAT_RGBA8)
	icon_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center: Vector2 = Vector2(9.0, 9.0)
	for y: int in range(18):
		for x: int in range(18):
			var distance: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			var alpha: float = clampf(7.75 - distance, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var pixel_color: Color = circle_color
			pixel_color.a *= alpha
			icon_image.set_pixel(x, y, pixel_color)
	var icon_texture: ImageTexture = ImageTexture.create_from_image(icon_image)
	chat_color_icon_cache[normalized] = icon_texture
	return icon_texture

func _update_chat_color_preview() -> void:
	if chat_color_selector == null:
		return
	var color_value: String = _get_selected_chat_color()
	var preview_color: Color = Color.WHITE
	if Color.html_is_valid(color_value):
		preview_color = Color.html(color_value)
	else:
		preview_color = CreatorThemeScript.nav_text_color()
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		chat_color_selector.add_theme_color_override(color_name, preview_color)
	if chat_color_custom_edit != null:
		chat_color_custom_edit.add_theme_color_override("font_color", preview_color)

func _on_profile_mode_selected(mode: String) -> void:
	if not _commit_manifest_form():
		return
	model.set_editor_mode(selected_character_index, mode)
	_refresh_profile_mode_visibility()
	_refresh_line_rows()

func _on_pack_id_input_changed(value: String) -> void:
	if suppress_identity_tracking:
		return
	pack_id_user_edited = true
	model.pack_id = value.strip_edges()
	_refresh_project_label()
	_invalidate_secondary_locales()
	model.dirty = true

func _on_pack_display_name_input_changed(value: String) -> void:
	if suppress_identity_tracking:
		return
	pack_display_name_user_edited = true
	model.display_name = value.strip_edges()
	_invalidate_secondary_locales()
	model.dirty = true

func _on_character_id_input_changed(value: String) -> void:
	if suppress_identity_tracking:
		return
	if selected_character_index >= 0 and selected_character_index < character_id_user_edited.size():
		character_id_user_edited[selected_character_index] = true
	if model.set_character_id(selected_character_index, value):
		_refresh_auto_pack_identity()
		_refresh_character_selector()
		_refresh_project_label()
		_invalidate_secondary_locales()
		model.dirty = true

func _on_character_display_name_changed(value: String) -> void:
	if suppress_identity_tracking:
		return
	if selected_character_index < 0 or selected_character_index >= model.characters.size():
		return
	var character: Dictionary = model.characters[selected_character_index]
	var profile: Dictionary = character.get("profile", {})
	profile["display_name"] = value
	character["profile"] = profile
	model.characters[selected_character_index] = character
	if (
		selected_character_index >= 0
		and selected_character_index < character_id_user_edited.size()
		and not character_id_user_edited[selected_character_index]
	):
		var generated_id: String = CreatorNamingScript.make_id(
			value,
			"character_%d" % (selected_character_index + 1)
		)
		suppress_identity_tracking = true
		manifest_profile_controls["id"].text = generated_id
		suppress_identity_tracking = false
		model.set_character_id(selected_character_index, generated_id)
	_refresh_auto_pack_identity(value)
	_refresh_character_selector()
	_refresh_project_label()
	_invalidate_secondary_locales()
	model.dirty = true

func _on_birthday_changed(_value: String) -> void:
	if suppress_identity_tracking:
		return
	_invalidate_secondary_locales()
	model.dirty = true

func _refresh_auto_pack_identity(current_name_override: String = "__NO_NAME_OVERRIDE__") -> void:
	if model == null or model.characters.is_empty():
		return
	var ids: Array[String] = []
	var names: Array[String] = []
	for index: int in range(model.characters.size()):
		var character: Dictionary = model.characters[index]
		var profile: Dictionary = character.get("profile", {})
		var character_name: String = str(profile.get("display_name", "Character %d" % (index + 1)))
		var character_id: String = str(character.get("id", "character_%d" % (index + 1)))
		if index == selected_character_index:
			if current_name_override != "__NO_NAME_OVERRIDE__":
				character_name = current_name_override
			character_id = str(manifest_profile_controls["id"].text).strip_edges()
		names.append(character_name.strip_edges())
		ids.append(character_id.strip_edges())

	suppress_identity_tracking = true
	if not pack_id_user_edited:
		var generated_pack_id: String = "_".join(ids)
		manifest_pack_controls["id"].text = generated_pack_id
		model.pack_id = generated_pack_id
	if not pack_display_name_user_edited:
		var generated_display_name: String = "&".join(names)
		manifest_pack_controls["display_name"].text = generated_display_name
		model.display_name = generated_display_name
	suppress_identity_tracking = false

func _on_default_desktop_toggled(pressed: bool) -> void:
	if model.characters.size() == 1:
		if not pressed:
			manifest_profile_controls["default_on_desktop"].set_pressed_no_signal(true)
		_set_character_desktop_default(0, true)
		return
	var other_index: int = 1 - selected_character_index
	_set_character_desktop_default(selected_character_index, pressed)
	_set_character_desktop_default(other_index, not pressed)
	_invalidate_secondary_locales()
	model.dirty = true

func _set_character_desktop_default(index: int, enabled: bool) -> void:
	if index < 0 or index >= model.characters.size():
		return
	var character: Dictionary = model.characters[index]
	var profile: Dictionary = character.get("profile", {})
	profile["desktop"] = {"default_on_desktop": enabled}
	character["profile"] = profile
	model.characters[index] = character

func _normalize_desktop_defaults() -> void:
	if model.characters.size() != 2:
		return
	var first_profile: Dictionary = model.characters[0].get("profile", {})
	var second_profile: Dictionary = model.characters[1].get("profile", {})
	var first_enabled: bool = bool((first_profile.get("desktop", {}) as Dictionary).get("default_on_desktop", true))
	var second_enabled: bool = bool((second_profile.get("desktop", {}) as Dictionary).get("default_on_desktop", false))
	if first_enabled == second_enabled:
		_set_character_desktop_default(0, true)
		_set_character_desktop_default(1, false)

func _refresh_manifest_form() -> void:
	suppress_identity_tracking = true
	if manifest_pack_controls.has("id"):
		manifest_pack_controls["id"].text = model.pack_id
		manifest_pack_controls["display_name"].text = model.display_name
		manifest_pack_controls["description"].text = model.description
		_refresh_language_selectors()
	if model.characters.is_empty():
		suppress_identity_tracking = false
		return
	_normalize_desktop_defaults()

	var character: Dictionary = model.characters[selected_character_index]
	var profile: Dictionary = character.get("profile", {})
	manifest_profile_controls["id"].text = str(character.get("id", ""))
	manifest_profile_controls["display_name"].text = str(profile.get("display_name", ""))
	var birthday: Dictionary = profile.get("birthday", {}) as Dictionary
	var birthday_text: String = ""
	if int(birthday.get("month", 0)) > 0 and int(birthday.get("day", 0)) > 0:
		birthday_text = "%02d-%02d" % [int(birthday.get("month", 0)), int(birthday.get("day", 0))]
	manifest_profile_controls["birthday"].text = birthday_text
	_refresh_chat_color_control(str(profile.get("chat_color", "#3A83F7")))

	var identity: Dictionary = profile.get("identity", {})
	manifest_profile_controls["role"].text = str(identity.get("role", ""))
	manifest_profile_controls["setting_note"].text = str(identity.get("setting_note", ""))
	manifest_profile_controls["appearance"].text = str((profile.get("appearance", {}) as Dictionary).get("summary", ""))
	manifest_profile_controls["core_personality"].text = _array_to_text(profile.get("core_personality", []))
	var voice: Dictionary = profile.get("voice", {})
	manifest_profile_controls["voice_casual"].text = str(voice.get("casual", ""))
	manifest_profile_controls["voice_avoid"].text = _array_to_text(voice.get("avoid", []))
	manifest_profile_controls["behavior_patterns"].text = _array_to_text(profile.get("behavior_patterns", []))
	manifest_profile_controls["mundane_details"].text = _array_to_text(profile.get("mundane_details", []))
	manifest_profile_controls["private_internal"].text = _array_to_text(profile.get("private_internal", []))
	var user_entity: Dictionary = profile.get("user_entity", {})
	manifest_profile_controls["user_role"].text = str(user_entity.get("role", ""))
	manifest_profile_controls["user_description"].text = str(user_entity.get("description", ""))
	manifest_profile_controls["ai_rules"].text = _array_to_text(profile.get("ai_behavior_rules", []))
	manifest_profile_controls["lore"].text = _array_to_text(profile.get("lore", []))
	var default_on_desktop: bool = bool(
		(profile.get("desktop", {}) as Dictionary).get("default_on_desktop", selected_character_index == 0)
	)
	if model.characters.size() == 1:
		default_on_desktop = true
		profile["desktop"] = {"default_on_desktop": true}
		character["profile"] = profile
		model.characters[selected_character_index] = character
	manifest_profile_controls["default_on_desktop"].set_pressed_no_signal(default_on_desktop)
	if desktop_row_control != null:
		desktop_row_control.visible = model.characters.size() == 2
	if desktop_note_control != null:
		desktop_note_control.visible = model.characters.size() == 2

	if model.characters.size() == 2:
		var other_index: int = 1 - selected_character_index
		var other_id: String = str(model.characters[other_index].get("id", ""))
		relationship_label.visible = true
		relationship_edit.visible = true
		relationship_label.text = _l("Relationship")
		var relationships: Dictionary = profile.get("relationships", {})
		var relationship: Dictionary = relationships.get(other_id, {})
		relationship_edit.text = str(relationship.get("summary", ""))
	else:
		relationship_label.visible = false
		relationship_edit.visible = false
		relationship_edit.text = ""

	suppress_identity_tracking = false
	_refresh_profile_mode_visibility()

func _commit_manifest_form() -> bool:
	if model.characters.is_empty():
		return false
	if manifest_pack_controls.has("id"):
		model.pack_id = str(manifest_pack_controls["id"].text).strip_edges()
		model.display_name = str(manifest_pack_controls["display_name"].text).strip_edges()
		model.description = str(manifest_pack_controls["description"].text)
		var default_selector: OptionButton = manifest_pack_controls["default_language"] as OptionButton
		model.default_language = str(default_selector.get_item_metadata(default_selector.selected))
		var supported_selector: OptionButton = manifest_pack_controls["supported_languages"] as OptionButton
		model.supported_languages = _comma_list(str(
			supported_selector.get_item_metadata(supported_selector.selected)
		))
		if model.supported_languages.is_empty():
			model.supported_languages = [model.default_language]
		elif not model.supported_languages.has(model.default_language):
			model.supported_languages.push_front(model.default_language)

	var new_id: String = str(manifest_profile_controls["id"].text).strip_edges()
	if not model.set_character_id(selected_character_index, new_id):
		_set_status(_l(
			"Character ID must use lowercase letters, numbers, or _, and must be unique within the pack.",
			"Character ID는 영문 소문자/숫자/_ 조합이며 팩 안에서 중복될 수 없습니다."
		), true)
		return false

	var character: Dictionary = model.characters[selected_character_index]
	var profile: Dictionary = character.get("profile", {})
	profile["display_name"] = str(manifest_profile_controls["display_name"].text).strip_edges()
	var birthday_text: String = str(manifest_profile_controls["birthday"].text).strip_edges()
	if birthday_text.is_empty():
		profile["birthday"] = {}
	else:
		var birthday_parts: PackedStringArray = birthday_text.split("-")
		if birthday_parts.size() != 2 or not birthday_parts[0].is_valid_int() or not birthday_parts[1].is_valid_int():
			_set_status(_l("Birthday must use MM-DD, or be left blank.", "생일은 MM-DD 형식으로 입력하거나 비워 두세요."), true)
			return false
		var birth_month: int = int(birthday_parts[0])
		var birth_day: int = int(birthday_parts[1])
		var max_birth_day: int = 31
		if birth_month == 2:
			max_birth_day = 29
		elif birth_month in [4, 6, 9, 11]:
			max_birth_day = 30
		if birth_month < 1 or birth_month > 12 or birth_day < 1 or birth_day > max_birth_day:
			_set_status(_l("Birthday is not a valid month/day.", "올바른 생일 월/일을 입력하세요."), true)
			return false
		profile["birthday"] = {"month": birth_month, "day": birth_day}
	profile["chat_color"] = _get_selected_chat_color()
	profile["desktop"] = {"default_on_desktop": manifest_profile_controls["default_on_desktop"].button_pressed}
	profile["identity"] = {
		"role": str(manifest_profile_controls["role"].text),
		"setting_note": str(manifest_profile_controls["setting_note"].text),
	}
	profile["appearance"] = {"summary": str(manifest_profile_controls["appearance"].text)}
	profile["core_personality"] = _text_to_array(str(manifest_profile_controls["core_personality"].text))
	profile["voice"] = {
		"casual": str(manifest_profile_controls["voice_casual"].text),
		"avoid": _text_to_array(str(manifest_profile_controls["voice_avoid"].text)),
	}
	profile["behavior_patterns"] = _text_to_array(str(manifest_profile_controls["behavior_patterns"].text))
	profile["mundane_details"] = _text_to_array(str(manifest_profile_controls["mundane_details"].text))
	profile["private_internal"] = _text_to_array(str(manifest_profile_controls["private_internal"].text))
	profile["user_entity"] = {
		"role": str(manifest_profile_controls["user_role"].text),
		"description": str(manifest_profile_controls["user_description"].text),
	}
	profile["ai_behavior_rules"] = _text_to_array(str(manifest_profile_controls["ai_rules"].text))
	profile["lore"] = _text_to_array(str(manifest_profile_controls["lore"].text))
	if model.characters.size() == 2:
		var other_index: int = 1 - selected_character_index
		var other_id: String = str(model.characters[other_index].get("id", ""))
		var relationships: Dictionary = profile.get("relationships", {})
		relationships[other_id] = {"summary": relationship_edit.text}
		profile["relationships"] = relationships
	character["profile"] = profile
	model.characters[selected_character_index] = character
	model.dirty = true
	return true

func _refresh_line_groups() -> void:
	if line_group_selector == null:
		return

	line_group_selector.clear()
	if model.characters.is_empty():
		return
	if conversation_view:
		_refresh_line_rows()
		return

	var groups: Array[Dictionary] = model.get_line_groups(selected_character_index)
	var selected: int = 0

	for index: int in range(groups.size()):
		var group: Dictionary = groups[index]
		var group_id: String = str(group.get("id", ""))
		line_group_selector.add_item(_line_group_label(group_id))
		line_group_selector.set_item_metadata(index, group_id)
		if group_id == current_line_group_id:
			selected = index

	line_group_selector.select(selected)
	if line_group_selector.item_count > 0:
		current_line_group_id = str(
			line_group_selector.get_item_metadata(selected)
		)
	_refresh_line_rows()

func _refresh_line_rows() -> void:
	if line_rows == null:
		return

	_clear_children(line_rows)
	if conversation_view:
		_refresh_conversation_rows()
		return
	var lines: Array[Dictionary] = model.get_line_group(
		selected_character_index,
		current_line_group_id
	)
	if lines.is_empty():
		var empty_label: Label = Label.new()
		var empty_message: String = "No lines yet. Use Generate all on the Save tab."
		if model.get_editor_mode(selected_character_index) == "advanced":
			empty_message = "No lines yet. Use + Line or Generate all on the Save tab."
		_bind_localized_property(
			empty_label,
			"text",
			empty_message
		)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", CreatorThemeScript.muted())
		line_rows.add_child(empty_label)

	for line: Dictionary in lines:
		_add_line_row(line)

	line_status.text = ""

func _refresh_conversation_rows() -> void:
	if model.conversations.is_empty():
		var empty_label: Label = Label.new()
		var empty_message: String = "No conversations yet. Use Generate all on the Save tab."
		if model.get_editor_mode(selected_character_index) == "advanced":
			empty_message = "No conversations yet. Use + Line or Generate all on the Save tab."
		_bind_localized_property(
			empty_label,
			"text",
			empty_message
		)
		empty_label.add_theme_color_override("font_color", CreatorThemeScript.muted())
		line_rows.add_child(empty_label)
		line_status.text = ""
		return
	for conversation_index: int in range(model.conversations.size()):
		var conversation: Dictionary = model.conversations[conversation_index]
		var panel: PanelContainer = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", CreatorThemeScript.row_panel())
		line_rows.add_child(panel)
		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		panel.add_child(margin)
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		margin.add_child(box)
		var title_row: HBoxContainer = HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 8)
		box.add_child(title_row)
		var title: Label = Label.new()
		title.text = _l("Conversation %d", "대화 %d") % (conversation_index + 1)
		title.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_MEDIUM)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		var play_button: Button = _toolbar_button(
			"Play",
			_on_preview_conversation.bind(conversation.duplicate(true))
		)
		play_button.custom_minimum_size.x = 72.0
		title_row.add_child(play_button)
		var turns_value: Variant = conversation.get("turns", [])
		if not (turns_value is Array):
			continue
		for turn_value: Variant in turns_value as Array:
			if not (turn_value is Dictionary):
				continue
			var turn: Dictionary = turn_value as Dictionary
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			box.add_child(row)
			var speaker: Label = Label.new()
			speaker.text = "%s · %s" % [
				_speaker_display_name(str(turn.get("speaker", ""))),
				_mood_label(str(turn.get("mood", "neutral")))
			]
			speaker.custom_minimum_size.x = 170.0
			speaker.add_theme_color_override("font_color", CreatorThemeScript.muted())
			row.add_child(speaker)
			var text_label: Label = Label.new()
			text_label.text = str(turn.get("text", ""))
			text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text_label)
	line_status.text = ""

func _speaker_display_name(character_id: String) -> String:
	for character: Dictionary in model.characters:
		if str(character.get("id", "")) != character_id:
			continue
		var profile: Dictionary = character.get("profile", {})
		return str(profile.get("display_name", character_id))
	return character_id

func _add_line_row(line: Dictionary = {}) -> void:
	if (
		line_rows.get_child_count() == 1
		and line_rows.get_child(0) is Label
		and not (line_rows.get_child(0) is LineEdit)
	):
		_clear_children(line_rows)

	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		CreatorThemeScript.row_panel()
	)
	line_rows.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)

	var mood: OptionButton = OptionButton.new()
	mood.custom_minimum_size = Vector2(
		145,
		CreatorThemeScript.CONTROL_HEIGHT
	)
	var mood_value: String = str(line.get("mood", "neutral"))
	var selected_mood: int = 0
	for index: int in range(MOODS.size()):
		mood.add_item(_mood_label(MOODS[index]))
		mood.set_item_metadata(index, MOODS[index])
		if MOODS[index] == mood_value:
			selected_mood = index
	mood.select(selected_mood)
	mood.item_selected.connect(_mark_dirty_int)
	row.add_child(mood)

	var text_edit: LineEdit = LineEdit.new()
	text_edit.text = str(line.get("text", ""))
	_bind_localized_property(text_edit, "placeholder_text", "Line")
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.custom_minimum_size.y = CreatorThemeScript.CONTROL_HEIGHT
	text_edit.text_changed.connect(_mark_dirty_text)
	row.add_child(text_edit)

	var play_button: Button = _toolbar_button(
		"Play",
		_on_preview_line.bind(mood, text_edit, selected_character_index)
	)
	play_button.custom_minimum_size.x = 72.0
	row.add_child(play_button)

	var delete_button: Button = Button.new()
	delete_button.text = "×"
	delete_button.custom_minimum_size = Vector2(
		38,
		CreatorThemeScript.CONTROL_HEIGHT
	)
	delete_button.pressed.connect(_on_delete_line.bind(panel))
	row.add_child(delete_button)

func _on_preview_line(
	mood_selector: OptionButton,
	text_edit: LineEdit,
	character_index: int
) -> void:
	preview_playback_token += 1
	var text_value: String = text_edit.text.strip_edges()
	if text_value.is_empty():
		_set_line_preview_status(_l("Enter a line before playing it."), true)
		return
	var mood_value: String = str(
		mood_selector.get_item_metadata(mood_selector.selected)
	)
	var actor: DesktopCharacterActor = _get_preview_actor_for_character_index(character_index)
	if actor == null:
		return
	_set_line_preview_status("")
	actor.show_dialogue(
		{"text": text_value, "mood": mood_value},
		_preview_line_duration(text_value)
	)

func _on_preview_conversation(conversation: Dictionary) -> void:
	preview_playback_token += 1
	var playback_token: int = preview_playback_token
	var turns_value: Variant = conversation.get("turns", [])
	if not (turns_value is Array):
		return
	for turn_value: Variant in turns_value as Array:
		if playback_token != preview_playback_token:
			return
		if not (turn_value is Dictionary):
			continue
		var turn: Dictionary = turn_value as Dictionary
		var text_value: String = str(turn.get("text", "")).strip_edges()
		if text_value.is_empty():
			continue
		var character_index: int = _creator_character_index_for_id(
			str(turn.get("speaker", ""))
		)
		var actor: DesktopCharacterActor = _get_preview_actor_for_character_index(character_index)
		if actor == null:
			return
		var duration: float = _preview_line_duration(text_value)
		_set_line_preview_status("")
		actor.show_dialogue(
			{"text": text_value, "mood": str(turn.get("mood", "neutral"))},
			duration
		)
		await get_tree().create_timer(duration + 0.25).timeout

func _creator_character_index_for_id(character_id: String) -> int:
	for index: int in range(model.characters.size()):
		if str(model.characters[index].get("id", "")) == character_id:
			return index
	return 0

func _get_preview_actor_for_character_index(
	character_index: int
) -> DesktopCharacterActor:
	if desktop_character_manager == null or not is_instance_valid(desktop_character_manager):
		_set_line_preview_status(_l("No desktop character is available for preview."), true)
		return null

	var character_ids: Array[String] = desktop_character_manager.get_active_character_ids()
	if character_ids.is_empty():
		var unavailable_message: String = _l("Characters are still loading.")
		if desktop_characters_ready:
			unavailable_message = _l("No desktop character is available for preview.")
		_set_line_preview_status(unavailable_message, true)
		return null

	var mapped_index: int = clampi(character_index, 0, character_ids.size() - 1)
	var actor: DesktopCharacterActor = desktop_character_manager.get_actor(character_ids[mapped_index])
	if actor != null:
		return actor
	_set_line_preview_status(_l("No desktop character is available for preview."), true)
	return null

func _sync_desktop_character_preview(mood: String = "") -> void:
	if (
		model == null
		or model.characters.is_empty()
		or desktop_character_manager == null
		or not is_instance_valid(desktop_character_manager)
	):
		return

	desktop_character_manager.set_preview_visible_character_limit(model.characters.size())
	var character_ids: Array[String] = desktop_character_manager.get_active_character_ids()
	for character_index: int in range(mini(model.characters.size(), character_ids.size())):
		var actor: DesktopCharacterActor = desktop_character_manager.get_actor(character_ids[character_index])
		if actor == null:
			continue
		var selected_mood: String = "neutral"
		if character_index == selected_character_index and not mood.is_empty():
			selected_mood = mood
		_apply_creator_sprites_to_actor(actor, character_index, selected_mood)

func _apply_creator_sprites_to_actor(
	actor: DesktopCharacterActor,
	character_index: int,
	mood: String
) -> void:
	var body_texture: Texture2D = _creator_sprite_texture(character_index, "body")
	if actor.body_sprite != null and body_texture != null:
		actor.body_sprite.texture = body_texture
		actor.configure_body_variants(actor.body_sprite, {"default": body_texture})

	if actor.expression_controller != null and actor.expression_controller.expression_sprite != null:
		var expression: AnimatedSprite2D = actor.expression_controller.expression_sprite
		var expression_frames := SpriteFrames.new()
		expression_frames.remove_animation(&"default")
		for mood_name: String in MOODS:
			var mood_texture: Texture2D = _creator_sprite_texture(character_index, mood_name)
			if mood_texture == null:
				continue
			var animation_name := StringName(mood_name)
			expression_frames.add_animation(animation_name)
			expression_frames.add_frame(animation_name, mood_texture)
			expression_frames.set_animation_loop(animation_name, true)
		expression.sprite_frames = expression_frames

	if actor.eyes != null:
		var eye_frames := SpriteFrames.new()
		eye_frames.remove_animation(&"default")
		eye_frames.add_animation(&"blink")
		for eye_slot: String in ["eyes_open", "eyes_half", "eyes_closed", "eyes_half", "eyes_open"]:
			var eye_texture: Texture2D = _creator_sprite_texture(character_index, eye_slot)
			if eye_texture != null:
				eye_frames.add_frame(&"blink", eye_texture)
		eye_frames.set_animation_loop(&"blink", false)
		eye_frames.set_animation_speed(&"blink", 12.0)
		actor.eyes.sprite_frames = eye_frames
		actor.eyes.animation = &"blink"
		actor.eyes.frame = 0

	var visible_mood: String = mood
	if visible_mood == "body" or visible_mood.begins_with("eyes_"):
		visible_mood = "neutral"
	actor.set_mood(visible_mood)

func _creator_sprite_texture(character_index: int, slot: String) -> Texture2D:
	var effective: Dictionary = model.get_effective_sprite(character_index, slot)
	return _load_texture(str(effective.get("path", PackModelScript.PLACEHOLDER_PATH)))

func _preview_line_duration(text_value: String) -> float:
	return clampf(2.6 + float(text_value.length()) * 0.035, 3.0, 8.0)

func _set_line_preview_status(message: String, error: bool = false) -> void:
	if line_status == null:
		return
	line_status.text = message
	line_status.add_theme_color_override(
		"font_color",
		CreatorThemeScript.danger() if error else CreatorThemeScript.muted()
	)

func _commit_line_rows() -> void:
	if conversation_view or model == null or model.characters.is_empty() or line_rows == null:
		return

	var lines: Array[Dictionary] = []
	for child: Node in line_rows.get_children():
		if not (child is PanelContainer):
			continue

		var panel: PanelContainer = child as PanelContainer
		var margin: MarginContainer = panel.get_child(0) as MarginContainer
		var row: HBoxContainer = margin.get_child(0) as HBoxContainer
		var mood: OptionButton = row.get_child(0) as OptionButton
		var text_edit: LineEdit = row.get_child(1) as LineEdit
		var text_value: String = text_edit.text.strip_edges()

		if text_value.is_empty():
			continue

		var mood_value: String = str(
			mood.get_item_metadata(mood.selected)
		)
		lines.append({
			"text": text_value,
			"mood": mood_value
		})

	model.set_line_group(
		selected_character_index,
		current_line_group_id,
		lines
	)

func _refresh_sprite_tab() -> void:
	if model.characters.is_empty():
		return
	var character: Dictionary = model.characters[selected_character_index]
	var mode := str(character.get("sprite_mode", "natural"))
	var mode_index := 1
	if mode == "simple": mode_index = 0
	elif mode == "expressive": mode_index = 2
	if mode == "simple":
		preview_slot = "eyes_open"
	elif mode == "natural" and preview_slot != "body" and not PackModelScript.NATURAL_PRIMARY.has(preview_slot):
		preview_slot = "eyes_open"
	sprite_mode_selector.select(mode_index)
	_refresh_sprite_cards()
	_refresh_sprite_preview()

func _refresh_sprite_cards() -> void:
	if sprite_grid == null or model.characters.is_empty():
		return

	_clear_children(sprite_grid)

	var mode: String = str(
		model.characters[selected_character_index].get(
			"sprite_mode",
			"natural"
		)
	)
	var sections: Array[Dictionary] = []

	match mode:
		"simple":
			sections = [
				{"title": "BODY", "slots": ["body"]},
				{"title": "BLINK", "slots": ["eyes_open"]},
			]
		"expressive":
			sections = [
				{"title": "BODY", "slots": ["body"]},
				{"title": "BLINK", "slots": PackModelScript.BLINK_SLOTS},
				{"title": "EMOTION", "slots": PackModelScript.EMOTION_SLOTS},
			]
		_:
			sections = [
				{"title": "BODY", "slots": ["body"]},
				{"title": "BLINK", "slots": PackModelScript.BLINK_SLOTS},
				{
					"title": "EMOTION",
					"slots": [
						"angry",
						"happy",
						"sad",
						"surprised",
						"embarrassed"
					]
				},
			]

	for section: Dictionary in sections:
		var heading: Label = Label.new()
		heading.text = _l(str(section.get("title", "")))
		heading.add_theme_font_size_override(
			"font_size",
			CreatorThemeScript.FONT_SMALL
		)
		heading.add_theme_color_override(
			"font_color",
			CreatorThemeScript.muted()
		)
		sprite_grid.add_child(heading)

		var slot_values: Variant = section.get("slots", [])
		if slot_values is Array:
			for slot_value: Variant in slot_values as Array:
				sprite_grid.add_child(
					_build_sprite_card(str(slot_value))
				)

func _build_sprite_card(slot: String) -> Control:
	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 5)

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 104.0
	row.add_theme_constant_override("separation", 8)
	wrapper.add_child(row)

	var preview: TextureRect = TextureRect.new()
	preview.custom_minimum_size = Vector2(64, 96)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var effective: Dictionary = model.get_effective_sprite(
		selected_character_index,
		slot
	)
	preview.texture = _load_texture(
		str(
			effective.get(
				"path",
				PackModelScript.PLACEHOLDER_PATH
			)
		)
	)
	preview.mouse_filter = Control.MOUSE_FILTER_STOP
	preview.gui_input.connect(
		_on_sprite_card_gui_input.bind(slot)
	)
	row.add_child(preview)

	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_box.add_theme_constant_override("separation", 4)
	row.add_child(info_box)

	var title: Label = Label.new()
	title.text = _sprite_slot_label(slot)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_child(title)

	var direct: String = model.get_sprite_path(
		selected_character_index,
		slot
	)
	var info: Label = Label.new()
	info.add_theme_font_size_override(
		"font_size",
		CreatorThemeScript.FONT_SMALL
	)

	if direct.is_empty():
		info.text = "%s · %s" % [
			_l("Fallback"),
			str(effective.get("source", "placeholder"))
		]
		info.add_theme_color_override(
			"font_color",
			CreatorThemeScript.muted()
		)
	else:
		var origin: String = model.get_sprite_origin(selected_character_index, slot)
		match origin:
			"default":
				info.text = _l("Default")
				info.add_theme_color_override("font_color", CreatorThemeScript.accent())
			"existing":
				info.text = _l("Existing")
				info.add_theme_color_override("font_color", CreatorThemeScript.muted())
			_:
				info.text = _l("Uploaded")
				info.add_theme_color_override("font_color", CreatorThemeScript.success())

	info_box.add_child(info)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buttons)

	var upload: Button = _toolbar_button(
		"Upload",
		_on_upload_sprite.bind(slot)
	)
	upload.custom_minimum_size.x = 70.0
	buttons.add_child(upload)

	var clear: Button = _toolbar_button(
		"Clear",
		_on_clear_sprite.bind(slot)
	)
	clear.custom_minimum_size.x = 58.0
	clear.disabled = direct.is_empty()
	buttons.add_child(clear)

	wrapper.add_child(HSeparator.new())
	return wrapper

func _refresh_sprite_preview() -> void:
	if model.characters.is_empty():
		return

	var body: Dictionary = model.get_effective_sprite(
		selected_character_index,
		"body"
	)
	var face: Dictionary = model.get_effective_sprite(
		selected_character_index,
		preview_slot
	)

	sprite_preview_body.texture = _load_texture(
		str(
			body.get(
				"path",
				PackModelScript.PLACEHOLDER_PATH
			)
		)
	)

	if preview_slot == "body":
		sprite_preview_face.texture = null
	else:
		sprite_preview_face.texture = _load_texture(
			str(
				face.get(
					"path",
					PackModelScript.PLACEHOLDER_PATH
				)
			)
		)

	var fallback_text: String = ""
	if bool(face.get("fallback", false)):
		fallback_text = " · %s: %s" % [
			_l("Fallback"),
			str(face.get("source", "placeholder"))
		]

	sprite_preview_caption.text = "%s%s" % [
		_sprite_slot_label(preview_slot),
		fallback_text
	]

func _on_new_one() -> void:
	_commit_current_edits()
	model.set_character_count(1)
	model.secondary_locales.clear()
	selected_character_index = mini(selected_character_index, 0)
	_refresh_all()
	_refresh_auto_pack_identity()
	_sync_desktop_character_preview()
	_set_status(_l(
		"This pack is now set to one character. Character 2 data is preserved.",
		"현재 팩을 1인으로 설정했습니다. 캐릭터 2의 편집 내용은 보존됩니다."
	))

func _on_new_two() -> void:
	_commit_current_edits()
	model.set_character_count(2)
	model.secondary_locales.clear()
	_refresh_all()
	_refresh_auto_pack_identity()
	_sync_desktop_character_preview()
	_set_status(_l(
		"This pack is now set to two characters.",
		"현재 팩을 2인으로 설정했습니다."
	))

func _on_manifest_file_selected(path: String) -> void:
	_commit_current_edits()
	var result: Dictionary = model.load_existing(path, _current_language_code())
	if not bool(result.get("ok", false)):
		_set_status(
			_localize_model_message(
				str(result.get("message", "Could not load pack."))
			),
			true
		)
		if not startup_selection_made and startup_window != null:
			startup_window.popup_centered()
		return

	startup_selection_made = true
	pack_id_user_edited = true
	pack_display_name_user_edited = true
	character_id_user_edited = [true, true]
	selected_character_index = 0
	current_line_group_id = "idle"
	_refresh_all()
	_sync_desktop_character_preview()
	_set_status(_localize_model_message(
		str(result.get("message", "Pack loaded."))
	))

func _on_export() -> void:
	if save_pipeline_active:
		return
	if not _commit_current_edits():
		return

	var missing_required: Array[String] = _collect_required_field_errors()
	if not missing_required.is_empty():
		_show_required_field_error(missing_required)
		return

	save_pipeline_active = true
	_continue_save()

func _collect_required_field_errors(include_generated_locales: bool = true) -> Array[String]:
	var errors: Array[String] = []
	if model.pack_id.strip_edges().is_empty():
		errors.append(_l("Pack ID"))
	if model.display_name.strip_edges().is_empty():
		errors.append(_l("Display name"))

	for index: int in range(model.characters.size()):
		var character: Dictionary = model.characters[index]
		var profile: Dictionary = character.get("profile", {})
		var character_name: String = str(profile.get("display_name", "")).strip_edges()
		var prefix: String = character_name
		if prefix.is_empty():
			prefix = str(character.get("id", "Character %d" % (index + 1)))
		if character_name.is_empty():
			errors.append("%s · %s" % [prefix, _l("Display name")])
		var identity: Dictionary = profile.get("identity", {})
		if str(identity.get("role", "")).strip_edges().is_empty():
			errors.append("%s · %s" % [prefix, _l("Role")])
		var appearance: Dictionary = profile.get("appearance", {})
		if str(appearance.get("summary", "")).strip_edges().is_empty():
			errors.append("%s · %s" % [prefix, _l("Appearance")])
		var personality_value: Variant = profile.get("core_personality", [])
		if not (personality_value is Array) or (personality_value as Array).is_empty():
			errors.append("%s · %s" % [prefix, _l("Personality")])
		var voice: Dictionary = profile.get("voice", {})
		if str(voice.get("casual", "")).strip_edges().is_empty():
			errors.append("%s · %s" % [prefix, _l("Voice")])
		var chat_color: String = str(profile.get("chat_color", "")).strip_edges()
		if not Color.html_is_valid(chat_color):
			errors.append("%s · %s" % [prefix, _l("Chat color")])
	if include_generated_locales:
		for language: String in model.supported_languages:
			if language == model.default_language or model.secondary_locales.has(language):
				continue
			errors.append("%s · %s" % [
				_l("Additional locales"),
				_language_display_name(language)
			])
	return errors

func _show_required_field_error(errors: Array[String]) -> void:
	if save_validation_dialog == null:
		_build_save_validation_dialog()
	var lines: PackedStringArray = PackedStringArray()
	for item: String in errors:
		lines.append("• " + item)
	save_validation_message.text = "\n".join(lines)
	_apply_language_to_node(save_validation_dialog)
	save_validation_dialog.theme = CreatorThemeScript.build()
	save_validation_background.color = CreatorThemeScript.background()
	save_validation_panel.add_theme_stylebox_override("panel", CreatorThemeScript.board_panel())
	save_validation_dialog.popup_centered()

func _build_save_validation_dialog() -> void:
	save_validation_dialog = Window.new()
	_bind_localized_property(save_validation_dialog, "title", "Missing required fields")
	save_validation_dialog.theme = CreatorThemeScript.build()
	save_validation_dialog.size = Vector2i(560, 360)
	save_validation_dialog.min_size = Vector2i(500, 300)
	save_validation_dialog.transient = true
	save_validation_dialog.close_requested.connect(save_validation_dialog.hide)
	add_child(save_validation_dialog)

	save_validation_background = ColorRect.new()
	save_validation_background.color = CreatorThemeScript.background()
	save_validation_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	save_validation_dialog.add_child(save_validation_background)

	var outer_margin: MarginContainer = MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 18)
	outer_margin.add_theme_constant_override("margin_right", 18)
	outer_margin.add_theme_constant_override("margin_top", 18)
	outer_margin.add_theme_constant_override("margin_bottom", 18)
	save_validation_dialog.add_child(outer_margin)

	save_validation_panel = PanelContainer.new()
	save_validation_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_validation_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	save_validation_panel.add_theme_stylebox_override("panel", CreatorThemeScript.board_panel())
	outer_margin.add_child(save_validation_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	save_validation_panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title: Label = Label.new()
	_bind_localized_property(title, "text", "Missing required fields")
	title.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_LARGE)
	box.add_child(title)

	var note: Label = Label.new()
	_bind_localized_property(note, "text", "Fill the following required fields first:")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	note.add_theme_color_override("font_color", CreatorThemeScript.muted())
	box.add_child(note)

	var message_scroll: ScrollContainer = ScrollContainer.new()
	message_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(message_scroll)

	save_validation_message = Label.new()
	save_validation_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_validation_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_validation_message.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	message_scroll.add_child(save_validation_message)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	buttons.add_child(_toolbar_button("Close", save_validation_dialog.hide))
	_apply_language_to_node(save_validation_dialog)

func _on_profile_generation_finished(fields: Dictionary) -> void:
	if not bulk_generation_active or pending_profile_character_index < 0:
		return
	var character_index: int = pending_profile_character_index
	model.apply_generated_profile_fields(character_index, fields)
	if not model.get_missing_advanced_profile_fields(character_index).is_empty():
		_finish_bulk_generation_error(_l(
			"AI returned an incomplete advanced profile.",
			"AI가 고급 프로필 항목을 모두 생성하지 못했습니다."
		))
		return
	if character_index == selected_character_index:
		_refresh_manifest_form()
	bulk_generation_completed_steps += 1
	_refresh_save_checklist()
	pending_profile_character_index = -1
	_generate_next_bulk_profile()

func _on_profile_generation_failed(message: String) -> void:
	if not bulk_generation_active:
		return
	_finish_bulk_generation_error(message)

func _continue_save() -> void:
	if not save_pipeline_active:
		return
	var warnings: Array[Dictionary] = model.get_sprite_save_warnings()
	if warnings.is_empty():
		_perform_export()
		return
	_show_sprite_save_warning(warnings)

func _show_sprite_save_warning(warnings: Array[Dictionary]) -> void:
	if sprite_warning_dialog == null:
		_build_sprite_warning_dialog()

	var detail_lines: PackedStringArray = PackedStringArray()
	var shown_count: int = mini(warnings.size(), 12)
	for index: int in range(shown_count):
		var warning: Dictionary = warnings[index]
		var kind_label: String = _l("Default") if str(warning.get("kind", "")) == "default" else _l("Missing")
		detail_lines.append("• %s · %s · %s" % [
			str(warning.get("character", "")),
			_sprite_slot_label(str(warning.get("slot", ""))),
			kind_label
		])
	if warnings.size() > shown_count:
		detail_lines.append("… +%d" % (warnings.size() - shown_count))

	sprite_warning_message.text = "\n".join(detail_lines)
	_apply_language_to_node(sprite_warning_dialog)
	sprite_warning_dialog.theme = CreatorThemeScript.build()
	sprite_warning_background.color = CreatorThemeScript.background()
	sprite_warning_panel.add_theme_stylebox_override("panel", CreatorThemeScript.board_panel())
	sprite_warning_dialog.popup_centered()

func _build_sprite_warning_dialog() -> void:
	sprite_warning_dialog = Window.new()
	_bind_localized_property(sprite_warning_dialog, "title", "Save warning")
	sprite_warning_dialog.theme = CreatorThemeScript.build()
	sprite_warning_dialog.size = Vector2i(620, 440)
	sprite_warning_dialog.min_size = Vector2i(540, 340)
	sprite_warning_dialog.transient = true
	sprite_warning_dialog.close_requested.connect(_on_sprite_warning_cancelled)
	add_child(sprite_warning_dialog)

	sprite_warning_background = ColorRect.new()
	sprite_warning_background.color = CreatorThemeScript.background()
	sprite_warning_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite_warning_dialog.add_child(sprite_warning_background)

	var outer_margin: MarginContainer = MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 18)
	outer_margin.add_theme_constant_override("margin_right", 18)
	outer_margin.add_theme_constant_override("margin_top", 18)
	outer_margin.add_theme_constant_override("margin_bottom", 18)
	sprite_warning_dialog.add_child(outer_margin)

	sprite_warning_panel = PanelContainer.new()
	sprite_warning_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_warning_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite_warning_panel.add_theme_stylebox_override("panel", CreatorThemeScript.board_panel())
	outer_margin.add_child(sprite_warning_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	sprite_warning_panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title: Label = Label.new()
	_bind_localized_property(title, "text", "Save warning")
	title.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_LARGE)
	box.add_child(title)

	var note: Label = Label.new()
	_bind_localized_property(note, "text", "Some sprites are missing or still use the Creator defaults.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	note.add_theme_color_override("font_color", CreatorThemeScript.muted())
	box.add_child(note)

	var message_scroll: ScrollContainer = ScrollContainer.new()
	message_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(message_scroll)

	sprite_warning_message = Label.new()
	sprite_warning_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_warning_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sprite_warning_message.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	message_scroll.add_child(sprite_warning_message)

	var confirmation: Label = Label.new()
	_bind_localized_property(confirmation, "text", "Save with missing sprites routed to available fallbacks/neutral?")
	confirmation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation.add_theme_font_size_override("font_size", CreatorThemeScript.FONT_SMALL)
	confirmation.add_theme_color_override("font_color", CreatorThemeScript.muted())
	box.add_child(confirmation)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 6)
	box.add_child(buttons)
	buttons.add_child(_toolbar_button("Cancel", _on_sprite_warning_cancelled))
	var save_button: Button = _toolbar_button("Save", _on_sprite_warning_confirmed)
	save_button.add_theme_stylebox_override(
		"normal",
		CreatorThemeScript.box(CreatorThemeScript.soft_accent(), CreatorThemeScript.soft_accent(), 9, 0.0)
	)
	buttons.add_child(save_button)
	_apply_language_to_node(sprite_warning_dialog)

func _on_sprite_warning_confirmed() -> void:
	sprite_warning_dialog.hide()
	_perform_export()

func _on_sprite_warning_cancelled() -> void:
	sprite_warning_dialog.hide()
	_cancel_save_pipeline()

func _perform_export() -> void:
	if not save_pipeline_active:
		return
	var result: Dictionary = model.export_to(
		DistributionPathsScript.get_characters_directory()
	)
	_set_status(
		_localize_model_message(str(result.get("message", "Save complete."))),
		not bool(result.get("ok", false))
	)
	if bool(result.get("ok", false)):
		model.source_root = str(result.get("path", ""))
		if generation_error_label != null:
			generation_error_label.visible = false
	elif generation_error_label != null:
		generation_error_label.text = "%s: %s" % [
			_l("Save error"),
			_localize_model_message(str(result.get("message", "Save failed.")))
		]
		generation_error_label.visible = true
	_refresh_project_label()
	_refresh_save_checklist()
	_cancel_save_pipeline(false)

func _cancel_save_pipeline(clear_status: bool = true) -> void:
	save_pipeline_active = false
	profile_generation_queue.clear()
	pending_profile_character_index = -1
	if clear_status:
		_set_status("")

func _on_character_selected(index: int) -> void:
	_commit_current_edits()
	conversation_view = false
	selected_character_index = clampi(index, 0, maxi(0, model.characters.size() - 1))
	_refresh_dialogue_scope_buttons()
	_refresh_manifest_form()
	_refresh_line_groups()
	_refresh_sprite_tab()
	_sync_desktop_character_preview(preview_slot)

func _on_tab_changed(_tab: int) -> void:
	_commit_current_edits()
	_refresh_project_label()
	_sync_index_tab_buttons()
	_refresh_save_checklist()

func _on_line_group_selected(index: int) -> void:
	_commit_line_rows()
	current_line_group_id = str(line_group_selector.get_item_metadata(index))
	_refresh_line_rows()

func _on_dialogue_scope_selected(index: int) -> void:
	if index < 0 or index >= dialogue_scope_buttons.size():
		return
	if index == 2 and model.characters.size() < 2:
		return
	if not _commit_current_edits():
		return
	conversation_view = index == 2
	if not conversation_view:
		selected_character_index = clampi(index, 0, model.characters.size() - 1)
	_refresh_character_selector()
	_refresh_manifest_form()
	_refresh_dialogue_scope_buttons()
	_refresh_line_groups()
	_refresh_sprite_tab()

func _on_add_line() -> void:
	if conversation_view:
		return
	if line_rows.get_child_count() == 1 and line_rows.get_child(0) is Label:
		_clear_children(line_rows)
	_add_line_row({"text": "", "mood": "neutral"})
	_invalidate_secondary_locales()
	model.dirty = true

func _on_delete_line(panel: PanelContainer) -> void:
	panel.queue_free()
	await get_tree().process_frame
	_commit_line_rows()
	_invalidate_secondary_locales()
	_refresh_line_rows()

func _on_bulk_generate() -> void:
	if bulk_generation_active:
		_cancel_bulk_generation()
		return
	if save_pipeline_active:
		return
	if not _commit_current_edits():
		return
	var missing_required: Array[String] = _collect_required_field_errors(false)
	if not missing_required.is_empty():
		_refresh_bulk_generate_button_state(missing_required)
		_show_required_field_error(missing_required)
		return
	var settings: Dictionary = ai.load_settings()
	if (
		str(settings.get("api_key", "")).strip_edges().is_empty()
		or str(settings.get("model", "")).strip_edges().is_empty()
	):
		_finish_bulk_generation_error(_l("AI settings are missing"))
		return

	bulk_generation_active = true
	bulk_generation_completed_steps = 0
	if generation_error_label != null:
		generation_error_label.visible = false
	profile_generation_queue.clear()
	for character_index: int in range(model.characters.size()):
		if not model.get_missing_advanced_profile_fields(character_index).is_empty():
			profile_generation_queue.append(character_index)
	var missing_dialogue_characters: int = 0
	for character_index: int in range(model.characters.size()):
		for group: Dictionary in model.get_line_groups(character_index):
			var group_id: String = str(group.get("id", ""))
			if model.get_line_group(character_index, group_id).is_empty():
				missing_dialogue_characters += 1
				break
	bulk_generation_total_steps = profile_generation_queue.size() + missing_dialogue_characters
	if model.characters.size() == 2 and model.conversations.is_empty():
		bulk_generation_total_steps += 1
	for language: String in model.supported_languages:
		if language != model.default_language and not model.secondary_locales.has(language):
			bulk_generation_total_steps += 1
	_refresh_bulk_generate_button_state([])
	_set_bulk_generation_progress(_l("Preparing generation", "생성 준비 중"))
	_generate_next_bulk_profile()

func _generate_next_bulk_profile() -> void:
	if not bulk_generation_active:
		return
	if profile_generation_queue.is_empty():
		dialogue_generation_queue.clear()
		dialogue_generated_group_count = 0
		for character_index: int in range(model.characters.size()):
			for group: Dictionary in model.get_line_groups(character_index):
				var group_id: String = str(group.get("id", ""))
				if model.get_line_group(character_index, group_id).is_empty():
					dialogue_generation_queue.append(character_index)
					break
		_generate_next_character_dialogue()
		return
	pending_profile_character_index = profile_generation_queue.pop_front()
	_set_bulk_generation_progress(
		_l("Generating profile: %s", "프로필 생성 중: %s")
		% _character_display_name(pending_profile_character_index)
	)
	ai.generate_profile_defaults(model, pending_profile_character_index)

func _generate_next_character_dialogue() -> void:
	if dialogue_generation_queue.is_empty():
		dialogue_generation_character_index = -1
		_refresh_line_groups()
		line_status.text = _l(
			"%d groups generated",
			"%d개 그룹 생성"
		) % dialogue_generated_group_count
		if bulk_generation_active:
			if model.characters.size() == 2 and model.conversations.is_empty():
				_set_bulk_generation_progress(_l("Generating conversation", "대화 생성 중"))
				ai.generate_conversations(model)
			else:
				_start_bulk_locale_generation()
		return
	dialogue_generation_character_index = dialogue_generation_queue.pop_front()
	_set_bulk_generation_progress(
		_l("Generating dialogue: %s", "대사 생성 중: %s")
		% _character_display_name(dialogue_generation_character_index)
	)
	ai.generate_defaults(model, dialogue_generation_character_index)

func _on_generation_finished(groups: Dictionary) -> void:
	if not bulk_generation_active:
		return
	var applied: int = model.apply_generated_groups(
		dialogue_generation_character_index,
		groups
	)
	dialogue_generated_group_count += applied
	bulk_generation_completed_steps += 1
	_generate_next_character_dialogue()

func _on_generation_failed(message: String) -> void:
	if not bulk_generation_active:
		return
	dialogue_generation_queue.clear()
	dialogue_generation_character_index = -1
	line_status.text = _l("Generation failed", "생성 실패")
	_set_status(message, true)
	if bulk_generation_active:
		_finish_bulk_generation_error(message)

func _on_conversation_generation_finished(conversations: Array) -> void:
	if not bulk_generation_active:
		return
	if model.apply_generated_conversations(conversations) <= 0:
		_finish_bulk_generation_error(_l(
			"The generation result did not contain conversations.",
			"생성 결과에 대화가 없습니다."
		))
		return
	if conversation_view:
		_refresh_line_rows()
	bulk_generation_completed_steps += 1
	_start_bulk_locale_generation()

func _on_conversation_generation_failed(message: String) -> void:
	if bulk_generation_active:
		_finish_bulk_generation_error(message)

func _start_bulk_locale_generation() -> void:
	pending_locale_languages.clear()
	for language: String in model.supported_languages:
		if language != model.default_language and not model.secondary_locales.has(language):
			pending_locale_languages.append(language)
	_generate_next_locale()

func _generate_next_locale() -> void:
	if not bulk_generation_active:
		return
	if pending_locale_languages.is_empty():
		_finish_bulk_generation_success()
		return
	var language: String = pending_locale_languages.pop_front()
	_set_bulk_generation_progress(
		_l("Generating locale: %s", "로캘 생성 중: %s")
		% _language_display_name(language)
	)
	ai.generate_locale(model, language)

func _on_locale_generation_finished(language: String, locale_data: Dictionary) -> void:
	if not bulk_generation_active:
		return
	if language.is_empty() or not _is_valid_generated_locale(locale_data):
		_finish_bulk_generation_error(_l(
			"The generated locale was not valid JSON.",
			"생성된 로캘을 JSON으로 해석할 수 없습니다."
		))
		return
	model.set_secondary_locale(language, locale_data)
	bulk_generation_completed_steps += 1
	_generate_next_locale()

func _is_valid_generated_locale(locale_data: Dictionary) -> bool:
	var characters_value: Variant = locale_data.get("characters", {})
	if not (characters_value is Dictionary):
		return false
	var translated_characters: Dictionary = characters_value as Dictionary
	for character: Dictionary in model.characters:
		var character_id: String = str(character.get("id", ""))
		var character_value: Variant = translated_characters.get(character_id, {})
		if not (character_value is Dictionary):
			return false
		var character_data: Dictionary = character_value as Dictionary
		if not (character_data.get("profile", null) is Dictionary):
			return false
		if not (character_data.get("dialogue", null) is Dictionary):
			return false
	if not (locale_data.get("desktop_events", null) is Dictionary):
		return false
	if not (locale_data.get("play_profiles", null) is Dictionary):
		return false
	return locale_data.get("conversations", null) is Array

func _on_locale_generation_failed(_language: String, message: String) -> void:
	if bulk_generation_active:
		_finish_bulk_generation_error(message)

func _finish_bulk_generation_success() -> void:
	bulk_generation_active = false
	bulk_generation_completed_steps = bulk_generation_total_steps
	pending_profile_character_index = -1
	pending_locale_languages.clear()
	_refresh_manifest_form()
	_refresh_line_rows()
	_refresh_save_checklist()
	_set_status("%s · 100%%" % _l("Generation completed"))

func _finish_bulk_generation_error(message: String) -> void:
	bulk_generation_active = false
	profile_generation_queue.clear()
	dialogue_generation_queue.clear()
	pending_locale_languages.clear()
	pending_profile_character_index = -1
	if generation_error_label != null:
		generation_error_label.text = "%s: %s" % [_l("Generation error"), message]
		generation_error_label.visible = true
	_refresh_bulk_generate_button_state(_collect_required_field_errors(false))
	_set_status(message, true)

func _cancel_bulk_generation() -> void:
	if not bulk_generation_active:
		return
	bulk_generation_active = false
	ai.cancel_generation()
	profile_generation_queue.clear()
	dialogue_generation_queue.clear()
	pending_locale_languages.clear()
	pending_profile_character_index = -1
	dialogue_generation_character_index = -1
	_refresh_bulk_generate_button_state(_collect_required_field_errors(false))
	_set_status("%s · %d%%" % [
		_l("Generation stopped"),
		_bulk_generation_percent()
	])

func _set_bulk_generation_progress(label: String) -> void:
	_set_status("%s · %d%%" % [label, _bulk_generation_percent()])

func _bulk_generation_percent() -> int:
	if bulk_generation_total_steps <= 0:
		return 0
	return clampi(
		roundi(
			100.0
			* float(bulk_generation_completed_steps)
			/ float(bulk_generation_total_steps)
		),
		0,
		100
	)

func _character_display_name(character_index: int) -> String:
	if character_index < 0 or character_index >= model.characters.size():
		return _l("Character")
	var character: Dictionary = model.characters[character_index]
	var profile: Dictionary = character.get("profile", {})
	return str(
		profile.get("display_name", character.get("id", "Character"))
	)

func _open_ai_settings() -> void:
	if ai_settings_window == null or not is_instance_valid(ai_settings_window):
		ai_settings_window = AISettingsDialog.new()
		ai_settings_window.theme = CreatorThemeScript.build()
		ai_settings_window.finished.connect(_on_ai_settings_finished)
		add_child(ai_settings_window)
	ai_settings_window.theme = CreatorThemeScript.build()
	ai_settings_window.open_centered()

func _on_ai_settings_finished(saved: bool) -> void:
	if not saved:
		return
	_refresh_save_checklist()
	_set_status(_l("AI settings saved.", "AI 설정을 저장했습니다."))

func _on_sprite_mode_selected(index: int) -> void:
	var modes := ["simple", "natural", "expressive"]
	var mode: String = modes[clampi(index, 0, 2)]
	model.set_sprite_mode(selected_character_index, mode)
	if mode == "simple":
		preview_slot = "eyes_open"
	elif mode == "natural" and preview_slot != "body" and not PackModelScript.NATURAL_PRIMARY.has(preview_slot):
		preview_slot = "eyes_open"
	_refresh_sprite_cards()
	_refresh_sprite_preview()
	_sync_desktop_character_preview(preview_slot)

func _on_upload_sprite(slot: String) -> void:
	pending_sprite_slot = slot
	sprite_dialog.popup_centered_ratio(0.72)

func _on_sprite_file_selected(path: String) -> void:
	if pending_sprite_slot.is_empty():
		return

	var result: Dictionary = model.validate_sprite_file(path)
	if not bool(result.get("ok", false)):
		sprite_status.text = _localize_model_message(
			str(result.get("message", "Invalid image."))
		)
		sprite_status.add_theme_color_override(
			"font_color",
			CreatorThemeScript.danger()
		)
		pending_sprite_slot = ""
		return

	model.set_sprite(
		selected_character_index,
		pending_sprite_slot,
		path
	)
	preview_slot = pending_sprite_slot
	sprite_status.text = _localize_model_message(
		str(result.get("message", "Upload complete."))
	)
	sprite_status.add_theme_color_override(
		"font_color",
		CreatorThemeScript.success()
	)
	pending_sprite_slot = ""
	_refresh_sprite_cards()
	_refresh_sprite_preview()
	_sync_desktop_character_preview(preview_slot)

func _on_clear_sprite(slot: String) -> void:
	model.clear_sprite(selected_character_index, slot)
	preview_slot = slot
	_refresh_sprite_cards()
	_refresh_sprite_preview()
	_sync_desktop_character_preview(preview_slot)

func _on_sprite_card_gui_input(event: InputEvent, slot: String) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		preview_slot = slot
		_refresh_sprite_preview()
		_sync_desktop_character_preview(preview_slot)

func _localize_model_message(message: String) -> String:
	if AppLanguageScript.get_language() == "ko":
		return message

	var exact_map: Dictionary = {
		"manifest.json을 읽을 수 없습니다.": "Could not read manifest.json.",
		"manifest.json의 characters가 배열이 아닙니다.": "manifest.json characters must be an array.",
		"현재 Creator는 1~2 캐릭터 팩만 지원합니다.": "The Creator currently supports packs with 1–2 characters.",
		"팩을 불러왔습니다.": "Pack loaded.",
		"저장 완료": "Save complete.",
		"업로드 완료": "Upload complete.",
		"잘못된 이미지": "Invalid image."
	}
	if exact_map.has(message):
		return str(exact_map[message])
	if message == "Pack ID가 비어 있습니다.":
		return "Pack ID is empty."
	if message == "캐릭터가 없습니다.":
		return "The pack has no characters."
	if message.begins_with("캐릭터 ") and message.ends_with("의 ID가 비어 있습니다."):
		return "A character ID is empty."
	if message.begins_with("내보냈습니다: "):
		return "Saved: " + message.trim_prefix("내보냈습니다: ")
	if message == "PNG 파일만 사용할 수 있습니다.":
		return "Only PNG files can be used."
	if message == "PNG 이미지를 읽을 수 없습니다.":
		return "Could not read the PNG image."
	if message.begins_with("이미지는 정확히 400×600이어야 합니다."):
		return message.replace("이미지는 정확히 400×600이어야 합니다. 현재", "The image must be exactly 400×600. Current size:")
	if message == "투명 배경이 있는 RGBA PNG가 필요합니다.":
		return "An RGBA PNG with a transparent background is required."
	if message == "400×600 투명 PNG":
		return "400×600 transparent PNG"

	return message

func _commit_current_edits() -> bool:
	_commit_line_rows()
	return _commit_manifest_form()

func _load_texture(path: String) -> Texture2D:
	if path.begins_with("res://"):
		var resource := ResourceLoader.load(path)
		if resource is Texture2D:
			return resource as Texture2D
		var fallback_resource := ResourceLoader.load(PackModelScript.PLACEHOLDER_PATH)
		return fallback_resource as Texture2D if fallback_resource is Texture2D else null
	var image := Image.new()
	if image.load(path) != OK:
		var image_fallback_resource := ResourceLoader.load(PackModelScript.PLACEHOLDER_PATH)
		return image_fallback_resource as Texture2D if image_fallback_resource is Texture2D else null
	return ImageTexture.create_from_image(image)

func _array_to_text(value: Variant) -> String:
	if not (value is Array):
		return ""
	var lines: Array[String] = []
	for item: Variant in value as Array:
		var text := str(item).strip_edges()
		if not text.is_empty():
			lines.append(text)
	return "\n".join(lines)

func _text_to_array(text: String) -> Array[String]:
	var result: Array[String] = []
	for line: String in text.split("\n"):
		var clean := line.strip_edges()
		if not clean.is_empty():
			result.append(clean)
	return result

func _comma_list(text: String) -> Array[String]:
	var result: Array[String] = []
	for piece: String in text.split(","):
		var clean := piece.strip_edges()
		if not clean.is_empty() and not result.has(clean):
			result.append(clean)
	return result

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _set_status(message: String, error: bool = false) -> void:
	if status_label == null:
		return

	status_label.text = message
	status_label.add_theme_color_override(
		"font_color",
		CreatorThemeScript.danger()
		if error
		else CreatorThemeScript.muted()
	)

func _mark_dirty() -> void:
	if model != null:
		_invalidate_secondary_locales()
		model.dirty = true

func _invalidate_secondary_locales() -> void:
	if model != null and not suppress_identity_tracking:
		model.secondary_locales.clear()

func _mark_dirty_text(_value: String) -> void:
	_mark_dirty()

func _mark_dirty_int(_value: int) -> void:
	_mark_dirty()
