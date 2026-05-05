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

  HoverHandler { id: hover }

  // Focus/hover pill background (only when showTitle)
  Rectangle {
    visible: showTitle && !isVertical
    anchors.centerIn: parent
    width: parent.width
    height: root.capsuleHeight
    radius: Style.radiusM
    color: hover.hovered || root.isFocused ? Color.mHover : "transparent"
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
        color: root.isFocused ? Color.mPrimary : (hover.hovered ? Color.mHover : "transparent")
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
      color: (hover.hovered || root.isFocused) ? Color.mOnHover : Color.mOnSurface
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    preventStealing: true

    onPressed: mouse => {
      if (mouse.button === Qt.LeftButton) {
        if (root.window)
          CompositorService.focusWindow(root.window);
        else if (root.pinnedAppId)
          root.entryClicked();
      } else if (mouse.button === Qt.RightButton) {
        TooltipService.hide();
        root.entryRightClicked(root);
      }
    }

    onEntered: {
      TooltipService.show(root, root.title, BarService.getTooltipDirection(null));
    }
    onExited: TooltipService.hide()
  }
}
