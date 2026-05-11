import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Services.Compositor
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Item {
  id: dockContentRoot
  required property var dockRoot
  required property int extraTop
  required property int extraBottom
  required property int extraLeft
  required property int extraRight
  property alias dockContainer: dockContainer
  readonly property bool isAttachedMode: Settings.data.dock.dockType === "attached"
  readonly property string tooltipDirection: dockRoot.dockPosition === "left" ? "right" : (dockRoot.dockPosition === "right" ? "left" : (dockRoot.dockPosition === "top" ? "bottom" : "top"))

  // Revision counter - incremented when CompositorService reports window list changes
  // Used to force reactive re-evaluation of liveWindows in each app delegate
  property int windowRevision: 0

  // Wheel scroll state
  property int wheelAccumulatedDelta: 0
  property bool wheelCooldown: false

  Timer {
    id: wheelDebounce
    interval: 150
    repeat: false
    onTriggered: {
      dockContentRoot.wheelCooldown = false;
      dockContentRoot.wheelAccumulatedDelta = 0;
    }
  }

  // React to window list changes from the compositor
  Connections {
    target: CompositorService
    function onWindowListChanged() {
      dockContentRoot.windowRevision++;
    }
    function onActiveWindowChanged() {
      dockContentRoot.windowRevision++;
    }
  }

  // WheelHandler at dockContentRoot level — completely outside the Flickable.
  // Same as Workspace.qml: scroll = move focus left/right through the scrolling layout.
  WheelHandler {
    id: dockWheelHandler
    target: dockContentRoot
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    grabPermissions: PointerHandler.CanTakeOverFromAnything
    onWheel: function(event) {
      if (dockContentRoot.wheelCooldown)
        return;

      var dy = event.angleDelta.y;
      var dx = event.angleDelta.x;
      var delta = Math.abs(dy) >= Math.abs(dx) ? dy : dx;
      dockContentRoot.wheelAccumulatedDelta += delta;

      if (Math.abs(dockContentRoot.wheelAccumulatedDelta) >= 120) {
        var direction = dockContentRoot.wheelAccumulatedDelta > 0 ? -1 : 1;
        if (Settings.data.general.reverseScroll)
          direction *= -1;

        CompositorService.scrollWorkspaceContent(direction);

        dockContentRoot.wheelCooldown = true;
        wheelDebounce.restart();
        dockContentRoot.wheelAccumulatedDelta = 0;
        event.accepted = true;
      }
    }
  }

  Rectangle {
    id: dockContainer
    // For vertical dock, swap width and height logic
    width: dockRoot.isVertical ? Math.round(dockRoot.iconSize * 1.5) : Math.min(dockLayout.implicitWidth + Style.marginXL, dockRoot.maxWidth)
    height: dockRoot.isVertical ? Math.min(dockLayout.implicitHeight + Style.marginXL, dockRoot.maxHeight) : Math.round(dockRoot.iconSize * 1.5)
    color: Qt.alpha(Color.mSurface, (isAttachedMode ? 0 : Color.adaptiveOpacity(Settings.data.dock.backgroundOpacity)))

    // Anchor based on padding to achieve centering shift
    anchors.horizontalCenter: extraLeft > 0 || extraRight > 0 ? undefined : parent.horizontalCenter
    anchors.right: extraLeft > 0 ? parent.right : undefined
    anchors.left: extraRight > 0 ? parent.left : undefined

    anchors.verticalCenter: extraTop > 0 || extraBottom > 0 ? undefined : parent.verticalCenter
    anchors.bottom: extraTop > 0 ? parent.bottom : undefined
    anchors.top: extraBottom > 0 ? parent.top : undefined

    radius: Style.radiusL
    border.width: 0
    border.color: "transparent"

    MouseArea {
      id: dockMouseArea
      anchors.fill: parent
      hoverEnabled: true

      onEntered: {
        dockRoot.dockHovered = true;
        if (dockRoot.autoHide) {
          dockRoot.showTimer.stop();
          dockRoot.hideTimer.stop();
          dockRoot.unloadTimer.stop(); // Cancel unload if hovering
          dockRoot.hidden = false; // Make sure dock is visible
        }
      }

      onExited: {
        dockRoot.dockHovered = false;
        if (dockRoot.autoHide && !dockRoot.anyAppHovered && !dockRoot.peekHovered && !dockRoot.menuHovered && dockRoot.dragSourceIndex === -1) {
          dockRoot.hideTimer.restart();
        }
      }

      onClicked: {
        // Close any open context menu when clicking on the dock background
        dockRoot.closeAllContextMenus();
      }
    }

    Flickable {
      id: dock
      // Use parent dimensions more directly to avoid clipping
      width: dockRoot.isVertical ? parent.width : Math.min(dockLayout.implicitWidth, parent.width - Style.marginXL)
      height: !dockRoot.isVertical ? parent.height : Math.min(dockLayout.implicitHeight, parent.height - Style.marginXL)
      contentWidth: dockLayout.implicitWidth
      contentHeight: dockLayout.implicitHeight
      anchors.centerIn: parent
      clip: false

      flickableDirection: dockRoot.isVertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick

      // Keep interactive dependent on overflow
      interactive: dockRoot.isVertical ? contentHeight > height : contentWidth > width

      // Centering margins
      contentX: dockRoot.isVertical && contentWidth < width ? (contentWidth - width) / 2 : 0
      contentY: !dockRoot.isVertical && contentHeight < height ? (contentHeight - height) / 2 : 0

      // No WheelHandler here — all scroll events are handled by
      // dockWheelHandler at dockContentRoot level (scrollWorkspaceContent).

      ScrollBar.horizontal: ScrollBar {
        visible: !dockRoot.isVertical && dock.interactive
        policy: ScrollBar.AsNeeded
      }
      ScrollBar.vertical: ScrollBar {
        visible: dockRoot.isVertical && dock.interactive
        policy: ScrollBar.AsNeeded
      }

      function getAppIcon(appData): string {
        if (!appData || !appData.appId)
          return "";
        return ThemeIcons.iconForAppId(appData.appId?.toLowerCase());
      }

      // ---------------------------------------------------------------
      // getWindowsForApp: returns CompositorService window objects (with .id)
      // for the given appId. These are the objects Workspace.qml passes
      // directly to CompositorService.focusWindow().
      // Results are sorted by screen X then Y (same as HyprlandService.toSortedWindowList).
      // ---------------------------------------------------------------
      function getWindowsForApp(appId) {
        if (!appId || !CompositorService || !CompositorService.windows)
          return [];

        const normalized = appId.toLowerCase().trim();
        const result = [];
        for (let i = 0; i < CompositorService.windows.count; i++) {
          const win = CompositorService.windows.get(i);
          if (win && win.appId && win.appId.toLowerCase().trim() === normalized) {
            result.push({
                           id: win.id,
                           title: win.title,
                           appId: win.appId,
                           isFocused: win.isFocused,
                           workspaceId: win.workspaceId,
                           x: win.x || 0,
                           y: win.y || 0
                         });
          }
        }

        // Sort by position: X first, then Y (left-to-right, top-to-bottom)
        result.sort((a, b) => {
          if (a.x !== b.x) return a.x - b.x;
          return a.y - b.y;
        });

        return result;
      }

      // Keep getValidToplevels for compatibility with existing code that uses
      // Wayland toplevels (e.g. drag-and-drop, close via middle-click)
      function getValidToplevels(appData) {
        if (!appData || !ToplevelManager || !ToplevelManager.toplevels)
          return [];
        const source = appData.toplevels && appData.toplevels.length > 0 ? appData.toplevels : (appData.toplevel ? [appData.toplevel] : []);
        const allToplevels = ToplevelManager.toplevels.values || [];
        return source.filter(toplevel => toplevel && allToplevels.includes(toplevel));
      }

      // Returns the primary Wayland toplevel for an app — used only for middle-click close
      function getPrimaryToplevel(appData) {
        const toplevels = getValidToplevels(appData);
        if (toplevels.length === 0)
          return null;
        if (ToplevelManager && ToplevelManager.activeToplevel && toplevels.includes(ToplevelManager.activeToplevel))
          return ToplevelManager.activeToplevel;
        return toplevels[0];
      }

      function launchAppById(appId) {
        if (!appId)
          return;

        const app = ThemeIcons.findAppEntry(appId);
        if (!app) {
          Logger.w("Dock", `Could not find desktop entry for pinned app: ${appId}`);
          return;
        }

        if (Settings.data.appLauncher.customLaunchPrefixEnabled && Settings.data.appLauncher.customLaunchPrefix.trim() !== "") {
          const prefix = Settings.data.appLauncher.customLaunchPrefix.trim().split(" ");

          if (app.runInTerminal && Settings.data.appLauncher.terminalCommand.trim() !== "") {
            const terminal = Settings.data.appLauncher.terminalCommand.trim().split(" ");
            const command = prefix.concat(terminal.concat(app.command));
            Quickshell.execDetached(command);
          } else {
            const command = prefix.concat(app.command);
            Quickshell.execDetached(command);
          }
        } else {
          if (app.runInTerminal && Settings.data.appLauncher.terminalCommand.trim() !== "") {
            Logger.d("Dock", "Executing terminal app manually: " + app.name);
            const terminal = Settings.data.appLauncher.terminalCommand.trim().split(" ");
            const command = terminal.concat(app.command);
            CompositorService.spawn(command);
          } else if (app.command && app.command.length > 0) {
            CompositorService.spawn(app.command);
          } else if (app.execute) {
            app.execute();
          } else {
            Logger.w("Dock", `Could not launch: ${app.name}. No valid launch method.`);
          }
        }
      }

      // Grid positioner: supports move transitions for smooth icon reordering
      // and avoids Flow's wrapping problem.
      Grid {
        id: dockLayout
        // Horizontal: many columns (single row). Vertical: 1 column (single column).
        columns: dockRoot.isVertical ? 1 : 100
        spacing: Style.marginS

        // Smooth slide animation when icons swap positions
        move: Transition {
          NumberAnimation {
            properties: "x, y"
            duration: Style.animationNormal || 250
            easing.type: Easing.OutCubic
          }
        }

        Component {
          id: launcherButtonComponent

          Item {
            id: launcherButton
            anchors.fill: parent
            readonly property string screenName: dockRoot.modelData ? dockRoot.modelData.name : (dockRoot.screen ? dockRoot.screen.name : "")
            readonly property var launcherWidgetSettings: {
              const widgetsBySection = screenName ? Settings.getBarWidgetsForScreen(screenName) : Settings.data.bar.widgets;
              if (!widgetsBySection)
                return {};
              const sections = ["left", "center", "right"];
              for (let i = 0; i < sections.length; i++) {
                const sectionWidgets = widgetsBySection[sections[i]] || [];
                for (let j = 0; j < sectionWidgets.length; j++) {
                  const widget = sectionWidgets[j];
                  if (widget && widget.id === "Launcher")
                    return widget;
                }
              }
              return {};
            }
            readonly property string launcherWidgetSection: {
              const widgetsBySection = screenName ? Settings.getBarWidgetsForScreen(screenName) : Settings.data.bar.widgets;
              if (!widgetsBySection)
                return "";
              const sections = ["left", "center", "right"];
              for (let i = 0; i < sections.length; i++) {
                const sectionWidgets = widgetsBySection[sections[i]] || [];
                for (let j = 0; j < sectionWidgets.length; j++) {
                  const widget = sectionWidgets[j];
                  if (widget && widget.id === "Launcher")
                    return sections[i];
                }
              }
              return "";
            }
            readonly property int launcherWidgetIndex: {
              const widgetsBySection = screenName ? Settings.getBarWidgetsForScreen(screenName) : Settings.data.bar.widgets;
              if (!widgetsBySection)
                return -1;
              const sections = ["left", "center", "right"];
              for (let i = 0; i < sections.length; i++) {
                const sectionWidgets = widgetsBySection[sections[i]] || [];
                for (let j = 0; j < sectionWidgets.length; j++) {
                  const widget = sectionWidgets[j];
                  if (widget && widget.id === "Launcher")
                    return j;
                }
              }
              return -1;
            }
            readonly property var launcherMetadata: BarWidgetRegistry.widgetMetadata["Launcher"]
            readonly property string launcherIcon: {
              if (Settings.data.dock.launcherIcon !== undefined && Settings.data.dock.launcherIcon !== "")
                return Settings.data.dock.launcherIcon;
              if (launcherWidgetSettings.icon !== undefined && launcherWidgetSettings.icon !== "")
                return launcherWidgetSettings.icon;
              return (launcherMetadata && launcherMetadata.icon) ? launcherMetadata.icon : "search";
            }
            readonly property string launcherIconColorKey: {
              if (Settings.data.dock.launcherIconColor !== undefined)
                return Settings.data.dock.launcherIconColor;
              if (launcherWidgetSettings.iconColor !== undefined)
                return launcherWidgetSettings.iconColor;
              if (launcherMetadata && launcherMetadata.iconColor !== undefined)
                return launcherMetadata.iconColor;
              return "none";
            }
            readonly property bool launcherUseDistroLogo: {
              if (Settings.data.dock.launcherUseDistroLogo !== undefined)
                return Settings.data.dock.launcherUseDistroLogo;
              if (launcherWidgetSettings.useDistroLogo !== undefined)
                return launcherWidgetSettings.useDistroLogo;
              if (launcherMetadata && launcherMetadata.useDistroLogo !== undefined)
                return launcherMetadata.useDistroLogo;
              return false;
            }

            Item {
              id: launcherIconContainer
              width: dockRoot.iconSize
              height: dockRoot.iconSize
              anchors.centerIn: parent

              scale: launcherMouseArea.containsMouse ? 1.15 : 1.0
              Behavior on scale {
                NumberAnimation {
                  duration: Style.animationNormal
                  easing.type: Easing.OutBack
                  easing.overshoot: 1.2
                }
              }

              NIcon {
                anchors.centerIn: parent
                icon: launcherButton.launcherIcon
                pointSize: dockRoot.iconSize * 0.7
                color: Color.resolveColorKey(launcherButton.launcherIconColorKey)
                visible: !launcherButton.launcherUseDistroLogo
              }

              IconImage {
                anchors.centerIn: parent
                width: dockRoot.iconSize * 0.8
                height: width
                source: launcherButton.launcherUseDistroLogo ? HostService.osLogo : ""
                visible: source !== ""
                smooth: true
                asynchronous: true
                layer.enabled: visible
                layer.effect: ShaderEffect {
                  property color targetColor: Color.resolveColorKey(launcherButton.launcherIconColorKey)
                  property real colorizeMode: 2.0

                  fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
                }
              }
            }

            MouseArea {
              id: launcherMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

              onEntered: {
                dockRoot.anyAppHovered = true;
                TooltipService.show(launcherButton, I18n.tr("actions.open-launcher"), tooltipDirection);
                if (dockRoot.autoHide) {
                  dockRoot.showTimer.stop();
                  dockRoot.hideTimer.stop();
                  dockRoot.unloadTimer.stop();
                  dockRoot.hidden = false;
                }
              }

              onExited: {
                dockRoot.anyAppHovered = false;
                TooltipService.hide();
                if (dockRoot.autoHide && !dockRoot.dockHovered && !dockRoot.peekHovered && !dockRoot.menuHovered && dockRoot.dragSourceIndex === -1) {
                  dockRoot.hideTimer.restart();
                }
              }

              onClicked: mouse => {
                           const targetScreen = dockRoot.modelData || dockRoot.screen || null;
                           if (!targetScreen) {
                             return;
                           }

                           if (mouse.button === Qt.RightButton) {
                             if (dockRoot.currentContextMenu === launcherContextMenu && launcherContextMenu.visible) {
                               dockRoot.closeAllContextMenus();
                               return;
                             }
                             dockRoot.closeAllContextMenus();
                             TooltipService.hideImmediately();
                             launcherContextMenu.show(launcherButton, null, targetScreen);
                             return;
                           }

                           if (mouse.button === Qt.LeftButton || mouse.button === Qt.MiddleButton) {
                             dockRoot.closeAllContextMenus();
                             PanelService.toggleLauncher(targetScreen);
                           }
                         }
            }

            DockMenu {
              id: launcherContextMenu
              dockPosition: dockRoot.dockPosition
              menuMode: "launcher"
              launcherWidgetSection: launcherButton.launcherWidgetSection
              launcherWidgetIndex: launcherButton.launcherWidgetIndex
              launcherWidgetSettings: launcherButton.launcherWidgetSettings

              onHoveredChanged: {
                if (dockRoot.currentContextMenu === launcherContextMenu && launcherContextMenu.visible) {
                  dockRoot.menuHovered = hovered;
                } else {
                  dockRoot.menuHovered = false;
                }
              }

              Connections {
                target: launcherContextMenu
                function onRequestClose() {
                  dockRoot.currentContextMenu = null;
                  dockRoot.hideTimer.stop();
                  launcherContextMenu.hide();
                  dockRoot.menuHovered = false;
                  dockRoot.anyAppHovered = false;
                }
              }

              onVisibleChanged: {
                if (visible) {
                  dockRoot.currentContextMenu = launcherContextMenu;
                } else if (dockRoot.currentContextMenu === launcherContextMenu) {
                  dockRoot.currentContextMenu = null;
                  dockRoot.hideTimer.stop();
                  dockRoot.menuHovered = false;
                  if (dockRoot.autoHide && !dockRoot.dockHovered && !dockRoot.anyAppHovered && !dockRoot.peekHovered && !dockRoot.menuHovered) {
                    dockRoot.hideTimer.restart();
                  }
                }
              }
            }
          }
        }

        Loader {
          id: launcherButtonStart
          active: Settings.data.dock.showLauncherIcon && Settings.data.dock.launcherPosition === "start"
          visible: active
          sourceComponent: launcherButtonComponent
          readonly property real indicatorMargin: Math.max(3, Math.round(dockRoot.iconSize * 0.18))
          width: active ? (dockRoot.isVertical ? dockRoot.iconSize + indicatorMargin * 2 : dockRoot.iconSize) : 0
          height: active ? (dockRoot.isVertical ? dockRoot.iconSize : dockRoot.iconSize + indicatorMargin * 2) : 0
        }

        Repeater {
          model: dockRoot.dockApps

          delegate: Item {
            id: appButton
            readonly property real indicatorMargin: Math.max(3, Math.round(dockRoot.iconSize * 0.18))
            width: dockRoot.isVertical ? dockRoot.iconSize + indicatorMargin * 2 : dockRoot.iconSize
            height: dockRoot.isVertical ? dockRoot.iconSize : dockRoot.iconSize + indicatorMargin * 2

            // --- liveWindows: CompositorService window objects for this app ---
            // Same pattern as Workspace.qml's groupedContainer.liveWindows.
            // These objects have .id, .isFocused, .x, .y and can be passed
            // DIRECTLY to CompositorService.focusWindow().
            property var liveWindows: []

            function updateLiveWindows() {
              if (!modelData || !modelData.appId) {
                liveWindows = [];
                return;
              }

              const allWins = dock.getWindowsForApp(modelData.appId);

              // If this dock entry represents a specific toplevel (ungrouped mode or
              // individual instance), only include THAT window — not all of the same appId.
              // This prevents 2 Dolphin icons from both showing as "active" when only one is focused.
              if (modelData.toplevel && modelData.toplevel.address && !Settings.data.dock.groupApps) {
                const addr = modelData.toplevel.address;
                liveWindows = allWins.filter(w => w.id === addr);
              } else {
                liveWindows = allWins;
              }
            }

            Component.onCompleted: Qt.callLater(updateLiveWindows)

            Connections {
              target: dockContentRoot
              function onWindowRevisionChanged() {
                Qt.callLater(appButton.updateLiveWindows);
              }
            }

            // Keep Wayland toplevels for drag-and-drop and close (middle click)
            property var toplevels: dock.getValidToplevels(modelData)
            property bool isActive: liveWindows.some(w => w.isFocused)
            property bool hovered: appMouseArea.containsMouse
            property string appId: modelData ? modelData.appId : ""
            property int groupedCount: liveWindows.length
            property int focusedWindowIndex: {
              for (let i = 0; i < liveWindows.length; i++) {
                if (liveWindows[i].isFocused) return i;
              }
              return -1;
            }
            property string groupedIndicatorText: focusedWindowIndex >= 0 ? (focusedWindowIndex + 1) + "/" + groupedCount : groupedCount.toString()
            property string appTitle: {
              if (!modelData)
                return "";
              // Use focused window title first
              for (let i = 0; i < liveWindows.length; i++) {
                if (liveWindows[i].isFocused && liveWindows[i].title && liveWindows[i].title !== "Loading...") {
                  return liveWindows[i].title;
                }
              }
              // Fallback to first window title
              if (liveWindows.length > 0 && liveWindows[0].title) {
                return liveWindows[0].title;
              }
              return dockRoot.getAppNameFromDesktopEntry(modelData.appId) || modelData.title || modelData.appId || "";
            }
            property bool isRunning: liveWindows.length > 0
            readonly property bool baseIndicatorVisible: Settings.data.dock.inactiveIndicators ? isRunning : isActive
            readonly property bool showGroupedIndicator: Settings.data.dock.groupApps && groupedCount > 1 && isRunning

            // WheelHandler removed — now handled globally by dockWheelHandler at dockContentRoot level

            // Store index for drag-and-drop
            property int modelIndex: index
            objectName: "dockAppButton"

            DropArea {
              anchors.fill: parent
              keys: ["dock-app"]
              onEntered: function (drag) {
                if (drag.source && drag.source.objectName === "dockAppButton") {
                  dockRoot.dragTargetIndex = appButton.modelIndex;
                }
              }
              onExited: function () {
                if (dockRoot.dragTargetIndex === appButton.modelIndex) {
                  dockRoot.dragTargetIndex = -1;
                }
              }
              onDropped: function (drop) {
                dockRoot.dragSourceIndex = -1;
                dockRoot.dragTargetIndex = -1;
                if (drop.source && drop.source.objectName === "dockAppButton" && drop.source !== appButton) {
                  dockRoot.reorderApps(drop.source.modelIndex, appButton.modelIndex);
                }
              }
            }

            // Listen for the toplevel being closed
            Connections {
              target: modelData?.toplevel
              function onClosed() {
                Qt.callLater(dockRoot.updateDockApps);
              }
            }

            // Draggable container for the icon
            Item {
              id: iconContainer
              width: dockRoot.iconSize
              height: dockRoot.iconSize

              // When dragging, remove anchors so MouseArea can position it
              anchors.centerIn: dragging ? undefined : parent

              property bool dragging: appMouseArea.drag.active
              onDraggingChanged: {
                if (dragging) {
                  dockRoot.dragSourceIndex = index;
                } else {
                  // Reset if not handled by drop (e.g. dropped outside)
                  Qt.callLater(() => {
                                 if (!appMouseArea.drag.active && dockRoot.dragSourceIndex === index) {
                                   dockRoot.dragSourceIndex = -1;
                                   dockRoot.dragTargetIndex = -1;
                                 }
                               });
                }
              }

              Drag.active: dragging
              Drag.source: appButton
              Drag.hotSpot.x: width / 2
              Drag.hotSpot.y: height / 2
              Drag.keys: ["dock-app"]

              z: (dockRoot.dragSourceIndex === index) ? 1000 : ((dragging ? 1000 : (appButton.isActive ? 10 : 0)))
              scale: dragging ? 1.1 : (appButton.isActive ? 1.15 : 1.0)
              Behavior on scale {
                NumberAnimation {
                  duration: Style.animationNormal
                  easing.type: Easing.OutBack
                  easing.overshoot: 1.2
                }
              }

              // Visual shifting logic
              readonly property bool isDragged: dockRoot.dragSourceIndex === index
              property real shiftOffset: 0

              Binding on shiftOffset {
                value: {
                  if (dockRoot.dragSourceIndex !== -1 && dockRoot.dragTargetIndex !== -1 && !iconContainer.isDragged) {
                    if (dockRoot.dragSourceIndex < dockRoot.dragTargetIndex) {
                      // Dragging Forward: Items between source and target shift Backward
                      if (index > dockRoot.dragSourceIndex && index <= dockRoot.dragTargetIndex) {
                        return -1 * (dockRoot.isVertical ? dockRoot.iconSize + Style.marginS : dockRoot.iconSize + Style.marginS);
                      }
                    } else if (dockRoot.dragSourceIndex > dockRoot.dragTargetIndex) {
                      // Dragging Backward: Items between target and source shift Forward
                      if (index >= dockRoot.dragTargetIndex && index < dockRoot.dragSourceIndex) {
                        return (dockRoot.isVertical ? dockRoot.iconSize + Style.marginS : dockRoot.iconSize + Style.marginS);
                      }
                    }
                  }
                  return 0;
                }
              }

              // shiftOffset is applied as a translate for drag operations
              transform: Translate {
                x: !dockRoot.isVertical ? iconContainer.shiftOffset : 0
                y: dockRoot.isVertical ? iconContainer.shiftOffset : 0

                Behavior on x {
                  NumberAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.OutQuad
                  }
                }
                Behavior on y {
                  NumberAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.OutQuad
                  }
                }
              }

              IconImage {
                id: appIcon
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                
                anchors.verticalCenterOffset: dockRoot.isVertical ? 0 : (appButton.hovered && !iconContainer.dragging ? (dockRoot.dockPosition === "bottom" ? -dockRoot.iconSize * 0.2 : dockRoot.iconSize * 0.2) : 0)
                anchors.horizontalCenterOffset: !dockRoot.isVertical ? 0 : (appButton.hovered && !iconContainer.dragging ? (dockRoot.dockPosition === "right" ? -dockRoot.iconSize * 0.2 : dockRoot.iconSize * 0.2) : 0)
                
                Behavior on anchors.verticalCenterOffset {
                  NumberAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.OutBack
                  }
                }
                Behavior on anchors.horizontalCenterOffset {
                  NumberAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.OutBack
                  }
                }
                source: {
                  dockRoot.iconRevision; // Force re-evaluation when revision changes
                  return dock.getAppIcon(modelData);
                }
                visible: source.toString() !== ""
                smooth: true
                asynchronous: true

                // Dim pinned apps that aren't running
                opacity: appButton.isRunning ? 1.0 : Settings.data.dock.deadOpacity

                // Apply dock-specific colorization shader only to non-focused apps
                layer.enabled: !appButton.isActive && Settings.data.dock.colorizeIcons
                layer.smooth: true
                layer.effect: ShaderEffect {
                  property color targetColor: Settings.data.colorSchemes.darkMode ? Color.mOnSurface : Color.mSurfaceVariant
                  property real colorizeMode: 0.0 // Dock mode (grayscale)

                  fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
                }

                Behavior on opacity {
                  NumberAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.OutQuad
                  }
                }
              }

              // Fall back if no icon
              NIcon {
                anchors.centerIn: parent
                visible: !appIcon.visible
                icon: "question-mark"
                pointSize: dockRoot.iconSize * 0.7
                color: appButton.isActive ? Color.mPrimary : Color.mOnSurfaceVariant
                opacity: appButton.isRunning ? 1.0 : 0.6

                Behavior on opacity {
                  NumberAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.OutQuad
                  }
                }
              }
            }

            // Context menu popup
            DockMenu {
              id: contextMenu
              dockPosition: dockRoot.dockPosition // Pass dock position for menu placement
              onHoveredChanged: {
                // Only update menuHovered if this menu is current and visible
                if (dockRoot.currentContextMenu === contextMenu && contextMenu.visible) {
                  dockRoot.menuHovered = hovered;
                } else {
                  dockRoot.menuHovered = false;
                }
              }

              Connections {
                target: contextMenu
                function onRequestClose() {
                  // Clear current menu immediately to prevent hover updates
                  dockRoot.currentContextMenu = null;
                  dockRoot.hideTimer.stop();
                  contextMenu.hide();
                  dockRoot.menuHovered = false;
                  dockRoot.anyAppHovered = false;
                }
              }
              onAppClosed: dockRoot.updateDockApps // Force immediate dock update when app is closed
              onVisibleChanged: {
                if (visible) {
                  dockRoot.currentContextMenu = contextMenu;
                } else if (dockRoot.currentContextMenu === contextMenu) {
                  dockRoot.currentContextMenu = null;
                  dockRoot.hideTimer.stop();
                  dockRoot.menuHovered = false;
                  // Restart hide timer after menu closes
                  if (dockRoot.autoHide && !dockRoot.dockHovered && !dockRoot.anyAppHovered && !dockRoot.peekHovered && !dockRoot.menuHovered) {
                    dockRoot.hideTimer.restart();
                  }
                }
              }
            }

            MouseArea {
              id: appMouseArea
              objectName: "appMouseArea"
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

              // Only allow left-click dragging via axis control
              drag.target: iconContainer
              drag.axis: (pressedButtons & Qt.LeftButton) ? (dockRoot.isVertical ? Drag.YAxis : Drag.XAxis) : Drag.None


              onPressed: {
                var p1 = appButton.mapFromItem(dockContainer, 0, 0);
                var p2 = appButton.mapFromItem(dockContainer, dockContainer.width, dockContainer.height);
                drag.minimumX = p1.x;
                drag.maximumX = p2.x - iconContainer.width;
                drag.minimumY = p1.y;
                drag.maximumY = p2.y - iconContainer.height;
              }

              onReleased: {
                if (iconContainer.Drag.active) {
                  iconContainer.Drag.drop();
                }
              }

              onEntered: {
                dockRoot.anyAppHovered = true;
                const appName = appButton.appTitle || appButton.appId || "Unknown";
                const tooltipText = appName.length > 40 ? appName.substring(0, 37) + "..." : appName;
                if (!contextMenu.visible) {
                  TooltipService.show(appButton, tooltipText, tooltipDirection);
                }
                if (dockRoot.autoHide) {
                  dockRoot.showTimer.stop();
                  dockRoot.hideTimer.stop();
                  dockRoot.unloadTimer.stop(); // Cancel unload if hovering app
                  dockRoot.hidden = false; // Make sure dock is visible
                }
              }

              onExited: {
                dockRoot.anyAppHovered = false;
                TooltipService.hide();
                // Clear menuHovered if no current menu or menu not visible
                if (!dockRoot.currentContextMenu || !dockRoot.currentContextMenu.visible) {
                  dockRoot.menuHovered = false;
                }
                if (dockRoot.autoHide && !dockRoot.dockHovered && !dockRoot.peekHovered && !dockRoot.menuHovered && dockRoot.dragSourceIndex === -1) {
                  dockRoot.hideTimer.restart();
                }
              }

              onClicked: mouse => {
                           if (mouse.button === Qt.RightButton) {
                             const targetScreen = dockRoot.modelData || dockRoot.screen || null;
                             // If right-clicking on the same app with an open context menu, close it
                             if (dockRoot.currentContextMenu === contextMenu && contextMenu.visible) {
                               dockRoot.closeAllContextMenus();
                               return;
                             }
                             // Close any other existing context menu first
                             dockRoot.closeAllContextMenus();
                             // Hide tooltip when showing context menu
                             TooltipService.hideImmediately();
                             contextMenu.show(appButton, modelData, targetScreen);
                             return;
                           }

                           // Close any existing context menu for non-right-click actions
                           dockRoot.closeAllContextMenus();

                           const wins = appButton.liveWindows;
                           const primaryToplevel = dock.getPrimaryToplevel(modelData); // for close (middle click)

                           if (mouse.button === Qt.MiddleButton) {
                             if (primaryToplevel && primaryToplevel.close) {
                               primaryToplevel.close();
                               Qt.callLater(dockRoot.updateDockApps);
                             }
                           } else if (mouse.button === Qt.LeftButton) {
                             if (wins.length === 0) {
                               dock.launchAppById(modelData?.appId);
                               return;
                             }

                             if (!Settings.data.dock.groupApps || wins.length <= 1) {
                               // Single window: focus directly with no warp
                               CompositorService.focusWindow(wins[0]);
                               return;
                             }

                             const clickAction = Settings.data.dock.groupClickAction || "cycle";
                             if (clickAction === "list") {
                               const targetScreen = dockRoot.modelData || dockRoot.screen || null;
                               TooltipService.hideImmediately();
                               contextMenu.show(appButton, modelData, targetScreen, "list");
                             } else {
                               const appKey = modelData?.appId || "";
                               const state = dockRoot.groupCycleIndices || {};
                               const nextIndex = (state[appKey] || 0) % wins.length;
                               CompositorService.focusWindow(wins[nextIndex]);
                               state[appKey] = (nextIndex + 1) % wins.length;
                               dockRoot.groupCycleIndices = Object.assign({}, state);
                             }
                           }
                         }
            }

            // Active indicator - positioned at the edge of the delegate area
            Rectangle {
              visible: baseIndicatorVisible && !showGroupedIndicator
              width: dockRoot.isVertical ? dockRoot.indicatorThickness : Style.toOdd(dockRoot.iconSize * 0.25)
              height: dockRoot.isVertical ? Style.toOdd(dockRoot.iconSize * 0.25) : dockRoot.indicatorThickness
              color: appButton.isActive ? Color.mPrimary : Qt.alpha(Color.mOnSurfaceVariant, 0.4)
              radius: Style.radiusXS

              // Anchor to the edge facing the screen center
              anchors.bottom: !dockRoot.isVertical && dockRoot.dockPosition === "bottom" ? parent.bottom : undefined
              anchors.top: !dockRoot.isVertical && dockRoot.dockPosition === "top" ? parent.top : undefined
              anchors.left: dockRoot.isVertical && dockRoot.dockPosition === "left" ? parent.left : undefined
              anchors.right: dockRoot.isVertical && dockRoot.dockPosition === "right" ? parent.right : undefined

              anchors.horizontalCenter: dockRoot.isVertical ? undefined : parent.horizontalCenter
              anchors.verticalCenter: dockRoot.isVertical ? parent.verticalCenter : undefined

              // Offset slightly from the edge
              anchors.bottomMargin: !dockRoot.isVertical && dockRoot.dockPosition === "bottom" ? 2 : 0
              anchors.topMargin: !dockRoot.isVertical && dockRoot.dockPosition === "top" ? 2 : 0
              anchors.leftMargin: dockRoot.isVertical && dockRoot.dockPosition === "left" ? 2 : 0
              anchors.rightMargin: dockRoot.isVertical && dockRoot.dockPosition === "right" ? 2 : 0
            }

            Loader {
              id: groupedIndicatorLoader
              active: showGroupedIndicator
              anchors.bottom: !dockRoot.isVertical && dockRoot.dockPosition === "bottom" ? parent.bottom : undefined
              anchors.top: !dockRoot.isVertical && dockRoot.dockPosition === "top" ? parent.top : undefined
              anchors.left: dockRoot.isVertical && dockRoot.dockPosition === "left" ? parent.left : undefined
              anchors.right: dockRoot.isVertical && dockRoot.dockPosition === "right" ? parent.right : undefined
              anchors.horizontalCenter: dockRoot.isVertical ? undefined : parent.horizontalCenter
              anchors.verticalCenter: dockRoot.isVertical ? parent.verticalCenter : undefined
              anchors.bottomMargin: !dockRoot.isVertical && dockRoot.dockPosition === "bottom" ? 1 : 0
              anchors.topMargin: !dockRoot.isVertical && dockRoot.dockPosition === "top" ? 1 : 0
              anchors.leftMargin: dockRoot.isVertical && dockRoot.dockPosition === "left" ? 1 : 0
              anchors.rightMargin: dockRoot.isVertical && dockRoot.dockPosition === "right" ? 1 : 0

              sourceComponent: Settings.data.dock.groupIndicatorStyle === "dots" ? groupDotsIndicatorComponent : groupNumberIndicatorComponent
            }

            Component {
              id: groupNumberIndicatorComponent
              Rectangle {
                radius: Style.radiusS
                color: Qt.alpha(Color.mSurface, 0.9)
                border.color: Qt.alpha(Color.mOutline, 0.7)
                border.width: Style.borderS
                width: Math.max(14, numberLabel.implicitWidth + Style.marginXS)
                height: Math.max(10, numberLabel.implicitHeight + 2)

                NText {
                  id: numberLabel
                  anchors.centerIn: parent
                  text: appButton.groupedIndicatorText
                  pointSize: Style.fontSizeXS
                  color: appButton.focusedWindowIndex >= 0 ? Color.mPrimary : Color.mOnSurfaceVariant
                }
              }
            }

            Component {
              id: groupDotsIndicatorComponent
              Item {
                readonly property int maxVisibleDots: 5
                readonly property int totalCount: Math.max(0, appButton.groupedCount)
                readonly property int focusedIndex: appButton.focusedWindowIndex >= 0 ? appButton.focusedWindowIndex : 0
                readonly property int visibleCount: Math.min(totalCount, maxVisibleDots)
                readonly property int dotSize: Math.max(2, Math.round(dockRoot.iconSize * 0.1))
                readonly property int dotSpacing: Math.max(1, Math.round(dotSize * 0.7))
                readonly property int pitch: dotSize + dotSpacing
                readonly property int windowStart: {
                  if (totalCount <= maxVisibleDots)
                    return 0;
                  const centeredStart = focusedIndex - Math.floor(maxVisibleDots / 2);
                  const maxStart = totalCount - maxVisibleDots;
                  return Math.max(0, Math.min(maxStart, centeredStart));
                }
                readonly property bool hasHiddenLeft: windowStart > 0
                readonly property bool hasHiddenRight: (windowStart + visibleCount) < totalCount
                width: dockRoot.isVertical ? dotSize : (visibleCount * dotSize + Math.max(0, visibleCount - 1) * dotSpacing)
                height: dockRoot.isVertical ? (visibleCount * dotSize + Math.max(0, visibleCount - 1) * dotSpacing) : dotSize

                Repeater {
                  model: parent.visibleCount
                  delegate: Rectangle {
                    readonly property int absoluteIndex: parent.windowStart + index
                    readonly property bool isFocusedDot: appButton.focusedWindowIndex >= 0 && absoluteIndex === appButton.focusedWindowIndex
                    readonly property bool isOverflowHint: (index === 0 && parent.hasHiddenLeft) || (index === parent.visibleCount - 1 && parent.hasHiddenRight)
                    width: isOverflowHint && !isFocusedDot ? Math.max(2, Math.round(parent.dotSize * 0.72)) : parent.dotSize
                    height: width
                    radius: width / 2
                    x: dockRoot.isVertical ? Math.round((parent.dotSize - width) / 2) : (index * parent.pitch + Math.round((parent.dotSize - width) / 2))
                    y: dockRoot.isVertical ? (index * parent.pitch + Math.round((parent.dotSize - width) / 2)) : Math.round((parent.dotSize - width) / 2)
                    color: isFocusedDot ? Color.mPrimary : Qt.alpha(Color.mOutline, 0.9)
                    opacity: isOverflowHint && !isFocusedDot ? 0.55 : 1.0
                  }
                }
              }
            }
          }
        }

        Loader {
          id: launcherButtonEnd
          active: Settings.data.dock.showLauncherIcon && Settings.data.dock.launcherPosition === "end"
          visible: active
          sourceComponent: launcherButtonComponent
          readonly property real indicatorMargin: Math.max(3, Math.round(dockRoot.iconSize * 0.18))
          width: active ? (dockRoot.isVertical ? dockRoot.iconSize + indicatorMargin * 2 : dockRoot.iconSize) : 0
          height: active ? (dockRoot.isVertical ? dockRoot.iconSize : dockRoot.iconSize + indicatorMargin * 2) : 0
        }
      }
    }
  }
}
