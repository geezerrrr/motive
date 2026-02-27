//
//  Localization.swift
//  Motive
//
//  Localization utilities for multi-language support.
//

import Foundation

/// Shorthand for localized strings
/// Usage: L10n.settings.general or "key".localized
enum L10n {
    // MARK: - Common

    static let appName = "app.name".localized
    static let cancel = "common.cancel".localized
    static let submit = "common.submit".localized
    static let save = "common.save".localized
    static let delete = "common.delete".localized
    static let done = "common.done".localized
    static let allow = "common.allow".localized
    static let deny = "common.deny".localized
    static let error = "common.error".localized
    static let warning = "common.warning".localized
    static let ok = "common.ok".localized
    static let unsavedChanges = "common.unsaved_changes".localized
    static let show = "common.show".localized
    static let hide = "common.hide".localized
    static let expand = "common.expand".localized
    static let collapse = "common.collapse".localized
    static let showLess = "common.show_less".localized
    static let loading = "common.loading".localized
    static let install = "common.install".localized
    static let edit = "common.edit".localized
    static let reject = "common.reject".localized
    static let allowOnce = "common.allow_once".localized
    static let alwaysAllow = "common.always_allow".localized
    /// "Show %d more lines" – use with `String(format:, count)`
    static let showMoreLines = "common.show_more_lines".localized

    // MARK: - Command Bar

    enum CommandBar {
        static let placeholder = "commandbar.placeholder".localized
        static let submit = "commandbar.submit".localized
        static let settings = "commandbar.settings".localized
        static let run = "commandbar.run".localized
        static let close = "commandbar.close".localized
        static let select = "commandbar.select".localized
        static let complete = "commandbar.complete".localized
        static let navigate = "commandbar.navigate".localized
        static let back = "commandbar.back".localized
        static let open = "commandbar.open".localized
        static let delete = "commandbar.delete".localized
        static let new = "commandbar.new".localized
        static let commands = "commandbar.commands".localized
        static let stop = "commandbar.stop".localized
        static let drawer = "commandbar.drawer".localized
        static let send = "commandbar.send".localized
        static let retry = "commandbar.retry".localized
        static let cancel = "commandbar.cancel".localized
        static let running = "commandbar.running".localized
        static let newTask = "commandbar.new_task".localized
        static let completed = "commandbar.completed".localized
        static let details = "commandbar.details".localized
        static let error = "commandbar.error".localized
        static let dismiss = "commandbar.dismiss".localized
        static let ready = "commandbar.ready".localized
        static let typeRequest = "commandbar.type_request".localized
        static let starting = "commandbar.starting".localized
        static let current = "commandbar.current".localized
        static let noSessions = "commandbar.no_sessions".localized
        static let noSessionsDesc = "commandbar.no_sessions.desc".localized
        static let modifiedFiles = "commandbar.modified_files".localized
        static let followUp = "commandbar.follow_up".localized
        static let toolsExecuted = "commandbar.tools_executed".localized
        static let taskFinished = "commandbar.task_finished".localized
        static let moreFiles = "commandbar.more_files".localized
        static let tab = "commandbar.tab".localized
        static let searchSessions = "commandbar.search_sessions".localized
        static let typeCommand = "commandbar.type_command".localized
    }

    // MARK: - Settings

    enum Settings {
        static let title = "settings.title".localized
        static let starOnGitHub = "settings.star_on_github".localized

