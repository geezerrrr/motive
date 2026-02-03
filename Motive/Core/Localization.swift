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
    }
    
    // MARK: - Settings
    enum Settings {
        static let title = "settings.title".localized
        static let starOnGitHub = "settings.star_on_github".localized
        
        // Tabs
        static let general = "settings.tab.general".localized
        static let generalSubtitle = "settings.tab.general.subtitle".localized
        static let aiProvider = "settings.tab.ai_provider".localized
        static let aiProviderSubtitle = "settings.tab.ai_provider.subtitle".localized
        static let permissions = "settings.tab.permissions".localized
        static let permissionsSubtitle = "settings.tab.permissions.subtitle".localized
        static let advanced = "settings.tab.advanced".localized
        static let advancedSubtitle = "settings.tab.advanced.subtitle".localized
        static let skills = "settings.tab.skills".localized
        static let skillsSubtitle = "settings.tab.skills.subtitle".localized
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
    }
    
    // MARK: - Permission Request
    enum Permission {
        static let filePermission = "permission.file".localized
        static let question = "permission.question".localized
        static let allowOnce = "permission.allow_once".localized
        static let denyOnce = "permission.deny_once".localized
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
