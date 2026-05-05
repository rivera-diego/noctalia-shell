import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

// WorkspaceTaskbar: Shows windows grouped by workspace with title text (like Taskbar)
// Based on Workspace.qml grouped mode, extended with Taskbar title/width options.
Item {
  id: root

  property ShellScreen screen

  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length)
        return widgets[sectionWidgetIndex];
    }
    return {};
  }

  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  // ── Workspace settings ──
  readonly property bool followFocusedScreen: (widgetSettings.followFocusedScreen !== undefined) ? widgetSettings.followFocusedScreen : widgetMetadata.followFocusedScreen
  readonly property bool hideUnoccupied: (widgetSettings.hideUnoccupied !== undefined) ? widgetSettings.hideUnoccupied : widgetMetadata.hideUnoccupied
  readonly property bool enableScrollWheel: (widgetSettings.enableScrollWheel !== undefined) ? widgetSettings.enableScrollWheel : widgetMetadata.enableScrollWheel
  readonly property bool reverseScroll: Settings.data.general.reverseScroll
  readonly property string focusedColor: (widgetSettings.focusedColor !== undefined) ? widgetSettings.focusedColor : widgetMetadata.focusedColor
  readonly property string occupiedColor: (widgetSettings.occupiedColor !== undefined) ? widgetSettings.occupiedColor : widgetMetadata.occupiedColor
  readonly property string emptyColor: (widgetSettings.emptyColor !== undefined) ? widgetSettings.emptyColor : widgetMetadata.emptyColor
  readonly property real groupedBorderOpacity: (widgetSettings.groupedBorderOpacity !== undefined) ? widgetSettings.groupedBorderOpacity : widgetMetadata.groupedBorderOpacity
  readonly property bool showWorkspaceBadge: (widgetSettings.showWorkspaceBadge !== undefined) ? widgetSettings.showWorkspaceBadge : widgetMetadata.showWorkspaceBadge
  readonly property string labelMode: (widgetSettings.labelMode !== undefined) ? widgetSettings.labelMode : widgetMetadata.labelMode
  readonly property int characterCount: (widgetSettings.characterCount !== undefined) ? widgetSettings.characterCount : widgetMetadata.characterCount

  // ── Taskbar settings ──
  readonly property bool showTitle: isVertical ? false : (widgetSettings.showTitle !== undefined) ? widgetSettings.showTitle : widgetMetadata.showTitle
  readonly property bool colorizeIcons: (widgetSettings.colorizeIcons !== undefined) ? widgetSettings.colorizeIcons : widgetMetadata.colorizeIcons
  readonly property real iconScale: (widgetSettings.iconScale !== undefined) ? widgetSettings.iconScale : widgetMetadata.iconScale
  readonly property bool showPinnedApps: (widgetSettings.showPinnedApps !== undefined) ? widgetSettings.showPinnedApps : widgetMetadata.showPinnedApps
  readonly property bool smartWidth: (widgetSettings.smartWidth !== undefined) ? widgetSettings.smartWidth : widgetMetadata.smartWidth
  readonly property int maxTaskbarWidthPercent: (widgetSettings.maxTaskbarWidth !== undefined) ? widgetSettings.maxTaskbarWidth : widgetMetadata.maxTaskbarWidth
  readonly property real unfocusedIconsOpacity: (widgetSettings.unfocusedIconsOpacity !== undefined) ? widgetSettings.unfocusedIconsOpacity : widgetMetadata.unfocusedIconsOpacity

  readonly property int baseItemSize: Style.toOdd(capsuleHeight * Math.max(0.1, iconScale))

  readonly property real maxTaskbarWidth: {
    if (!screen || isVertical || !smartWidth || maxTaskbarWidthPercent <= 0)
      return 0;
    var barFloating = Settings.data.bar.barType === "floating";
    var barMarginH = barFloating ? Math.ceil(Settings.data.bar.marginHorizontal) : 0;
    return Math.round((screen.width - barMarginH * 2) * (maxTaskbarWidthPercent / 100));
  }

  readonly property int titleWidth: {
    var w = (widgetSettings.titleWidth !== undefined) ? widgetSettings.titleWidth : widgetMetadata.titleWidth;
    if (smartWidth && maxTaskbarWidth > 0) {
      if (cachedWindowCount > 0) {
        var maxPer = (maxTaskbarWidth / cachedWindowCount) - baseItemSize - Style.marginS - Style.margin2M;
        w = Math.min(w, maxPer);
      }
      w = Math.max(Math.round(w), 20);
    }
    return w;
  }

  // Cached total window count to avoid binding loops
  property int cachedWindowCount: 0
  function updateCachedWindowCount() {
    var total = 0;
    for (var i = 0; i < localWorkspaces.count; i++) {
      var wsId = localWorkspaces.get(i).id;
      total += CompositorService.getWindowsForWorkspace(wsId).length;
    }
    cachedWindowCount = total;
  }

  // ── State ──
  property ListModel localWorkspaces: ListModel {}
  property int lastFocusedWorkspaceId: -1
  property real masterProgress: 0.0
  property bool effectsActive: false
  property color effectColor: Color.mPrimary
  property bool isDestroying: false
  property int iconRevision: 0
  property int windowRevision: 0
  property string selectedWindowId: ""
  property string selectedAppId: ""
  property int wheelAccumulatedDelta: 0
  property bool wheelCooldown: false

  readonly property int horizontalPadding: Style.marginS
  readonly property int groupSpacing: Style.marginS
  readonly property int itemSpacing: Style.marginXS

  signal workspaceChanged(int workspaceId, color accentColor)

  // ── Width/Height ──
  readonly property real contentWidth: {
    if (isVertical) return barHeight;
    var w = taskbarFlow.implicitWidth + horizontalPadding * 2;
    if (smartWidth && maxTaskbarWidth > 0)
      w = Math.min(w, maxTaskbarWidth);
    return Math.round(w);
  }
  readonly property real contentHeight: isVertical ? taskbarFlow.implicitHeight + horizontalPadding * 2 : barHeight;

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  // ── Helpers ──
  function normalizeAppId(appId) {
    if (!appId || typeof appId !== 'string') return "";
    return appId.toLowerCase().trim();
  }

  function isAppPinned(appId) {
    if (!appId) return false;
    const pinnedApps = Settings.data.dock.pinnedApps || [];
    return pinnedApps.some(p => normalizeAppId(p) === normalizeAppId(appId));
  }

  function toggleAppPin(appId) {
    if (!appId) return;
    let pinnedApps = (Settings.data.dock.pinnedApps || []).slice();
    const idx = pinnedApps.findIndex(p => normalizeAppId(p) === normalizeAppId(appId));
    if (idx >= 0) pinnedApps.splice(idx, 1);
    else pinnedApps.push(appId);
    Settings.data.dock.pinnedApps = pinnedApps;
  }

  function getAppName(appId) {
    if (!appId) return appId;
    try {
      if (typeof DesktopEntries !== 'undefined' && DesktopEntries.heuristicLookup) {
        const e = DesktopEntries.heuristicLookup(appId);
        if (e && e.name) return e.name;
      }
    } catch(e) {}
    return appId;
  }

  function getSelectedWindow() {
    if (!selectedWindowId) return null;
    for (var i = 0; i < CompositorService.windows.count; i++) {
      var w = CompositorService.windows.get(i);
      if (w && (w.id == selectedWindowId || w.address == selectedWindowId))
        return w;
    }
    return null;
  }

  function scheduleRefresh() {
    if (!root.isDestroying)
      Qt.callLater(root.refreshWorkspaces);
  }

  Component.onCompleted: scheduleRefresh()
  Component.onDestruction: { root.isDestroying = true; }

  onScreenChanged: scheduleRefresh()
  onScreenNameChanged: scheduleRefresh()
  onHideUnoccupiedChanged: scheduleRefresh()

  Connections {
    target: CompositorService
    function onWorkspacesChanged() { scheduleRefresh(); }
    function onWindowListChanged() { root.windowRevision++; root.updateCachedWindowCount(); scheduleRefresh(); }
    function onActiveWindowChanged() { root.windowRevision++; scheduleRefresh(); }
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.iconRevision++; }
  }

  function refreshWorkspaces() {
    var targetList = [];
    var focusedOutput = null;
    if (followFocusedScreen) {
      for (var i = 0; i < CompositorService.workspaces.count; i++) {
        const ws = CompositorService.workspaces.get(i);
        if (ws.isFocused) focusedOutput = ws.output.toLowerCase();
      }
    }
    if (screen !== null) {
      const sName = screen.name.toLowerCase();
      for (var i = 0; i < CompositorService.workspaces.count; i++) {
        const ws = CompositorService.workspaces.get(i);
        const matchesScreen = CompositorService.globalWorkspaces ||
          (followFocusedScreen && ws.output.toLowerCase() == focusedOutput) ||
          (!followFocusedScreen && ws.output.toLowerCase() == sName);
        if (!matchesScreen) continue;
        if (hideUnoccupied && !ws.isOccupied && !ws.isFocused) continue;
        targetList.push({
          id: ws.id, idx: ws.idx, name: ws.name, output: ws.output,
          isFocused: ws.isFocused, isActive: ws.isActive,
          isUrgent: ws.isUrgent, isOccupied: ws.isOccupied
        });
      }
    }
    var i = 0;
    while (i < localWorkspaces.count || i < targetList.length) {
      if (i < localWorkspaces.count && i < targetList.length) {
        if (localWorkspaces.get(i).id === targetList[i].id) {
          localWorkspaces.set(i, targetList[i]); i++;
        } else {
          localWorkspaces.remove(i);
        }
      } else if (i < localWorkspaces.count) {
        localWorkspaces.remove(i);
      } else {
        localWorkspaces.append(targetList[i]); i++;
      }
    }
    updateWorkspaceFocus();
  }

  function triggerUnifiedWave() {
    effectColor = Color.mPrimary;
    masterAnimation.restart();
  }

  function updateWorkspaceFocus() {
    for (var i = 0; i < localWorkspaces.count; i++) {
      const ws = localWorkspaces.get(i);
      if (ws.isFocused === true) {
        if (root.lastFocusedWorkspaceId !== -1 && root.lastFocusedWorkspaceId !== ws.id)
          root.triggerUnifiedWave();
        root.lastFocusedWorkspaceId = ws.id;
        root.workspaceChanged(ws.id, Color.mPrimary);
        break;
      }
    }
  }

  SequentialAnimation {
    id: masterAnimation
    PropertyAction { target: root; property: "effectsActive"; value: true }
    NumberAnimation {
      target: root; property: "masterProgress"
      from: 0.0; to: 1.0
      duration: Style.animationSlow * 2
      easing.type: Easing.OutQuint
    }
    PropertyAction { target: root; property: "effectsActive"; value: false }
    PropertyAction { target: root; property: "masterProgress"; value: 0.0 }
  }

  // ── Context menu ──
  NPopupContextMenu {
    id: contextMenu
    onTriggered: (action, item) => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      const selectedWindow = root.getSelectedWindow();
      if (action === "focus" && selectedWindow) {
        CompositorService.focusWindow(selectedWindow);
      } else if (action === "pin" && root.selectedAppId) {
        root.toggleAppPin(root.selectedAppId);
      } else if (action === "close" && selectedWindow) {
        CompositorService.closeWindow(selectedWindow);
      } else if (action === "widget-settings") {
        BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
      } else if (action.startsWith("desktop-action-") && item && item.desktopAction) {
        if (item.desktopAction.command && item.desktopAction.command.length > 0)
          Quickshell.execDetached(item.desktopAction.command);
        else if (item.desktopAction.execute)
          item.desktopAction.execute();
      }
      root.selectedWindowId = "";
      root.selectedAppId = "";
    }
  }

  // Build and show context menu imperatively (same pattern as Taskbar.qml)
  function openTaskbarContextMenu(item) {
    var items = [];
    if (root.selectedWindowId) {
      items.push({
        "label": I18n.tr("common.focus"),
        "action": "focus",
        "icon": "eye"
      });

      const isPinned = root.isAppPinned(root.selectedAppId);
      items.push({
        "label": !isPinned ? I18n.tr("common.pin") : I18n.tr("common.unpin"),
        "action": "pin",
        "icon": !isPinned ? "pin" : "unpin"
      });

      items.push({
        "label": I18n.tr("common.close"),
        "action": "close",
        "icon": "x"
      });

      if (typeof DesktopEntries !== 'undefined' && DesktopEntries.byId && root.selectedAppId) {
        const entry = (DesktopEntries.heuristicLookup) ?
          DesktopEntries.heuristicLookup(root.selectedAppId) : DesktopEntries.byId(root.selectedAppId);
        if (entry != null && entry.actions) {
          entry.actions.forEach(function(action) {
            items.push({
              "label": action.name,
              "action": "desktop-action-" + action.name,
              "icon": "chevron-right",
              "desktopAction": action
            });
          });
        }
      }
    }
    items.push({
      "label": I18n.tr("actions.widget-settings"),
      "action": "widget-settings",
      "icon": "settings"
    });

    contextMenu.model = items;
    PanelService.showContextMenu(contextMenu, root, screen, item);
  }

  // ── Scroll to switch workspaces ──
  Timer {
    id: wheelDebounce
    interval: 150
    repeat: false
    onTriggered: { root.wheelCooldown = false; root.wheelAccumulatedDelta = 0; }
  }

  WheelHandler {
    target: root
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    enabled: root.enableScrollWheel
    onWheel: function(event) {
      if (root.wheelCooldown) return;
      var dy = event.angleDelta.y, dx = event.angleDelta.x;
      var delta = Math.abs(dy) >= Math.abs(dx) ? dy : dx;
      root.wheelAccumulatedDelta += delta;
      if (Math.abs(root.wheelAccumulatedDelta) >= 120) {
        var dir = root.wheelAccumulatedDelta > 0 ? -1 : 1;
        if (root.reverseScroll) dir *= -1;
        CompositorService.scrollWorkspaceContent(dir);
        root.wheelCooldown = true;
        wheelDebounce.restart();
        root.wheelAccumulatedDelta = 0;
        event.accepted = true;
      }
    }
  }

  // ── Visual capsule ──
  Rectangle {
    id: visualCapsule
    anchors.centerIn: parent
    width: root.contentWidth
    height: root.contentHeight
    radius: Style.radiusM
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.RightButton
      onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
          root.selectedWindowId = "";
          root.selectedAppId = "";
          root.openTaskbarContextMenu(visualCapsule);
        }
      }
    }

    // ── Flow of workspace groups ──
    Flow {
      id: taskbarFlow
      x: root.isVertical ? Style.pixelAlignCenter(parent.width, width) : root.horizontalPadding
      y: root.isVertical ? root.horizontalPadding : Style.pixelAlignCenter(parent.height, height)
      spacing: root.groupSpacing
      flow: root.isVertical ? Flow.TopToBottom : Flow.LeftToRight

      Repeater {
        model: localWorkspaces
        delegate: WorkspaceTaskbarGroup {
          required property var model
          workspaceModel: model
          isVertical: root.isVertical
          barHeight: root.barHeight
          capsuleHeight: root.capsuleHeight
          barFontSize: root.barFontSize
          baseItemSize: root.baseItemSize
          titleWidth: root.titleWidth
          showTitle: root.showTitle
          colorizeIcons: root.colorizeIcons
          unfocusedIconsOpacity: root.unfocusedIconsOpacity
          showPinnedApps: root.showPinnedApps
          groupedBorderOpacity: root.groupedBorderOpacity
          focusedColor: root.focusedColor
          occupiedColor: root.occupiedColor
          emptyColor: root.emptyColor
          showWorkspaceBadge: root.showWorkspaceBadge
          labelMode: root.labelMode
          characterCount: root.characterCount
          itemSpacing: root.itemSpacing
          iconRevision: root.iconRevision
          windowRevision: root.windowRevision
          masterProgress: root.masterProgress
          effectsActive: root.effectsActive
          effectColor: root.effectColor
          taskbarRoot: root
        }
      }
    }
  }
}
