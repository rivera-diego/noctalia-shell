# Cambios Personalizados — Noctalia Shell

Referencia para reaplicar tras un pull upstream. Cada seccion es un cambio autocontenido.

---

## 1. Style.qml

Archivo: `Commons/Style.qml`

### 1.1 Altura de barra horizontal

En `defaultBarHeight`, caso `default`, cambiar `31` por `30`:

```qml
h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 33 : 30;
```

### 1.2 Propiedades reactivas de color de capsula

Agregar despues de la linea `readonly property color capsuleColor: ...`:

```qml
readonly property color capsulePrimary: Settings.data.bar.showCapsule ? Qt.alpha(Color.mPrimary, Settings.data.bar.capsuleOpacity) : "transparent"
readonly property color capsuleSecondary: Settings.data.bar.showCapsule ? Qt.alpha(Color.mSecondary, Settings.data.bar.capsuleOpacity) : "transparent"
readonly property color capsuleTertiary: Settings.data.bar.showCapsule ? Qt.alpha(Color.mTertiary, Settings.data.bar.capsuleOpacity) : "transparent"
readonly property color capsuleError: Settings.data.bar.showCapsule ? Qt.alpha(Color.mError, Settings.data.bar.capsuleOpacity) : "transparent"
readonly property color capsuleSurfaceVariant: Settings.data.bar.showCapsule ? Qt.alpha(Color.mSurfaceVariant, Settings.data.bar.capsuleOpacity) : "transparent"
readonly property color capsuleOnSurface: Settings.data.bar.showCapsule ? Qt.alpha(Color.mOnSurface, Settings.data.bar.capsuleOpacity) : "transparent"
readonly property color capsuleHover: Settings.data.bar.showCapsule ? Qt.alpha(Color.mHover, Settings.data.bar.capsuleOpacity) : "transparent"
readonly property color capsuleMPrimary: Settings.data.bar.showCapsule ? Qt.alpha(Color.mPrimary, Settings.data.bar.capsuleOpacity) : "transparent"
```

---

## 2. Color.qml

Archivo: `Commons/Color.qml`

### 2.1 Colores extra en las tres funciones resolve

Agregar estos cases **despues** de `hover` y **antes** de `white`/`black` en `resolveColorKey`, `resolveColorKeyOptional`, y `resolveOnColorKey`:

**En `resolveColorKey` y `resolveColorKeyOptional`:**

```qml
case "primary-dim":
  return Qt.color(Qt.darker(root.mPrimary, 1.8));
case "secondary-dim":
  return Qt.color(Qt.darker(root.mSecondary, 1.8));
case "tertiary-dim":
  return Qt.color(Qt.darker(root.mTertiary, 1.8));
case "error-dim":
  return Qt.color(Qt.darker(root.mError, 1.8));
case "surface-bright":
  return Qt.color(Qt.lighter(root.mSurfaceVariant, 1.6));
case "surface-tint":
  return Qt.color(Qt.tint(root.mSurfaceVariant, Qt.alpha(root.mPrimary, 0.3)));
```

**En `resolveOnColorKey`** (texto contrastante):

```qml
case "primary-dim":
  return root.mOnPrimary;
case "secondary-dim":
  return root.mOnSecondary;
case "tertiary-dim":
  return root.mOnTertiary;
case "error-dim":
  return root.mOnError;
case "surface-bright":
  return root.mOnSurface;
case "surface-tint":
  return root.mOnSurface;
```

> **Importante:** Todas las funciones resolve deben devolver objetos color, no strings. Usar `Qt.color()` para wrappear resultados de `Qt.darker()`, `Qt.lighter()`, `Qt.tint()`, y strings como `"#ffffff"`. Sin esto, `withOpacity()` falla porque `.a` es `undefined` en strings.

### 2.2 Color picker model

El `colorKeyModel` debe quedar asi (orden exacto):

