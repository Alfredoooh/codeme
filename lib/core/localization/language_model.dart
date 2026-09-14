// ══════════════════════════════════════════════════════════════
// FILE: lib/core/language/language_model.dart
// Sistema de idioma transversal ao app inteiro — vive em core/,
// ao lado de core/theme e core/widgets, porque qualquer feature
// (settings, drawer, chat, docs, sheets...) pode vir a consumir
// isto, não só o Settings.
//
// Modelo de idioma + o dicionário de strings (AppStrings) que
// cada ficheiro de idioma concreto preenche. Este ficheiro é a
// fonte de verdade de TODAS as chaves de texto disponíveis no
// app — cada idioma novo implementa AppStrings por inteiro.
// ══════════════════════════════════════════════════════════════

/// Metadados de um idioma disponível no seletor.
class AppLanguage {
  final String code; // ex "pt-PT", "en-US"
  final String nativeName; // nome no próprio idioma
  final String englishName; // nome em inglês, para busca/fallback
  final String flagEmoji;
  final bool isRtl;

  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.flagEmoji,
    this.isRtl = false,
  });
}

/// Dicionário completo de strings do app. Cada idioma concreto
/// (language_pt_pt.dart, language_en_us.dart, etc.) cria uma
/// instância const desta classe com todos os campos preenchidos.
///
/// Organização por ecrã/secção, prefixada, para evitar colisões
/// entre conceitos repetidos em ecrãs diferentes (ex: settingsTitle
/// vs appearanceTitle vs memoryTitle são três títulos distintos).
/// Só o Settings consome isto por agora — os restantes ecrãs
/// continuam com texto fixo em português até serem migrados, um
/// de cada vez.
class AppStrings {
  // ── Genérico / ações comuns ──────────────────────────────────
  final String commonCancel;
  final String commonSave;
  final String commonConfirm;
  final String commonDelete;
  final String commonChange;
  final String commonBack;
  final String commonNone;
  final String commonEdited;

  // ── Settings — título e secções ──────────────────────────────
  final String settingsTitle;
  final String settingsSectionGeneral;
  final String settingsSectionAccount;
  final String settingsSectionAbout;

  // ── Settings — linhas de "Geral" ─────────────────────────────
  final String settingsAppearance;
  final String settingsPersonalization;
  final String settingsMemory;
  final String settingsWorkspace;
  final String settingsLanguage;

  // ── Settings — linhas de "Conta" ─────────────────────────────
  final String settingsName;
  final String settingsEmail;
  final String settingsPassword;
  final String settingsCredits;

  // ── Settings — linhas de "Sobre" ─────────────────────────────
  final String settingsVersion;
  final String settingsTerms;
  final String settingsPrivacyPolicy;
  final String settingsSendFeedback;
  final String settingsHelpSupport;

  // ── Settings — logout / confirmações ─────────────────────────
  final String settingsLogout;
  final String settingsLogoutConfirmTitle;
  final String settingsLogoutConfirmMessage;
  final String settingsDeleteAllConversationsConfirmMessage;
  final String settingsDeleteAllConversationsConfirmLabel;

  // ── Settings — avatar ─────────────────────────────────────────
  final String settingsAvatarUploadNewImage;
  final String settingsAvatarUploadError;
  final String settingsAvatarUploadErrorTooLarge;

  // ── Settings — editar nome ───────────────────────────────────
  final String settingsEditNameTitle;
  final String settingsEditNameLabel;
  final String settingsEditNameHint;

  // ── Settings — alterar password ──────────────────────────────
  final String settingsChangePasswordTitle;
  final String settingsChangePasswordCurrent;
  final String settingsChangePasswordNew;
  final String settingsChangePasswordNewHint;
  final String settingsChangePasswordForgot;
  final String settingsChangePasswordForgotBack;
  final String settingsChangePasswordForgotMessage;

  // ── Language picker ───────────────────────────────────────────
  final String languagePickerTitle;
  final String languagePickerSearchHint;
  final String languagePickerNoResults;

  // ── Appearance ────────────────────────────────────────────────
  final String appearanceTitle;
  final String appearanceThemeLight;
  final String appearanceThemeDark;
  final String appearanceThemeSystem;
  final String appearanceTextSize;
  final String appearanceTextSizePreviewLabel;
  final String appearanceTextSizePreviewQuestion;
  final String appearanceTextSizePreviewAnswer;
  final String appearancePrimaryColor;
  final String appearanceFontFamily;
  final String appearanceFontFamilyDescription;
  final String appearanceIconStyle;
  final String appearanceIconStyleDescription;
  final String appearanceChatBubbleStyle;
  final String appearanceChatBubbleStyleDescription;
  final String appearanceReduceMotion;
  final String appearanceReduceMotionDescription;

