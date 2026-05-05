import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

// One workspace group: border rectangle + row/column of window entries
Item {
  id: root

  required property var workspaceModel

  // Layout
  required property bool isVertical
  required property real barHeight
  required property real capsuleHeight
  required property real barFontSize
  required property real baseItemSize
  required property int itemSpacing

  // Taskbar options
  required property bool showTitle
  required property int titleWidth
  required property bool colorizeIcons
  required property real unfocusedIconsOpacity
  required property bool showPinnedApps

  // Workspace visuals
  required property real groupedBorderOpacity
  required property string focusedColor
  required property string occupiedColor
  required property string emptyColor
  required property bool showWorkspaceBadge
  required property string labelMode
  required property int characterCount

  // Misc
  required property int iconRevision
  required property int windowRevision
  required property real masterProgress
  required property bool effectsActive
  required property color effectColor

  // Reference to the parent WorkspaceTaskbar for direct context menu calls
  property var taskbarRoot: null

  // Live windows for this workspace
  property var liveWindows: []
  property var livePinnedApps: []

  function updateWindows() {
    var wsId = workspaceModel ? workspaceModel.id : undefined;
    if (wsId !== undefined && wsId !== null) {
      var wins = CompositorService.getWindowsForWorkspace(wsId);
      liveWindows = wins;
      if (root.showPinnedApps) {
        var pinnedApps = Settings.data.dock.pinnedApps || [];
        var runningAppIds = wins.map(function(w) { return (w.appId || "").toLowerCase(); });
        var pinned = [];
        pinnedApps.forEach(function(appId) {
          if (!runningAppIds.includes(appId.toLowerCase()))
            pinned.push({ appId: appId, isPinnedOnly: true });
        });
        livePinnedApps = pinned;
      } else {
        livePinnedApps = [];
      }
    } else {
      liveWindows = [];
      livePinnedApps = [];
    }
  }

  Component.onCompleted: Qt.callLater(updateWindows)
  onWorkspaceModelChanged: Qt.callLater(updateWindows)
  onWindowRevisionChanged: Qt.callLater(updateWindows)
  onShowPinnedAppsChanged: Qt.callLater(updateWindows)

  property bool hasWindows: liveWindows.length > 0 || livePinnedApps.length > 0

  // Single entry content width
  readonly property real entryWidth: showTitle ? baseItemSize + itemSpacing + titleWidth : baseItemSize
  readonly property real entryHeight: isVertical ? baseItemSize : capsuleHeight

  // Group outer size
  readonly property int innerPad: Style.marginM
  readonly property int totalEntries: liveWindows.length + livePinnedApps.length
  readonly property real groupInnerW: isVertical
    ? (hasWindows ? entryWidth : baseItemSize) + innerPad * 2
    : totalEntries * (entryWidth + itemSpacing) - (totalEntries > 0 ? itemSpacing : 0) + innerPad * 2
  readonly property real groupInnerH: isVertical
    ? totalEntries * (entryHeight + itemSpacing) - (totalEntries > 0 ? itemSpacing : 0) + innerPad * 2
    : (hasWindows ? entryHeight : baseItemSize) + innerPad * 2

  width: isVertical ? barHeight : Math.max(groupInnerW, baseItemSize + innerPad * 2)
  height: isVertical ? Math.max(groupInnerH, baseItemSize + innerPad * 2) : barHeight

  Behavior on width { NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic } }
  Behavior on height { NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic } }

  HoverHandler { id: groupHover }

  // ── Group border rectangle ──
  Rectangle {
    id: groupRect
    anchors.centerIn: parent
    width: root.isVertical ? root.baseItemSize + root.innerPad * 2 : root.groupInnerW
    height: root.isVertical ? root.groupInnerH : root.capsuleHeight
    radius: Style.radiusS
    color: "transparent"
    border.color: Qt.alpha(
      workspaceModel.isFocused ? Color.resolveColorKey(root.focusedColor)
        : (groupHover.hovered ? Color.mHover : Color.mOutline),
      root.groupedBorderOpacity)
    border.width: Style.borderS

    Behavior on border.color { ColorAnimation { duration: Style.animationFast } }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onPressed: mouse => {
        if (mouse.button === Qt.LeftButton) {
          CompositorService.switchToWorkspace(workspaceModel);
        } else if (mouse.button === Qt.RightButton) {
          // Right-click on empty group area: only widget settings
          if (root.taskbarRoot) {
            root.taskbarRoot.selectedWindowId = "";
            root.taskbarRoot.selectedAppId = "";
            root.taskbarRoot.openTaskbarContextMenu(groupRect);
          }
        }
      }
    }

    // ── Windows row/column ──
    Flow {
      id: windowsFlow
      anchors.centerIn: parent
      spacing: root.itemSpacing
      flow: root.isVertical ? Flow.TopToBottom : Flow.LeftToRight

      // Running windows
      Repeater {
        model: liveWindows
        delegate: WorkspaceTaskbarEntry {
          required property var modelData
          window: modelData
          pinnedAppId: ""
          isPinnedOnly: false
          isVertical: root.isVertical
          baseItemSize: root.baseItemSize
          capsuleHeight: root.capsuleHeight
          barFontSize: root.barFontSize
          titleWidth: root.titleWidth
          showTitle: root.showTitle
          colorizeIcons: root.colorizeIcons
          unfocusedIconsOpacity: root.unfocusedIconsOpacity
          iconRevision: root.iconRevision
          onEntryClicked: {}
          onEntryRightClicked: function(item) {
            if (root.taskbarRoot) {
              root.taskbarRoot.selectedWindowId = modelData.id || "";
              root.taskbarRoot.selectedAppId = modelData.appId || "";
              root.taskbarRoot.openTaskbarContextMenu(item);
            }
          }
        }
      }

      // Pinned-only apps
      Repeater {
        model: livePinnedApps
        delegate: WorkspaceTaskbarEntry {
          required property var modelData
          window: null
          pinnedAppId: modelData.appId
          isPinnedOnly: true
          isVertical: root.isVertical
          baseItemSize: root.baseItemSize
          capsuleHeight: root.capsuleHeight
          barFontSize: root.barFontSize
          titleWidth: root.titleWidth
          showTitle: root.showTitle
          colorizeIcons: root.colorizeIcons
          unfocusedIconsOpacity: root.unfocusedIconsOpacity
          iconRevision: root.iconRevision
          onEntryClicked: {}
          onEntryRightClicked: function(item) {
            if (root.taskbarRoot) {
              root.taskbarRoot.selectedWindowId = "";
              root.taskbarRoot.selectedAppId = modelData.appId || "";
              root.taskbarRoot.openTaskbarContextMenu(item);
            }
          }
        }
      }
    }
  }

  // ── Workspace badge (number/name label) ──
  Item {
    id: badge
    visible: root.showWorkspaceBadge && root.labelMode !== "none" && (root.hasWindows || workspaceModel.isFocused)
    anchors.left: groupRect.left
    anchors.top: groupRect.top
    anchors.leftMargin: -Style.fontSizeXS * 0.3
    anchors.topMargin: -Style.fontSizeXS * 0.3

    width: Math.max(badgeLabel.implicitWidth + Style.margin2XS, Style.fontSizeXXS * 2)
    height: Math.max(badgeLabel.implicitHeight + Style.marginXS, Style.fontSizeXXS * 2)

    Rectangle {
      anchors.fill: parent
      radius: Math.min(Style.radiusL, width / 2)
      color: workspaceModel.isFocused ? Color.resolveColorKey(root.focusedColor)
           : workspaceModel.isUrgent ? Color.mError
           : root.hasWindows ? Color.resolveColorKey(root.occupiedColor)
           : Color.resolveColorKey(root.emptyColor)
      Behavior on color { enabled: !Color.isTransitioning; ColorAnimation { duration: Style.animationFast } }
    }

    // Burst ring
    Rectangle {
      anchors.centerIn: parent
      width: parent.width + 12 * root.masterProgress
      height: parent.height + 12 * root.masterProgress
      radius: width / 2
      color: "transparent"
      border.color: root.effectColor
      border.width: Math.max(1, Math.round(2 + 4 * (1.0 - root.masterProgress)))
      opacity: root.effectsActive && workspaceModel.isFocused ? (1.0 - root.masterProgress) * 0.7 : 0
      visible: root.effectsActive && workspaceModel.isFocused
    }

    NText {
      id: badgeLabel
      anchors.centerIn: parent
      text: {
        if (workspaceModel.name && workspaceModel.name.length > 0) {
          if (root.labelMode === "name") return workspaceModel.name.substring(0, root.characterCount);
          if (root.labelMode === "index+name") return workspaceModel.idx + workspaceModel.name.substring(0, 1);
        }
        return workspaceModel.idx.toString();
      }
      family: Settings.data.ui.fontFixed
      font { pointSize: barFontSize * 0.6; weight: Font.Bold; capitalization: Font.AllUppercase }
      applyUiScale: false
      color: workspaceModel.isFocused ? Color.resolveOnColorKey(root.focusedColor)
           : workspaceModel.isUrgent ? Color.mOnError
           : root.hasWindows ? Color.resolveOnColorKey(root.occupiedColor)
           : Color.resolveOnColorKey(root.emptyColor)
      Behavior on color { enabled: !Color.isTransitioning; ColorAnimation { duration: Style.animationFast } }
    }
  }
}