```qml
readonly property var colorKeyModel: [
  { "key": "none",               "name": I18n.tr("common.none") },
  { "key": "primary",            "name": I18n.tr("common.primary") },
  { "key": "secondary",          "name": I18n.tr("common.secondary") },
  { "key": "tertiary",           "name": I18n.tr("common.tertiary") },
  { "key": "error",              "name": I18n.tr("common.error") },
  { "key": "surface-variant",    "name": "Surface Variant" },
  { "key": "on-surface-variant", "name": "On Surface Variant" },
  { "key": "outline",            "name": "Outline" },
  { "key": "hover",              "name": "Hover" },
  { "key": "primary-dim",        "name": "Primary Dim" },
  { "key": "secondary-dim",      "name": "Secondary Dim" },
  { "key": "tertiary-dim",       "name": "Tertiary Dim" },
  { "key": "error-dim",          "name": "Error Dim" },
  { "key": "surface-bright",     "name": "Surface Bright" },
  { "key": "surface-tint",       "name": "Surface Tint" },
  { "key": "white",              "name": "White" },
  { "key": "black",              "name": "Black" }
]
```

`white` y `black` siempre al final. No incluir `surface` ni `on-surface` en el model.

---

## 3. NColorChoice.qml

Archivo: `Widgets/NColorChoice.qml`

Cambiar `RowLayout` a `GridLayout` para soportar 2 filas cuando hay >8 colores.

Agregar propiedades:

```qml
readonly property int colorCount: Color.colorKeyModel.length
readonly property int rowCount: colorCount > 8 ? 2 : 1
readonly property int columnCount: rowCount === 2 ? Math.ceil(colorCount / 2) : colorCount
```

Reemplazar el `RowLayout` por:

```qml
GridLayout {
  id: colourGrid
  columns: root.columnCount
  columnSpacing: Style.marginXXS
  rowSpacing: Style.marginXXS
  // ... Repeater igual que antes
}
```

---

## 4. Persistencia de settings compartidos

Archivo: `Commons/Settings.qml`

En `upgradeWidget(widget)`, agregar excepcion para no borrar los keys de apariencia:

```qml
const sharedAppearanceKeys = ["capsuleColor", "capsuleOpacity", "borderColor", "borderOpacity"];

for (const k of Object.keys(widget)) {
  if (k === "id") continue;
  if (sharedAppearanceKeys.includes(k)) continue;
  if (!keys.includes(k)) {
    delete widget[k];
  }
}
```

---

## 5. BarPill — Override por widget

### 5.1 BarPill.qml

Archivo: `Modules/Bar/Extras/BarPill.qml`

Agregar propiedad y pasarla a horizontal y vertical:

```qml
property var appearanceSettings: ({})
```

En los dos Loaders (horizontal y vertical) agregar:

```qml
appearanceSettings: root.appearanceSettings
```

### 5.2 BarPillHorizontal.qml y BarPillVertical.qml

Archivos: `Modules/Bar/Extras/BarPillHorizontal.qml`, `BarPillVertical.qml`

Agregar despues de las propiedades custom existentes:

```qml
property var appearanceSettings: ({})

// Per-widget capsule/border overrides from shared appearance settings
readonly property string capsuleColorKey: appearanceSettings && appearanceSettings.capsuleColor !== undefined ? appearanceSettings.capsuleColor : "none"
readonly property real capsuleOpacity: appearanceSettings && appearanceSettings.capsuleOpacity !== undefined ? appearanceSettings.capsuleOpacity : 1.0
readonly property string borderColorKey: appearanceSettings && appearanceSettings.borderColor !== undefined ? appearanceSettings.borderColor : "none"
readonly property real borderOpacity: appearanceSettings && appearanceSettings.borderOpacity !== undefined ? appearanceSettings.borderOpacity : 1.0

function withOpacity(baseColor, opacity) {
  var clamped = Math.max(0.0, Math.min(1.0, opacity));
  return Qt.alpha(baseColor, clamped);
}

readonly property color resolvedCapsuleColor: capsuleColorKey !== "none" ? withOpacity(Color.resolveColorKey(capsuleColorKey), capsuleOpacity) : Style.capsuleColor
readonly property color resolvedBorderColor: borderColorKey !== "none" ? withOpacity(Color.resolveColorKey(borderColorKey), borderOpacity) : Style.capsuleBorderColor
```