  // ── Personalization ───────────────────────────────────────────
  final String personalizationTitle;
  final String personalizationPromptPreferences;
  final String personalizationEmojiFrequency;
  final String personalizationEmojiNone;
  final String personalizationEmojiLow;
  final String personalizationEmojiMedium;
  final String personalizationEmojiHigh;
  final String personalizationPromptEditorTitle;
  final String personalizationPromptEditorDescription;
  final String personalizationPromptEditorHint;
  final String personalizationCustomInstructions;
  final String personalizationCustomInstructionsDescription;
  final String personalizationTraits;
  final String personalizationTraitsDescription;
  final String personalizationKnownInfo;
  final String personalizationKnownInfoDescription;
  final String personalizationResponseStyle;
  final String personalizationResponseStyleDescription;
  final String personalizationResponseStyleConcise;
  final String personalizationResponseStyleBalanced;
  final String personalizationResponseStyleDetailed;
  final String personalizationAlwaysSearchWeb;
  final String personalizationAlwaysSearchWebDescription;
  final String personalizationRememberAcrossChats;
  final String personalizationRememberAcrossChatsDescription;

  // ── Memory ────────────────────────────────────────────────────
  final String memoryTitle;
  final String memoryDescription;
  final String memoryDeleteAllConversations;

  // ── Workspace ─────────────────────────────────────────────────
  final String workspaceTitle;
  final String workspacePersonal;

  const AppStrings({
    required this.commonCancel,
    required this.commonSave,
    required this.commonConfirm,
    required this.commonDelete,
    required this.commonChange,
    required this.commonBack,
    required this.commonNone,
    required this.commonEdited,
    required this.settingsTitle,
    required this.settingsSectionGeneral,
    required this.settingsSectionAccount,
    required this.settingsSectionAbout,
    required this.settingsAppearance,
    required this.settingsPersonalization,
    required this.settingsMemory,
    required this.settingsWorkspace,
    required this.settingsLanguage,
    required this.settingsName,
    required this.settingsEmail,
    required this.settingsPassword,
    required this.settingsCredits,
    required this.settingsVersion,
    required this.settingsTerms,
    required this.settingsPrivacyPolicy,
    required this.settingsSendFeedback,
    required this.settingsHelpSupport,
    required this.settingsLogout,
    required this.settingsLogoutConfirmTitle,
    required this.settingsLogoutConfirmMessage,
    required this.settingsDeleteAllConversationsConfirmMessage,
    required this.settingsDeleteAllConversationsConfirmLabel,
    required this.settingsAvatarUploadNewImage,
    required this.settingsAvatarUploadError,
    required this.settingsAvatarUploadErrorTooLarge,
    required this.settingsEditNameTitle,
    required this.settingsEditNameLabel,
    required this.settingsEditNameHint,
    required this.settingsChangePasswordTitle,
    required this.settingsChangePasswordCurrent,
    required this.settingsChangePasswordNew,
    required this.settingsChangePasswordNewHint,
    required this.settingsChangePasswordForgot,
    required this.settingsChangePasswordForgotBack,
    required this.settingsChangePasswordForgotMessage,
    required this.languagePickerTitle,
    required this.languagePickerSearchHint,
    required this.languagePickerNoResults,
    required this.appearanceTitle,
    required this.appearanceThemeLight,
    required this.appearanceThemeDark,
    required this.appearanceThemeSystem,
    required this.appearanceTextSize,
    required this.appearanceTextSizePreviewLabel,
    required this.appearanceTextSizePreviewQuestion,
    required this.appearanceTextSizePreviewAnswer,
    required this.appearancePrimaryColor,
    required this.appearanceFontFamily,
    required this.appearanceFontFamilyDescription,
    required this.appearanceIconStyle,
    required this.appearanceIconStyleDescription,
    required this.appearanceChatBubbleStyle,
    required this.appearanceChatBubbleStyleDescription,
    required this.appearanceReduceMotion,
    required this.appearanceReduceMotionDescription,
    required this.personalizationTitle,
    required this.personalizationPromptPreferences,
    required this.personalizationEmojiFrequency,
    required this.personalizationEmojiNone,
    required this.personalizationEmojiLow,
    required this.personalizationEmojiMedium,
    required this.personalizationEmojiHigh,
    required this.personalizationPromptEditorTitle,
    required this.personalizationPromptEditorDescription,
    required this.personalizationPromptEditorHint,
    required this.personalizationCustomInstructions,
    required this.personalizationCustomInstructionsDescription,
    required this.personalizationTraits,
    required this.personalizationTraitsDescription,
    required this.personalizationKnownInfo,
    required this.personalizationKnownInfoDescription,
    required this.personalizationResponseStyle,
    required this.personalizationResponseStyleDescription,
    required this.personalizationResponseStyleConcise,
    required this.personalizationResponseStyleBalanced,
    required this.personalizationResponseStyleDetailed,
    required this.personalizationAlwaysSearchWeb,
    required this.personalizationAlwaysSearchWebDescription,
    required this.personalizationRememberAcrossChats,
    required this.personalizationRememberAcrossChatsDescription,
    required this.memoryTitle,
    required this.memoryDescription,
    required this.memoryDeleteAllConversations,
    required this.workspaceTitle,
    required this.workspacePersonal,
  });
}

/// Par idioma + o seu dicionário de strings preenchido.
class AppLocale {
  final AppLanguage language;
  final AppStrings strings;
  const AppLocale({required this.language, required this.strings});
}