        // Tabs
        static let general = "settings.tab.general".localized
        static let generalSubtitle = "settings.tab.general.subtitle".localized
        static let scheduledTasks = "settings.tab.scheduled_tasks".localized
        static let scheduledTasksSubtitle = "settings.tab.scheduled_tasks.subtitle".localized
        static let aiProvider = "settings.tab.ai_provider".localized
        static let aiProviderSubtitle = "settings.tab.ai_provider.subtitle".localized
        static let usage = "settings.tab.usage".localized
        static let usageSubtitle = "settings.tab.usage.subtitle".localized
        static let permissions = "settings.tab.permissions".localized
        static let permissionsSubtitle = "settings.tab.permissions.subtitle".localized
        static let advanced = "settings.tab.advanced".localized
        static let advancedSubtitle = "settings.tab.advanced.subtitle".localized
        static let skills = "settings.tab.skills".localized
        static let skillsSubtitle = "settings.tab.skills.subtitle".localized
        static let memory = "settings.tab.memory".localized
        static let memorySubtitle = "settings.tab.memory.subtitle".localized
        static let aboutSubtitle = "settings.tab.about.subtitle".localized

        // General
        static let startup = "settings.general.startup".localized
        static let launchAtLogin = "settings.general.launch_at_login".localized
        static let launchAtLoginDesc = "settings.general.launch_at_login.desc".localized
        static let keyboard = "settings.general.keyboard".localized
        static let globalHotkey = "settings.general.global_hotkey".localized
        static let globalHotkeyDesc = "settings.general.global_hotkey.desc".localized
        static let appearance = "settings.general.appearance".localized
        static let theme = "settings.general.theme".localized
        static let themeDesc = "settings.general.theme.desc".localized
        static let themeSystem = "settings.general.theme.system".localized
        static let themeLight = "settings.general.theme.light".localized
        static let themeDark = "settings.general.theme.dark".localized
        static let commandBarPosition = "settings.general.command_bar_position".localized
        static let commandBarPositionDesc = "settings.general.command_bar_position.desc".localized
        static let glassEffect = "settings.general.glass_effect".localized
        static let glassEffectDesc = "settings.general.glass_effect.desc".localized
        static let liquidGlassClear = "settings.general.glass_effect.clear".localized
        static let liquidGlassTinted = "settings.general.glass_effect.tinted".localized
        static let positionCenter = "settings.general.position.center".localized
        static let positionTopLeading = "settings.general.position.top_leading".localized
        static let positionTopMiddle = "settings.general.position.top_middle".localized
        static let positionTopTrailing = "settings.general.position.top_trailing".localized
        static let positionBottomLeading = "settings.general.position.bottom_leading".localized
        static let positionBottomMiddle = "settings.general.position.bottom_middle".localized
        static let positionBottomTrailing = "settings.general.position.bottom_trailing".localized

        // Language
        static let language = "settings.general.language".localized
        static let languageDesc = "settings.general.language.desc".localized
        static let languageSystem = "settings.general.language.system".localized
        static let languageEnglish = "settings.general.language.english".localized
        static let languageChinese = "settings.general.language.chinese".localized
        static let languageJapanese = "settings.general.language.japanese".localized
        static let languageRestartRequired = "settings.general.language.restart_required".localized
        static let restartNow = "settings.general.restart_now".localized

        // AI Provider
        static let selectProvider = "settings.provider.select".localized
        static let apiKey = "settings.provider.api_key".localized
        static let apiKeyPlaceholder = "settings.provider.api_key.placeholder".localized
        static let apiKeyConfigured = "settings.provider.api_key.configured".localized
        static let baseURL = "settings.provider.base_url".localized
        static let baseURLPlaceholder = "settings.provider.base_url.placeholder".localized
        static let modelName = "settings.provider.model_name".localized
        static let modelNamePlaceholder = "settings.provider.model_name.placeholder".localized

        // Permissions
        static let fileOperations = "settings.permissions.file_operations".localized
        static let riskLevels = "settings.permissions.risk_levels".localized
        static let resetToDefaults = "settings.permissions.reset_to_defaults".localized
        static let policyAlwaysAllow = "settings.permissions.policy.always_allow".localized
        static let policyAlwaysAsk = "settings.permissions.policy.always_ask".localized
        static let policyAskOnce = "settings.permissions.policy.ask_once".localized
        static let policyAlwaysDeny = "settings.permissions.policy.always_deny".localized