Usar `resolvedCapsuleColor` como `bgColor` y `resolvedBorderColor` como border. Si el usuario define `borderColor`, forzar ancho minimo visible:

```qml
readonly property int resolvedBorderWidth: borderColorKey !== "none" ? Math.max(Style.borderS, Style.capsuleBorderWidth) : Style.capsuleBorderWidth
```

---

## 6. Widgets basados en BarPill

Agregar `appearanceSettings: root.widgetSettings` al componente `BarPill` en cada archivo:

```text
Modules/Bar/Widgets/Volume.qml
Modules/Bar/Widgets/Microphone.qml
Modules/Bar/Widgets/Battery.qml
Modules/Bar/Widgets/Brightness.qml
Modules/Bar/Widgets/Network.qml
Modules/Bar/Widgets/CustomButton.qml
Modules/Bar/Widgets/Bluetooth.qml
Modules/Bar/Widgets/VPN.qml
Modules/Bar/Widgets/KeyboardLayout.qml
Modules/Bar/Widgets/KeepAwake.qml
```

Ejemplo (en Volume.qml, dentro del BarPill):

```qml
appearanceSettings: root.widgetSettings
```

Una sola linea por widget. No duplicar propiedades.

---

## 7. Widgets con capsula propia

Estos widgets no usan `BarPill` sino rectangulos/botones propios. Cada uno necesita el bloque de override local.

### Bloque estandar (copiar en cada widget)

```qml
// Per-widget capsule/border overrides
readonly property string capsuleColorKey: widgetSettings.capsuleColor !== undefined ? widgetSettings.capsuleColor : "none"
readonly property real capsuleOpacityVal: widgetSettings.capsuleOpacity !== undefined ? widgetSettings.capsuleOpacity : 1.0
readonly property string borderColorKey: widgetSettings.borderColor !== undefined ? widgetSettings.borderColor : "none"
readonly property real borderOpacityVal: widgetSettings.borderOpacity !== undefined ? widgetSettings.borderOpacity : 1.0

function withOpacity(baseColor, opacity) {
  var clamped = Math.max(0.0, Math.min(1.0, opacity));
  return Qt.alpha(baseColor, clamped);
}

readonly property color effectiveCapsuleColor: capsuleColorKey !== "none" ? withOpacity(Color.resolveColorKey(capsuleColorKey), capsuleOpacityVal) : DEFAULT_COLOR
readonly property color effectiveBorderColor: borderColorKey !== "none" ? withOpacity(Color.resolveColorKey(borderColorKey), borderOpacityVal) : Style.capsuleBorderColor
readonly property int effectiveBorderWidth: borderColorKey !== "none" ? Math.max(Style.borderS, Style.capsuleBorderWidth) : Style.capsuleBorderWidth
```

### Color por defecto de cada widget

Reemplazar `DEFAULT_COLOR` con el fallback de cada widget:

| Widget | Archivo | DEFAULT_COLOR |
|--------|---------|---------------|
| Launcher | `Modules/Bar/Widgets/Launcher.qml` | `Style.capsuleError` |
| Clock | `Modules/Bar/Widgets/Clock.qml` | `Style.capsuleOnSurface` |
| SystemMonitor | `Modules/Bar/Widgets/SystemMonitor.qml` | `Style.capsuleSecondary` |
| Tray | `Modules/Bar/Widgets/Tray.qml` | `Style.capsulePrimary` |
| NotificationHistory | `Modules/Bar/Widgets/NotificationHistory.qml` | `Style.capsuleTertiary` |
| ControlCenter | `Modules/Bar/Widgets/ControlCenter.qml` | `Style.capsuleError` |
| Workspace | `Modules/Bar/Widgets/Workspace.qml` | `Style.capsuleColor` |
| WallpaperSelector | `Modules/Bar/Widgets/WallpaperSelector.qml` | `Style.capsuleColor` |
| Settings | `Modules/Bar/Widgets/Settings.qml` | `Style.capsuleColor` |
| DarkMode | `Modules/Bar/Widgets/DarkMode.qml` | `Style.capsuleColor` |
| NightLight | `Modules/Bar/Widgets/NightLight.qml` | `Style.capsuleColor` |
| NoctaliaPerformance | `Modules/Bar/Widgets/NoctaliaPerformance.qml` | `Style.capsuleColor` |
| PowerProfile | `Modules/Bar/Widgets/PowerProfile.qml` | `Style.capsuleColor` |
| SessionMenu | `Modules/Bar/Widgets/SessionMenu.qml` | `Style.capsuleColor` |

### Donde aplicar los colores resueltos

**Widgets tipo NIconButton** (Launcher, ControlCenter, Settings, DarkMode, NightLight, NoctaliaPerformance, PowerProfile, SessionMenu):

```qml
colorBg: effectiveCapsuleColor
colorBorder: effectiveBorderColor
colorBorderHover: effectiveBorderColor
```

> **Aviso:** NO sobrescribir `colorBgHover` ni `colorFgHover` para mantener el efecto visual predeterminado del sistema al pasar el ratón.

**Widgets tipo Rectangle** (Clock, Tray, SystemMonitor, Workspace):

```qml
color: root.effectiveCapsuleColor
border.color: root.effectiveBorderColor
border.width: root.effectiveBorderWidth
```

**Widgets tipo NIconButton sin hover border** (NotificationHistory, WallpaperSelector):

```qml
colorBg: effectiveCapsuleColor
border.color: effectiveBorderColor
border.width: effectiveBorderWidth
```

> **Importante:** Recuerda añadir `import QtQuick` al principio de cada uno de estos archivos para evitar errores de tipo `color` o `border`.

---

## 8. Workspace.qml — Cambios adicionales

Archivo: `Modules/Bar/Widgets/Workspace.qml`

### 8.1 baseItemSize y Escalado de Iconos

Para permitir que los iconos ocupen más espacio en la barra:

```diff
-  readonly property int baseItemSize: Style.toOdd(capsuleHeight * 0.85)
+  readonly property int baseItemSize: Style.toOdd(capsuleHeight * 1.10)
```

También, en el delegado del widget agrupado (`groupedContainer`), reduce el margen vertical para aprovechar el espacio:

```diff
-      width: Style.toOdd((hasWindows ? groupedIconsFlow.implicitWidth : root.iconSize) + (root.isVertical ? (root.baseItemSize - root.iconSize + Style.marginXS) : Style.marginXL))
-      height: Style.toOdd((hasWindows ? groupedIconsFlow.implicitHeight : root.iconSize) + (root.isVertical ? Style.marginL : (root.baseItemSize - root.iconSize + Style.marginXS)))
+      width: Style.toOdd((hasWindows ? groupedIconsFlow.implicitWidth : root.iconSize) + (root.isVertical ? (root.baseItemSize - root.iconSize + Style.marginXS) : Style.marginS))
+      height: Style.toOdd((hasWindows ? groupedIconsFlow.implicitHeight : root.iconSize) + (root.isVertical ? Style.marginS : (root.baseItemSize - root.iconSize + Style.marginXS)))
```

Archivo: `Modules/Panels/Settings/Bar/WidgetSettings/WorkspaceSettings.qml`

Aumentar el límite del slider de escalado de icono:

