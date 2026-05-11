import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

// Single window/app entry inside a WorkspaceTaskbarGroup
Item {
  id: root

  // One of these is set
  property var window: null           // live compositor window (plain JS object from getWindowsForWorkspace)
  property string pinnedAppId: ""     // app ID for pinned-only
  property bool isPinnedOnly: false

  required property bool isVertical
  required property real baseItemSize
  required property real capsuleHeight
  required property real barFontSize
  required property bool showTitle
  required property int titleWidth
  required property bool colorizeIcons
  required property real unfocusedIconsOpacity
  required property int iconRevision
  required property string entryBgColor
  required property string titleFocusedColor
  required property string titleDefaultColor
  required property string screenName

  signal entryClicked()
  signal entryRightClicked(var item)

  readonly property string appId: window ? (window.appId || "") : pinnedAppId
  readonly property string windowId: window ? (window.id || "") : ""
  readonly property string title: window ? (window.title || appId || "App") : (appId || "App")
  readonly property bool isFocused: window ? (window.isFocused || false) : false

  readonly property real entryW: showTitle && !isVertical
    ? root.baseItemSize + Style.marginS + root.titleWidth + Style.margin2M
    : root.baseItemSize
  readonly property real entryH: isVertical ? root.baseItemSize : root.capsuleHeight

  width: entryW
  height: entryH

  property bool isHovered: false

  // Resolved pill background: user pick overrides the default hover color
  readonly property color resolvedEntryBg: {
    if (root.isHovered || root.isFocused) {
      return root.entryBgColor !== "none"
        ? Color.resolveColorKey(root.entryBgColor)
        : Color.mHover;
    }
    return "transparent";
  }

  // Focus/hover pill background (only when showTitle)
  Rectangle {
    visible: showTitle && !isVertical
    anchors.centerIn: parent
    width: parent.width
    height: root.capsuleHeight
    radius: Style.radiusM
    color: root.resolvedEntryBg
    Behavior on color { ColorAnimation { duration: Style.animationFast } }
  }

  RowLayout {
    anchors.centerIn: parent
    spacing: Style.marginS

    // Icon
    Item {
      Layout.preferredWidth: root.baseItemSize
      Layout.preferredHeight: root.baseItemSize
      Layout.alignment: Qt.AlignVCenter

      IconImage {
        id: appIcon
        anchors.fill: parent
        source: {
          root.iconRevision;
          return ThemeIcons.iconForAppId(root.appId ? root.appId.toLowerCase() : "");
        }
        smooth: true
        asynchronous: true
        opacity: root.isFocused ? Style.opacityFull : root.unfocusedIconsOpacity

        layer.enabled: root.colorizeIcons && !root.isFocused
        layer.effect: ShaderEffect {
          property color targetColor: Settings.data.colorSchemes.darkMode ? Color.mOnSurface : Color.mSurfaceVariant
          property real colorizeMode: 0
          fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
        }
      }

      // Focus indicator dot (only when not showing title)
      Rectangle {
        visible: !showTitle || isVertical
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -2
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.toOdd(root.baseItemSize * 0.25)
        height: 4
        radius: Math.min(Style.radiusXXS, width / 2)
        color: root.isFocused ? Color.mPrimary : (root.isHovered ? Color.mHover : "transparent")
        Behavior on color { ColorAnimation { duration: Style.animationFast } }
      }
    }

    // Title text
    NText {
      visible: root.showTitle && !root.isVertical
      Layout.preferredWidth: root.titleWidth
      Layout.preferredHeight: root.baseItemSize
      Layout.alignment: Qt.AlignVCenter
      text: root.title
      elide: Text.ElideRight
      verticalAlignment: Text.AlignVCenter
      horizontalAlignment: Text.AlignLeft
      pointSize: root.barFontSize
      color: (root.isHovered || root.isFocused)
        ? (root.titleFocusedColor !== "none" ? Color.resolveColorKey(root.titleFocusedColor) : Color.mOnHover)
        : (root.titleDefaultColor !== "none" ? Color.resolveColorKey(root.titleDefaultColor) : Color.mOnSurface)
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    preventStealing: true

    onContainsMouseChanged: {
      root.isHovered = containsMouse;
    }

    onPressed: mouse => {
      if (mouse.button === Qt.LeftButton) {
        if (root.window)
          CompositorService.focusWindow(root.window);
        else if (root.pinnedAppId)
          root.entryClicked();
      }
    }

    onEntered: {
      TooltipService.show(root, root.title, BarService.getTooltipDirection(root.screenName));
    }

    onExited: {
      TooltipService.hide(root);
    }

    onReleased: mouse => {
      if (mouse.button === Qt.RightButton) {
        mouse.accepted = true;
        TooltipService.hide(root);
        root.entryRightClicked(root);
      }
    }
  }
}