        // File Operations
        static let opCreate = "settings.permissions.op.create".localized
        static let opCreateDesc = "settings.permissions.op.create.desc".localized
        static let opDelete = "settings.permissions.op.delete".localized
        static let opDeleteDesc = "settings.permissions.op.delete.desc".localized
        static let opModify = "settings.permissions.op.modify".localized
        static let opModifyDesc = "settings.permissions.op.modify.desc".localized
        static let opOverwrite = "settings.permissions.op.overwrite".localized
        static let opOverwriteDesc = "settings.permissions.op.overwrite.desc".localized
        static let opRename = "settings.permissions.op.rename".localized
        static let opRenameDesc = "settings.permissions.op.rename.desc".localized
        static let opMove = "settings.permissions.op.move".localized
        static let opMoveDesc = "settings.permissions.op.move.desc".localized
        static let opReadBinary = "settings.permissions.op.read_binary".localized
        static let opReadBinaryDesc = "settings.permissions.op.read_binary.desc".localized
        static let opExecute = "settings.permissions.op.execute".localized
        static let opExecuteDesc = "settings.permissions.op.execute.desc".localized

        // Risk Levels
        static let riskLow = "settings.permissions.risk.low".localized
        static let riskLowDesc = "settings.permissions.risk.low.desc".localized
        static let riskMedium = "settings.permissions.risk.medium".localized
        static let riskMediumDesc = "settings.permissions.risk.medium.desc".localized
        static let riskHigh = "settings.permissions.risk.high".localized
        static let riskHighDesc = "settings.permissions.risk.high.desc".localized
        static let riskCritical = "settings.permissions.risk.critical".localized
        static let riskCriticalDesc = "settings.permissions.risk.critical.desc".localized

        // Browser Automation
        static let browserTitle = "settings.browser.title".localized
        static let browserEnable = "settings.browser.enable".localized
        static let browserEnableDesc = "settings.browser.enable.desc".localized
        static let browserShowWindow = "settings.browser.show_window".localized
        static let browserShowWindowDesc = "settings.browser.show_window.desc".localized
        static let browserAgentMode = "settings.browser.agent_mode".localized
        static let browserAgentProvider = "settings.browser.agent_provider".localized
        static let browserAgentProviderDesc = "settings.browser.agent_provider.desc".localized
        static let browserApiKeyDesc = "settings.browser.api_key.desc".localized
        static let browserBaseUrl = "settings.browser.base_url".localized
        static let browserBaseUrlDesc = "settings.browser.base_url.desc".localized
        static let browserStatus = "settings.browser.status".localized
        static let browserStatusReady = "settings.browser.status.ready".localized
        static let browserStatusNotFound = "settings.browser.status.not_found".localized
        static let browserStatusDisabled = "settings.browser.status.disabled".localized
        static let browserNotSet = "settings.browser.not_set".localized

        // Persona
        static let persona = "settings.tab.persona".localized
        static let personaSubtitle = "settings.tab.persona.subtitle".localized
        static let agentIdentity = "settings.persona.agent_identity".localized
        static let workspaceFiles = "settings.persona.workspace_files".localized
        static let personaName = "settings.persona.name".localized
        static let personaNameDesc = "settings.persona.name.desc".localized
        static let personaEmoji = "settings.persona.emoji".localized
        static let personaEmojiDesc = "settings.persona.emoji.desc".localized
        static let personaCreature = "settings.persona.creature".localized
        static let personaCreatureDesc = "settings.persona.creature.desc".localized
        static let personaVibe = "settings.persona.vibe".localized
        static let personaVibeDesc = "settings.persona.vibe.desc".localized
        static let openWorkspace = "settings.persona.open_workspace".localized
        static let openWorkspaceDesc = "settings.persona.open_workspace.desc".localized
        static let openInFinder = "settings.persona.open_in_finder".localized
        static let editSoulMd = "settings.persona.edit_soul".localized
        static let editSoulMdDesc = "settings.persona.edit_soul.desc".localized
        static let editUserMd = "settings.persona.edit_user".localized
        static let editUserMdDesc = "settings.persona.edit_user.desc".localized
        static let edit = "settings.persona.edit".localized
        static let saveAndApply = "settings.persona.save_and_apply".localized
        static let openEmojiPicker = "settings.persona.open_emoji_picker".localized
        static let personaTabIdentity = "settings.persona.tab.identity".localized
        static let personaTabSoul = "settings.persona.tab.soul".localized
        static let personaTabUser = "settings.persona.tab.user".localized