```diff
-    to: 1
+    to: 1.5
```

### 8.2 Tamaño y Posición del Índice del Workspace

Para que el número indicador y su fondo sean más compactos:

```diff
-        width: Math.max(groupedWorkspaceNumber.implicitWidth + Style.margin2XS, Style.fontSizeXXS * 2)
-        height: Math.max(groupedWorkspaceNumber.implicitHeight + Style.marginXS, Style.fontSizeXXS * 2)
+        width: Math.max(groupedWorkspaceNumber.implicitWidth + Style.marginXXXS, Style.fontSizeXXS * 1.6)
+        height: Math.max(groupedWorkspaceNumber.implicitHeight + Style.marginXXXS, Style.fontSizeXXS * 1.6)
```

Y el tamaño de la fuente:

```diff
-            pointSize: barFontSize * 0.75
+            pointSize: barFontSize * 0.8
```

Para cambiar la posición vertical del círculo indicador (más abajo):

```diff
        anchors {
          left: parent.left
          top: parent.top
          leftMargin: -Style.fontSizeXS * 0.55
-         topMargin: -Style.fontSizeXS * 0.25
+         topMargin: -Style.fontSizeXS * 0.15
        }
```

### 8.3 Factores de escala globales

Agregar propiedades:

```qml
readonly property real workspaceActiveSizeFactor: 1.0
readonly property real workspaceInactiveSizeFactor: 0.8
readonly property real groupedBadgeActiveScale: 1.2
readonly property real groupedBadgeInactiveScale: 0.65
```

### 8.4 Aplicar factores

En `getWorkspaceWidth` y `getWorkspaceHeight`:

```diff
- const factor = isActive ? 2.2 : 1;
+ const factor = isActive ? root.workspaceActiveSizeFactor : root.workspaceInactiveSizeFactor;
```

En el badge del modo agrupado:

```diff
- scale: groupedContainer.workspaceModel.isActive ? 1.0 : 0.8
+ scale: groupedContainer.workspaceModel.isActive ? root.groupedBadgeActiveScale : root.groupedBadgeInactiveScale
```

### 8.5 Capsulas en modo agrupado

Reemplazar `Style.capsuleColor` en el rectangulo `groupedContainer` tambien:

```qml
color: root.effectiveCapsuleColor
```

---

## 9. Dialog de settings de widgets

Archivo: `Modules/Panels/Settings/Bar/BarWidgetSettingsDialog.qml`

### 9.1 Propiedades de estado

Agregar junto a `settingsCache`:

```qml
property string valueCapsuleColor: "none"
property real valueCapsuleOpacity: 1.0
property string valueBorderColor: "none"
property real valueBorderOpacity: 1.0
```

### 9.2 Bloque de UI compartido

Agregar **antes** del `Loader` de settings del widget, dentro del `ColumnLayout` del `NScrollView`:

```qml
NText {
  text: "Appearance"
  pointSize: Style.fontSizeM
  font.weight: Style.fontWeightMedium
  color: Color.mOnSurface
}

NColorChoice {
  label: "Capsule Color"
  description: "Override the capsule background color for this widget"
  currentKey: root.valueCapsuleColor
  onSelected: key => { root.valueCapsuleColor = key; root.saveSharedAppearance(); }
}

NValueSlider {
  label: "Capsule Opacity"
  from: 0; to: 1; stepSize: 0.05
  value: root.valueCapsuleOpacity
  text: Math.floor(root.valueCapsuleOpacity * 100) + "%"
  onMoved: value => { root.valueCapsuleOpacity = value; root.saveSharedAppearance(); }
}

NColorChoice {
  label: "Border Color"
  description: "Override the border color for this widget"
  currentKey: root.valueBorderColor
  onSelected: key => { root.valueBorderColor = key; root.saveSharedAppearance(); }
}

NValueSlider {
  label: "Border Opacity"
  from: 0; to: 1; stepSize: 0.05
  value: root.valueBorderOpacity
  text: Math.floor(root.valueBorderOpacity * 100) + "%"
  onMoved: value => { root.valueBorderOpacity = value; root.saveSharedAppearance(); }
}

Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Color.mOutline }
```

