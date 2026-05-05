import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  property var screen: null
  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  readonly property bool isVerticalBar: Settings.data.bar.position === "left" || Settings.data.bar.position === "right"

  // ── Local state ──
  property bool valueHideUnoccupied: widgetData.hideUnoccupied !== undefined ? widgetData.hideUnoccupied : widgetMetadata.hideUnoccupied
  property bool valueFollowFocusedScreen: widgetData.followFocusedScreen !== undefined ? widgetData.followFocusedScreen : widgetMetadata.followFocusedScreen
  property bool valueEnableScrollWheel: widgetData.enableScrollWheel !== undefined ? widgetData.enableScrollWheel : widgetMetadata.enableScrollWheel
  property string valueLabelMode: widgetData.labelMode !== undefined ? widgetData.labelMode : widgetMetadata.labelMode
  property int valueCharacterCount: widgetData.characterCount !== undefined ? widgetData.characterCount : widgetMetadata.characterCount
  property string valueFocusedColor: widgetData.focusedColor !== undefined ? widgetData.focusedColor : widgetMetadata.focusedColor
  property string valueOccupiedColor: widgetData.occupiedColor !== undefined ? widgetData.occupiedColor : widgetMetadata.occupiedColor
  property string valueEmptyColor: widgetData.emptyColor !== undefined ? widgetData.emptyColor : widgetMetadata.emptyColor
  property real valueGroupedBorderOpacity: widgetData.groupedBorderOpacity !== undefined ? widgetData.groupedBorderOpacity : widgetMetadata.groupedBorderOpacity
  property bool valueShowWorkspaceBadge: widgetData.showWorkspaceBadge !== undefined ? widgetData.showWorkspaceBadge : widgetMetadata.showWorkspaceBadge

  property bool valueShowTitle: isVerticalBar ? false : (widgetData.showTitle !== undefined ? widgetData.showTitle : widgetMetadata.showTitle)
  property bool valueColorizeIcons: widgetData.colorizeIcons !== undefined ? widgetData.colorizeIcons : widgetMetadata.colorizeIcons
  property real valueIconScale: widgetData.iconScale !== undefined ? widgetData.iconScale : widgetMetadata.iconScale
  property bool valueShowPinnedApps: widgetData.showPinnedApps !== undefined ? widgetData.showPinnedApps : widgetMetadata.showPinnedApps
  property bool valueSmartWidth: widgetData.smartWidth !== undefined ? widgetData.smartWidth : widgetMetadata.smartWidth
  property int valueMaxTaskbarWidth: widgetData.maxTaskbarWidth !== undefined ? widgetData.maxTaskbarWidth : widgetMetadata.maxTaskbarWidth
  property real valueUnfocusedIconsOpacity: widgetData.unfocusedIconsOpacity !== undefined ? widgetData.unfocusedIconsOpacity : widgetMetadata.unfocusedIconsOpacity

  function saveSettings() {
    var s = Object.assign({}, widgetData || {});
    s.hideUnoccupied = valueHideUnoccupied;
    s.followFocusedScreen = valueFollowFocusedScreen;
    s.enableScrollWheel = valueEnableScrollWheel;
    s.labelMode = valueLabelMode;
    s.characterCount = valueCharacterCount;
    s.focusedColor = valueFocusedColor;
    s.occupiedColor = valueOccupiedColor;
    s.emptyColor = valueEmptyColor;
    s.groupedBorderOpacity = valueGroupedBorderOpacity;
    s.showWorkspaceBadge = valueShowWorkspaceBadge;
    s.showTitle = valueShowTitle;
    s.colorizeIcons = valueColorizeIcons;
    s.iconScale = valueIconScale;
    s.showPinnedApps = valueShowPinnedApps;
    s.smartWidth = valueSmartWidth;
    s.maxTaskbarWidth = valueMaxTaskbarWidth;
    s.titleWidth = parseInt(titleWidthInput.text) || widgetMetadata.titleWidth;
    s.unfocusedIconsOpacity = valueUnfocusedIconsOpacity;
    settingsChanged(s);
  }

  // ── Workspace section ──
  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("bar.workspace.label-mode-label")
    description: I18n.tr("bar.workspace.label-mode-description")
    model: [
      { "key": "none", "name": I18n.tr("common.none") },
      { "key": "index", "name": I18n.tr("options.workspace-labels.index") },
      { "key": "name", "name": I18n.tr("options.workspace-labels.name") },
      { "key": "index+name", "name": I18n.tr("options.workspace-labels.index-and-name") }
    ]
    currentKey: valueLabelMode
    onSelected: key => { valueLabelMode = key; saveSettings(); }
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.workspace.show-badge-label")
    description: I18n.tr("bar.workspace.show-badge-description")
    checked: valueShowWorkspaceBadge
    onToggled: checked => { valueShowWorkspaceBadge = checked; saveSettings(); }
    defaultValue: widgetMetadata.showWorkspaceBadge
    visible: valueLabelMode !== "none"
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.workspace.hide-unoccupied-label")
    description: I18n.tr("bar.workspace.hide-unoccupied-description")
    checked: valueHideUnoccupied
    onToggled: checked => { valueHideUnoccupied = checked; saveSettings(); }
    defaultValue: widgetMetadata.hideUnoccupied
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.workspace.follow-focused-screen-label")
    description: I18n.tr("bar.workspace.follow-focused-screen-description")
    checked: valueFollowFocusedScreen
    onToggled: checked => { valueFollowFocusedScreen = checked; saveSettings(); }
    defaultValue: widgetMetadata.followFocusedScreen
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.workspace.enable-scrollwheel-label")
    description: I18n.tr("bar.workspace.enable-scrollwheel-description")
    checked: valueEnableScrollWheel
    onToggled: checked => { valueEnableScrollWheel = checked; saveSettings(); }
    defaultValue: widgetMetadata.enableScrollWheel
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("bar.workspace.grouped-border-opacity-label")
    description: I18n.tr("bar.workspace.grouped-border-opacity-description")
    from: 0; to: 1; stepSize: 0.01
    showReset: true
    value: valueGroupedBorderOpacity
    defaultValue: widgetMetadata.groupedBorderOpacity
    onMoved: value => { valueGroupedBorderOpacity = value; saveSettings(); }
    text: Math.floor(valueGroupedBorderOpacity * 100) + "%"
  }

  NDivider { Layout.fillWidth: true }

  // ── Taskbar section ──
  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.icon-scale-label")
    description: I18n.tr("bar.taskbar.icon-scale-description")
    from: 0.5; to: 1; stepSize: 0.01
    showReset: true
    value: valueIconScale
    defaultValue: widgetMetadata.iconScale
    onMoved: value => { valueIconScale = value; saveSettings(); }
    text: Math.round(valueIconScale * 100) + "%"
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("bar.workspace.unfocused-icons-opacity-label")
    description: I18n.tr("bar.workspace.unfocused-icons-opacity-description")
    from: 0; to: 1; stepSize: 0.01
    showReset: true
    value: valueUnfocusedIconsOpacity
    defaultValue: widgetMetadata.unfocusedIconsOpacity
    onMoved: value => { valueUnfocusedIconsOpacity = value; saveSettings(); }
    text: Math.floor(valueUnfocusedIconsOpacity * 100) + "%"
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.tray.colorize-icons-label")
    description: I18n.tr("bar.taskbar.colorize-icons-description")
    checked: valueColorizeIcons
    onToggled: checked => { valueColorizeIcons = checked; saveSettings(); }
    defaultValue: widgetMetadata.colorizeIcons
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.show-pinned-apps-label")
    description: I18n.tr("bar.taskbar.show-pinned-apps-description")
    checked: valueShowPinnedApps
    onToggled: checked => { valueShowPinnedApps = checked; saveSettings(); }
    defaultValue: widgetMetadata.showPinnedApps
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.show-title-label")
    description: isVerticalBar ? I18n.tr("bar.taskbar.show-title-description-disabled") : I18n.tr("bar.taskbar.show-title-description")
    checked: valueShowTitle
    onToggled: checked => { valueShowTitle = checked; saveSettings(); }
    enabled: !isVerticalBar
    defaultValue: widgetMetadata.showTitle
  }

  NTextInput {
    id: titleWidthInput
    visible: valueShowTitle && !isVerticalBar
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.title-width-label")
    description: I18n.tr("bar.taskbar.title-width-description")
    text: widgetData.titleWidth || widgetMetadata.titleWidth
    placeholderText: I18n.tr("placeholders.enter-width-pixels")
    onTextChanged: saveSettings()
    defaultValue: String(widgetMetadata.titleWidth)
  }

  NToggle {
    Layout.fillWidth: true
    visible: !isVerticalBar && valueShowTitle
    label: I18n.tr("bar.taskbar.smart-width-label")
    description: I18n.tr("bar.taskbar.smart-width-description")
    checked: valueSmartWidth
    onToggled: checked => { valueSmartWidth = checked; saveSettings(); }
    defaultValue: widgetMetadata.smartWidth
  }

  NValueSlider {
    visible: valueSmartWidth && !isVerticalBar && valueShowTitle
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.max-width-label")
    description: I18n.tr("bar.taskbar.max-width-description")
    from: 10; to: 100; stepSize: 5
    showReset: true
    value: valueMaxTaskbarWidth
    defaultValue: widgetMetadata.maxTaskbarWidth
    onMoved: value => { valueMaxTaskbarWidth = Math.round(value); saveSettings(); }
    text: Math.round(valueMaxTaskbarWidth) + "%"
  }

  NDivider { Layout.fillWidth: true }

  NColorChoice {
    label: I18n.tr("bar.workspace.focused-color-label")
    description: I18n.tr("bar.workspace.focused-color-description")
    currentKey: valueFocusedColor
    onSelected: key => { valueFocusedColor = key; saveSettings(); }
  }

  NColorChoice {
    label: I18n.tr("bar.workspace.occupied-color-label")
    description: I18n.tr("bar.workspace.occupied-color-description")
    currentKey: valueOccupiedColor
    onSelected: key => { valueOccupiedColor = key; saveSettings(); }
  }

  NColorChoice {
    label: I18n.tr("bar.workspace.empty-color-label")
    description: I18n.tr("bar.workspace.empty-color-description")
    currentKey: valueEmptyColor
    onSelected: key => { valueEmptyColor = key; saveSettings(); }
  }
}