        // Skills
        static let skillsSystem = "settings.skills.system".localized
        static let skillsEnable = "settings.skills.enable".localized
        static let skillsEnableDesc = "settings.skills.enable.desc".localized
        static let skillsList = "settings.skills.list".localized
        static let skillsEligible = "settings.skills.eligible".localized
        static let skillsIneligible = "settings.skills.ineligible".localized
        static let skillsRefresh = "settings.skills.refresh".localized
        static let skillsNoSkills = "settings.skills.no_skills".localized
        static let skillsNoSkillsDesc = "settings.skills.no_skills.desc".localized

        // Advanced
        static let openCodeBinary = "settings.advanced.opencode_binary".localized
        static let binaryStatus = "settings.advanced.binary_status".localized
        static let binaryBundled = "settings.advanced.binary.bundled".localized
        static let binaryCustom = "settings.advanced.binary.custom".localized
        static let binaryNotFound = "settings.advanced.binary.not_found".localized
        static let importBinary = "settings.advanced.import_binary".localized
        static let importing = "settings.advanced.importing".localized
        static let selectBinary = "settings.advanced.select_binary".localized
        static let autoDetect = "settings.advanced.auto_detect".localized
        static let sourcePath = "settings.advanced.source_path".localized
        static let diagnostics = "settings.advanced.diagnostics".localized
        static let debugMode = "settings.advanced.debug_mode".localized
        static let debugModeDesc = "settings.advanced.debug_mode.desc".localized
        static let about = "settings.advanced.about".localized
        static let version = "settings.advanced.version".localized
        static let build = "settings.advanced.build".localized
        static let notConfigured = "settings.advanced.not_configured".localized

        // Provider Config
        static let provider = "settings.provider.provider".localized
        static let configuration = "settings.provider.configuration".localized
        static let ollamaHost = "settings.provider.ollama_host".localized
        static let defaultEndpoint = "settings.provider.default_endpoint".localized
        static let model = "settings.provider.model".localized
        static let saveRestart = "settings.provider.save_restart".localized
        static let agentRestarted = "settings.provider.agent_restarted".localized

        // Hotkey Recorder
        static let pressKeys = "settings.hotkey.press_keys".localized
        static let clickToRecord = "settings.hotkey.click_to_record".localized

        // Trust Level
        static let trustCareful = "settings.permissions.trust.careful".localized
        static let trustCarefulDesc = "settings.permissions.trust.careful.desc".localized
        static let trustBalanced = "settings.permissions.trust.balanced".localized
        static let trustBalancedDesc = "settings.permissions.trust.balanced.desc".localized
        static let trustYolo = "settings.permissions.trust.yolo".localized
        static let trustYoloDesc = "settings.permissions.trust.yolo.desc".localized

        // Permission Policy
        static let trustLevel = "settings.permissions.trust_level".localized
        static let trustAllOps = "settings.permissions.trust_all_ops".localized
        static let addRule = "settings.permissions.add_rule".localized
        static let addRuleFor = "settings.permissions.add_rule_for".localized
        static let pattern = "settings.permissions.pattern".localized
        static let action = "settings.permissions.action".localized
        static let descriptionOptional = "settings.permissions.description_optional".localized
        static let whatRuleDoes = "settings.permissions.what_rule_does".localized