> **Critico:** Usar `NValueSlider`, NO `NSlider`. `NSlider` es el slider raw sin label, causa error.

### 9.3 loadWidgetSettings — cargar valores compartidos

En `loadWidgetSettings()`, despues de obtener `currentWidgetData` y antes de `settingsLoader.setSource`:

```qml
valueCapsuleColor = currentWidgetData.capsuleColor !== undefined ? currentWidgetData.capsuleColor : "none";
valueCapsuleOpacity = currentWidgetData.capsuleOpacity !== undefined ? currentWidgetData.capsuleOpacity : 1.0;
valueBorderColor = currentWidgetData.borderColor !== undefined ? currentWidgetData.borderColor : "none";
valueBorderOpacity = currentWidgetData.borderOpacity !== undefined ? currentWidgetData.borderOpacity : 1.0;
```

### 9.4 saveSharedAppearance

> **Critico:** Siempre partir de `widgetData` como base para preservar el `id` del widget. Nunca usar `settingsCache` como base primario porque se inicializa como `({})` vacio (truthy pero sin id).

```qml
function saveSharedAppearance() {
  var settings = Object.assign({}, widgetData || {});
  var cache = settingsCache;
  if (cache && Object.keys(cache).length > 0) {
    Object.assign(settings, cache);
  }
  settings.capsuleColor = valueCapsuleColor;
  settings.capsuleOpacity = valueCapsuleOpacity;
  settings.borderColor = valueBorderColor;
  settings.borderOpacity = valueBorderOpacity;
  settingsCache = settings;
  saveTimer.start();
}
```

### 9.5 Merge en onSettingsChanged y saveAndClose

En `onSettingsChanged(newSettings)`, inyectar los keys compartidos antes de guardar en caché y empezar el timer.

Para evitar que los ajustes se pierdan si el usuario cierra el popup muy rápido (antes de los 150ms del timer), reescribir `saveAndClose` para hacer un guardado síncrono:

```qml
function saveAndClose() {
  if (settingsLoader.item && typeof settingsLoader.item.saveSettings === 'function') {
    settingsLoader.item.saveSettings();
  }

  if (root.settingsCache && Object.keys(root.settingsCache).length > 0) {
    root.settingsCache.capsuleColor = valueCapsuleColor;
    root.settingsCache.capsuleOpacity = valueCapsuleOpacity;
    root.settingsCache.borderColor = valueBorderColor;
    root.settingsCache.borderOpacity = valueBorderOpacity;

    root.updateWidgetSettings(root.sectionId, root.widgetIndex, root.settingsCache);
    saveTimer.stop();
  }

  root.close();
}
```

---

## 10. Clock.qml — Tamaño de fuente

Archivo: `Modules/Bar/Widgets/Clock.qml`

Se ajustó el multiplicador del tamaño base de la letra para que el reloj sea un 10% más grande en formato de una sola línea, y un 20% más grande en la primera línea del formato de dos líneas.

```diff
              Binding on pointSize {
                value: {
                  if (repeater.model.length == 1) {
                    // Single line: Full size
-                   return barFontSize;
+                   return barFontSize * 1.1;
                  } else if (repeater.model.length == 2) {
                    // Two lines: First line is bigger than the second
-                   return (index == 0) ? Math.round(barFontSize * 0.9) : Math.round(barFontSize * 0.75);
+                   return (index == 0) ? Math.round(barFontSize * 1.2) : Math.round(barFontSize * 0.75);
                  } else {
                    // More than two lines: Make it small!
                    return Math.round(barFontSize * 0.75);
                  }
                }
              }
```

---

## 11. Checklist de archivos