        // Skills
        static let skillsSearch = "settings.skills.search".localized
        static let skillsRefreshA11y = "settings.skills.refresh_a11y".localized
        static let skillsLoading = "settings.skills.loading".localized
        static let skillsNoMatch = "settings.skills.no_match".localized
        static let skillsSelect = "settings.skills.select".localized
        static let skillsUnableToLoad = "settings.skills.unable_to_load".localized
        static let skillsMissingReqs = "settings.skills.missing_reqs".localized
        static let skillsEnterApiKey = "settings.skills.enter_api_key".localized
        static let skillsGuide = "settings.skills.guide".localized
        static let skillsBlocked = "settings.skills.blocked".localized
        static let skillsDisabled = "settings.skills.disabled".localized
        static let skillsEnabled = "settings.skills.enabled".localized
        static let skillsRestartPending = "settings.skills.restart_pending".localized

        // Memory
        static let memorySystem = "settings.memory.system".localized
        static let memoryEnable = "settings.memory.enable".localized
        static let memoryEnableDesc = "settings.memory.enable.desc".localized
        static let memoryIndexStatus = "settings.memory.index_status".localized
        static let memoryIndexedFiles = "settings.memory.indexed_files".localized
        static let memoryIndexedFilesDesc = "settings.memory.indexed_files.desc".localized
        static let memoryLastSync = "settings.memory.last_sync".localized
        static let memoryRebuildIndex = "settings.memory.rebuild_index".localized
        static let memoryRebuildIndexDesc = "settings.memory.rebuild_index.desc".localized
        static let memoryRebuild = "settings.memory.rebuild".localized
        static let memoryFileSection = "settings.memory.file_section".localized
        static let memoryFileDesc = "settings.memory.file.desc".localized
        static let memoryNoMemories = "settings.memory.no_memories".localized
        static let memoryNever = "settings.memory.never".localized
        static let memoryNotIndexed = "settings.memory.not_indexed".localized
        static let memoryPluginStatus = "settings.memory.plugin_status".localized
        static let memoryPluginStatusDesc = "settings.memory.plugin_status.desc".localized
        static let memoryPluginAvailable = "settings.memory.plugin_available".localized
        static let memoryPluginMissing = "settings.memory.plugin_missing".localized

        // About
        static let poweredBy = "settings.about.powered_by".localized
        static let allRightsReserved = "settings.about.all_rights_reserved".localized
        static let actions = "settings.advanced.actions".localized

        // Scheduled Tasks
        static let searchPrompt = "settings.search.prompt".localized
        static let openSettingsHintFormat = "settings.a11y.open_settings_hint".localized
        static let schedulerRuntimeSection = "settings.scheduled_tasks.runtime_scheduler".localized
        static let schedulerScope = "settings.scheduled_tasks.scope".localized
        static let schedulerScopeDesc = "settings.scheduled_tasks.scope.desc".localized
        static let schedulerInAppOnly = "settings.scheduled_tasks.in_app_only".localized
        static let scheduledTasksSection = "settings.scheduled_tasks.section".localized
        static let noTasksYet = "settings.scheduled_tasks.no_tasks".localized
        static let noTasksYetDesc = "settings.scheduled_tasks.no_tasks.desc".localized
        static let newTask = "settings.scheduled_tasks.new_task".localized
        static let refresh = "settings.scheduled_tasks.refresh".localized
        static let runNow = "settings.scheduled_tasks.run_now".localized
        static let notScheduled = "settings.scheduled_tasks.not_scheduled".localized
        static let neverRun = "settings.scheduled_tasks.never_run".localized
        static let scheduleSummaryFormat = "settings.scheduled_tasks.summary".localized
        static let editorNewTitle = "settings.scheduled_tasks.editor.new".localized
        static let editorEditTitle = "settings.scheduled_tasks.editor.edit".localized
        static let taskName = "settings.scheduled_tasks.task_name".localized
        static let prompt = "settings.scheduled_tasks.prompt".localized
        static let workingDirectoryOptional = "settings.scheduled_tasks.working_directory_optional".localized
        static let agentOptional = "settings.scheduled_tasks.agent_optional".localized
        static let scheduleType = "settings.scheduled_tasks.schedule_type".localized
        static let scheduleOnce = "settings.scheduled_tasks.schedule.once".localized
        static let scheduleInterval = "settings.scheduled_tasks.schedule.interval".localized
        static let scheduleDaily = "settings.scheduled_tasks.schedule.daily".localized
        static let scheduleWeekly = "settings.scheduled_tasks.schedule.weekly".localized
        static let scheduleCron = "settings.scheduled_tasks.schedule.cron".localized
        static let enabled = "settings.scheduled_tasks.enabled".localized
        static let runAt = "settings.scheduled_tasks.run_at".localized
        static let intervalSeconds = "settings.scheduled_tasks.interval_seconds".localized
        static let time = "settings.scheduled_tasks.time".localized
        static let weekday = "settings.scheduled_tasks.weekday".localized
        static let cronExpression = "settings.scheduled_tasks.cron_expression".localized
        static let nextRunFormat = "settings.scheduled_tasks.next_run".localized
        static let nextRunUnavailable = "settings.scheduled_tasks.next_run_unavailable".localized
        static let taskNameRequired = "settings.scheduled_tasks.error.task_name_required".localized
        static let promptRequired = "settings.scheduled_tasks.error.prompt_required".localized
        static let intervalMinimum = "settings.scheduled_tasks.error.interval_minimum".localized
    }

    // MARK: - Drawer

    enum Drawer {
        static let newSession = "drawer.new_session".localized
        static let newChat = "drawer.new_chat".localized
        static let conversation = "drawer.conversation".localized
        static let thinking = "drawer.thinking".localized
        static let processing = "drawer.processing".localized
        static let completed = "drawer.completed".localized
        static let failed = "drawer.failed".localized
        static let interrupted = "drawer.interrupted".localized
        static let running = "drawer.running".localized
        static let stop = "drawer.stop".localized
        static let close = "drawer.close".localized
        static let inputPlaceholder = "drawer.input.placeholder".localized
        static let messagePlaceholder = "drawer.message.placeholder".localized
        static let startConversation = "drawer.start_conversation".localized
        static let startHint = "drawer.start_hint".localized
        static let history = "drawer.history".localized
        static let noHistory = "drawer.no_history".localized
        static let assistant = "drawer.assistant".localized
        static let tool = "drawer.tool".localized
        static let tip = "drawer.tip".localized
        static let tasks = "drawer.tasks".localized
        static let changes = "drawer.changes".localized
        static let contextHelp = "drawer.context_help".localized
        static let showOutput = "drawer.show_output".localized
        static let hideOutput = "drawer.hide_output".localized
        static let copyResult = "drawer.copy_result".localized
        static let editLastMessage = "drawer.edit_last_message".localized
        static let previewPlan = "drawer.preview_plan".localized
        static let previewPlanHint = "drawer.preview_plan_hint".localized
        static let planPreview = "drawer.plan_preview".localized
        static let reloadPlanPreview = "drawer.reload_plan_preview".localized
        static let planPreviewLoadFailed = "drawer.plan_preview_load_failed".localized
        static let planDraftStreaming = "drawer.plan_draft_streaming".localized
    }

    // MARK: - Permission Request

    enum Permission {
        static let filePermission = "permission.file".localized
        static let question = "permission.question".localized
        static let allowOnce = "permission.allow_once".localized
        static let denyOnce = "permission.deny_once".localized
        static let permissionRequired = "permission.required".localized
        static let permissionLabel = "permission.label".localized
        static let pathLabel = "permission.path".localized
        static let pathsLabel = "permission.paths".localized
        static let typeResponse = "permission.type_response".localized
        static let typeAnswer = "permission.type_answer".localized
        static let previewChanges = "permission.preview_changes".localized
    }

    // MARK: - Alerts