Al reaplicar, verificar en este orden:

| # | Archivo | Cambio |
|---|---------|--------|
| 1 | `Commons/Style.qml` | Altura 30, 8 capsule colors |
| 2 | `Commons/Color.qml` | 6 dim keys en 3 funciones + colorKeyModel |
| 3 | `Commons/Settings.qml` | sharedAppearanceKeys en upgradeWidget |
| 4 | `Widgets/NColorChoice.qml` | GridLayout 2 filas |
| 5 | `Modules/Bar/Extras/BarPill.qml` | appearanceSettings prop |
| 6 | `Modules/Bar/Extras/BarPillHorizontal.qml` | Override system completo |
| 7 | `Modules/Bar/Extras/BarPillVertical.qml` | Override system completo |
| 8 | 10× widgets BarPill | Una linea: `appearanceSettings: root.widgetSettings` |
| 9 | 14× widgets capsula propia | Bloque override + colores por defecto |
| 10 | `Modules/Bar/Widgets/Workspace.qml` | baseItemSize, factores, capsulas |
| 11 | `Modules/Panels/Settings/Bar/BarWidgetSettingsDialog.qml` | UI compartida + save/load |

---

## 12. Errores conocidos a evitar

| Error | Causa | Solucion |
|-------|-------|----------|
| Widgets se borran al cambiar color | `saveSharedAppearance` usaba `settingsCache \|\| widgetData` pero `settingsCache` es `({})` truthy sin id | Siempre partir de `widgetData` como base |
| Settings dialog no abre | Usar `NSlider` con `label` | Usar `NValueSlider` que si tiene label |
| Colores extra son negro/blanco | Keys como `on-primary` resuelven a text color (#0e0e43) | Usar `primary-dim` con `Qt.darker()` |
| Settings de apariencia se pierden tras reinicio | `upgradeWidget()` borra keys no registrados | Agregar excepcion `sharedAppearanceKeys` |
| Settings no se guardan al cerrar menú rápido | `saveAndClose` descartaba el guardado por no esperar al timer asíncrono | Combinar y guardar `root.settingsCache` síncronamente al invocar `saveAndClose` |
| "color is not a type" (error de arranque) | Al agregar `readonly property color`, el QML no tiene cargados los tipos básicos | Añadir explícitamente `import QtQuick` al inicio de *todos* los widgets modificados (ej. `DarkMode.qml`) |
| Icono de CustomButton ignora colores custom | La función interna `_getColorValue` usa un bloque de un switch fijo ignorando la paleta extendida | Borrar el switch y usar directamente `Color.resolveColorKey(colorName)` en `CustomButton.qml` |

---

## 13. Workspace vertical — Tamaño y posición

Archivo: `Modules/Bar/Widgets/Workspace.qml`

Se añadieron factores específicos para cuando la barra está en vertical (`left`/`right`) para compactar el widget y reposicionar el badge del índice.

### 13.1 Escala de tamaño en vertical

```qml
readonly property real groupedVerticalBaseItemScale: 1.02
readonly property int baseItemSize: Style.toOdd(capsuleHeight * (isVertical ? groupedVerticalBaseItemScale : 1.10))

readonly property real workspaceActiveSizeFactor: isVertical ? 0.94 : 1.0
readonly property real workspaceInactiveSizeFactor: isVertical ? 0.76 : 0.8
```

### 13.2 Badge (índice) más compacto en vertical

```qml
readonly property real groupedBadgeActiveScale: isVertical ? 1.2 : 1.2
readonly property real groupedBadgeInactiveScale: isVertical ? 0.60 : 0.65
readonly property real groupedBadgeFontScale: isVertical ? 0.8 : 0.8
readonly property real groupedBadgeMinSizeFactor: isVertical ? 1.45 : 1.6
```

Aplicación del tamaño mínimo y fuente:

```qml
width: Math.max(groupedWorkspaceNumber.implicitWidth + Style.marginXXXS, Style.fontSizeXXS * root.groupedBadgeMinSizeFactor)
height: Math.max(groupedWorkspaceNumber.implicitHeight + Style.marginXXXS, Style.fontSizeXXS * root.groupedBadgeMinSizeFactor)

font {
  pointSize: barFontSize * root.groupedBadgeFontScale
}
```

### 13.3 Posición del badge en vertical

```qml
readonly property real groupedBadgeOffsetX: isVertical ? 0.3 : 0.55
readonly property real groupedBadgeOffsetY: isVertical ? 0.08 : 0.15
```

Aplicación en márgenes:

```qml
leftMargin: -Style.fontSizeXS * root.groupedBadgeOffsetX
topMargin: -Style.fontSizeXS * root.groupedBadgeOffsetY
```

### 13.4 Padding del contenedor agrupado en vertical

```qml
width: Style.toOdd((hasWindows ? groupedIconsFlow.implicitWidth : root.iconSize) + (root.isVertical ? (root.baseItemSize - root.iconSize + Style.marginXXS) : Style.marginS))
height: Style.toOdd((hasWindows ? groupedIconsFlow.implicitHeight : root.iconSize) + (root.isVertical ? Style.marginXXS : (root.baseItemSize - root.iconSize + Style.marginXS)))
```

---

## 14. Workspace wheel en Hyprland/Niri — foco multi-direccion

Archivos:
- `Modules/Bar/Widgets/Workspace.qml`
- `Services/Compositor/HyprlandService.qml`

Objetivo: en Hyprland y Niri, la rueda del widget `Workspace` debe enfocarse entre ventanas (no cambiar workspace), disparando dos direcciones por paso para cubrir mejor escenarios multi-monitor.

### 14.1 Workspace.qml — Usar scrollWorkspaceContent solo en Hyprland

Dentro de `WheelHandler.onWheel`, reemplazar la llamada directa a `switchByOffset(direction)` por branching por compositor:

```qml
if (CompositorService.isHyprland || CompositorService.isNiri) {
  CompositorService.scrollWorkspaceContent(direction);
} else {
  root.switchByOffset(direction);
}
```

Con esto, Hyprland y Niri usan navegación interna de ventanas; el resto mantiene cambio de workspace por rueda.

### 14.2 HyprlandService.qml — scrollWorkspaceContent con pares de focus

Implementar/ajustar `scrollWorkspaceContent(direction)` para ejecutar dos dispatchers por dirección:

```qml
function scrollWorkspaceContent(direction) {
  try {
    if (direction < 0) {
      dispatchLua('hl.dsp.layout("focus r")');
      dispatchLua('hl.dsp.layout("focus u")');
    } else {
      dispatchLua('hl.dsp.layout("focus l")');
      dispatchLua('hl.dsp.layout("focus d")');
    }
  } catch (e) {
    Logger.e("HyprlandService", "Failed to scroll workspace content:", e);
  }
}
```

Mapeo final:
- `direction < 0` -> `focus r` + `focus u`
- `direction >= 0` -> `focus l` + `focus d`

### 14.3 NiriService.qml — scrollWorkspaceContent con pares de focus

Implementar/ajustar `scrollWorkspaceContent(direction)` para ejecutar dos dispatchers por dirección:

```qml
function scrollWorkspaceContent(direction) {
  try {
    if (direction < 0) {
      Niri.dispatch(["focus-column-right"]);
      Niri.dispatch(["focus-window-up"]);
    } else {
      Niri.dispatch(["focus-column-left"]);
      Niri.dispatch(["focus-window-down"]);
    }
  } catch (e) {
    Logger.e("NiriService", "Failed to scroll workspace content:", e);
  }
}
```

Mapeo final:
- `direction < 0` -> `focus-column-right` + `focus-window-up`
- `direction >= 0` -> `focus-column-left` + `focus-window-down`