    enum Alert {
        static let deleteSessionTitle = "alert.delete_session_title".localized
        static let deleteSessionMessage = "alert.delete_session_message".localized
    }

    // MARK: - Time

    enum Time {
        static let justNow = "time.just_now".localized
        static let minutesAgo = "time.minutes_ago".localized
        static let hoursAgo = "time.hours_ago".localized
        static let daysAgo = "time.days_ago".localized
    }

    // MARK: - Status Bar

    enum StatusBar {
        static let idle = "statusbar.idle".localized
        static let reasoning = "statusbar.reasoning".localized
        static let executing = "statusbar.executing".localized
        static let commandBar = "statusbar.command_bar".localized
        static let settings = "statusbar.settings".localized
        static let quit = "statusbar.quit".localized
    }

    // MARK: - Usage

    enum Usage {
        static let tokenUsage = "usage.token_usage".localized
        static let noData = "usage.no_data".localized
        static let cumulative = "usage.cumulative".localized
        static let costReported = "usage.cost_reported".localized
        static let reset = "usage.reset".localized
        static let input = "usage.input".localized
        static let output = "usage.output".localized
        static let reasoning = "usage.reasoning".localized
        static let cacheRead = "usage.cache_read".localized
        static let cacheWrite = "usage.cache_write".localized
    }

    // MARK: - Errors

    enum Error {
        static let noApiKey = "error.no_api_key".localized
        static let invalidConfig = "error.invalid_config".localized
        static let binaryNotFound = "error.binary_not_found".localized
        static let connectionFailed = "error.connection_failed".localized
    }

    // MARK: - Onboarding

    enum Onboarding {
        // Welcome
        static let welcomeTitle = "onboarding.welcome.title".localized
        static let welcomeSubtitle = "onboarding.welcome.subtitle".localized
        static let getStarted = "onboarding.welcome.get_started".localized

        // AI Provider
        static let aiProviderTitle = "onboarding.ai_provider.title".localized
        static let aiProviderSubtitle = "onboarding.ai_provider.subtitle".localized

        // Accessibility
        static let accessibilityTitle = "onboarding.accessibility.title".localized
        static let accessibilitySubtitle = "onboarding.accessibility.subtitle".localized
        static let accessibilityGranted = "onboarding.accessibility.granted".localized
        static let accessibilityRequired = "onboarding.accessibility.required".localized
        static let accessibilityInstructions = "onboarding.accessibility.instructions".localized
        static let openSystemSettings = "onboarding.accessibility.open_settings".localized

        // Browser
        static let browserTitle = "onboarding.browser.title".localized
        static let browserSubtitle = "onboarding.browser.subtitle".localized
        static let browserEnableDesc = "onboarding.browser.enable_desc".localized
        static let browserInfo = "onboarding.browser.info".localized

        // Complete
        static let completeTitle = "onboarding.complete.title".localized
        static let completeSubtitle = "onboarding.complete.subtitle".localized
        static let hotkeyLabel = "onboarding.complete.hotkey_label".localized
        static let hotkeyHint = "onboarding.complete.hotkey_hint".localized
        static let startUsing = "onboarding.complete.start_using".localized

        // Accessibility
        static let hotkeyReady = "onboarding.accessibility.hotkey_ready".localized
        static let hotkeyRequired = "onboarding.accessibility.hotkey_required".localized

        // Permission
        static let permissionMode = "onboarding.permission.mode".localized
        static let permissionModeDesc = "onboarding.permission.mode_desc".localized
        static let permissionYoloWarning = "onboarding.permission.yolo_warning".localized
        static let permissionChangeHint = "onboarding.permission.change_hint".localized

        // Common
        static let skip = "onboarding.skip".localized
        static let continueButton = "onboarding.continue".localized
    }
}

// MARK: - String Extension

extension String {
    /// Get localized string for this key
    var localized: String {
        NSLocalizedString(self, tableName: nil, bundle: .main, value: self, comment: "")
    }

    /// Get localized string with arguments
    func localized(with arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
}
